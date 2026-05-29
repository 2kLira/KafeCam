# KafeCam — Backend↔Frontend Audit & Remediation Report

**Date:** 2026-05-29
**Prod project:** `uzdvklhsxsujuwjfncdw` (App-Store-live)
**Scope:** Supabase integration audit of the live iOS app, plus the client-side
and database fixes that followed.

This document is the canonical record of what was found, what was changed, why,
and what remains. Companion files:
- [`SCHEMA_SNAPSHOT.md`](./SCHEMA_SNAPSHOT.md) — live schema captured during the audit
- [`INTEGRATION_AUDIT.md`](./INTEGRATION_AUDIT.md) — contract matrix (client vs DB)
- [`AUDIT_PROGRESS.md`](./AUDIT_PROGRESS.md) — working checkpoint log
- Migrations: [`migrations/20260529120000_integration_audit_fixes.sql`](./migrations/20260529120000_integration_audit_fixes.sql),
  [`migrations/20260529130000_security_hardening.sql`](./migrations/20260529130000_security_hardening.sql)

---

## 1. Executive summary

The audit diffed every Swift client contract (DTOs, payloads, RPC calls, edge
function invocations, storage keys) against the live Postgres schema. It found a
mix of **runtime-breaking mismatches** and **security gaps**. All v1 issues are
now resolved:

- The **technician↔farmer assignment feature** had no backend at all (missing
  tables + RPCs + undeployed edge function). It is now **feature-flagged OFF**
  (`FeatureFlags.assignmentsEnabled = false`) — deferred to v2, not deleted.
- The **"emails are wrong, phone missing" bug** was rooted in the
  `handle_new_user` DB trigger writing the synthetic login id into `profiles.email`.
  Trigger fixed + client now sanitizes synthetic emails.
- **Profile editing** silently failed because the DB was missing 13 columns the
  app writes. Columns added.
- **Photo uploads were silently RLS-denied** (object keys never matched the
  storage policy). Key construction fixed.
- **Avatars were completely broken** — the `avatars` bucket had **zero** RLS
  policies. Policies added; client key standardized.
- Security advisors: the SECURITY DEFINER **view ERROR** and all
  `function_search_path_mutable` warnings are cleared.

**Build status:** `xcodebuild` → **BUILD SUCCEEDED** (iOS Simulator, Debug).

---

## 2. What was broken (audit findings)

| # | Sev | Area | Finding |
|---|-----|------|---------|
| C1 | 🔴 | DB tables | `assignment_requests` and `technician_farmers` did not exist |
| C2 | 🔴 | RPCs | `search_farmer_exact`, `respond_assignment_request`, `list_technicians_for_current_farmer` did not exist |
| C3 | 🔴 | Edge fn | `notify-technician` not deployed; `upload_url` not deployed (and was dead client code) |
| C4 | 🔴 | Auth wiring | `handle_new_user` wrote `profiles.email = <phone>@kafe.local` (synthetic login id) and left `profiles.phone` NULL |
| C5 | 🟠 | Schema | `profiles` missing `gender, date_of_birth, age, country, state, about, show_*` (6), `apns_token` → profile-edit upsert failed (PGRST204) |
| C6 | 🟠 | Storage | `captures` object keys built from profile name / uppercased UUID → never matched RLS `name LIKE auth.uid()/%` → uploads denied |
| C7 | 🟠 | Storage | `avatars` bucket had no RLS policies → all avatar upload/download denied |
| C8 | 🟡 | Schema | `captures.notes` column referenced by client, absent in DB |
| C9 | 🟡 | DTO | `PlotDTO.ownerUserId` non-optional but column is nullable → latent decode crash |
| C10 | 🟡 | RLS | technicians could not read assigned farmer profiles (policy = self/admin only) |
| C11 | 🟢 | Security | `diseases` had RLS on but no policy; SECURITY DEFINER view; mutable `search_path` on 4 functions; SECURITY DEFINER functions API-exposed |

---

## 3. Client-side changes (Swift) — APPLIED, build verified

### Feature gating (the v2 assignment surface)
New flag in [`KafeCam/Config/FeatureFlags.swift`](../KafeCam/Config/FeatureFlags.swift):
`static let assignmentsEnabled = false`.

