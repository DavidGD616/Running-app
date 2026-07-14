create table if not exists public.goal_edit_proposals (
  id                       text primary key,
  user_id                  uuid references auth.users(id) on delete cascade not null,
  source_plan_version_id   text references public.plan_versions(id) on delete cascade not null,
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
  constraint goal_edit_proposals_status_check
    check (status in ('pending', 'accepted', 'superseded', 'expired')),
  constraint goal_edit_proposals_suggested_target_check
    check (suggested_target_seconds is null or suggested_target_seconds > 0),
  constraint goal_edit_proposals_expiry_check
    check (expires_at > created_at),
  constraint goal_edit_proposals_warnings_array_check
    check (jsonb_typeof(warnings) = 'array'),
  constraint goal_edit_proposals_goal_object_check
    check (jsonb_typeof(proposed_goal) = 'object'),
  constraint goal_edit_proposals_profile_fragment_object_check
    check (jsonb_typeof(proposed_profile_fragment) = 'object'),
  constraint goal_edit_proposals_summary_object_check
    check (jsonb_typeof(change_summary) = 'object'),
  constraint goal_edit_proposals_candidate_object_check
    check (jsonb_typeof(candidate_plan) = 'object'),
  constraint goal_edit_proposals_acceptance_check
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

create index if not exists goal_edit_proposals_user_created
  on public.goal_edit_proposals (user_id, created_at desc);

create index if not exists goal_edit_proposals_user_status
  on public.goal_edit_proposals (user_id, status);

create unique index if not exists goal_edit_proposals_one_pending_per_user
  on public.goal_edit_proposals (user_id)
  where status = 'pending';

create unique index if not exists goal_edit_proposals_one_acceptance_per_plan
  on public.goal_edit_proposals (accepted_plan_version_id)
  where accepted_plan_version_id is not null;

comment on column public.goal_edit_proposals.accepted_plan_version_id is
  'Immutable link to the plan version created by the first successful acceptance; used for idempotent retries.';

alter table public.goal_edit_proposals enable row level security;

drop policy if exists "Users view own goal edit proposals"
  on public.goal_edit_proposals;

create policy "Users view own goal edit proposals"
  on public.goal_edit_proposals for select
  using ((select auth.uid()) = user_id);

revoke all on table public.goal_edit_proposals from public, anon, authenticated;
grant select on table public.goal_edit_proposals to authenticated;
grant all on table public.goal_edit_proposals to service_role;

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

create or replace function public.store_goal_edit_proposal(
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
  p_expires_at timestamptz default null
) returns public.goal_edit_proposals
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source_plan_id text;
  v_expires_at timestamptz;
  v_proposal public.goal_edit_proposals%rowtype;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  select plan.id
    into v_source_plan_id
    from public.plan_versions as plan
   where plan.user_id = p_user_id
     and plan.id = p_source_plan_version_id
     and plan.is_active = true
   for update;

  if v_source_plan_id is null then
    raise exception using
      message = 'goal_edit_source_plan_not_active',
      errcode = 'P0001';
  end if;

  v_expires_at := coalesce(
    p_expires_at,
    p_created_at + interval '30 minutes'
  );
  if v_expires_at <= p_created_at then
    raise exception using
      message = 'goal_edit_invalid_expiry',
      errcode = 'P0001';
  end if;

  update public.goal_edit_proposals
     set status = 'expired'
   where user_id = p_user_id
     and status = 'pending'
     and expires_at <= p_created_at;

  update public.goal_edit_proposals
     set status = 'superseded',
         superseded_at = p_created_at
   where user_id = p_user_id
     and status = 'pending';

  insert into public.goal_edit_proposals (
    id,
    user_id,
    source_plan_version_id,
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

revoke all on function public.store_goal_edit_proposal(
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
  timestamptz
) from public, anon, authenticated;

grant execute on function public.store_goal_edit_proposal(
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
  timestamptz
) to service_role;

create or replace function public.accept_goal_edit_proposal(
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
  v_proposal public.goal_edit_proposals%rowtype;
  v_profile_data jsonb;
  v_source_plan_id text;
  v_plan_data jsonb;
  v_accepted_at timestamptz;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  select proposal.*
    into v_proposal
    from public.goal_edit_proposals as proposal
   where proposal.user_id = p_user_id
     and proposal.id = p_proposal_id
   for update;

  if not found then
    raise exception using
      message = 'goal_edit_proposal_not_found',
      errcode = 'P0001';
  end if;

  -- A committed acceptance is idempotent. The proposal row is locked and its
  -- immutable version link is unique, so a concurrent caller waits and then
  -- returns the exact plan produced by the first transaction.
  if v_proposal.status = 'accepted' then
    if v_proposal.accepted_plan_version_id is null
       or v_proposal.accepted_at is null then
      raise exception using
        message = 'goal_edit_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    select plan.data
      into v_plan_data
      from public.plan_versions as plan
     where plan.id = v_proposal.accepted_plan_version_id
       and plan.user_id = p_user_id
       and plan.requested_by = 'edit_goal'
       and plan.data ->> 'id' = v_proposal.accepted_plan_version_id
     for share;

    if not found then
      raise exception using
        message = 'goal_edit_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    select profile.data
      into v_profile_data
      from public.runner_profiles as profile
     where profile.user_id = p_user_id
     for update;

    if not found then
      raise exception using
        message = 'goal_edit_proposal_inconsistent',
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
      message = 'goal_edit_proposal_expired',
      errcode = 'P0001';
  end if;

  if v_proposal.status <> 'pending' then
    raise exception using
      message = 'goal_edit_proposal_not_pending',
      errcode = 'P0001';
  end if;

  v_accepted_at := pg_catalog.transaction_timestamp();

  select profile.data
    into v_profile_data
    from public.runner_profiles as profile
   where profile.user_id = p_user_id
   for update;

  if not found then
    raise exception using
      message = 'goal_edit_runner_profile_not_found',
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
      message = 'goal_edit_source_plan_stale',
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
    'edit_goal',
    true,
    1,
    v_plan_data
  );

  update public.goal_edit_proposals
     set status = 'accepted',
         accepted_at = v_accepted_at,
         accepted_plan_version_id = p_new_plan_version_id
   where user_id = p_user_id
     and id = p_proposal_id;

  return query
  select p_new_plan_version_id, v_plan_data, v_profile_data;
end;
$$;

revoke all on function public.accept_goal_edit_proposal(
  uuid,
  text,
  text,
  timestamptz
) from public, anon, authenticated;

grant execute on function public.accept_goal_edit_proposal(
  uuid,
  text,
  text,
  timestamptz
) to service_role;
