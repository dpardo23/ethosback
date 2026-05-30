-- =============================================================================
-- V2__refactor_profile_schema.sql
-- EthosHub — Profile Schema Refactor
-- Replaces public."user" with normalized profile hierarchy:
--   profile_role (lookup) → profile (base) → profile_basic | profile_company
-- Applied: 2026-05-29 via Supabase MCP apply_migration
-- NOTE: Trigger on auth.users must be swapped manually in Supabase SQL Editor:
--   DROP TRIGGER IF EXISTS trg_sync_auth_user_on_insert ON auth.users;
--   DROP FUNCTION IF EXISTS public.fn_sync_auth_user_on_insert();
--   CREATE TRIGGER trg_on_auth_user_created AFTER INSERT ON auth.users
--       FOR EACH ROW EXECUTE FUNCTION public.fn_on_auth_user_created();
-- =============================================================================

-- ── 1. NEUTRALIZE OLD TRIGGER FUNCTION ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_sync_auth_user_on_insert()
    RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$ BEGIN RETURN NEW; END; $$;

-- ── 2. LOOKUP TABLE: profile_role ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profile_role (
    id_profile_role UUID         NOT NULL DEFAULT gen_random_uuid(),
    role_key        VARCHAR(30)  NOT NULL,
    display_name    VARCHAR(50)  NOT NULL,
    description     TEXT,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ,
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT pk_profile_role     PRIMARY KEY (id_profile_role),
    CONSTRAINT uq_profile_role_key UNIQUE      (role_key)
);

INSERT INTO public.profile_role (role_key, display_name, description)
VALUES
    ('professional', 'Profesional',   'Profesional en búsqueda activa de oportunidades laborales'),
    ('recruiter',    'Reclutador',    'Reclutador evaluando candidatos para vacantes abiertas'),
    ('admin',        'Administrador', 'Administrador de la plataforma con acceso irrestricto')
ON CONFLICT (role_key) DO NOTHING;

