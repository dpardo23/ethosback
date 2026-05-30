-- =============================================================================
-- V5__swap_core_auth_trigger.sql
-- EthosHub — Wire auth.users trigger to core.fn_on_auth_user_created
--
-- ⚠  IMPORTANT: This file touches the auth.* schema (Supabase-managed).
--    Flyway CANNOT apply this migration directly — apply manually via:
--      • Supabase Dashboard → SQL Editor
--      • Supabase MCP tool: mcp__supabase__apply_migration
--
-- Context:
--   V4 created core.fn_on_auth_user_created and left the auth.users trigger
--   pointing to public.fn_on_auth_user_created (proxy). This script completes
--   the migration by replacing the proxy with the canonical core function,
--   then drops the remaining public stubs.
-- =============================================================================

-- ── 1. REMOVE OLD TRIGGER ─────────────────────────────────────────────────────
-- The trigger was created in V3 pointing to public.fn_on_auth_user_created.
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;

-- ── 2. CREATE PRODUCTION TRIGGER ─────────────────────────────────────────────
-- Points directly to the core function; the public proxy is no longer needed.
CREATE TRIGGER trg_on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION core.fn_on_auth_user_created();

COMMENT ON TRIGGER trg_on_auth_user_created ON auth.users IS
    'Provisions core.profiles + role-specific sub-profile (profiles_basic or profiles_company) '
    'via core.sp_provision_profile on every new auth.users row. '
    'Covers OAuth sign-ups. Local email registration is also provisioned directly by Spring '
    'in AuthService.register() as a belt-and-suspenders guarantee.';

-- ── 3. DROP PUBLIC PROXY FUNCTION ─────────────────────────────────────────────
-- No longer called by any trigger or application code.
DROP FUNCTION IF EXISTS public.fn_on_auth_user_created() CASCADE;

-- ── 4. DROP REMAINING PUBLIC STUB ────────────────────────────────────────────
-- fn_set_updated_at was dropped in V4 after all public profile tables were removed.
-- This DROP is a safety net in case V4 ran before the tables were confirmed empty.
DROP FUNCTION IF EXISTS public.fn_set_updated_at() CASCADE;
