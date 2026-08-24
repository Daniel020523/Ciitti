-- ============================================================
-- Migration: remove conversation "name" field, add image support
-- Run in the Supabase SQL editor for this project.
-- ============================================================

-- 1) Remove the name field from conversations
alter table public.conversations
  drop column if exists name;

-- 2) Add an image_url column to chat_messages so a message can
--    carry an image instead of (or alongside) text.
alter table public.chat_messages
  add column if not exists image_url text;

-- Messages should have text, an image, or both — but not neither.
alter table public.chat_messages
  drop constraint if exists chat_messages_has_content;
alter table public.chat_messages
  add constraint chat_messages_has_content
  check (
    (message is not null and length(trim(message)) > 0)
    or image_url is not null
  );

-- Let "message" default to empty string so image-only sends don't need it.
alter table public.chat_messages
  alter column message set default '';

-- ============================================================
-- 3) Storage bucket for chat image attachments
-- ============================================================

insert into storage.buckets (id, name, public)
values ('chat-images', 'chat-images', true)
on conflict (id) do nothing;

-- Anyone can read images (bucket is public, links are shared in chat).
drop policy if exists "Public read chat images" on storage.objects;
create policy "Public read chat images"
  on storage.objects for select
  using ( bucket_id = 'chat-images' );

-- Anyone (anon widget visitors + logged-in admins) can upload images.
-- Tighten this later (e.g. restrict by file size/type at the app layer,
-- or require auth) if abuse becomes a concern.
drop policy if exists "Public upload chat images" on storage.objects;
create policy "Public upload chat images"
  on storage.objects for insert
  with check ( bucket_id = 'chat-images' );

-- ============================================================
-- Notes:
-- - This assumes RLS policies already exist on public.conversations
--   and public.chat_messages that allow anon insert/select (since the
--   widget was already inserting/reading without auth). If not, you'll
--   need equivalent policies for those tables too.
-- - image_url stores the public URL returned by
--   supabase.storage.from('chat-images').getPublicUrl(path).
-- ============================================================
