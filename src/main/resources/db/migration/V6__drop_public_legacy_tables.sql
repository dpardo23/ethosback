-- =============================================================================
-- V6__drop_public_legacy_tables.sql
-- EthosHub — Eliminar tablas y funciones legacy del esquema public
--
-- Scope:
--   • Desconectar trigger antiguo public.fn_on_auth_user_created de auth.users
--   • Eliminar public.sp_provision_profile y public.fn_on_auth_user_created
--   • Eliminar tablas legacy: public.profile_basic, public.profile_company,
--     public.profile, public.profile_role, public.profile_moderation,
--     public.skill_tags, public.hard_skills, public.soft_skills,
--     public.skill_endorsements, public.admin_audit_log
--
-- Precondiciones:
--   • core.sp_provision_profile existe y está operativa (V5/seed aplicados)
--   • public.handle_new_auth_profile (función de trigger activa) se MANTIENE
--   • Los datos de public.profile han sido migrados a core.profiles (backfill)
--
-- ⚠  APLICAR MANUALMENTE via Supabase SQL Editor o MCP — toca auth.* schema.
-- =============================================================================

-- ── 1. DESCONECTAR TRIGGER LEGACY de auth.users ──────────────────────────────
-- El trigger activo es trg_handle_new_auth_profile → public.handle_new_auth_profile.
-- Este drop elimina cualquier trigger que apunte al proxy antiguo.
DROP TRIGGER IF EXISTS trg_on_auth_user_created        ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_created             ON auth.users;

-- ── 2. ELIMINAR FUNCIONES/PROCEDIMIENTOS LEGACY DEL ESQUEMA public ───────────
DROP PROCEDURE IF EXISTS public.sp_provision_profile(
    UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, CHAR
) CASCADE;

DROP FUNCTION IF EXISTS public.fn_on_auth_user_created() CASCADE;

-- ── 3. ELIMINAR TABLAS LEGACY (hijos → padres) ───────────────────────────────
-- Sub-perfiles primero (FK a public.profile)
DROP TABLE IF EXISTS public.profile_basic      CASCADE;
DROP TABLE IF EXISTS public.profile_company    CASCADE;

-- Tabla base de perfiles
DROP TABLE IF EXISTS public.profile            CASCADE;

-- Catálogo de roles (ahora en core.roles)
DROP TABLE IF EXISTS public.profile_role       CASCADE;

-- Moderación legacy (ahora en core.profile_moderation)
DROP TABLE IF EXISTS public.profile_moderation CASCADE;

-- Catálogos de habilidades legacy (ahora en core.skills / core.skill_tags)
DROP TABLE IF EXISTS public.admin_audit_log    CASCADE;
DROP TABLE IF EXISTS public.skill_endorsements CASCADE;
DROP TABLE IF EXISTS public.hard_skills        CASCADE;
DROP TABLE IF EXISTS public.soft_skills        CASCADE;
DROP TABLE IF EXISTS public.skill_tags         CASCADE;

-- ── 4. ELIMINAR FUNCIÓN UTILITARIA LEGACY ────────────────────────────────────
-- fn_set_updated_at en public (reemplazada por core.fn_set_updated_at)
DROP FUNCTION IF EXISTS public.fn_set_updated_at() CASCADE;
