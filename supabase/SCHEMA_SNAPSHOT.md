# KafeCam — Live Schema Snapshot

> Source: read-only MCP against prod `uzdvklhsxsujuwjfncdw`, 2026-05-29.
> Captured via `list_tables`, `pg_policies`, `pg_proc`, `storage.buckets`, `get_advisors`.
> All tables currently have **0 rows** (date-format sampling not possible against live data).

## Tables (public schema)

| Table | Notable columns (type, nullability) |
|---|---|
| **profiles** | `id` uuid PK→auth.users (NOT NULL), `phone` varchar UNIQUE null, `name` varchar NOT NULL, `email` varchar null, `role` varchar NOT NULL CHECK in (farmer,technician,admin), `locale` varchar NOT NULL def 'es', `created_at` tstz NOT NULL def now(), `deleted_at` tstz null, `organization` varchar null |
| **plots** | `id` uuid PK, `name` varchar NOT NULL, `lat`/`lon` numeric null, `altitude_m` int null, `region` varchar null, `created_at` tstz NOT NULL def now(), `owner_user_id` uuid null →profiles |
| **captures** | `id` uuid PK, `plot_id` uuid NOT NULL →plots, `uploaded_by_user_id` uuid NOT NULL →profiles, `taken_at` tstz NOT NULL, `photo_key` varchar NOT NULL, `device_model` varchar null, `client_uuid` uuid NOT NULL, `created_offline_at` tstz null, `checksum_sha256` bpchar null, `created_at` tstz NOT NULL def now() |
| **diagnoses** | id, `capture_id` uuid UNIQUE →captures, `disease_code`→diseases, `stage` int2 CHECK 0/1/2, `confidence` float4 CHECK 0..1 null, `model_version`, `created_at` |
| **diseases** | `code` PK, `name`, `description` null |
| **recommendations** | id, `diagnosis_id`→diagnoses, `level` CHECK info/warn/critical, `text`, `created_at` |
| **soil_readings** | id, `plot_id`→plots, `taken_at`, ph/ec/moisture/n/p/k/temp_c numeric null, source*, created_at |
| **weather_snapshots** | id, `plot_id` null→plots, fetched_at, provider def 'open-meteo', payload jsonb, ttl_seconds def 7200, created_by null→profiles |
| **notifications** | id, `user_id` null→profiles, `plot_id` null→plots, `type`, `payload` jsonb null, `created_at`, `read_at` null |
| **consents** | id, user_id→profiles, scope, granted_at, revoked_at null |
| **audit_log** | id, actor_user_id null→profiles, action, entity, entity_id, at, ip null |

### ❌ Tables that DO NOT EXIST (client references them)
- **`assignment_requests`** — `to_regclass` → NULL
- **`technician_farmers`** — `to_regclass` → NULL

### ❌ profiles columns the client encodes but that DO NOT EXIST
`gender`, `date_of_birth`, `age`, `country`, `state`, `about`,
`show_gender`, `show_date_of_birth`, `show_age`, `show_country`, `show_state`, `show_about`,
**`apns_token`**.

## Functions (public schema)
| name | args | returns | security |
|---|---|---|---|
| `delete_current_user` | () | void | DEFINER (search_path set) ✅ exists |
| `is_admin` | () | bool | INVOKER |
| `is_technician` | () | bool | INVOKER |
| `nearest_soil_reading` | (p_plot uuid, p_at tstz) | soil_readings | INVOKER |
| `handle_new_user` | () | trigger | DEFINER |
| `block_role_change_by_non_admin` | () | trigger | DEFINER |
| `rls_auto_enable` | () | event_trigger | DEFINER |

### ❌ RPCs the client calls but that DO NOT EXIST
- **`search_farmer_exact(p_name, p_phone)`**
- **`respond_assignment_request(req_id, accept)`**
- **`list_technicians_for_current_farmer()`**

## RLS policies (relevant tables)
- **profiles** — SELECT/UPDATE: `id = auth.uid() OR is_admin()`. INSERT/DELETE: `auth.uid() = id`.
  → **No technician read path.** A technician CANNOT read another user's profile row.
- **plots** — SELECT: owner OR technician/admin. INSERT/UPDATE/DELETE: owner OR admin.
- **captures** — SELECT: uploader OR plot-owner OR technician/admin. INSERT: `uploaded_by_user_id = auth.uid()`. UPDATE: uploader OR admin.
- **storage.objects (captures bucket)** — INSERT/SELECT/DELETE keyed on `name LIKE auth.uid() || '/%'` (+ staff read, admin delete).
  → ⚠️ Client capture keys are `"<profile.name>/<ts>_<uuid>.jpg"`, **not** `"<uid>/..."` — see audit.
- **diseases** — RLS enabled, **no policies** → unreadable by clients (advisor INFO).

## Storage buckets
| id | public |
|---|---|
| avatars | **false** (private) |
| captures | **false** (private) |

## Migrations
`list_migrations` → **empty**. Entire schema was applied out-of-band (no migration history in remote).

## Edge functions
`functions list` → **[]** (none deployed). `notify-technician` and `upload_url` are not deployed.

## Security advisors (highlights)
- **ERROR**: `v_latest_diagnosis_per_plot` is a SECURITY DEFINER view.
- WARN: 4 functions with mutable search_path (`is_admin`, `is_technician`, `nearest_soil_reading`, `block_role_change_by_non_admin`).
- WARN: SECURITY DEFINER funcs executable by anon/authenticated (`delete_current_user`, `handle_new_user`, `rls_auto_enable`, `block_role_change_by_non_admin`).
- WARN: leaked-password protection disabled.
