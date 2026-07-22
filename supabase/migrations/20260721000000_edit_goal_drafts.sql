-- Edit Goal is deliberately a resumable, review-first flow.  The active plan
-- is never changed by these tables; activation remains the responsibility of
-- accept_goal_edit_proposal.

create table if not exists public.goal_edit_drafts (
  user_id                uuid references auth.users(id) on delete cascade primary key,
  source_plan_version_id text references public.plan_versions(id) on delete cascade not null,
  data                   jsonb not null default '{}'::jsonb,
  status                 text not null default 'editing',
  revision               integer not null default 1,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint goal_edit_drafts_status_check
    check (status in ('editing', 'assessment_pending', 'proposal_ready')),
  constraint goal_edit_drafts_revision_check
    check (revision > 0),
  constraint goal_edit_drafts_data_object_check
    check (jsonb_typeof(data) = 'object')
);

create index if not exists goal_edit_drafts_updated
  on public.goal_edit_drafts (updated_at desc);

alter table public.goal_edit_drafts enable row level security;

drop policy if exists "Users manage own goal edit draft"
  on public.goal_edit_drafts;

create policy "Users manage own goal edit draft"
  on public.goal_edit_drafts
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on table public.goal_edit_drafts from public, anon;
grant select, insert, update, delete on table public.goal_edit_drafts to authenticated;
grant all on table public.goal_edit_drafts to service_role;

create table if not exists public.goal_edit_assessments (
  id              text primary key,
  user_id         uuid references auth.users(id) on delete cascade not null,
  draft_user_id   uuid references public.goal_edit_drafts(user_id) on delete cascade not null,
  kind            text not null,
  scheduled_for   date not null,
  safe_dates      jsonb not null default '[]'::jsonb,
  result          jsonb,
  status          text not null default 'scheduled',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  completed_at    timestamptz,
  constraint goal_edit_assessments_kind_check
    check (kind in ('one_km_run', 'five_k_run')),
  constraint goal_edit_assessments_status_check
    check (status in ('scheduled', 'completed', 'cancelled')),
  constraint goal_edit_assessments_safe_dates_array_check
    check (jsonb_typeof(safe_dates) = 'array'),
  constraint goal_edit_assessments_result_object_check
    check (result is null or jsonb_typeof(result) = 'object'),
  constraint goal_edit_assessments_completion_check
    check (
      (status = 'completed' and completed_at is not null and result is not null)
      or status <> 'completed'
    )
);

create index if not exists goal_edit_assessments_user_status
  on public.goal_edit_assessments (user_id, status, scheduled_for);

alter table public.goal_edit_assessments enable row level security;

drop policy if exists "Users manage own goal edit assessments"
  on public.goal_edit_assessments;

create policy "Users manage own goal edit assessments"
  on public.goal_edit_assessments
  for all
  to authenticated
  using (
    (select auth.uid()) = user_id
    and draft_user_id = user_id
  )
  with check (
    (select auth.uid()) = user_id
    and draft_user_id = user_id
  );

revoke all on table public.goal_edit_assessments from public, anon;
grant select, insert, update, delete on table public.goal_edit_assessments to authenticated;
grant all on table public.goal_edit_assessments to service_role;

comment on table public.goal_edit_drafts is
  'One resumable, cross-device Edit Goal draft per runner. Saving a draft never changes an active plan.';

comment on table public.goal_edit_assessments is
  'Standalone fitness checks for an Edit Goal. They are intentionally not plan sessions and do not replace scheduled training.';