Gated everywhere the missing backend was touched:
- [`Profile/ProfileTabView.swift`](../KafeCam/Profile/ProfileTabView.swift) — hides "Técnico", "Peticiones", "Farmers"
- [`Profile/ProfileTabViewModel.swift`](../KafeCam/Profile/ProfileTabViewModel.swift) — skips `listIncoming()` + `list_technicians_for_current_farmer` RPC (and made them non-fatal with `try?`)
- [`Detecta/DetectaView.swift`](../KafeCam/Detecta/DetectaView.swift) — skips `notifyTechnicianCaptureSaved`
- [`Profile/UserDetailView.swift`](../KafeCam/Profile/UserDetailView.swift) — hides technician assign/remove actions
- [`Repositories/AssignmentRequestsRepository.swift`](../KafeCam/Repositories/AssignmentRequestsRepository.swift), [`Repositories/TechnicianAssignmentsRepository.swift`](../KafeCam/Repositories/TechnicianAssignmentsRepository.swift), [`Profile/FarmersListViewModel.swift`](../KafeCam/Profile/FarmersListViewModel.swift) — defensive guards (return empty / throw clear error)
- [`Help/PedirAyudaView.swift`](../KafeCam/Help/PedirAyudaView.swift) — the technician directory was **mock data**; behind the flag it now shows a "coming soon" card instead of fake contacts, keeping the supportive messaging and the lesson "ask for help" entry intact

### Correctness fixes
- **`Models/PlotDTO.swift`** — `ownerUserId: UUID` → `UUID?` (matches nullable column; prevents decode crash).
- **`Services/CapturesService.swift`** — capture object key is now `"<lowercased-uid>/<timestamp>_<uuid8>.jpg"` so it matches the `captures` Storage RLS policy (`name LIKE auth.uid()::text || '/%'`, which is lowercase). Removed the profile-name folder logic that broke RLS.
- **`Profile/ProfileTabViewModel.swift`** — avatar upload standardized to a single key `"<lowercased-uid>.jpg"`; removed the 3-candidate brute-force loop.
- **`Repositories/CapturesRepository.swift`** — removed dead `createSignedUploadURL` / `upload_url` code (zero callers; function undeployed).

### Auth / profile wiring (the "emails/phone wrong" fix)
Login identity = `<phone>@kafe.local` (synthetic). The real email lives in
`profiles.email` / auth metadata `personal_email`.
- **`Networking/SupaClient.swift`** — added `SupaAuthService.syntheticEmailDomain` + `sanitizedPersonalEmail(_:)` (returns nil for `@kafe.local`). Synthetic email built from the constant.
- **`Repositories/ProfilesRepository.swift`** — `getOrCreateCurrent()` now sanitizes synthetic emails in both the repair and create paths, and repairs a profile whose stored email is synthetic.
- **`Profile/ProfileTabViewModel.swift`** — display email is sanitized in `load()` and `saveProfile()`.
- **`Profile/ProfileTabView.swift`** — phone field in Edit Profile is now **read-only** (it is the login identifier; editing it would desync login ↔ profile).

### Unrelated pre-existing fix (flagged)
- **`Monitoring/CrashMonitor.swift`** — `enableSwiftAsyncStacktraces` (removed in Sentry 9.x) → `swiftAsyncStacktraces`. The project resolves `sentry-cocoa 9.15.0`; the old symbol broke compilation. This is part of the existing Sentry integration, not the audit.

---

## 4. Database migrations — APPLIED to prod

Applied via the Supabase Dashboard SQL Editor (read-only MCP could not write).
Both are idempotent.

### `20260529120000_integration_audit_fixes.sql` ✅ applied + verified
1. **profiles**: added `gender, date_of_birth (date), age (int), country, state, about, show_* (6 bool NOT NULL default true), apns_token` + partial index on `apns_token`.
2. **captures**: added `notes text`.
3. **`handle_new_user` trigger fixed** — now inserts `email = nullif(meta.personal_email,'')` (real email or NULL, never synthetic) and `phone = coalesce(meta.phone, new.phone)`; `on conflict (id) do nothing`.
4. **`is_admin()` / `is_technician()`** → `SECURITY DEFINER` + `search_path = public` (also eliminates RLS recursion when used in policies).
5. **`nearest_soil_reading`, `block_role_change_by_non_admin`** → `search_path = public`.
6. **`profiles technician read`** policy → `is_technician()` (see §6 note on breadth).
7. **`diseases read all`** policy → `to authenticated using (true)`.
8. **avatars Storage policies** (insert/update/delete own `= auth.uid()::text || '.jpg'`; select to any authenticated).
9. **Bucket config**: avatars 5 MB, captures 10 MB, both private, mime `image/jpeg|png|heic|heif`.

