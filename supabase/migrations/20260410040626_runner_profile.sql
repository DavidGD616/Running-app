create table if not exists public.runner_profiles (
  user_id uuid references auth.users(id) on delete cascade primary key,
  schema_version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_onboarding_at timestamptz,
  data jsonb not null default '{}'::jsonb
);

alter table public.runner_profiles enable row level security;

drop policy if exists "Users manage own profile" on public.runner_profiles;

create policy "Users manage own profile"
  on public.runner_profiles
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.runner_profile_drafts (
  user_id uuid references auth.users(id) on delete cascade primary key,
  updated_at timestamptz not null default now(),
  data jsonb not null default '{}'::jsonb
);

alter table public.runner_profile_drafts enable row level security;

drop policy if exists "Users manage own draft" on public.runner_profile_drafts;

create policy "Users manage own draft"
  on public.runner_profile_drafts
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
