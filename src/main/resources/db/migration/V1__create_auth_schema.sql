-- =============================================================================
-- V1__create_auth_schema.sql
-- EthosHub — User Auth Schema
-- Supabase PostgreSQL 15+
-- =============================================================================

BEGIN;

-- =============================================================================
-- EXTENSIONS
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
COMMENT ON EXTENSION pgcrypto IS 'Provides gen_random_uuid() and cryptographic functions.';

-- =============================================================================
-- ENUMS
-- =============================================================================

CREATE TYPE public.user_role AS ENUM (
    'professional',
    'recruiter',
    'admin'
);

COMMENT ON TYPE public.user_role IS
    'Business role for EthosHub users. '
    'professional = job seeker building a portfolio. '
    'recruiter    = talent finder evaluating candidates. '
    'admin        = platform administrator with full privileges. '
    'Assigned once at registration; mutable only by admin.';

-- =============================================================================
-- BASE ENTITY: public."user"
-- =============================================================================
-- NOTE: "user" is quoted because USER is a reserved keyword in PostgreSQL.

CREATE TABLE public."user" (
    id_user      UUID                NOT NULL DEFAULT gen_random_uuid(),
    auth_id      UUID                NOT NULL,
    email        VARCHAR(255)        NOT NULL,
    first_name   VARCHAR(100)        NOT NULL,
    last_name    VARCHAR(100)        NOT NULL DEFAULT '',
    role         public.user_role    NOT NULL DEFAULT 'professional',
    phone_number VARCHAR(30),
    country_code CHAR(2),
    avatar_url   TEXT,
    is_active    BOOLEAN             NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ,
    deleted_at   TIMESTAMPTZ,

    CONSTRAINT pk_user
        PRIMARY KEY (id_user),

    CONSTRAINT uq_user_auth_id
        UNIQUE (auth_id),

    CONSTRAINT uq_user_email
        UNIQUE (email),

    CONSTRAINT ck_user_email_format
        CHECK (email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'),

    CONSTRAINT ck_user_first_name_length
        CHECK (char_length(trim(first_name)) >= 1),

    CONSTRAINT ck_user_phone_format
        CHECK (phone_number IS NULL OR phone_number ~* '^\+?[0-9\s\-]{7,20}$'),

    CONSTRAINT ck_user_country_code_format
        CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$'),

    CONSTRAINT ck_user_audit_order
        CHECK (deleted_at IS NULL OR deleted_at >= created_at),

    CONSTRAINT fk_user_auth
        FOREIGN KEY (auth_id)
        REFERENCES auth.users(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- =============================================================================
-- COMMENTS — TABLE & COLUMNS
-- =============================================================================

COMMENT ON TABLE public."user" IS
    'Core EthosHub user profile. Extends auth.users with business role, identity '
    'data, and contact information. Every authenticated user must have exactly one '
    'corresponding row here. Created atomically on registration; synced via trigger '
    'for OAuth flows.';

COMMENT ON COLUMN public."user".id_user IS
    'Internal profile UUID. Exposed as profileId to API clients. '
    'Distinct from auth_id to allow profile migration without touching Supabase Auth.';

COMMENT ON COLUMN public."user".auth_id IS
    'FK to auth.users(id). The Supabase Auth identity anchor. '
    'ON DELETE CASCADE ensures profile cleanup when the auth user is removed.';

COMMENT ON COLUMN public."user".email IS
    'Denormalized copy of auth.users.email for fast profile lookups. '
    'Kept in sync via the auth.users INSERT trigger. '
    'Not updated on email change — requires explicit sync if email change is enabled.';

COMMENT ON COLUMN public."user".first_name IS
    'Given name. Set from the registration form on local auth. '
    'Set from OAuth provider metadata (full_name split) on OAuth auth.';

COMMENT ON COLUMN public."user".last_name IS
    'Family name. May be empty string for OAuth users who did not supply it.';

COMMENT ON COLUMN public."user".role IS
    'Business role assigned at registration time. '
    'Immutable after account creation except through admin operations. '
    'Maps to app_metadata.role in the Supabase JWT for claim-based RBAC.';

COMMENT ON COLUMN public."user".phone_number IS
    'Full E.164 phone number including country dial prefix (e.g. +59175001234). '
    'Optional; collected during registration.';

COMMENT ON COLUMN public."user".country_code IS
    'ISO 3166-1 alpha-2 country code (e.g. BO, AR, US). '
    'Inferred from the phone country picker during registration.';

COMMENT ON COLUMN public."user".avatar_url IS
    'URL to the user profile image. '
    'May be set from OAuth provider avatar or uploaded manually.';

COMMENT ON COLUMN public."user".is_active IS
    'Logical enable/disable flag. FALSE suspends login without data deletion. '
    'All SELECT queries MUST filter WHERE is_active = TRUE AND deleted_at IS NULL.';

COMMENT ON COLUMN public."user".created_at IS
    'Record creation timestamp in UTC. Immutable after insert.';

COMMENT ON COLUMN public."user".updated_at IS
    'Last modification timestamp. Set automatically by trg_user_set_updated_at.';

COMMENT ON COLUMN public."user".deleted_at IS
    'Soft-delete timestamp. NULL = active. Non-NULL = logically deleted. '
    'Hard delete is handled by Supabase Auth cascade on auth_id FK.';

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX idx_user_auth_id
    ON public."user"(auth_id);
COMMENT ON INDEX idx_user_auth_id IS
    'Supports FK lookups from auth_id (used on every authenticated request).';

CREATE INDEX idx_user_email
    ON public."user"(email);
COMMENT ON INDEX idx_user_email IS
    'Supports login lookups and duplicate email validation.';

CREATE INDEX idx_user_role
    ON public."user"(role)
    WHERE deleted_at IS NULL AND is_active = TRUE;
COMMENT ON INDEX idx_user_role IS
    'Partial index for role-based queries on active users only.';

CREATE INDEX idx_user_is_active_deleted
    ON public."user"(is_active, deleted_at)
    WHERE is_active = TRUE AND deleted_at IS NULL;
COMMENT ON INDEX idx_user_is_active_deleted IS
    'Partial index accelerating the standard active-user filter.';

CREATE INDEX idx_user_created_at
    ON public."user"(created_at DESC);
COMMENT ON INDEX idx_user_created_at IS
    'Supports time-ordered admin listings and audit queries.';

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_set_updated_at() IS
    'Generic trigger function that sets updated_at = NOW() on any UPDATE. '
    'Reusable across all auditable tables.';

CREATE OR REPLACE FUNCTION public.fn_sync_auth_user_on_insert()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
AS $$
DECLARE
    v_role       public.user_role;
    v_first_name VARCHAR(100);
    v_last_name  VARCHAR(100);
    v_full_name  TEXT;
BEGIN
    v_full_name  := NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), '');

    v_first_name := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), ''),
        split_part(COALESCE(v_full_name, SPLIT_PART(NEW.email, '@', 1)), ' ', 1)
    );

    v_last_name  := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), ''),
        CASE
            WHEN v_full_name IS NOT NULL AND position(' ' IN v_full_name) > 0
            THEN TRIM(substring(v_full_name FROM position(' ' IN v_full_name) + 1))
            ELSE ''
        END
    );

    v_role := COALESCE(
        (NULLIF(TRIM(NEW.raw_user_meta_data->>'role'), ''))::public.user_role,
        'professional'::public.user_role
    );

    INSERT INTO public."user" (auth_id, email, first_name, last_name, role)
    VALUES (NEW.id, NEW.email, v_first_name, COALESCE(v_last_name, ''), v_role)
    ON CONFLICT (auth_id) DO NOTHING;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_sync_auth_user_on_insert() IS
    'Automatically provisions a public.user row when a new auth.users row is inserted. '
    'Handles both local email registration (via raw_user_meta_data) and OAuth flows. '
    'SECURITY DEFINER is required to write to public."user" from the auth schema trigger context. '
    'ON CONFLICT DO NOTHING prevents duplicate rows when Spring also inserts the profile directly.';

