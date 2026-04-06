# KafeCam

## Supabase Integration (Development)

- Add package: `https://github.com/supabase-community/supabase-swift` (Xcode > Add Packages)
- Create `KafeCam/Configuration/SupabaseConfig.swift` and set:
  - `url`: https://dmctlhsjdwykywrjmpax.supabase.co
  - `anonKey`: <anon key>
- Build and run.

### Endpoints used
- PostgREST
  - `plots`: select with `.eq("owner_user_id", userId)` and insert with `owner_user_id` set
  - `captures`: insert only (after upload)
- Storage
  - Private bucket `captures`. Signed upload URL is obtained via Edge Function `upload_url` (client uploads via signed URL). `get_url` is used to read.

### Security
- No secrets are committed.
- Only anon key used in-app. Service role is never used on-device.

## Technician / Farmer roles

### Promote a user to technician or admin (SQL)
Run in Supabase SQL editor:
```sql
-- Make user technician
update public.profiles set role = 'technician' where phone = '9511407969';

-- Make user admin
update public.profiles set role = 'admin' where phone = '9511407969';
```
- You can also match by email:
```sql
update public.profiles set role = 'technician' where email = '1234567890@kafe.local';
```

### Assign farmers to a technician
```sql
insert into public.technician_farmers (technician_id, farmer_id)
values ('<TECH_UUID>', '<FARMER_UUID>');
```
- In-app, technicians can assign by phone and unassign from `Profile > Farmers`.

## Edge Functions (Storage)

- `upload_url` (POST): returns `{ signedUrl, token }` for `captures/<user-id>/<uuid>.jpg`
- `get_url` (GET): returns `{ signedUrl }` to read images
- Both run with service role and respect Storage RLS (object keys are prefixed with user id).

## What’s implemented
- Profiles: fetch and display name/email/phone/organization/role. Change password. Logout.
- Home: greets with first name (from `profiles.name`).
- Detecta: camera capture; on “Aceptar”, inserts `captures` row and ensures default plot. Storage upload wiring via edge functions is pending.
- Consulta: lists current user’s captures. Images switch to signed URLs once wired.
- Roles: technicians see a `Farmers` entry and can assign/unassign farmers by phone; list is filterable.

## What’s pending
- Wire `upload_url` and multipart upload in-app, then use `get_url` for thumbnails.
- Optional: richer farmer picker (search across profiles with paging).
