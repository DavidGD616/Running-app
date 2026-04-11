create table if not exists public.activity_records (
  id text primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  recorded_at timestamptz not null,
  linked_session_id text,
  activity_type text,
  data jsonb not null
);

create index if not exists activity_records_user_recorded
  on public.activity_records (user_id, recorded_at desc);

create index if not exists activity_records_user_linked_session
  on public.activity_records (user_id, linked_session_id);

alter table public.activity_records enable row level security;

drop policy if exists "Users manage own activities" on public.activity_records;

create policy "Users manage own activities"
  on public.activity_records
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
