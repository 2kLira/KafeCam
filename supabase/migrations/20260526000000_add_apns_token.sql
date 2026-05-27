-- Add APNs device token to profiles so we can send push notifications
alter table profiles
  add column if not exists apns_token text;

-- Index para lookups rápidos por token (usado por la Edge Function)
create index if not exists profiles_apns_token_idx on profiles (apns_token)
  where apns_token is not null;
