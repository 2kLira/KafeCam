-- =============================================================================
-- KafeCam — Integration audit fixes (v1)
-- Generated 2026-05-29 from INTEGRATION_AUDIT.md.  REVIEW BEFORE APPLYING.
-- Target: prod project uzdvklhsxsujuwjfncdw (App-Store-live).
--
-- This migration is IDEMPOTENT (if-not-exists / or-replace / drop-if-exists) and
-- supersedes the never-applied 20260526000000_add_apns_token.sql (apns_token is
-- folded in below). It does NOT create the v2 assignment tables
-- (assignment_requests / technician_farmers) — those stay gated in the client.
--
-- NOTE: 0 rows exist in profiles/captures today, so backfill is not required.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Extended profile columns (the Edit-Profile screen writes these; without
--    them the upsert fails with PGRST204 and the whole profile save is lost).
--    Types chosen to match the Swift contracts:
--      date_of_birth -> `date`  (client sends "yyyy-MM-dd"; ProfileDTO.parseDate)
--      age           -> integer
--      show_*        -> boolean NOT NULL DEFAULT true (VM defaults to true)
-- -----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists gender             varchar,
  add column if not exists date_of_birth      date,
  add column if not exists age                integer,
  add column if not exists country            varchar,
  add column if not exists state              varchar,
  add column if not exists about              text,
  add column if not exists show_gender        boolean not null default true,
  add column if not exists show_date_of_birth boolean not null default true,
  add column if not exists show_age           boolean not null default true,
  add column if not exists show_country       boolean not null default true,
  add column if not exists show_state         boolean not null default true,
  add column if not exists show_about         boolean not null default true,
  add column if not exists apns_token         text;

-- Fast lookup by APNs token (used by future notify-technician function).
create index if not exists profiles_apns_token_idx on public.profiles (apns_token)
  where apns_token is not null;

-- -----------------------------------------------------------------------------
-- 2. captures.notes — CapturesRepository.updateNotes() writes this column.
-- -----------------------------------------------------------------------------
alter table public.captures
  add column if not exists notes text;

-- -----------------------------------------------------------------------------
-- 3. Fix handle_new_user (root cause of "emails are wrong, phone, etc.").
--    OLD behaviour set:
--      profiles.email = new.email  -> the SYNTHETIC login id <phone>@kafe.local
--      profiles.phone = new.phone  -> NULL (auth native phone is never set)
--    NEW behaviour reads the REAL values from signup metadata:
--      email -> personal_email (NULL if not provided; never the synthetic id)
--      phone -> raw_user_meta_data.phone (the 10-digit login code)
--    Also made idempotent with ON CONFLICT so the client upsert can't collide.
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, email, phone, organization, role, locale)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', ''),
    nullif(new.raw_user_meta_data->>'personal_email', ''),               -- real email or NULL
    coalesce(nullif(new.raw_user_meta_data->>'phone', ''), new.phone),   -- 10-digit code from metadata
    new.raw_user_meta_data->>'organization',
    'farmer',
    'es'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Make is_admin()/is_technician() SECURITY DEFINER with a fixed search_path.
--    Two birds: (a) silences the function_search_path_mutable advisor, and
--    (b) lets these helpers be used inside profiles RLS policies WITHOUT
--    infinite RLS recursion (they now bypass RLS when reading profiles).
-- -----------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  );
$$;

create or replace function public.is_technician()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'technician'
  );
$$;

-- -----------------------------------------------------------------------------
-- 5. Fix mutable search_path on the remaining flagged functions (no body change).
-- -----------------------------------------------------------------------------
alter function public.nearest_soil_reading(uuid, timestamp with time zone)
  set search_path = public;
alter function public.block_role_change_by_non_admin()
  set search_path = public;

