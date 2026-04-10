create table if not exists public.user_preferences (
  user_id uuid references auth.users(id) on delete cascade primary key,
  unit_system text not null default 'km',
  short_distance_unit text,
  display_name text,
  gender text,
  date_of_birth_ms bigint,
  updated_at timestamptz not null default now()
);

alter table public.user_preferences enable row level security;

drop policy if exists "Users manage own preferences" on public.user_preferences;

create policy "Users manage own preferences"
  on public.user_preferences
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
