create table if not exists public.plan_versions (
  id            text primary key,
  user_id       uuid references auth.users(id) on delete cascade not null,
  generated_at  timestamptz not null default now(),
  requested_by  text not null,       -- 'onboarding' | 'settings_update' | 'retry'
  is_active     boolean not null default false,
  schema_version int not null default 1,
  data          jsonb not null       -- full TrainingPlan JSON
);

create index if not exists plan_versions_user_active
  on public.plan_versions (user_id, is_active);

create index if not exists plan_versions_user_generated
  on public.plan_versions (user_id, generated_at desc);

alter table public.plan_versions enable row level security;

create policy "Users manage own plan versions"
  on public.plan_versions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
