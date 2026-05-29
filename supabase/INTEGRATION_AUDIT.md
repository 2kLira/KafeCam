# KafeCam — Backend ↔ Frontend Integration Audit

> Diff of Swift client contracts vs. live prod schema (`uzdvklhsxsujuwjfncdw`), 2026-05-29.
> Live schema in [SCHEMA_SNAPSHOT.md](./SCHEMA_SNAPSHOT.md). **Prod is the App-Store-live app — every CRITICAL below is a runtime failure for real users.**

## Severity summary
| # | Severity | Area | Effect |
|---|---|---|---|
| C1 | 🔴 CRITICAL | `assignment_requests` table missing | Entire technician↔farmer assignment feature is dead (read + write + accept/reject) |
| C2 | 🔴 CRITICAL | `technician_farmers` table missing | Farmer/technician relationship reads fail |
| C3 | 🔴 CRITICAL | 3 RPCs missing | `search_farmer_exact`, `respond_assignment_request`, `list_technicians_for_current_farmer` → 404 |
| C4 | 🔴 CRITICAL | Edge function `notify-technician` not deployed | Push-notify on diagnosis silently 404s |
| C5 | 🟠 HIGH | profiles extended cols missing | Editing gender/DOB/age/country/state/about/show_* → upsert PGRST204, whole save fails |
| C6 | 🟠 HIGH | `profiles.apns_token` missing | APNs token registration write fails (no push targeting) |
| C7 | 🟠 HIGH | Technician cannot read farmer profile (RLS) | `FarmerDetailViewModel` shows plots/captures but blank profile |
| H1 | 🟡 MED | Storage capture key ≠ RLS prefix | Capture upload/read path mismatch vs. `name LIKE uid/%` policy — verify |
| H2 | 🟡 MED | avatars bucket key chaos | Brute-force probing; standardize on `{uidLower}.jpg` |
| L1 | 🟢 LOW | `diseases` RLS no policy | Disease catalog unreadable to clients |
| L2 | 🟢 LOW | Security advisors | DEFINER view ERROR + mutable search_path + leaked-password off |

---

## Contract matrix (client expectation → live reality)

### DTO decode (non-Optional fields = decode-crash if DB NULL)
| DTO | Field | DB col | Verdict |
|---|---|---|---|
| ProfileDTO | id (req) | NOT NULL | ✅ |
| ProfileDTO | gender,date_of_birth,age,country,state,about,show_*,apns_token (opt) | **absent** | ⚠️ decode-safe (Optional→nil) but **encode breaks** (see C5/C6) |
| CaptureDTO | id,plot_id,uploaded_by_user_id,taken_at,photo_key (req) | all NOT NULL | ✅ |
| CaptureDTO | client_uuid (opt in DTO) | NOT NULL in DB | ✅ (DTO laxer than DB — safe) |
| CaptureDTO | notes (opt) | **no `notes` col** | ✅ harmless (always nil; not sent) |
| PlotDTO | id,name,owner_user_id (req) | `owner_user_id` is **NULLABLE** | ⚠️ decode-crash if a plot has NULL owner |
| AssignmentRequestDTO | all req | **table absent** | 🔴 C1 |

> **PlotDTO note:** `owner_user_id` is non-Optional in Swift but nullable in DB. Any plot row with NULL owner will crash decode. Currently 0 rows, so latent.

### Payload encode
| Payload | Target | Verdict |
|---|---|---|
| UpsertProfilePayload | profiles | ✅ for id/name/email/phone/organization/locale/role; 🔴 C5 for any extended field |
| NewCapturePayload | captures | ✅ all columns exist |
| NewPlotPayload | plots | ✅ |
| NewRequestPayload | assignment_requests | 🔴 C1 (table absent) |

### RPC call sites
| Call | Live? |
|---|---|
| `delete_current_user()` | ✅ exists (DEFINER) |
| `search_farmer_exact(p_name,p_phone)` | 🔴 **missing** |
| `respond_assignment_request(req_id,accept)` | 🔴 **missing** (the `accept` String-vs-bool question is moot — fn doesn't exist) |
| `list_technicians_for_current_farmer()` | 🔴 **missing** |

### Edge functions
| Invocation | Deployed? |
|---|---|
| `notify-technician` | 🔴 no (C4) |
| `upload_url` | n/a (dead code, no callers) |

---

## Detail & remediation

**C1/C2/C3 — Assignment/farmer-list feature has no backend.** `assignment_requests` and `technician_farmers` tables don't exist, and all three supporting RPCs are absent. Every code path in `AssignmentRequestsRepository`, `FarmersListViewModel.search`, and `ProfileTabViewModel` technician-list will 404/error at runtime. Either (a) deploy the missing tables + RPCs + RLS, or (b) feature-flag these screens off until backend ships. Decide before any further client work.

**C4 — `notify-technician` not deployed.** `PushNotificationService.swift:73-84` invokes it after a diagnosis; returns 404. Deploy the function or gate the call.

**C5 — profiles extended columns.** `UpsertProfilePayload` omits nils, so a basic save (name/email/phone/org) works. But the Edit-Profile screen passes gender/DOB/age/country/state/about/show_* — as soon as any is non-nil, PostgREST returns PGRST204 (column not found) and the **entire upsert fails**, losing the basic edits too. Fix: add the columns (migration) or strip them from the payload + UI.

**C6 — apns_token.** Column absent (the `20260526000000` local migration was never applied to remote — `list_migrations` is empty). APNs registration write fails → no device targeting even once C4 is fixed.

**C7 — technician → farmer profile read.** profiles SELECT policy is `id = auth.uid() OR is_admin()` only. `FarmerDetailViewModel.load` reads `profiles` by id for another user → RLS returns empty → blank header, while plots/captures load fine (those policies include technician). Add a technician-read policy on profiles (e.g. via a `technician_farmers` link or `is_technician()`).

**H1 — capture storage key vs RLS.** storage.objects captures-bucket INSERT requires `name LIKE auth.uid() || '/%'`, but client builds keys as `"<profile.name>/<ts>_<uuid>.jpg"`. If uploads currently succeed, the prefix must actually be the uid — re-verify `StorageRepository.upload` / `CapturesService` key construction against the policy; a mismatch means **all capture uploads are RLS-denied**.

**H2 — avatars key chaos.** Standardize on `{uidLower}.jpg`; remove brute-force probing.

**L1/L2 — hardening.** Add a read policy to `diseases`; address advisors (DEFINER view, mutable search_path, leaked-password protection).

---

## Verification status
- ✅ Confirmed live via read-only MCP: table existence, columns/nullability, RLS policies, function signatures, buckets, advisors, empty migration history, zero edge functions.
- ⏳ Not verifiable (0 rows live): timestamptz wire format vs. `ProfileDTO` 3-format date parser and `ISO8601DateFormatter` (no fractional seconds). Re-check against a row once data exists — risk that 6-digit microsecond timestamps fail the `.SSSXXXXX` parser.
- ⏳ H1 needs a client-side re-read of capture-key construction to confirm uid prefix.
