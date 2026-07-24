create table if not exists public.new_goal_drafts (
  user_id                uuid references auth.users(id) on delete cascade primary key,
  source_plan_version_id text references public.plan_versions(id) on delete cascade not null,
  data                   jsonb not null default '{}'::jsonb,
  status                 text not null default 'editing',
  revision               integer not null default 1,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint new_goal_drafts_status_check
    check (status in ('editing', 'assessment_pending', 'proposal_ready')),
  constraint new_goal_drafts_revision_check
    check (revision > 0),
  constraint new_goal_drafts_data_object_check
    check (jsonb_typeof(data) = 'object')
);

create index if not exists new_goal_drafts_updated
  on public.new_goal_drafts (updated_at desc);

alter table public.new_goal_drafts enable row level security;

drop policy if exists "Users manage own new goal draft"
  on public.new_goal_drafts;

create policy "Users manage own new goal draft"
  on public.new_goal_drafts
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on table public.new_goal_drafts from public, anon;
grant select, insert, update, delete on table public.new_goal_drafts to authenticated;
grant all on table public.new_goal_drafts to service_role;

create or replace function public.enforce_new_goal_draft_source_plan_ownership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Service-role callers are trusted and may write any draft row for backend tasks.
  if coalesce(auth.role(), '') <> 'service_role'
     and auth.uid() is distinct from NEW.user_id then
    raise exception using
      message = 'insufficient_privilege',
      errcode = '42501';
  end if;

  if not exists (
    select 1
      from public.plan_versions as plan
     where plan.id = NEW.source_plan_version_id
       and plan.user_id = NEW.user_id
  ) then
    raise exception using
      message = 'new_goal_draft_source_plan_not_owned',
      errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists new_goal_drafts_source_plan_ownership_guard on public.new_goal_drafts;
create trigger new_goal_drafts_source_plan_ownership_guard
  before insert or update on public.new_goal_drafts
  for each row execute function public.enforce_new_goal_draft_source_plan_ownership();

create table if not exists public.new_goal_assessments (
  id              text primary key,
  user_id         uuid references auth.users(id) on delete cascade not null,
  draft_user_id   uuid references public.new_goal_drafts(user_id) on delete cascade not null,
  kind            text not null,
  scheduled_for   date not null,
  safe_dates      jsonb not null default '[]'::jsonb,
  result          jsonb,
  status          text not null default 'scheduled',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  completed_at    timestamptz,
  constraint new_goal_assessments_kind_check
    check (kind in ('one_km_run', 'five_k_run')),
  constraint new_goal_assessments_status_check
    check (status in ('scheduled', 'completed', 'cancelled')),
  constraint new_goal_assessments_safe_dates_array_check
    check (jsonb_typeof(safe_dates) = 'array'),
  constraint new_goal_assessments_result_object_check
    check (result is null or jsonb_typeof(result) = 'object'),
  constraint new_goal_assessments_completion_check
    check (
      (status = 'completed' and completed_at is not null and result is not null)
      or status <> 'completed'
    )
);

create index if not exists new_goal_assessments_user_status
  on public.new_goal_assessments (user_id, status, scheduled_for);

alter table public.new_goal_assessments enable row level security;

drop policy if exists "Users manage own new goal assessments"
  on public.new_goal_assessments;

create policy "Users manage own new goal assessments"
  on public.new_goal_assessments
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

revoke all on table public.new_goal_assessments from public, anon;
grant select, insert, update, delete on table public.new_goal_assessments to authenticated;
grant all on table public.new_goal_assessments to service_role;

