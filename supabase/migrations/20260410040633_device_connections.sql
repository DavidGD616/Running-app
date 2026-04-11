create table if not exists public.device_connections (
  id             text primary key,
  user_id        uuid references auth.users(id) on delete cascade not null,
  vendor         text not null,
  kind           text,
  state          text,
  connected_at   timestamptz,
  last_synced_at timestamptz,
  data           jsonb not null
);

create index if not exists device_connections_user
  on public.device_connections (user_id);

alter table public.device_connections enable row level security;

drop policy if exists "Users manage own device connections"
  on public.device_connections;

create policy "Users manage own device connections"
  on public.device_connections for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
