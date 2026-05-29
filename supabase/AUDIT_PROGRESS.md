# KafeCam Supabase Integration Audit — PROGRESS / CHECKPOINT

> Working notes for the backend↔frontend integration audit. Safe to delete once
> `SCHEMA_SNAPSHOT.md` + `INTEGRATION_AUDIT.md` are finalized.
> Prod project ref: **uzdvklhsxsujuwjfncdw** (App Store live app — treat as READ-ONLY).

## Access status
- Read-only MCP `supabase` (`project_ref=uzdvklhsxsujuwjfncdw&read_only=true`) is configured in `.mcp.json` and authenticated, but `mcp__supabase__*` tools require a session MCP-reconnect to load.
- `claude.ai Supabase` connector is on the WRONG account (has shown Dasza 3PL/DLT/Transformarte, then afi_preProd) — do NOT use it for KafeCam.
- Supabase CLI is linked to uzdvklhsxsujuwjfncdw; `migration list`, `functions list` work (no Docker). `db dump` needs Docker (unavailable). `psql` needs a password (keychain read denied).

## CONFIRMED findings (live, via CLI) — do not re-litigate
1. **Edge functions deployed = NONE.** `supabase functions list --project-ref uzdvklhsxsujuwjfncdw -o json` → `[]`.
   → Client invokes `notify-technician` ([PushNotificationService.swift:73-84]) → **runtime 404 / failure**. CRITICAL candidate. `upload_url` also absent (but it's dead code anyway).
2. **`add_apns_token` migration not in remote history.** `supabase migration list` shows local `20260526000000` with a blank Remote column → schema applied out-of-band. Verify `profiles.apns_token` actually exists in live DB.

## Swift client contracts (fully extracted) — to diff against live schema

### DTOs (decode; non-Optional = decode-crash if DB NULL)
- **ProfileDTO** (`Models/ProfileDTO.swift`): `id:UUID` (req) + all else Optional. Custom `init(from:)` hand-parses dates `created_at`,`date_of_birth` via 3 formats: `yyyy-MM-dd'T'HH:mm:ssXXXXX`, `yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX`, `yyyy-MM-dd`. Cols: phone,name,email,role,organization,locale,created_at,gender,date_of_birth,age,country,state,about,show_* (6 bools),apns_token.
- **CaptureDTO** (`Models/CaptureDTO.swift`): NON-OPTIONAL → `id`,`plot_id`,`uploaded_by_user_id`,`taken_at`(Date),`photo_key`. Optional → `client_uuid`,`created_offline_at`,`device_model`,`checksum_sha256`,`created_at`,`notes`.
- **PlotDTO** (`Models/PlotDTO.swift`): NON-OPTIONAL → `id`,`name`,`owner_user_id`. Optional → `lat`,`lon`,`altitude_m`,`region`,`created_at`. Defines `JSONDecoder.supabaseDefault` (.iso8601) — **but SupaClient does NOT wire it into the SDK client → likely dead code; SDK uses its own default decoder.**
- **AssignmentRequestDTO** (`Models/AssignmentRequestDTO.swift`): ALL NON-OPTIONAL → `id`,`technician_id`,`farmer_id`,`status`,`created_at`(Date).

### Payloads (encode)
- **UpsertProfilePayload** (`ProfilesRepository.swift:15-63`): conditional-encodes (omits nils); `id` always. role: `"farmer"` on create (line ~183), `nil`/omitted on upsert (line ~84). `personal_email` lives in AUTH metadata, not profiles.
- **NewCapturePayload** (`CapturesRepository.swift:50-70`): plot_id,uploaded_by_user_id,taken_at(ISO8601 string),photo_key (req); client_uuid,created_offline_at,device_model,checksum_sha256 (opt). Dates via `ISO8601DateFormatter()` (NO fractional seconds).
- **NewPlotPayload** (`PlotsRepository.swift:37-70`): name,owner_user_id (req); lat,lon,region (opt). Omits altitude_m,created_at.
- **NewRequestPayload** (`AssignmentRequestsRepository.swift:15-19`): technician_id,farmer_id. Upsert onConflict `"technician_id,farmer_id,status"`.

### RPC call sites → verify each EXISTS with matching signature
- `delete_current_user()` no args — `SupaClient.swift:115` (expect SECURITY DEFINER).
- `search_farmer_exact(p_name, p_phone)` both String — `FarmersListViewModel.swift:102-104`.
- **`respond_assignment_request(req_id, accept)`** — `AssignmentRequestsRepository.swift:74-79`. **CLIENT SENDS `accept` AS STRING `"true"`/`"false"`** (`accept ? "true" : "false"`). req_id as uuidString. ⇒ verify DB param type: if `boolean`, string may still coerce via PostgREST, but if typed strictly could fail. PRIME SUSPECT.
- `list_technicians_for_current_farmer()` no args — `ProfileTabViewModel.swift:117-120`.

### Edge function invocations
- `notify-technician` payload `{farmer_id, capture_id, prediction}` (all String) — `PushNotificationService.swift:73-84`. (NOT DEPLOYED — see finding #1.)
- `upload_url` `{objectKey}` — `CapturesRepository.swift:25-47` `createSignedUploadURL` = **DEAD CODE** (zero callers). Real upload = `StorageRepository.upload()` REST POST to `/storage/v1/object/{bucket}/{key}` — `CapturesService.swift:43-44`, `StorageRepository.swift:111-134`.

### Storage keys
- **captures** bucket: key = `"<cleaned profile.name>/<timestamp>_<uuid8>.jpg"`; full key stored in `photo_key`; read back as-is in `HistoryStore.fetchImage` (`HistoryStore.swift:113-132`) → CONSISTENT.
- **avatars** bucket: CHAOS. Upload tries (in order) `{uidLower}.jpg`, `{uidLower}-avatar.jpg`, `{uidUpper}.jpg` (`ProfileTabViewModel.swift:166-219`); stores chosen key in auth metadata `avatar_key`. Readers brute-force probe: CommunityListView up to 20 variants (4 names × {jpg,jpeg,png,heic,pdf}); CreateListView/EditListView/UserDetailView probe 4; ProfileTabViewModel uses metadata `avatar_key` then fallback `{uid}.jpg`. → standardize on ONE convention (recommend `{uidLower}.jpg`).

### Cross-user RLS-dependent reads (verify policies permit technician→assigned-farmer)
- `FarmerDetailViewModel.load(farmerId:)` (`FarmerDetailView.swift:63-86`): reads `profiles` by id, `plots` by owner_user_id, `captures` by uploaded_by_user_id for ANOTHER user. If RLS blocks → silent empty.
- `technician_farmers` RLS-recursion: code comment "Prefer a SECURITY DEFINER function to avoid RLS recursion" (`FarmersListViewModel.swift` ~line 100) → verify policies don't self-recurse.

## 🔧 REMEDIATION PHASE 1 (2026-05-29) — client fixes APPLIED (build SUCCEEDED), migration WRITTEN (not applied)
Client (compiled clean via xcodebuild, iOS Simulator):
- `FeatureFlags.assignmentsEnabled = false` gates: ProfileTabView (técnico/Peticiones/Farmers), ProfileTabViewModel farmer-load, DetectaView notify-technician, UserDetailView assign UI, PedirAyudaView (mock contacts → "ComingSoonCard"), AssignmentRequestsRepository/TechnicianAssignmentsRepository/FarmersListViewModel guards.
- PlotDTO.ownerUserId → `UUID?`; CapturesService key → `<lowercaseuid>/...` (RLS match); avatar upload single key `<uidLower>.jpg`; removed `upload_url` dead code.
- Synthetic-email fix: `SupaAuthService.sanitizedPersonalEmail()` (drops `@kafe.local`) applied in ProfilesRepository.getOrCreateCurrent (both branches) + ProfileTabViewModel; phone made read-only in Edit Profile (login identity).
- Pre-existing unrelated build blocker fixed: CrashMonitor `enableSwiftAsyncStacktraces` → `swiftAsyncStacktraces` (Sentry 9.x rename). Flag for user.
Migration WRITTEN (review, NOT applied): `supabase/migrations/20260529120000_integration_audit_fixes.sql` — extended profile cols+apns_token, captures.notes, **handle_new_user trigger fix (email/phone root cause)**, is_admin/is_technician→SECURITY DEFINER+search_path, nearest_soil_reading/block_role_change search_path, profiles technician read policy, diseases read policy, **avatars storage policies (bucket had ZERO)**. Supersedes stale 20260526000000_add_apns_token.sql.
**✅ APPLIED to prod uzdvklhsxsujuwjfncdw (2026-05-29, user pasted via Dashboard SQL Editor). Verified:** 13 profile cols + apns_token, captures.notes, handle_new_user fixed, is_admin/is_technician→DEFINER+search_path, technician/diseases read policies, 4 avatars storage policies, bucket size/mime limits. Advisors: all function_search_path_mutable warnings cleared.
Follow-up `20260529130000_security_hardening.sql` (view security_invoker + REVOKE on trigger funcs) WRITTEN + presented — awaiting user paste (optional). .mcp.json restored to read_only=true.
Remaining (non-blocking): leaked-password protection (Dashboard toggle), pre-existing perf advisors (auth_rls_initplan/unindexed FK/unused index).

## ✅ AUDIT COMPLETE (2026-05-29) — live read-only MCP run finished
Deliverables written: [SCHEMA_SNAPSHOT.md](./SCHEMA_SNAPSHOT.md), [INTEGRATION_AUDIT.md](./INTEGRATION_AUDIT.md).
Headline confirmed findings (prod uzdvklhsxsujuwjfncdw):
- 🔴 `assignment_requests` & `technician_farmers` tables DO NOT EXIST (to_regclass NULL).
- 🔴 RPCs missing: `search_farmer_exact`, `respond_assignment_request`, `list_technicians_for_current_farmer`. Only `delete_current_user` exists. (The accept String-vs-bool question is moot — fn absent.)
- 🔴 No edge functions deployed; `notify-technician` 404 (re-confirmed via schema run context).
- 🟠 profiles missing ALL extended cols (gender/date_of_birth/age/country/state/about/show_*) + `apns_token` → UpsertProfilePayload PGRST204 when those fields set.
- 🟠 profiles SELECT policy = `id=auth.uid() OR is_admin()` → technician CANNOT read farmer profile (FarmerDetailView blank header; plots/captures OK).
- 🟡 PlotDTO.owner_user_id non-Optional but DB nullable → latent decode-crash.
- migrations history empty; buckets avatars+captures both private.

**STOPPED for user approval before any remediation (migrations / code changes).**

## (historical) TODO once `mcp__supabase__*` loads (all read-only execute_sql / list_tables)
1. `list_tables(verbose, schemas=['public'])` → columns/types/nullability/PK/FK/unique. Diff vs DTOs above (esp. CaptureDTO/PlotDTO/AssignmentRequestDTO non-optional fields vs DB nullability; confirm `apns_token` exists).
2. `execute_sql`: `SELECT proname, pg_get_function_identity_arguments(oid), prosecdef, proconfig FROM pg_proc JOIN pg_namespace n ON pronamespace=n.oid WHERE n.nspname='public'` → RPC signatures (esp. respond_assignment_request `accept` type).
3. `execute_sql` on `pg_policies` for profiles,plots,captures,technician_farmers,assignment_requests + storage.objects.
4. `SELECT * FROM storage.buckets` (public flag), `list_extensions`, `list_migrations`.
5. Date format: `SELECT to_jsonb(taken_at), to_jsonb(created_at) FROM captures LIMIT 2` etc. (no PII cols) → confirm format vs SDK decoder + ProfileDTO 3-format parser. Also read supabase-swift PostgREST default decoder (checkout under DerivedData SourcePackages) to confirm effective date strategy.
6. `get_advisors(security)` + `get_advisors(performance)`.
7. Write `SCHEMA_SNAPSHOT.md`, build contract matrix, write `INTEGRATION_AUDIT.md`, STOP for approval.