create table if not exists public.new_goal_proposals (
  id                       text primary key,
  user_id                  uuid references auth.users(id) on delete cascade not null,
  source_plan_version_id   text references public.plan_versions(id) on delete cascade not null,
  source_profile_schema_version integer not null,
  source_profile_updated_at timestamptz not null,
  candidate_plan           jsonb not null,
  proposed_goal            jsonb not null,
  proposed_profile_fragment jsonb not null default '{}'::jsonb,
  change_summary           jsonb not null default '{}'::jsonb,
  warnings                 jsonb not null default '[]'::jsonb,
  suggested_target_seconds integer,
  status                   text not null default 'pending',
  created_at               timestamptz not null default now(),
  expires_at               timestamptz not null default (now() + interval '30 minutes'),
  accepted_at              timestamptz,
  accepted_plan_version_id text references public.plan_versions(id) on delete restrict,
  superseded_at            timestamptz,
  constraint new_goal_proposals_status_check
    check (status in ('pending', 'accepted', 'superseded', 'expired')),
  constraint new_goal_proposals_suggested_target_check
    check (suggested_target_seconds is null or suggested_target_seconds > 0),
  constraint new_goal_proposals_expiry_check
    check (expires_at > created_at),
  constraint new_goal_proposals_warnings_array_check
    check (jsonb_typeof(warnings) = 'array'),
  constraint new_goal_proposals_goal_object_check
    check (jsonb_typeof(proposed_goal) = 'object'),
  constraint new_goal_proposals_profile_fragment_object_check
    check (jsonb_typeof(proposed_profile_fragment) = 'object'),
  constraint new_goal_proposals_summary_object_check
    check (jsonb_typeof(change_summary) = 'object'),
  constraint new_goal_proposals_candidate_object_check
    check (jsonb_typeof(candidate_plan) = 'object'),
  constraint new_goal_proposals_acceptance_check
    check (
      (
        status = 'accepted'
        and accepted_at is not null
        and accepted_plan_version_id is not null
      )
      or (
        status <> 'accepted'
        and accepted_at is null
        and accepted_plan_version_id is null
      )
    )
);

create index if not exists new_goal_proposals_user_created
  on public.new_goal_proposals (user_id, created_at desc);

create index if not exists new_goal_proposals_user_status
  on public.new_goal_proposals (user_id, status);

create unique index if not exists new_goal_proposals_one_pending_per_user
  on public.new_goal_proposals (user_id)
  where status = 'pending';

create unique index if not exists new_goal_proposals_one_acceptance_per_plan
  on public.new_goal_proposals (accepted_plan_version_id)
  where accepted_plan_version_id is not null;

comment on column public.new_goal_proposals.accepted_plan_version_id is
  'Immutable link to the plan version created by the first successful acceptance; used for idempotent retries.';

alter table public.new_goal_proposals enable row level security;

drop policy if exists "Users view own new goal proposals"
  on public.new_goal_proposals;

create policy "Users view own new goal proposals"
  on public.new_goal_proposals
  for select
  using ((select auth.uid()) = user_id);

revoke all on table public.new_goal_proposals from public, anon, authenticated;
grant select on table public.new_goal_proposals to authenticated;
grant all on table public.new_goal_proposals to service_role;

-- Older writers did not serialize plan activation. Repair any duplicate active
-- rows deterministically before enforcing the invariant for every future writer.
with ranked_active_plans as (
  select
    id,
    row_number() over (
      partition by user_id
      order by generated_at desc, id desc
    ) as active_rank
  from public.plan_versions
  where is_active = true
)
update public.plan_versions as plan
   set is_active = false
  from ranked_active_plans as ranked
 where plan.id = ranked.id
   and ranked.active_rank > 1;

create unique index if not exists plan_versions_one_active_per_user
  on public.plan_versions (user_id)
  where is_active = true;