-- ── 3. BASE PROFILE ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profile (
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
    CONSTRAINT pk_profile           PRIMARY KEY (id_profile),
    CONSTRAINT uq_profile_auth_id   UNIQUE (auth_id),
    CONSTRAINT uq_profile_email     UNIQUE (email),
    CONSTRAINT ck_profile_email_fmt CHECK (email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT ck_profile_phone_fmt CHECK (phone_number IS NULL OR phone_number ~* '^\+?[0-9\s\-]{7,20}$'),
    CONSTRAINT ck_profile_cc_fmt    CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_profile_audit     CHECK (deleted_at   IS NULL OR deleted_at  >= created_at),
    CONSTRAINT fk_profile_auth      FOREIGN KEY (auth_id)
        REFERENCES auth.users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_profile_role      FOREIGN KEY (id_profile_role)
        REFERENCES public.profile_role(id_profile_role)
);

-- ── 4. PROFESSIONAL SUB-PROFILE ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profile_basic (
    id_profile_basic UUID        NOT NULL DEFAULT gen_random_uuid(),
    id_profile       UUID        NOT NULL,
    headline         VARCHAR(200),
    bio              TEXT,
    location         VARCHAR(100),
    website          VARCHAR(255),
    years_experience SMALLINT    NOT NULL DEFAULT 0,
    portfolio_url    VARCHAR(255),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ,
    deleted_at       TIMESTAMPTZ,
    CONSTRAINT pk_profile_basic   PRIMARY KEY (id_profile_basic),
    CONSTRAINT uq_profile_basic_p UNIQUE      (id_profile),
    CONSTRAINT fk_profile_basic_p FOREIGN KEY (id_profile)
        REFERENCES public.profile(id_profile) ON DELETE CASCADE
);

-- ── 5. RECRUITER SUB-PROFILE ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profile_company (
    id_profile_company  UUID        NOT NULL DEFAULT gen_random_uuid(),
    id_profile          UUID        NOT NULL,
    company_name        VARCHAR(200),
    company_size        VARCHAR(50),
    industry            VARCHAR(100),
    company_website     VARCHAR(255),
    company_logo_url    TEXT,
    company_description TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ,
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT pk_profile_company   PRIMARY KEY (id_profile_company),
    CONSTRAINT uq_profile_company_p UNIQUE      (id_profile),
    CONSTRAINT fk_profile_company_p FOREIGN KEY (id_profile)
        REFERENCES public.profile(id_profile) ON DELETE CASCADE
);

-- ── 6. DATA MIGRATION ─────────────────────────────────────────────────────────
INSERT INTO public.profile
    (auth_id, id_profile_role, email, first_name, last_name,
     phone_number, country_code, avatar_url, is_active,
     created_at, updated_at, deleted_at)
SELECT u.auth_id, pr.id_profile_role, u.email, u.first_name, u.last_name,
       u.phone_number, u.country_code, u.avatar_url, u.is_active,
       u.created_at, u.updated_at, u.deleted_at
FROM   public."user" u
JOIN   public.profile_role pr ON pr.role_key = u.role::TEXT
ON CONFLICT (auth_id) DO NOTHING;

INSERT INTO public.profile_basic (id_profile)
SELECT p.id_profile FROM public.profile p
JOIN   public.profile_role pr ON pr.id_profile_role = p.id_profile_role
WHERE  pr.role_key = 'professional' ON CONFLICT (id_profile) DO NOTHING;

INSERT INTO public.profile_company (id_profile)
SELECT p.id_profile FROM public.profile p
JOIN   public.profile_role pr ON pr.id_profile_role = p.id_profile_role
WHERE  pr.role_key = 'recruiter' ON CONFLICT (id_profile) DO NOTHING;

-- ── 7. DROP OLD SCHEMA ────────────────────────────────────────────────────────
DROP TABLE IF EXISTS public."user";
DROP TYPE  IF EXISTS public.user_role;

-- ── 8. UPDATED_AT TRIGGERS ────────────────────────────────────────────────────
CREATE TRIGGER trg_profile_role_updated_at
    BEFORE UPDATE ON public.profile_role     FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
CREATE TRIGGER trg_profile_updated_at
    BEFORE UPDATE ON public.profile          FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
CREATE TRIGGER trg_profile_basic_updated_at
    BEFORE UPDATE ON public.profile_basic    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
CREATE TRIGGER trg_profile_company_updated_at
    BEFORE UPDATE ON public.profile_company  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- ── 9. STORED PROCEDURE: sp_provision_profile ─────────────────────────────────
CREATE OR REPLACE PROCEDURE public.sp_provision_profile(
    p_auth_id UUID, p_email VARCHAR, p_first_name VARCHAR,
    p_last_name VARCHAR, p_role_key VARCHAR,
    p_phone_number VARCHAR DEFAULT NULL, p_country_code CHAR(2) DEFAULT NULL
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_id_profile_role UUID;
    v_id_profile      UUID;
    v_resolved_role   VARCHAR;
BEGIN
    v_resolved_role := LOWER(TRIM(COALESCE(p_role_key, 'professional')));
    SELECT id_profile_role INTO v_id_profile_role FROM public.profile_role
    WHERE role_key = v_resolved_role AND deleted_at IS NULL;
    IF v_id_profile_role IS NULL THEN
        SELECT id_profile_role INTO v_id_profile_role FROM public.profile_role WHERE role_key = 'professional';
    END IF;
    INSERT INTO public.profile (auth_id, id_profile_role, email, first_name, last_name, phone_number, country_code)
    VALUES (p_auth_id, v_id_profile_role, p_email,
            COALESCE(NULLIF(TRIM(p_first_name),''), SPLIT_PART(p_email,'@',1)),
            COALESCE(p_last_name,''), p_phone_number, p_country_code)
    ON CONFLICT (auth_id) DO NOTHING RETURNING id_profile INTO v_id_profile;
    IF v_id_profile IS NULL THEN RETURN; END IF;
    IF v_resolved_role = 'recruiter' THEN
        INSERT INTO public.profile_company (id_profile) VALUES (v_id_profile) ON CONFLICT (id_profile) DO NOTHING;
    ELSE
        INSERT INTO public.profile_basic   (id_profile) VALUES (v_id_profile) ON CONFLICT (id_profile) DO NOTHING;
    END IF;
END;
$$;

-- ── 10. TRIGGER FUNCTION: fn_on_auth_user_created ─────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_on_auth_user_created()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_role VARCHAR; v_first_name VARCHAR; v_last_name VARCHAR;
    v_full_name TEXT; v_email VARCHAR;
BEGIN
    v_full_name  := NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), '');
    v_role       := LOWER(TRIM(COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'role'),''),
        NULLIF(TRIM(NEW.raw_app_meta_data ->>'role'),''), 'professional')));
    v_first_name := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'),''),
        NULLIF(split_part(COALESCE(v_full_name,
            NULLIF(TRIM(NEW.raw_user_meta_data->>'preferred_username'),''),
            NULLIF(TRIM(NEW.raw_user_meta_data->>'user_name'),''),
            SPLIT_PART(COALESCE(NEW.email,''),'@',1)),' ',1),''));
    v_last_name  := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'),''),
        CASE WHEN v_full_name IS NOT NULL AND position(' ' IN v_full_name) > 0
             THEN TRIM(substring(v_full_name FROM position(' ' IN v_full_name)+1)) ELSE '' END);
    v_email      := COALESCE(NULLIF(TRIM(NEW.email),''), 'oauth-'||NEW.id::TEXT||'@ethoshub.noreply');
    CALL public.sp_provision_profile(
        NEW.id, v_email, COALESCE(v_first_name,'usuario'), COALESCE(v_last_name,''), v_role,
        NULLIF(TRIM(NEW.raw_user_meta_data->>'phone_number'),''),
        NULLIF(TRIM(UPPER(NEW.raw_user_meta_data->>'country_code')),''));
    RETURN NEW;