-- =============================================================================
-- TRIGGERS
-- =============================================================================

CREATE TRIGGER trg_user_set_updated_at
    BEFORE UPDATE ON public."user"
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_set_updated_at();

COMMENT ON TRIGGER trg_user_set_updated_at ON public."user" IS
    'Maintains updated_at timestamp on every row modification.';

CREATE TRIGGER trg_sync_auth_user_on_insert
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_auth_user_on_insert();

COMMENT ON TRIGGER trg_sync_auth_user_on_insert ON auth.users IS
    'Provisions public.user from auth.users on new user creation. '
    'Covers OAuth sign-ups where Spring does not perform the insert directly.';

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE public."user" ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read only their own profile.
CREATE POLICY pol_user_select_own
    ON public."user"
    FOR SELECT
    TO authenticated
    USING (auth_id = auth.uid());

COMMENT ON POLICY pol_user_select_own ON public."user" IS
    'Restricts row-level reads to the authenticated user''s own profile.';

-- Authenticated users can update only their own non-deleted profile.
CREATE POLICY pol_user_update_own
    ON public."user"
    FOR UPDATE
    TO authenticated
    USING  (auth_id = auth.uid() AND deleted_at IS NULL)
    WITH CHECK (auth_id = auth.uid() AND deleted_at IS NULL);

COMMENT ON POLICY pol_user_update_own ON public."user" IS
    'Allows authenticated users to modify only their own active profile.';

-- Service role (Spring Boot backend) bypasses RLS for all operations.
CREATE POLICY pol_service_role_all
    ON public."user"
    FOR ALL
    TO service_role
    USING (TRUE)
    WITH CHECK (TRUE);

COMMENT ON POLICY pol_service_role_all ON public."user" IS
    'Service role (Spring Boot) has unrestricted access for administrative operations '
    'such as registration, profile provisioning, and user management.';

-- =============================================================================
-- AUDIT STRUCTURE: updated_at NOT NULL constraint enforced via trigger
-- =============================================================================

-- updated_at is intentionally nullable on INSERT (trigger fires only on UPDATE).
-- This is standard behavior: a record that has never been modified has NULL updated_at.

COMMIT;
