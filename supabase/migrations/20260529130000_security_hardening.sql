-- =============================================================================
-- KafeCam — Security hardening follow-up (advisor cleanup)
-- Target: prod uzdvklhsxsujuwjfncdw. Idempotent.
-- Addresses Supabase security advisors left after 20260529120000.
-- =============================================================================

-- 1. v_latest_diagnosis_per_plot was SECURITY DEFINER (advisor ERROR 0010):
--    it bypassed the querying user's RLS. Flip to SECURITY INVOKER so the
--    caller's RLS on captures/diagnoses applies. The view definition is
--    unchanged; the client does not query this view today.
alter view public.v_latest_diagnosis_per_plot set (security_invoker = on);

-- 2. Reduce SECURITY DEFINER function attack surface (advisors 0028/0029).
--    These functions are invoked by TRIGGERS / event triggers, never via the
--    REST API. Trigger execution does NOT require the caller to hold EXECUTE.
--    IMPORTANT: the default grant is to PUBLIC (which anon+authenticated inherit),
--    so we must revoke FROM PUBLIC — revoking from anon/authenticated alone is a
--    no-op while the PUBLIC grant stands.
revoke execute on function public.handle_new_user()                from public, anon, authenticated;
revoke execute on function public.block_role_change_by_non_admin() from public, anon, authenticated;
revoke execute on function public.rls_auto_enable()                from public, anon, authenticated;

-- delete_current_user() IS called via RPC by the app (authenticated). Deny anon.
revoke execute on function public.delete_current_user() from anon;

-- NOTE (intentional, NOT a defect): is_admin() and is_technician() keep their
-- PUBLIC EXECUTE grant ON PURPOSE. They are referenced inside RLS policies, so
-- the executing role (including anon during policy evaluation) must be able to
-- run them. They only reveal the caller's own role, so the residual 0028/0029
-- advisor lines for these two are expected and acceptable.

-- REMAINING (not addressed here — see notes):
--  * auth_leaked_password_protection: enable in Dashboard → Authentication →
--    Providers → Email (not a SQL change).
--  * Performance advisors (auth_rls_initplan, unindexed_foreign_keys,
--    unused_index, multiple_permissive_policies) are pre-existing optimizations,
--    not errors; safe to defer (0 rows today).
