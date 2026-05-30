-- =============================================================================
-- V4__migrate_to_core_schema.sql
-- EthosHub — Migrate profile entities from public.* to core.*
--
-- Scope (Flyway-safe — does NOT touch auth.* schema):
--   • Creates schema core
--   • Creates core.profile_roles, core.profiles, core.profiles_basic,
--     core.profiles_company, core.profile_moderation,
--     core.skill_tags, core.hard_skills, core.soft_skills, core.profile_skills
--   • Migrates existing data from public.profile_role / profile / profile_basic /
--     profile_company into the new core tables
--   • Creates core.sp_provision_profile and core.fn_on_auth_user_created
--   • Updates public.fn_on_auth_user_created to proxy → core.sp_provision_profile
--     (keeps auth.users trigger functional until V5 swaps it)
--   • Drops public.profile*, public.skill_tags, public.hard_skills,
--     public.soft_skills, public.profile_moderation (IF EXISTS)
--   • Drops public.fn_set_updated_at and public.sp_provision_profile
--
-- NOTE: The auth.users trigger still calls public.fn_on_auth_user_created until
--       V5__swap_core_auth_trigger.sql is applied via Supabase SQL Editor or MCP.
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. EXTENSIONS
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =============================================================================
-- 2. SCHEMA
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS core;

COMMENT ON SCHEMA core IS
    'Business domain schema for EthosHub. Contains all profile entities, '
    'skill catalogs, moderation records, and related lookup tables. '
    'Strict separation from public schema; service_role is the only writer.';

-- =============================================================================
-- 3. UTILITY TRIGGER FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.fn_set_updated_at()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SET search_path = core
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION core.fn_set_updated_at() IS
    'Generic BEFORE UPDATE trigger that stamps updated_at = NOW(). '
    'Reusable across all auditable tables in the core schema.';

-- =============================================================================
-- 4. CATALOG: core.profile_roles
-- =============================================================================

CREATE TABLE IF NOT EXISTS core.profile_roles (
    id_profile_role UUID        NOT NULL DEFAULT gen_random_uuid(),
    role_key        VARCHAR(30) NOT NULL,
    display_name    VARCHAR(50) NOT NULL,
    description     TEXT,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ,
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT pk_profile_roles     PRIMARY KEY (id_profile_role),
    CONSTRAINT uq_profile_roles_key UNIQUE      (role_key),
    CONSTRAINT ck_profile_roles_key CHECK       (role_key = LOWER(TRIM(role_key))),
    CONSTRAINT ck_profile_roles_audit CHECK     (deleted_at IS NULL OR deleted_at >= created_at)
);

COMMENT ON TABLE core.profile_roles IS
    'Lookup table for EthosHub user roles. '
    'Immutable catalog: professional, recruiter, admin. '
    'Referenced by core.profiles.id_profile_role to enforce role semantics at DB level.';
COMMENT ON COLUMN core.profile_roles.id_profile_role IS 'Surrogate PK. Stable UUID exposed as FK target.';
COMMENT ON COLUMN core.profile_roles.role_key        IS 'Machine key (lowercase snake_case). Used as FK-matching slug from JWT claims.';
COMMENT ON COLUMN core.profile_roles.display_name    IS 'Human-readable label for UI display.';
COMMENT ON COLUMN core.profile_roles.description     IS 'Extended role description for admin tooling.';
COMMENT ON COLUMN core.profile_roles.is_active       IS 'FALSE disables role assignment without data deletion.';
COMMENT ON COLUMN core.profile_roles.created_at      IS 'Immutable record creation timestamp (UTC).';
COMMENT ON COLUMN core.profile_roles.updated_at      IS 'Last modification timestamp. Set by trg_profile_roles_updated_at.';
COMMENT ON COLUMN core.profile_roles.deleted_at      IS 'Soft-delete sentinel. NULL = active.';

CREATE INDEX IF NOT EXISTS idx_profile_roles_key
    ON core.profile_roles(role_key)
    WHERE deleted_at IS NULL;
COMMENT ON INDEX core.idx_profile_roles_key IS
    'Partial index on role_key for active roles. '
    'Used in sp_provision_profile and JWT claim resolution lookups.';

-- =============================================================================
-- 5. BASE ENTITY: core.profiles
-- =============================================================================