END;
$$;

-- ── 11. B-TREE INDEXES ────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profile_auth_id         ON public.profile(auth_id);
CREATE INDEX IF NOT EXISTS idx_profile_email           ON public.profile(email);
CREATE INDEX IF NOT EXISTS idx_profile_role_fk         ON public.profile(id_profile_role);
CREATE INDEX IF NOT EXISTS idx_profile_active          ON public.profile(is_active, deleted_at) WHERE is_active = TRUE AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profile_role_key        ON public.profile_role(role_key);
CREATE INDEX IF NOT EXISTS idx_profile_basic_profile   ON public.profile_basic(id_profile);
CREATE INDEX IF NOT EXISTS idx_profile_company_profile ON public.profile_company(id_profile);

-- ── 12. ROW LEVEL SECURITY ────────────────────────────────────────────────────
ALTER TABLE public.profile         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_basic   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_company ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_role    ENABLE ROW LEVEL SECURITY;

CREATE POLICY pol_profile_select_own     ON public.profile FOR SELECT TO authenticated USING (auth_id = auth.uid());
CREATE POLICY pol_profile_update_own     ON public.profile FOR UPDATE TO authenticated USING (auth_id = auth.uid() AND deleted_at IS NULL) WITH CHECK (auth_id = auth.uid() AND deleted_at IS NULL);
CREATE POLICY pol_profile_service_all    ON public.profile FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY pol_profile_basic_select   ON public.profile_basic FOR SELECT TO authenticated USING ((SELECT auth_id FROM public.profile p WHERE p.id_profile = profile_basic.id_profile) = auth.uid());
CREATE POLICY pol_profile_basic_update   ON public.profile_basic FOR UPDATE TO authenticated USING ((SELECT auth_id FROM public.profile p WHERE p.id_profile = profile_basic.id_profile) = auth.uid()) WITH CHECK ((SELECT auth_id FROM public.profile p WHERE p.id_profile = profile_basic.id_profile) = auth.uid());
CREATE POLICY pol_profile_basic_service  ON public.profile_basic FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY pol_profile_company_select ON public.profile_company FOR SELECT TO authenticated USING ((SELECT auth_id FROM public.profile p WHERE p.id_profile = profile_company.id_profile) = auth.uid());
CREATE POLICY pol_profile_company_update ON public.profile_company FOR UPDATE TO authenticated USING ((SELECT auth_id FROM public.profile p WHERE p.id_profile = profile_company.id_profile) = auth.uid()) WITH CHECK ((SELECT auth_id FROM public.profile p WHERE p.id_profile = profile_company.id_profile) = auth.uid());
CREATE POLICY pol_profile_company_service ON public.profile_company FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY pol_profile_role_select    ON public.profile_role FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY pol_profile_role_service   ON public.profile_role FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);