create or replace function public.store_new_goal_proposal(
  p_user_id uuid,
  p_proposal_id text,
  p_source_plan_version_id text,
  p_candidate_plan jsonb,
  p_proposed_goal jsonb,
  p_proposed_profile_fragment jsonb,
  p_change_summary jsonb,
  p_warnings jsonb,
  p_suggested_target_seconds integer default null,
  p_created_at timestamptz default now(),
  p_expires_at timestamptz default null,
  p_source_profile_schema_version integer default null,
  p_source_profile_updated_at timestamptz default null
) returns public.new_goal_proposals
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source_plan_id text;
  v_expires_at timestamptz;
  v_profile_schema_version integer;
  v_profile_updated_at timestamptz;
  v_proposal public.new_goal_proposals%rowtype;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  if exists (
    select 1
      from pg_catalog.jsonb_object_keys(
        coalesce(p_proposed_profile_fragment, '{}'::jsonb)
      ) as key_name
     where key_name not in (
       'acceptedRaceTarget',
       'schedule',
       'trainingPreferences',
       'health'
     )
  ) then
    raise exception using
      message = 'new_goal_profile_fragment_restricted',
      errcode = 'P0001';
  end if;

  select plan.id
    into v_source_plan_id
    from public.plan_versions as plan
   where plan.user_id = p_user_id
     and plan.id = p_source_plan_version_id
     and plan.is_active = true
   for update;

  if v_source_plan_id is null then
    raise exception using
      message = 'new_goal_source_plan_not_active',
      errcode = 'P0001';
  end if;

  v_expires_at := coalesce(
    p_expires_at,
    p_created_at + interval '30 minutes'
  );
  if v_expires_at <= p_created_at then
    raise exception using
      message = 'new_goal_invalid_expiry',
      errcode = 'P0001';
  end if;

  select
    profile.schema_version,
    profile.updated_at
    into v_profile_schema_version, v_profile_updated_at
    from public.runner_profiles as profile
   where profile.user_id = p_user_id
   for update;

  if not found then
    raise exception using
      message = 'new_goal_runner_profile_not_found',
      errcode = 'P0001';
  end if;

  if p_source_profile_schema_version is not null
     and p_source_profile_schema_version is distinct from v_profile_schema_version then
    raise exception using
      message = 'new_goal_source_profile_stale',
      errcode = 'P0001';
  end if;

  if p_source_profile_updated_at is not null
     and p_source_profile_updated_at is distinct from v_profile_updated_at then
    raise exception using
      message = 'new_goal_source_profile_stale',
      errcode = 'P0001';
  end if;

  update public.new_goal_proposals
     set status = 'expired'
   where user_id = p_user_id
     and status = 'pending'
     and expires_at <= p_created_at;

  update public.new_goal_proposals
     set status = 'superseded',
         superseded_at = p_created_at
   where user_id = p_user_id
     and status = 'pending';

  insert into public.new_goal_proposals (
    id,
    user_id,
    source_plan_version_id,
    source_profile_schema_version,
    source_profile_updated_at,
    candidate_plan,
    proposed_goal,
    proposed_profile_fragment,
    change_summary,
    warnings,
    suggested_target_seconds,
    status,
    created_at,
    expires_at
  ) values (
    p_proposal_id,
    p_user_id,
    p_source_plan_version_id,
    v_profile_schema_version,
    v_profile_updated_at,
    p_candidate_plan,
    p_proposed_goal,
    coalesce(p_proposed_profile_fragment, '{}'::jsonb),
    coalesce(p_change_summary, '{}'::jsonb),
    coalesce(p_warnings, '[]'::jsonb),
    p_suggested_target_seconds,
    'pending',
    p_created_at,
    v_expires_at
  )
  returning * into v_proposal;

  return v_proposal;
end;
$$;

revoke all on function public.store_new_goal_proposal(
  uuid,
  text,
  text,
  jsonb,
  jsonb,
  jsonb,
  jsonb,
  jsonb,
  integer,
  timestamptz,
  timestamptz,
  integer,
  timestamptz
) from public, anon, authenticated;

grant execute on function public.store_new_goal_proposal(
  uuid,
  text,
  text,
  jsonb,
  jsonb,
  jsonb,
  jsonb,
  jsonb,
  integer,
  timestamptz,
  timestamptz,
  integer,
  timestamptz
) to service_role;