-- -----------------------------------------------------------------------------
-- 6. profiles read policy for technicians.
--    Today profiles SELECT = (id = auth.uid() OR is_admin()), so a technician
--    cannot read an assigned farmer's profile (FarmerDetailView header is blank).
--    NOTE: v1 has no technician_farmers link table, so this grants a technician
--    read access to ALL profiles. That is broad; tighten in v2 to the
--    technician_farmers relationship. (FarmerDetailView is gated off until v2.)
-- -----------------------------------------------------------------------------
drop policy if exists "profiles technician read" on public.profiles;
create policy "profiles technician read"
  on public.profiles
  for select
  to authenticated
  using (public.is_technician());

-- -----------------------------------------------------------------------------
-- 7. diseases read policy — RLS is enabled but no policy exists, so the disease
--    catalog is unreadable by clients. It is reference data; allow read to all
--    signed-in users.
-- -----------------------------------------------------------------------------
drop policy if exists "diseases read all" on public.diseases;
create policy "diseases read all"
  on public.diseases
  for select
  to authenticated
  using (true);

-- -----------------------------------------------------------------------------
-- 8. avatars Storage RLS — the bucket currently has ZERO policies, so every
--    avatar upload/download is denied. Standardized key = '<lowercase-uid>.jpg'
--    (matches the client after this change). auth.uid()::text is lowercase.
--    SELECT is open to any authenticated user because avatars are shown across
--    the app (community/farmer detail). Restrict if that is not desired.
-- -----------------------------------------------------------------------------
drop policy if exists "avatars insert own"        on storage.objects;
drop policy if exists "avatars update own"        on storage.objects;
drop policy if exists "avatars delete own"        on storage.objects;
drop policy if exists "avatars read authenticated" on storage.objects;

create policy "avatars insert own"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and name = (auth.uid()::text || '.jpg'));

create policy "avatars update own"
  on storage.objects for update to authenticated
  using      (bucket_id = 'avatars' and name = (auth.uid()::text || '.jpg'))
  with check (bucket_id = 'avatars' and name = (auth.uid()::text || '.jpg'));

create policy "avatars delete own"
  on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and name = (auth.uid()::text || '.jpg'));

create policy "avatars read authenticated"
  on storage.objects for select to authenticated
  using (bucket_id = 'avatars');

-- -----------------------------------------------------------------------------
-- 9. Bucket hardening. Both buckets stay PRIVATE (the app uses signed URLs).
--    Enforce sane size limits and image-only mime types. The client uploads
--    JPEG for both avatars and captures.
-- -----------------------------------------------------------------------------
update storage.buckets
  set file_size_limit = 5242880,  -- 5 MB
      allowed_mime_types = array['image/jpeg','image/png','image/heic','image/heif']
  where id = 'avatars';

update storage.buckets
  set file_size_limit = 10485760, -- 10 MB
      allowed_mime_types = array['image/jpeg','image/png','image/heic','image/heif']
  where id = 'captures';

commit;

-- =============================================================================
-- OPTIONAL HARDENING (review separately — addresses security advisors).
-- Safe to apply: these are trigger / event-trigger functions; revoking the
-- PostgREST RPC EXECUTE grant does NOT affect trigger firing.
-- =============================================================================
-- revoke execute on function public.handle_new_user()                from anon, authenticated;
-- revoke execute on function public.block_role_change_by_non_admin() from anon, authenticated;
-- revoke execute on function public.rls_auto_enable()                from anon, authenticated;

-- =============================================================================
-- NOT INCLUDED (out of scope / needs its own decision):
--  * v_latest_diagnosis_per_plot is a SECURITY DEFINER view (advisor ERROR).
--    Recreate with `with (security_invoker = true)` once its definition is
--    reviewed — not touched here because the client does not query it.
--  * Auth "leaked password protection" is a Dashboard setting
--    (Authentication → Providers → Email), not SQL.
--  * assignment_requests / technician_farmers tables + RPCs
--    (search_farmer_exact, respond_assignment_request,
--    list_technicians_for_current_farmer) and the notify-technician Edge
--    Function are intentionally deferred to v2 (client gated via
--    FeatureFlags.assignmentsEnabled).
-- =============================================================================
