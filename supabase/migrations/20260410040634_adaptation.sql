create table if not exists public.session_feedback (
  id                text primary key,
  user_id           uuid references auth.users(id) on delete cascade not null,
  linked_session_id text,
  recorded_at       timestamptz not null,
  data              jsonb not null
);

create index if not exists session_feedback_user_recorded
  on public.session_feedback (user_id, recorded_at desc);

create index if not exists session_feedback_user_linked_session
  on public.session_feedback (user_id, linked_session_id);

alter table public.session_feedback enable row level security;

drop policy if exists "Users manage own feedback"
  on public.session_feedback;

create policy "Users manage own feedback"
  on public.session_feedback for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.plan_adjustments (
  id                text primary key,
  user_id           uuid references auth.users(id) on delete cascade not null,
  linked_session_id text,
  status            text,
  created_at        timestamptz not null,
  data              jsonb not null
);

create index if not exists plan_adjustments_user
  on public.plan_adjustments (user_id);

create index if not exists plan_adjustments_user_status
  on public.plan_adjustments (user_id, status);

alter table public.plan_adjustments enable row level security;

drop policy if exists "Users manage own adjustments"
  on public.plan_adjustments;

create policy "Users manage own adjustments"
  on public.plan_adjustments for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.plan_revisions (
  id         text primary key,
  user_id    uuid references auth.users(id) on delete cascade not null,
  status     text,
  created_at timestamptz not null,
  data       jsonb not null
);

create index if not exists plan_revisions_user
  on public.plan_revisions (user_id);

alter table public.plan_revisions enable row level security;

drop policy if exists "Users manage own revisions"
  on public.plan_revisions;

create policy "Users manage own revisions"
  on public.plan_revisions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
