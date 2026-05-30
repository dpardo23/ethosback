-- =============================================================================
-- V3__swap_auth_trigger.sql
-- Completes the V2 migration: replaces the neutralized trigger with the new one
-- that calls fn_on_auth_user_created() → sp_provision_profile().
--
-- IMPORTANT: This file touches auth.users (Supabase-managed schema).
--            Apply via Supabase SQL Editor or MCP tool:
--              mcp__supabase__apply_migration
--            Do NOT rely on Flyway to run this — Flyway lacks access to auth schema.
-- =============================================================================

-- ── 1. DROP neutralized stub ─────────────────────────────────────────────────
-- V2 left fn_sync_auth_user_on_insert as a no-op; the trigger is still bound to it.
DROP TRIGGER  IF EXISTS trg_sync_auth_user_on_insert  ON auth.users;
DROP FUNCTION IF EXISTS public.fn_sync_auth_user_on_insert();

-- ── 2. CREATE the production trigger ─────────────────────────────────────────
-- fn_on_auth_user_created was fully defined in V2__refactor_profile_schema.sql.
-- It calls sp_provision_profile, which handles profile_basic / profile_company fanout.
CREATE TRIGGER trg_on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_on_auth_user_created();

COMMENT ON TRIGGER trg_on_auth_user_created ON auth.users IS
    'Provisions public.profile + sub-profile (profile_basic or profile_company) '
    'via sp_provision_profile on every new auth.users row. '
    'Covers OAuth sign-ups. Email registration is also provisioned directly by Spring '
    'in AuthService.register() as a belt-and-suspenders guarantee.';