**Verification:** 13/13 profile columns present, `captures.notes` present, all
policies present, all functions show expected `prosecdef`/`search_path`, buckets
configured. Advisors: all `function_search_path_mutable` warnings gone.

### `20260529130000_security_hardening.sql` ✅ applied (with one correction)
- `v_latest_diagnosis_per_plot` → `security_invoker = on` (clears the advisor **ERROR**). **Verified `security_invoker=on`.**
- Revoke API `EXECUTE` on the trigger/event-trigger functions.
  - ⚠️ The first applied version revoked from `anon, authenticated`, which was a
    **no-op** because the grant is to `PUBLIC`. The file has since been corrected
    to `REVOKE ... FROM PUBLIC`. **Re-paste the corrected file to fully clear the
    `0028/0029` warnings for `handle_new_user`, `block_role_change_by_non_admin`,
    `rls_auto_enable`.**
- `is_admin()` / `is_technician()` intentionally keep PUBLIC execute (RLS policies
  must run them). `delete_current_user()` keeps `authenticated` (app RPC), anon denied.

---

## 5. Storage, buckets & edge functions

- **Buckets:** `avatars` and `captures` — both **private** (app uses signed URLs),
  now with size + image-mime limits. Correct as-is.
- **Storage policies:** `captures` policies already existed and were correct; the
  client now produces matching keys. `avatars` policies created from scratch.
- **Edge functions:**
  - `upload_url` — dead client code, **removed**. Nothing to deploy.
  - `notify-technician` ([`supabase/functions/notify-technician/index.ts`](./functions/notify-technician/index.ts)) — code is correct but depends on the `technician_farmers` v2 table. **Not deployed** (consistent with deferring assignments to v2). Deploy it together with the v2 backend.
  - **No edge functions are required for v1.**

---

## 6. Decisions & trade-offs (review these)

1. **`avatars` SELECT is open to any authenticated user.** Profile photos are shown
   across community/farmer screens. Tighten to owner+staff if undesired.
2. **`profiles technician read` grants a technician read of ALL profiles.** v1 has
   no `technician_farmers` link table, so it can't be scoped yet. `FarmerDetailView`
   is gated off until v2; tighten this policy when the link table lands.
3. **`PedirAyudaView` gated to a "coming soon" card** rather than removing the entry
   point — it was mock data, and the lesson flow links to it.
4. **Phone is read-only in Edit Profile** — it is the login identity.
5. **`is_admin`/`is_technician` remain PUBLIC-executable** — required by RLS policy
   evaluation; residual advisor WARNs are expected and acceptable.

---

## 7. Remaining / optional

- **Re-paste corrected `20260529130000`** to clear the trigger-function advisor WARNs (the `REVOKE ... FROM PUBLIC` correction). Non-functional; hygiene only.
- **Leaked-password protection** — enable in Dashboard → Authentication → Providers → Email (a toggle, not SQL).
- **Performance advisors** (`auth_rls_initplan` on ~20 pre-existing policies, unindexed FKs, unused indexes) — optimizations, not errors; safe to defer on a 0-row DB. Can be batched later (wrap `auth.<fn>()` in `(select auth.<fn>())`, add FK indexes).
- **v2 (assignments):** to re-enable, create `assignment_requests` + `technician_farmers` tables, the 3 RPCs, deploy `notify-technician` with its APNs secrets, scope the technician read policy, then flip `FeatureFlags.assignmentsEnabled = true`.

---

## 8. How to verify locally

```bash
# Build (Metal toolchain required once: xcodebuild -downloadComponent MetalToolchain)
xcodebuild build -project KafeCam.xcodeproj -scheme KafeCam \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
```

MCP safety: `.mcp.json` is pinned to `project_ref=uzdvklhsxsujuwjfncdw` and is
back to `read_only=true`. The afi project was never written to.