create or replace function public.accept_new_goal_proposal(
  p_user_id uuid,
  p_proposal_id text,
  p_new_plan_version_id text,
  p_generated_at timestamptz default now()
) returns table (
  new_plan_version_id text,
  plan_data jsonb,
  profile_data jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_proposal public.new_goal_proposals%rowtype;
  v_profile_data jsonb;
  v_profile_schema_version integer;
  v_profile_updated_at timestamptz;
  v_source_plan_id text;
  v_plan_data jsonb;
  v_accepted_at timestamptz;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  select proposal.*
    into v_proposal
    from public.new_goal_proposals as proposal
   where proposal.user_id = p_user_id
     and proposal.id = p_proposal_id
   for update;

  if not found then
    raise exception using
      message = 'new_goal_proposal_not_found',
      errcode = 'P0001';
  end if;

  -- A committed acceptance is idempotent. The proposal row is locked and its
  -- immutable version link is unique, so a concurrent caller waits and then
  -- returns the exact plan produced by the first transaction.
  if v_proposal.status = 'accepted' then
    if v_proposal.accepted_plan_version_id is null
       or v_proposal.accepted_at is null then
      raise exception using
        message = 'new_goal_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    select plan.data
      into v_plan_data
      from public.plan_versions as plan
     where plan.id = v_proposal.accepted_plan_version_id
       and plan.user_id = p_user_id
       and plan.requested_by = 'new_goal'
       and plan.data ->> 'id' = v_proposal.accepted_plan_version_id
     for share;

    if not found then
      raise exception using
        message = 'new_goal_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    select profile.data
      into v_profile_data
      from public.runner_profiles as profile
     where profile.user_id = p_user_id
     for update;

    if not found then
      raise exception using
        message = 'new_goal_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    return query
    select
      v_proposal.accepted_plan_version_id,
      v_plan_data,
      v_profile_data;
    return;
  end if;

  if v_proposal.status = 'expired'
     or (
       v_proposal.status = 'pending'
       and v_proposal.expires_at <= pg_catalog.now()
     ) then
    raise exception using
      message = 'new_goal_proposal_expired',
      errcode = 'P0001';
  end if;

  if v_proposal.status <> 'pending' then
    raise exception using
      message = 'new_goal_proposal_not_pending',
      errcode = 'P0001';
  end if;

  v_accepted_at := pg_catalog.transaction_timestamp();

  select
    profile.schema_version,
    profile.updated_at,
    profile.data
    into v_profile_schema_version, v_profile_updated_at, v_profile_data
    from public.runner_profiles as profile
   where profile.user_id = p_user_id
   for update;

  if not found then
    raise exception using
      message = 'new_goal_runner_profile_not_found',
      errcode = 'P0001';
  end if;

  if v_profile_schema_version is distinct from v_proposal.source_profile_schema_version then
    raise exception using
      message = 'new_goal_source_profile_stale',
      errcode = 'P0001';
  end if;

  if v_profile_updated_at is distinct from v_proposal.source_profile_updated_at then
    raise exception using
      message = 'new_goal_source_profile_stale',
      errcode = 'P0001';
  end if;

  select plan.id
    into v_source_plan_id
    from public.plan_versions as plan
   where plan.user_id = p_user_id
     and plan.id = v_proposal.source_plan_version_id
     and plan.is_active = true
   for update;

  if v_source_plan_id is null then
    raise exception using
      message = 'new_goal_source_plan_stale',
      errcode = 'P0001';
  end if;

  v_profile_data := jsonb_set(
    coalesce(v_profile_data, '{}'::jsonb),
    '{goal}',
    v_proposal.proposed_goal,
    true
  );
  v_profile_data := jsonb_set(
    v_profile_data,
    '{acceptedRaceTarget}',
    coalesce(
      v_proposal.proposed_profile_fragment -> 'acceptedRaceTarget',
      'null'::jsonb
    ),
    true
  );
  if v_proposal.proposed_profile_fragment ? 'schedule' then
    v_profile_data := jsonb_set(
      v_profile_data,
      '{schedule}',
      v_proposal.proposed_profile_fragment -> 'schedule',
      true
    );
  end if;
  if v_proposal.proposed_profile_fragment ? 'trainingPreferences' then
    v_profile_data := jsonb_set(
      v_profile_data,
      '{trainingPreferences}',
      v_proposal.proposed_profile_fragment -> 'trainingPreferences',
      true
    );
  end if;
  if v_proposal.proposed_profile_fragment ? 'health' then
    v_profile_data := jsonb_set(
      v_profile_data,
      '{health}',
      v_proposal.proposed_profile_fragment -> 'health',
      true
    );
  end if;
  v_profile_data := jsonb_set(
    v_profile_data,
    '{updatedAt}',
    pg_catalog.to_jsonb(v_accepted_at),
    true
  );

  update public.runner_profiles
     set data = v_profile_data,
         updated_at = v_accepted_at
   where user_id = p_user_id;

  update public.plan_versions
     set is_active = false
   where user_id = p_user_id
     and is_active = true;

  v_plan_data := jsonb_set(
    v_proposal.candidate_plan,
    '{id}',
    pg_catalog.to_jsonb(p_new_plan_version_id),
    true
  );

  insert into public.plan_versions (
    id,
    user_id,
    generated_at,
    requested_by,
    is_active,
    schema_version,
    data
  ) values (
    p_new_plan_version_id,
    p_user_id,
    p_generated_at,
    'new_goal',
    true,
    1,
    v_plan_data
  );

  update public.new_goal_proposals
     set status = 'accepted',
         accepted_at = v_accepted_at,
         accepted_plan_version_id = p_new_plan_version_id
   where user_id = p_user_id
     and id = p_proposal_id;

  return query
  select p_new_plan_version_id, v_plan_data, v_profile_data;
end;
$$;

revoke all on function public.accept_new_goal_proposal(
  uuid,
  text,
  text,
  timestamptz
) from public, anon, authenticated;

grant execute on function public.accept_new_goal_proposal(
  uuid,
  text,
  text,
  timestamptz
) to service_role;
