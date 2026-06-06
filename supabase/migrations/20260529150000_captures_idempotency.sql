-- =============================================================================
-- KafeCam — capture idempotency (P0-6)
-- Target: prod uzdvklhsxsujuwjfncdw. Idempotent.
--
-- Adds the unique index that makes capture inserts idempotent. The client now
-- upserts on (uploaded_by_user_id, client_uuid) and uses a deterministic storage
-- key derived from client_uuid, so an offline retry overwrites the same row +
-- object instead of creating duplicates.
--
-- Safe: existing rows each have a distinct random client_uuid (the old code
-- minted a fresh UUID per insert), so no duplicate pairs block the index.
-- =============================================================================

create unique index if not exists captures_uploader_client_uuid_key
  on public.captures (uploaded_by_user_id, client_uuid);