CREATE TABLE IF NOT EXISTS core.profiles (
    id_profile      UUID         NOT NULL DEFAULT gen_random_uuid(),
    auth_id         UUID         NOT NULL,
    id_profile_role UUID         NOT NULL,
    email           VARCHAR(255) NOT NULL,
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL DEFAULT '',
    phone_number    VARCHAR(30),
    country_code    CHAR(2),
    avatar_url      TEXT,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ,
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT pk_profiles           PRIMARY KEY (id_profile),
    CONSTRAINT uq_profiles_auth_id   UNIQUE      (auth_id),
    CONSTRAINT uq_profiles_email     UNIQUE      (email),
    CONSTRAINT ck_profiles_email_fmt CHECK       (email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT ck_profiles_phone_fmt CHECK       (phone_number IS NULL OR phone_number ~* '^\+?[0-9\s\-]{7,20}$'),
    CONSTRAINT ck_profiles_cc_fmt    CHECK       (country_code IS NULL OR country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_profiles_name_len  CHECK       (char_length(trim(first_name)) >= 1),
    CONSTRAINT ck_profiles_audit     CHECK       (deleted_at IS NULL OR deleted_at >= created_at),
    CONSTRAINT fk_profiles_auth      FOREIGN KEY (auth_id)
        REFERENCES auth.users(id)            ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT fk_profiles_role      FOREIGN KEY (id_profile_role)
        REFERENCES core.profile_roles(id_profile_role) ON DELETE RESTRICT ON UPDATE CASCADE
);

COMMENT ON TABLE core.profiles IS
    'Core EthosHub profile. One row per authenticated user. '
    'Extends auth.users with business identity, contact data, and role assignment. '
    'Parent of profiles_basic (professional) and profiles_company (recruiter).';
COMMENT ON COLUMN core.profiles.id_profile      IS 'Internal profile UUID. Returned as profileId in API responses. Distinct from auth_id.';
COMMENT ON COLUMN core.profiles.auth_id         IS 'FK to auth.users(id). Supabase Auth identity anchor. CASCADE deletes profile when auth user is removed.';
COMMENT ON COLUMN core.profiles.id_profile_role IS 'FK to core.profile_roles. Business role assigned at registration; mutable only by admin.';
COMMENT ON COLUMN core.profiles.email           IS 'Denormalized copy of auth.users.email for fast lookups. Not auto-synced on email change.';
COMMENT ON COLUMN core.profiles.first_name      IS 'Given name. Minimum 1 non-blank character required.';
COMMENT ON COLUMN core.profiles.last_name       IS 'Family name. Empty string allowed for OAuth users who did not supply it.';
COMMENT ON COLUMN core.profiles.phone_number    IS 'E.164-compatible phone number including country dial prefix. Optional.';
COMMENT ON COLUMN core.profiles.country_code    IS 'ISO 3166-1 alpha-2 country code (e.g. BO, AR, US). Optional.';
COMMENT ON COLUMN core.profiles.avatar_url      IS 'Profile image URL. Set from OAuth provider or uploaded manually.';
COMMENT ON COLUMN core.profiles.is_active       IS 'FALSE suspends login without data deletion. All queries MUST filter WHERE is_active = TRUE AND deleted_at IS NULL.';
COMMENT ON COLUMN core.profiles.created_at      IS 'Record creation timestamp (UTC). Immutable.';
COMMENT ON COLUMN core.profiles.updated_at      IS 'Last modification timestamp. Set by trg_profiles_updated_at.';
COMMENT ON COLUMN core.profiles.deleted_at      IS 'Soft-delete sentinel. NULL = active. Hard delete cascades from auth.users.';

CREATE INDEX IF NOT EXISTS idx_profiles_auth_id
    ON core.profiles(auth_id);
COMMENT ON INDEX core.idx_profiles_auth_id IS
    'Supports FK lookups by auth_id on every authenticated API request.';

CREATE INDEX IF NOT EXISTS idx_profiles_email
    ON core.profiles(email);
COMMENT ON INDEX core.idx_profiles_email IS
    'Supports login lookups and duplicate-email validation during registration.';

CREATE INDEX IF NOT EXISTS idx_profiles_role_fk
    ON core.profiles(id_profile_role);
COMMENT ON INDEX core.idx_profiles_role_fk IS
    'Covers FK to core.profile_roles; avoids sequential scan on role-based joins.';

CREATE INDEX IF NOT EXISTS idx_profiles_active
    ON core.profiles(is_active, deleted_at)
    WHERE is_active = TRUE AND deleted_at IS NULL;
COMMENT ON INDEX core.idx_profiles_active IS
    'Partial index for the standard active-user filter applied on every profile read.';

CREATE INDEX IF NOT EXISTS idx_profiles_created_at
    ON core.profiles(created_at DESC);
COMMENT ON INDEX core.idx_profiles_created_at IS
    'Supports time-ordered admin listings and audit queries.';

-- =============================================================================
-- 6. PROFESSIONAL SUB-PROFILE: core.profiles_basic
-- =============================================================================

CREATE TABLE IF NOT EXISTS core.profiles_basic (
    id_profile_basic  UUID         NOT NULL DEFAULT gen_random_uuid(),
    id_profile        UUID         NOT NULL,
    headline          VARCHAR(200),
    bio               TEXT,
    location          VARCHAR(100),
    website           VARCHAR(255),
    years_experience  SMALLINT     NOT NULL DEFAULT 0,
    portfolio_url     VARCHAR(255),
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ,
    deleted_at        TIMESTAMPTZ,

    CONSTRAINT pk_profiles_basic       PRIMARY KEY (id_profile_basic),
    CONSTRAINT uq_profiles_basic_prof  UNIQUE      (id_profile),
    CONSTRAINT ck_profiles_basic_exp   CHECK       (years_experience >= 0),
    CONSTRAINT ck_profiles_basic_audit CHECK       (deleted_at IS NULL OR deleted_at >= created_at),
    CONSTRAINT fk_profiles_basic_prof  FOREIGN KEY (id_profile)
        REFERENCES core.profiles(id_profile) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON TABLE core.profiles_basic IS
    'Professional sub-profile. Created for every professional role at registration. '
    'Stores career-specific fields: headline, bio, location, website, experience. '
    'One-to-one composition with core.profiles (uq constraint).';
COMMENT ON COLUMN core.profiles_basic.id_profile_basic IS 'Surrogate PK. Distinct from id_profile to allow future table splits.';
COMMENT ON COLUMN core.profiles_basic.id_profile       IS 'FK to core.profiles. ONE-TO-ONE: unique constraint enforced.';
COMMENT ON COLUMN core.profiles_basic.headline         IS 'Short professional tagline (≤200 chars). Displayed on profile card.';
COMMENT ON COLUMN core.profiles_basic.bio              IS 'Free-text biography. No length limit enforced at DB level.';
COMMENT ON COLUMN core.profiles_basic.location         IS 'City / region label. Freeform text; not FK-bound to a geo table.';
COMMENT ON COLUMN core.profiles_basic.website          IS 'Personal or portfolio website URL.';
COMMENT ON COLUMN core.profiles_basic.years_experience IS 'Self-reported years of professional experience. Non-negative.';
COMMENT ON COLUMN core.profiles_basic.portfolio_url    IS 'Link to an external portfolio or project showcase.';
COMMENT ON COLUMN core.profiles_basic.created_at       IS 'Record creation timestamp (UTC). Immutable.';
COMMENT ON COLUMN core.profiles_basic.updated_at       IS 'Last modification timestamp. Set by trg_profiles_basic_updated_at.';
COMMENT ON COLUMN core.profiles_basic.deleted_at       IS 'Soft-delete sentinel. Cascades from parent profile deletion.';

CREATE INDEX IF NOT EXISTS idx_profiles_basic_profile
    ON core.profiles_basic(id_profile);
COMMENT ON INDEX core.idx_profiles_basic_profile IS
    'Covers the FK join from core.profiles to core.profiles_basic on profile reads.';

-- =============================================================================
-- 7. RECRUITER SUB-PROFILE: core.profiles_company
-- =============================================================================

CREATE TABLE IF NOT EXISTS core.profiles_company (
    id_profile_company  UUID         NOT NULL DEFAULT gen_random_uuid(),
    id_profile          UUID         NOT NULL,
    nit                 VARCHAR(20),
    company_name        VARCHAR(200),
    company_size        VARCHAR(50),
    industry            VARCHAR(100),
    company_website     VARCHAR(255),
    company_logo_url    TEXT,
    company_description TEXT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ,
    deleted_at          TIMESTAMPTZ,

    CONSTRAINT pk_profiles_company       PRIMARY KEY (id_profile_company),
    CONSTRAINT uq_profiles_company_prof  UNIQUE      (id_profile),
    CONSTRAINT ck_profiles_company_audit CHECK       (deleted_at IS NULL OR deleted_at >= created_at),
    CONSTRAINT fk_profiles_company_prof  FOREIGN KEY (id_profile)
        REFERENCES core.profiles(id_profile) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON TABLE core.profiles_company IS
    'Recruiter sub-profile. Created for every recruiter role at registration. '
    'Stores company identity: name, NIT, industry, size, website, logo, description. '
    'One-to-one composition with core.profiles.';
COMMENT ON COLUMN core.profiles_company.id_profile_company  IS 'Surrogate PK for the recruiter company record.';
COMMENT ON COLUMN core.profiles_company.id_profile          IS 'FK to core.profiles. ONE-TO-ONE: unique constraint enforced.';
COMMENT ON COLUMN core.profiles_company.nit                 IS 'Tax identification number (NIT). Optional; format varies by country.';
COMMENT ON COLUMN core.profiles_company.company_name        IS 'Legal company name. Displayed on recruiter cards and job posts.';
COMMENT ON COLUMN core.profiles_company.company_size        IS 'Headcount band (e.g. "1-10", "50-200"). Freeform label.';
COMMENT ON COLUMN core.profiles_company.industry            IS 'Industry sector label (e.g. "Tecnología", "Finanzas").';
COMMENT ON COLUMN core.profiles_company.company_website     IS 'Corporate website URL.';
COMMENT ON COLUMN core.profiles_company.company_logo_url    IS 'URL of the company logo image.';
COMMENT ON COLUMN core.profiles_company.company_description IS 'Free-text company overview. Used as bio equivalent for recruiter role.';
COMMENT ON COLUMN core.profiles_company.created_at          IS 'Record creation timestamp (UTC). Immutable.';
COMMENT ON COLUMN core.profiles_company.updated_at          IS 'Last modification timestamp. Set by trg_profiles_company_updated_at.';
COMMENT ON COLUMN core.profiles_company.deleted_at          IS 'Soft-delete sentinel. Cascades from parent profile deletion.';

CREATE INDEX IF NOT EXISTS idx_profiles_company_profile
    ON core.profiles_company(id_profile);
COMMENT ON INDEX core.idx_profiles_company_profile IS
    'Covers the FK join from core.profiles to core.profiles_company on profile reads.';

-- =============================================================================
-- 8. MODERATION: core.profile_moderation
-- =============================================================================

CREATE TABLE IF NOT EXISTS core.profile_moderation (
    id_profile_moderation UUID        NOT NULL DEFAULT gen_random_uuid(),
    id_profile            UUID        NOT NULL,
    moderator_auth_id     UUID,
    action                VARCHAR(30) NOT NULL,
    reason                TEXT        NOT NULL,
    notes                 TEXT,
    resolved_at           TIMESTAMPTZ,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ,
    deleted_at            TIMESTAMPTZ,

    CONSTRAINT pk_profile_moderation      PRIMARY KEY (id_profile_moderation),
    CONSTRAINT ck_pm_action               CHECK       (action IN ('suspend', 'warn', 'restore', 'ban', 'review')),
    CONSTRAINT ck_pm_reason_nonempty      CHECK       (char_length(trim(reason)) >= 1),
    CONSTRAINT ck_pm_audit                CHECK       (deleted_at IS NULL OR deleted_at >= created_at),
    CONSTRAINT ck_pm_resolved_order       CHECK       (resolved_at IS NULL OR resolved_at >= created_at),
    CONSTRAINT fk_pm_profile              FOREIGN KEY (id_profile)
        REFERENCES core.profiles(id_profile)  ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT fk_pm_moderator            FOREIGN KEY (moderator_auth_id)
        REFERENCES auth.users(id)             ON DELETE SET NULL ON UPDATE CASCADE
);

COMMENT ON TABLE core.profile_moderation IS
    'Immutable audit trail of moderation actions applied to a profile. '
    'Each row records one action (suspend, warn, restore, ban, review) by an admin. '
    'Append-only in practice; rows are soft-deleted, not physically removed.';
COMMENT ON COLUMN core.profile_moderation.id_profile_moderation IS 'Surrogate PK for the moderation record.';
COMMENT ON COLUMN core.profile_moderation.id_profile            IS 'FK to the affected profile. Cascades on profile delete.';
COMMENT ON COLUMN core.profile_moderation.moderator_auth_id     IS 'FK to the admin who executed the action. NULL if performed by an automated rule.';
COMMENT ON COLUMN core.profile_moderation.action                IS 'Moderation action type: suspend | warn | restore | ban | review.';
COMMENT ON COLUMN core.profile_moderation.reason                IS 'Mandatory human-readable justification for the action.';
COMMENT ON COLUMN core.profile_moderation.notes                 IS 'Optional internal notes visible only to admins.';
COMMENT ON COLUMN core.profile_moderation.resolved_at           IS 'Timestamp when the action was lifted or resolved. NULL = still active.';
COMMENT ON COLUMN core.profile_moderation.created_at            IS 'Record creation timestamp (UTC). Immutable.';
COMMENT ON COLUMN core.profile_moderation.updated_at            IS 'Last modification timestamp. Set by trg_profile_moderation_updated_at.';
COMMENT ON COLUMN core.profile_moderation.deleted_at            IS 'Soft-delete sentinel.';

CREATE INDEX IF NOT EXISTS idx_profile_moderation_profile
    ON core.profile_moderation(id_profile);
COMMENT ON INDEX core.idx_profile_moderation_profile IS
    'Supports listing all moderation events for a given profile.';

CREATE INDEX IF NOT EXISTS idx_profile_moderation_created
    ON core.profile_moderation(created_at DESC);
COMMENT ON INDEX core.idx_profile_moderation_created IS
    'Supports time-ordered admin moderation queue queries.';

-- =============================================================================
-- 9. SKILL CATALOG: core.skill_tags
-- =============================================================================

CREATE TABLE IF NOT EXISTS core.skill_tags (
    id_skill_tag  UUID         NOT NULL DEFAULT gen_random_uuid(),
    tag_key       VARCHAR(50)  NOT NULL,
    display_name  VARCHAR(100) NOT NULL,
    description   TEXT,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ,
    deleted_at    TIMESTAMPTZ,

    CONSTRAINT pk_skill_tags     PRIMARY KEY (id_skill_tag),
    CONSTRAINT uq_skill_tags_key UNIQUE      (tag_key),
    CONSTRAINT ck_skill_tags_key CHECK       (tag_key = LOWER(TRIM(tag_key))),
    CONSTRAINT ck_skill_tags_audit CHECK     (deleted_at IS NULL OR deleted_at >= created_at)
);

COMMENT ON TABLE core.skill_tags IS
    'Skill category/domain catalog used to classify hard and soft skills. '
    'Examples: "backend", "frontend", "leadership", "communication". '
    'Seeded by platform administrators; not user-generated.';
COMMENT ON COLUMN core.skill_tags.id_skill_tag IS 'Surrogate PK.';
COMMENT ON COLUMN core.skill_tags.tag_key      IS 'Lowercase machine key. Used as slug in API and search filters.';
COMMENT ON COLUMN core.skill_tags.display_name IS 'Human-readable category label.';
COMMENT ON COLUMN core.skill_tags.description  IS 'Optional extended description of the category.';
COMMENT ON COLUMN core.skill_tags.is_active    IS 'FALSE hides the tag from the UI without deleting associations.';
COMMENT ON COLUMN core.skill_tags.created_at   IS 'Record creation timestamp (UTC).';
COMMENT ON COLUMN core.skill_tags.updated_at   IS 'Last modification timestamp.';
COMMENT ON COLUMN core.skill_tags.deleted_at   IS 'Soft-delete sentinel.';

CREATE INDEX IF NOT EXISTS idx_skill_tags_key
    ON core.skill_tags(tag_key)
    WHERE deleted_at IS NULL AND is_active = TRUE;
COMMENT ON INDEX core.idx_skill_tags_key IS
    'Partial index for active tag key lookups and API filter resolution.';

-- =============================================================================
-- 10. SKILL CATALOG: core.hard_skills
-- =============================================================================

CREATE TABLE IF NOT EXISTS core.hard_skills (
    id_hard_skill UUID         NOT NULL DEFAULT gen_random_uuid(),
    id_skill_tag  UUID,
    skill_key     VARCHAR(100) NOT NULL,
    display_name  VARCHAR(150) NOT NULL,
    description   TEXT,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ,
    deleted_at    TIMESTAMPTZ,

    CONSTRAINT pk_hard_skills      PRIMARY KEY (id_hard_skill),
    CONSTRAINT uq_hard_skills_key  UNIQUE      (skill_key),
    CONSTRAINT ck_hard_skills_key  CHECK       (skill_key = LOWER(TRIM(skill_key))),
    CONSTRAINT ck_hard_skills_audit CHECK      (deleted_at IS NULL OR deleted_at >= created_at),
    CONSTRAINT fk_hard_skills_tag  FOREIGN KEY (id_skill_tag)
        REFERENCES core.skill_tags(id_skill_tag) ON DELETE SET NULL ON UPDATE CASCADE
);

COMMENT ON TABLE core.hard_skills IS
    'Platform catalog of technical / hard skills (e.g. Java, React, PostgreSQL, AWS). '
    'Optionally categorized via core.skill_tags. '
    'Users associate themselves via core.profile_skills.';
COMMENT ON COLUMN core.hard_skills.id_hard_skill IS 'Surrogate PK.';
COMMENT ON COLUMN core.hard_skills.id_skill_tag  IS 'Optional FK to skill_tags. SET NULL on tag deletion preserves skill record.';
COMMENT ON COLUMN core.hard_skills.skill_key     IS 'Lowercase machine key (e.g. "java", "react", "postgresql").';
COMMENT ON COLUMN core.hard_skills.display_name  IS 'Human-readable skill label (e.g. "Java", "React", "PostgreSQL").';
COMMENT ON COLUMN core.hard_skills.description   IS 'Optional description or canonical definition of the skill.';
COMMENT ON COLUMN core.hard_skills.is_active     IS 'FALSE removes skill from the UI without breaking existing associations.';
COMMENT ON COLUMN core.hard_skills.created_at    IS 'Record creation timestamp (UTC).';
COMMENT ON COLUMN core.hard_skills.updated_at    IS 'Last modification timestamp.';
COMMENT ON COLUMN core.hard_skills.deleted_at    IS 'Soft-delete sentinel.';

CREATE INDEX IF NOT EXISTS idx_hard_skills_tag
    ON core.hard_skills(id_skill_tag)
    WHERE id_skill_tag IS NOT NULL;
COMMENT ON INDEX core.idx_hard_skills_tag IS 'Covers FK join from skill_tags to hard_skills.';

CREATE INDEX IF NOT EXISTS idx_hard_skills_key
    ON core.hard_skills(skill_key)
    WHERE deleted_at IS NULL AND is_active = TRUE;
COMMENT ON INDEX core.idx_hard_skills_key IS 'Partial index for active skill key resolution in search.';

-- =============================================================================
-- 11. SKILL CATALOG: core.soft_skills
-- =============================================================================

CREATE TABLE IF NOT EXISTS core.soft_skills (
    id_soft_skill UUID         NOT NULL DEFAULT gen_random_uuid(),
    id_skill_tag  UUID,
    skill_key     VARCHAR(100) NOT NULL,
    display_name  VARCHAR(150) NOT NULL,
    description   TEXT,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ,
    deleted_at    TIMESTAMPTZ,

    CONSTRAINT pk_soft_skills      PRIMARY KEY (id_soft_skill),
    CONSTRAINT uq_soft_skills_key  UNIQUE      (skill_key),
    CONSTRAINT ck_soft_skills_key  CHECK       (skill_key = LOWER(TRIM(skill_key))),
    CONSTRAINT ck_soft_skills_audit CHECK      (deleted_at IS NULL OR deleted_at >= created_at),
    CONSTRAINT fk_soft_skills_tag  FOREIGN KEY (id_skill_tag)
        REFERENCES core.skill_tags(id_skill_tag) ON DELETE SET NULL ON UPDATE CASCADE
);

COMMENT ON TABLE core.soft_skills IS
    'Platform catalog of interpersonal / soft skills (e.g. leadership, communication, teamwork). '
    'Optionally categorized via core.skill_tags. '
    'Users associate themselves via core.profile_skills.';
COMMENT ON COLUMN core.soft_skills.id_soft_skill IS 'Surrogate PK.';
COMMENT ON COLUMN core.soft_skills.id_skill_tag  IS 'Optional FK to skill_tags. SET NULL on tag deletion preserves the skill record.';
COMMENT ON COLUMN core.soft_skills.skill_key     IS 'Lowercase machine key (e.g. "leadership", "communication").';
COMMENT ON COLUMN core.soft_skills.display_name  IS 'Human-readable skill label.';
COMMENT ON COLUMN core.soft_skills.description   IS 'Optional canonical description.';
COMMENT ON COLUMN core.soft_skills.is_active     IS 'FALSE hides from UI without breaking existing associations.';
COMMENT ON COLUMN core.soft_skills.created_at    IS 'Record creation timestamp (UTC).';
COMMENT ON COLUMN core.soft_skills.updated_at    IS 'Last modification timestamp.';
COMMENT ON COLUMN core.soft_skills.deleted_at    IS 'Soft-delete sentinel.';

CREATE INDEX IF NOT EXISTS idx_soft_skills_tag
    ON core.soft_skills(id_skill_tag)
    WHERE id_skill_tag IS NOT NULL;
COMMENT ON INDEX core.idx_soft_skills_tag IS 'Covers FK join from skill_tags to soft_skills.';

CREATE INDEX IF NOT EXISTS idx_soft_skills_key
    ON core.soft_skills(skill_key)
    WHERE deleted_at IS NULL AND is_active = TRUE;
COMMENT ON INDEX core.idx_soft_skills_key IS 'Partial index for active soft skill key lookups.';

-- =============================================================================
-- 12. JUNCTION TABLE: core.profile_skills
-- =============================================================================

CREATE TABLE IF NOT EXISTS core.profile_skills (
    id_profile_skill  UUID     NOT NULL DEFAULT gen_random_uuid(),
    id_profile        UUID     NOT NULL,
    id_hard_skill     UUID,
    id_soft_skill     UUID,
    proficiency_level SMALLINT,
    is_featured       BOOLEAN  NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ,
    deleted_at        TIMESTAMPTZ,

    CONSTRAINT pk_profile_skills           PRIMARY KEY (id_profile_skill),
    CONSTRAINT ck_ps_exactly_one_skill     CHECK (
        (id_hard_skill IS NOT NULL AND id_soft_skill IS NULL) OR
        (id_hard_skill IS NULL     AND id_soft_skill IS NOT NULL)
    ),
    CONSTRAINT ck_ps_proficiency           CHECK (proficiency_level IS NULL OR proficiency_level BETWEEN 1 AND 5),
    CONSTRAINT ck_ps_audit                 CHECK (deleted_at IS NULL OR deleted_at >= created_at),
    CONSTRAINT fk_ps_profile               FOREIGN KEY (id_profile)
        REFERENCES core.profiles(id_profile)      ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT fk_ps_hard_skill            FOREIGN KEY (id_hard_skill)
        REFERENCES core.hard_skills(id_hard_skill) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ps_soft_skill            FOREIGN KEY (id_soft_skill)
        REFERENCES core.soft_skills(id_soft_skill) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON TABLE core.profile_skills IS
    'M:N junction between core.profiles and the skill catalogs. '
    'Each row associates a profile with exactly one skill (hard XOR soft), '
    'enforced via ck_ps_exactly_one_skill. '
    'proficiency_level: 1 (beginner) → 5 (expert). is_featured: pinned on public profile.';
COMMENT ON COLUMN core.profile_skills.id_profile_skill  IS 'Surrogate PK.';
COMMENT ON COLUMN core.profile_skills.id_profile        IS 'FK to the owning profile. Cascades on profile deletion.';
COMMENT ON COLUMN core.profile_skills.id_hard_skill     IS 'FK to core.hard_skills. Mutually exclusive with id_soft_skill.';
COMMENT ON COLUMN core.profile_skills.id_soft_skill     IS 'FK to core.soft_skills. Mutually exclusive with id_hard_skill.';
COMMENT ON COLUMN core.profile_skills.proficiency_level IS 'Self-assessed proficiency 1–5. NULL = not rated.';
COMMENT ON COLUMN core.profile_skills.is_featured       IS 'TRUE pins this skill to the top of the public profile.';
COMMENT ON COLUMN core.profile_skills.created_at        IS 'Record creation timestamp (UTC).';
COMMENT ON COLUMN core.profile_skills.updated_at        IS 'Last modification timestamp.';
COMMENT ON COLUMN core.profile_skills.deleted_at        IS 'Soft-delete sentinel.';

-- Partial unique indexes enforce one association per (profile, skill) while allowing NULLs
CREATE UNIQUE INDEX IF NOT EXISTS uq_ps_profile_hard_skill
    ON core.profile_skills(id_profile, id_hard_skill)
    WHERE id_hard_skill IS NOT NULL AND deleted_at IS NULL;
COMMENT ON INDEX core.uq_ps_profile_hard_skill IS
    'Prevents a profile from associating the same hard skill twice (excluding soft-deleted rows).';

CREATE UNIQUE INDEX IF NOT EXISTS uq_ps_profile_soft_skill
    ON core.profile_skills(id_profile, id_soft_skill)
    WHERE id_soft_skill IS NOT NULL AND deleted_at IS NULL;
COMMENT ON INDEX core.uq_ps_profile_soft_skill IS
    'Prevents a profile from associating the same soft skill twice (excluding soft-deleted rows).';

CREATE INDEX IF NOT EXISTS idx_ps_profile
    ON core.profile_skills(id_profile)
    WHERE deleted_at IS NULL;
COMMENT ON INDEX core.idx_ps_profile IS
    'Partial index for fast profile skill listing queries.';

-- =============================================================================
-- 13. UPDATED_AT TRIGGERS (all core tables)
-- =============================================================================

CREATE TRIGGER trg_profile_roles_updated_at
    BEFORE UPDATE ON core.profile_roles
    FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
COMMENT ON TRIGGER trg_profile_roles_updated_at ON core.profile_roles IS
    'Maintains updated_at on every row modification in core.profile_roles.';

CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON core.profiles
    FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
COMMENT ON TRIGGER trg_profiles_updated_at ON core.profiles IS
    'Maintains updated_at on every row modification in core.profiles.';

CREATE TRIGGER trg_profiles_basic_updated_at
    BEFORE UPDATE ON core.profiles_basic
    FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
COMMENT ON TRIGGER trg_profiles_basic_updated_at ON core.profiles_basic IS
    'Maintains updated_at on every row modification in core.profiles_basic.';

CREATE TRIGGER trg_profiles_company_updated_at
    BEFORE UPDATE ON core.profiles_company
    FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
COMMENT ON TRIGGER trg_profiles_company_updated_at ON core.profiles_company IS
    'Maintains updated_at on every row modification in core.profiles_company.';

CREATE TRIGGER trg_profile_moderation_updated_at
    BEFORE UPDATE ON core.profile_moderation
    FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
COMMENT ON TRIGGER trg_profile_moderation_updated_at ON core.profile_moderation IS
    'Maintains updated_at on every row modification in core.profile_moderation.';

CREATE TRIGGER trg_skill_tags_updated_at
    BEFORE UPDATE ON core.skill_tags
    FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
COMMENT ON TRIGGER trg_skill_tags_updated_at ON core.skill_tags IS
    'Maintains updated_at on every row modification in core.skill_tags.';

CREATE TRIGGER trg_hard_skills_updated_at
    BEFORE UPDATE ON core.hard_skills
    FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
COMMENT ON TRIGGER trg_hard_skills_updated_at ON core.hard_skills IS
    'Maintains updated_at on every row modification in core.hard_skills.';

CREATE TRIGGER trg_soft_skills_updated_at
    BEFORE UPDATE ON core.soft_skills
    FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
COMMENT ON TRIGGER trg_soft_skills_updated_at ON core.soft_skills IS
    'Maintains updated_at on every row modification in core.soft_skills.';

CREATE TRIGGER trg_profile_skills_updated_at
    BEFORE UPDATE ON core.profile_skills
    FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
COMMENT ON TRIGGER trg_profile_skills_updated_at ON core.profile_skills IS
    'Maintains updated_at on every row modification in core.profile_skills.';

-- =============================================================================
-- 14. ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE core.profile_roles    ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.profiles_basic   ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.profiles_company ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.profile_moderation ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.skill_tags       ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.hard_skills      ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.soft_skills      ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.profile_skills   ENABLE ROW LEVEL SECURITY;

-- ── core.profile_roles ────────────────────────────────────────────────────────
CREATE POLICY pol_profile_roles_select
    ON core.profile_roles FOR SELECT TO authenticated USING (TRUE);
COMMENT ON POLICY pol_profile_roles_select ON core.profile_roles IS
    'All authenticated users may read the role catalog (public lookup data).';

CREATE POLICY pol_profile_roles_service
    ON core.profile_roles FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
COMMENT ON POLICY pol_profile_roles_service ON core.profile_roles IS
    'Service role has unrestricted access for seeding and admin operations.';

-- ── core.profiles ─────────────────────────────────────────────────────────────
CREATE POLICY pol_profiles_select_own
    ON core.profiles FOR SELECT TO authenticated
    USING (auth_id = auth.uid());
COMMENT ON POLICY pol_profiles_select_own ON core.profiles IS
    'Users may only read their own profile row.';

CREATE POLICY pol_profiles_update_own
    ON core.profiles FOR UPDATE TO authenticated
    USING  (auth_id = auth.uid() AND deleted_at IS NULL)
    WITH CHECK (auth_id = auth.uid() AND deleted_at IS NULL);
COMMENT ON POLICY pol_profiles_update_own ON core.profiles IS
    'Users may only update their own active profile.';

CREATE POLICY pol_profiles_service_all
    ON core.profiles FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
COMMENT ON POLICY pol_profiles_service_all ON core.profiles IS
    'Service role (Spring Boot) has unrestricted access for registration and admin ops.';

-- ── core.profiles_basic ───────────────────────────────────────────────────────
CREATE POLICY pol_profiles_basic_select
    ON core.profiles_basic FOR SELECT TO authenticated
    USING ((SELECT auth_id FROM core.profiles p WHERE p.id_profile = profiles_basic.id_profile) = auth.uid());
COMMENT ON POLICY pol_profiles_basic_select ON core.profiles_basic IS
    'Users may read only the profiles_basic row belonging to their own profile.';

CREATE POLICY pol_profiles_basic_update
    ON core.profiles_basic FOR UPDATE TO authenticated
    USING  ((SELECT auth_id FROM core.profiles p WHERE p.id_profile = profiles_basic.id_profile) = auth.uid())
    WITH CHECK ((SELECT auth_id FROM core.profiles p WHERE p.id_profile = profiles_basic.id_profile) = auth.uid());
COMMENT ON POLICY pol_profiles_basic_update ON core.profiles_basic IS
    'Users may update only their own profiles_basic row.';

CREATE POLICY pol_profiles_basic_service
    ON core.profiles_basic FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
COMMENT ON POLICY pol_profiles_basic_service ON core.profiles_basic IS
    'Service role has unrestricted access for profile provisioning and updates.';

-- ── core.profiles_company ─────────────────────────────────────────────────────
CREATE POLICY pol_profiles_company_select
    ON core.profiles_company FOR SELECT TO authenticated
    USING ((SELECT auth_id FROM core.profiles p WHERE p.id_profile = profiles_company.id_profile) = auth.uid());
COMMENT ON POLICY pol_profiles_company_select ON core.profiles_company IS
    'Users may read only the profiles_company row belonging to their own profile.';

CREATE POLICY pol_profiles_company_update
    ON core.profiles_company FOR UPDATE TO authenticated
    USING  ((SELECT auth_id FROM core.profiles p WHERE p.id_profile = profiles_company.id_profile) = auth.uid())
    WITH CHECK ((SELECT auth_id FROM core.profiles p WHERE p.id_profile = profiles_company.id_profile) = auth.uid());
COMMENT ON POLICY pol_profiles_company_update ON core.profiles_company IS
    'Users may update only their own profiles_company row.';

CREATE POLICY pol_profiles_company_service
    ON core.profiles_company FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
COMMENT ON POLICY pol_profiles_company_service ON core.profiles_company IS
    'Service role has unrestricted access for company profile provisioning and updates.';

-- ── core.profile_moderation ───────────────────────────────────────────────────
CREATE POLICY pol_profile_moderation_service
    ON core.profile_moderation FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
COMMENT ON POLICY pol_profile_moderation_service ON core.profile_moderation IS
    'Moderation records are admin-only. Service role has full access; no authenticated policy granted.';

-- ── core.skill_tags ───────────────────────────────────────────────────────────
CREATE POLICY pol_skill_tags_select
    ON core.skill_tags FOR SELECT TO authenticated USING (TRUE);
COMMENT ON POLICY pol_skill_tags_select ON core.skill_tags IS
    'Skill tag catalog is readable by all authenticated users.';

CREATE POLICY pol_skill_tags_service
    ON core.skill_tags FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
COMMENT ON POLICY pol_skill_tags_service ON core.skill_tags IS
    'Service role manages the skill tag catalog.';

-- ── core.hard_skills ──────────────────────────────────────────────────────────
CREATE POLICY pol_hard_skills_select
    ON core.hard_skills FOR SELECT TO authenticated USING (TRUE);
COMMENT ON POLICY pol_hard_skills_select ON core.hard_skills IS
    'Hard skill catalog is readable by all authenticated users for search and association.';

CREATE POLICY pol_hard_skills_service
    ON core.hard_skills FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
COMMENT ON POLICY pol_hard_skills_service ON core.hard_skills IS
    'Service role manages the hard skill catalog.';

-- ── core.soft_skills ──────────────────────────────────────────────────────────
CREATE POLICY pol_soft_skills_select
    ON core.soft_skills FOR SELECT TO authenticated USING (TRUE);
COMMENT ON POLICY pol_soft_skills_select ON core.soft_skills IS
    'Soft skill catalog is readable by all authenticated users.';

CREATE POLICY pol_soft_skills_service
    ON core.soft_skills FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
COMMENT ON POLICY pol_soft_skills_service ON core.soft_skills IS
    'Service role manages the soft skill catalog.';

-- ── core.profile_skills ───────────────────────────────────────────────────────
CREATE POLICY pol_profile_skills_select_own
    ON core.profile_skills FOR SELECT TO authenticated
    USING ((SELECT auth_id FROM core.profiles p WHERE p.id_profile = profile_skills.id_profile) = auth.uid());
COMMENT ON POLICY pol_profile_skills_select_own ON core.profile_skills IS
    'Users may read only their own skill associations.';

CREATE POLICY pol_profile_skills_insert_own
    ON core.profile_skills FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth_id FROM core.profiles p WHERE p.id_profile = profile_skills.id_profile) = auth.uid());
COMMENT ON POLICY pol_profile_skills_insert_own ON core.profile_skills IS
    'Users may add skills only to their own profile.';

CREATE POLICY pol_profile_skills_update_own
    ON core.profile_skills FOR UPDATE TO authenticated
    USING  ((SELECT auth_id FROM core.profiles p WHERE p.id_profile = profile_skills.id_profile) = auth.uid())
    WITH CHECK ((SELECT auth_id FROM core.profiles p WHERE p.id_profile = profile_skills.id_profile) = auth.uid());
COMMENT ON POLICY pol_profile_skills_update_own ON core.profile_skills IS
    'Users may update only their own skill associations.';

CREATE POLICY pol_profile_skills_service
    ON core.profile_skills FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
COMMENT ON POLICY pol_profile_skills_service ON core.profile_skills IS
    'Service role has unrestricted access.';

-- =============================================================================
-- 15. SEED DATA: core.profile_roles
-- =============================================================================

INSERT INTO core.profile_roles (role_key, display_name, description)
VALUES
    ('professional', 'Profesional',   'Profesional en búsqueda activa de oportunidades laborales'),
    ('recruiter',    'Reclutador',    'Reclutador evaluando candidatos para vacantes abiertas'),
    ('admin',        'Administrador', 'Administrador de la plataforma con acceso irrestricto')
ON CONFLICT (role_key) DO NOTHING;

-- =============================================================================
-- 16. DATA MIGRATION: public.* → core.*
-- =============================================================================

-- ── profile_roles ─────────────────────────────────────────────────────────────
-- Preserve existing UUIDs so FKs from public.profile survive the copy.
INSERT INTO core.profile_roles (id_profile_role, role_key, display_name, description,
                                is_active, created_at, updated_at, deleted_at)
SELECT id_profile_role, role_key, display_name, description,
       is_active, created_at, updated_at, deleted_at
FROM   public.profile_role
ON CONFLICT (role_key) DO NOTHING;

-- ── profiles ──────────────────────────────────────────────────────────────────
-- Copies base profile rows; id_profile_role UUIDs match core.profile_roles
-- since we preserved them in the previous step.
INSERT INTO core.profiles (id_profile, auth_id, id_profile_role, email,
                           first_name, last_name, phone_number, country_code,
                           avatar_url, is_active, created_at, updated_at, deleted_at)
SELECT p.id_profile, p.auth_id, p.id_profile_role, p.email,
       p.first_name, p.last_name, p.phone_number, p.country_code,
       p.avatar_url, p.is_active, p.created_at, p.updated_at, p.deleted_at
FROM   public.profile p
ON CONFLICT (auth_id) DO NOTHING;

-- ── profiles_basic ────────────────────────────────────────────────────────────
INSERT INTO core.profiles_basic (id_profile_basic, id_profile, headline, bio,
                                  location, website, years_experience, portfolio_url,
                                  created_at, updated_at, deleted_at)
SELECT id_profile_basic, id_profile, headline, bio,
       location, website, COALESCE(years_experience, 0), portfolio_url,
       created_at, updated_at, deleted_at
FROM   public.profile_basic
ON CONFLICT (id_profile) DO NOTHING;

-- ── profiles_company ──────────────────────────────────────────────────────────
INSERT INTO core.profiles_company (id_profile_company, id_profile, company_name,
                                    company_size, industry, company_website,
                                    company_logo_url, company_description,
                                    created_at, updated_at, deleted_at)
SELECT id_profile_company, id_profile, company_name,
       company_size, industry, company_website,
       company_logo_url, company_description,
       created_at, updated_at, deleted_at
FROM   public.profile_company
ON CONFLICT (id_profile) DO NOTHING;

-- =============================================================================
-- 17. PROCEDURE: core.sp_provision_profile
-- =============================================================================

CREATE OR REPLACE PROCEDURE core.sp_provision_profile(
    p_auth_id      UUID,
    p_email        VARCHAR,
    p_first_name   VARCHAR,
    p_last_name    VARCHAR,
    p_role_key     VARCHAR,
    p_phone_number VARCHAR  DEFAULT NULL,
    p_country_code CHAR(2)  DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = core
AS $$
DECLARE
    v_id_profile_role UUID;
    v_id_profile      UUID;
    v_resolved_role   VARCHAR;
BEGIN
    v_resolved_role := LOWER(TRIM(COALESCE(p_role_key, 'professional')));

    -- Resolve role UUID; fall back to 'professional' if the key is unknown.
    SELECT id_profile_role INTO v_id_profile_role
    FROM   core.profile_roles
    WHERE  role_key    = v_resolved_role
      AND  deleted_at IS NULL;

    IF v_id_profile_role IS NULL THEN
        SELECT id_profile_role INTO v_id_profile_role
        FROM   core.profile_roles
        WHERE  role_key = 'professional';
    END IF;

    -- Create base profile; silently skip if auth_id already exists (idempotent).
    INSERT INTO core.profiles (auth_id, id_profile_role, email,
                               first_name, last_name, phone_number, country_code)
    VALUES (
        p_auth_id,
        v_id_profile_role,
        p_email,
        COALESCE(NULLIF(TRIM(p_first_name), ''), SPLIT_PART(p_email, '@', 1)),
        COALESCE(p_last_name, ''),
        p_phone_number,
        p_country_code
    )
    ON CONFLICT (auth_id) DO NOTHING
    RETURNING id_profile INTO v_id_profile;

    -- Nothing to do if the profile already existed.
    IF v_id_profile IS NULL THEN RETURN; END IF;

    -- Fan out into the role-specific sub-profile table.
    IF v_resolved_role = 'recruiter' THEN
        INSERT INTO core.profiles_company (id_profile)
        VALUES (v_id_profile)
        ON CONFLICT (id_profile) DO NOTHING;
    ELSE
        INSERT INTO core.profiles_basic (id_profile)
        VALUES (v_id_profile)
        ON CONFLICT (id_profile) DO NOTHING;
    END IF;
END;
$$;

COMMENT ON PROCEDURE core.sp_provision_profile IS
    'Atomically provisions core.profiles + the role-specific sub-profile '
    '(profiles_basic for professional/admin, profiles_company for recruiter). '
    'Idempotent: repeated calls with the same auth_id are safe (ON CONFLICT DO NOTHING). '
    'Called by: Spring AuthService (local registration), core.fn_on_auth_user_created (OAuth).';

-- =============================================================================
-- 18. FUNCTION: core.fn_on_auth_user_created
-- =============================================================================

CREATE OR REPLACE FUNCTION core.fn_on_auth_user_created()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = core
AS $$
DECLARE
    v_role       VARCHAR;
    v_first_name VARCHAR;
    v_last_name  VARCHAR;
    v_full_name  TEXT;
    v_email      VARCHAR;
BEGIN
    v_full_name  := NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), '');

    v_role := LOWER(TRIM(COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'role'),    ''),
        NULLIF(TRIM(NEW.raw_app_meta_data  ->>'role'),   ''),
        'professional'
    )));

    v_first_name := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), ''),
        NULLIF(split_part(COALESCE(
            v_full_name,
            NULLIF(TRIM(NEW.raw_user_meta_data->>'preferred_username'), ''),
            NULLIF(TRIM(NEW.raw_user_meta_data->>'user_name'),          ''),
            SPLIT_PART(COALESCE(NEW.email, ''), '@', 1)
        ), ' ', 1), '')
    );

    v_last_name := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), ''),
        CASE
            WHEN v_full_name IS NOT NULL AND position(' ' IN v_full_name) > 0
            THEN TRIM(substring(v_full_name FROM position(' ' IN v_full_name) + 1))
            ELSE ''
        END
    );

    v_email := COALESCE(
        NULLIF(TRIM(NEW.email), ''),
        'oauth-' || NEW.id::TEXT || '@ethoshub.noreply'
    );

    CALL core.sp_provision_profile(
        NEW.id,
        v_email,
        COALESCE(v_first_name, 'usuario'),
        COALESCE(v_last_name,  ''),
        v_role,
        NULLIF(TRIM(NEW.raw_user_meta_data->>'phone_number'), ''),
        NULLIF(TRIM(UPPER(NEW.raw_user_meta_data->>'country_code')), '')
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION core.fn_on_auth_user_created() IS
    'Trigger function for auth.users INSERT. '
    'Extracts identity fields from Supabase raw_user_meta_data / raw_app_meta_data '
    'and delegates to core.sp_provision_profile. '
    'Handles local email registration and all OAuth providers (Google, GitHub, etc.). '
    'SECURITY DEFINER is required to write to core.profiles from the auth schema context. '
    'Wired to auth.users via V5__swap_core_auth_trigger.sql (manual apply).';

-- =============================================================================
-- 19. UPDATE PROXY: public.fn_on_auth_user_created
--     Keeps the existing auth.users trigger functional until V5 replaces it.
--     The body now delegates entirely to core.sp_provision_profile.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_on_auth_user_created()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
AS $$
DECLARE
    v_role       VARCHAR;
    v_first_name VARCHAR;
    v_last_name  VARCHAR;
    v_full_name  TEXT;
    v_email      VARCHAR;
BEGIN
    v_full_name  := NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), '');

    v_role := LOWER(TRIM(COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'role'),    ''),
        NULLIF(TRIM(NEW.raw_app_meta_data  ->>'role'),   ''),
        'professional'
    )));

    v_first_name := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), ''),
        NULLIF(split_part(COALESCE(
            v_full_name,
            NULLIF(TRIM(NEW.raw_user_meta_data->>'preferred_username'), ''),
            NULLIF(TRIM(NEW.raw_user_meta_data->>'user_name'),          ''),
            SPLIT_PART(COALESCE(NEW.email, ''), '@', 1)
        ), ' ', 1), '')
    );

    v_last_name := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), ''),
        CASE
            WHEN v_full_name IS NOT NULL AND position(' ' IN v_full_name) > 0
            THEN TRIM(substring(v_full_name FROM position(' ' IN v_full_name) + 1))
            ELSE ''
        END
    );

    v_email := COALESCE(
        NULLIF(TRIM(NEW.email), ''),
        'oauth-' || NEW.id::TEXT || '@ethoshub.noreply'
    );

    -- Delegate to core.sp_provision_profile (writes to core schema).
    -- The trigger on auth.users still calls this public function until V5.
    CALL core.sp_provision_profile(
        NEW.id,
        v_email,
        COALESCE(v_first_name, 'usuario'),
        COALESCE(v_last_name,  ''),
        v_role,
        NULLIF(TRIM(NEW.raw_user_meta_data->>'phone_number'), ''),
        NULLIF(TRIM(UPPER(NEW.raw_user_meta_data->>'country_code')), '')
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_on_auth_user_created() IS
    'Proxy function kept alive while the auth.users trigger still points here. '
    'Delegates entirely to core.sp_provision_profile. '
    'This function and the trigger pointing to it are replaced by V5__swap_core_auth_trigger.sql.';

-- =============================================================================
-- 20. DROP PUBLIC PROFILE TABLES
--     Order: children first, then parents, then lookup.
--     CASCADE handles any remaining FK references or triggers automatically.
-- =============================================================================

DROP TABLE IF EXISTS public.profile_basic      CASCADE;
DROP TABLE IF EXISTS public.profile_company    CASCADE;
DROP TABLE IF EXISTS public.profile            CASCADE;
DROP TABLE IF EXISTS public.profile_role       CASCADE;
DROP TABLE IF EXISTS public.profile_moderation CASCADE;
DROP TABLE IF EXISTS public.hard_skills        CASCADE;
DROP TABLE IF EXISTS public.soft_skills        CASCADE;
DROP TABLE IF EXISTS public.skill_tags         CASCADE;

-- =============================================================================
-- 21. DROP OBSOLETE PUBLIC FUNCTIONS / PROCEDURES
-- =============================================================================

-- fn_set_updated_at: all public profile triggers are gone (dropped with their tables above).
DROP FUNCTION IF EXISTS public.fn_set_updated_at() CASCADE;

-- sp_provision_profile: replaced by core.sp_provision_profile.
-- public.fn_on_auth_user_created (proxy) now calls core.sp_provision_profile directly.
DROP PROCEDURE IF EXISTS public.sp_provision_profile(UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, CHAR) CASCADE;

COMMIT;
