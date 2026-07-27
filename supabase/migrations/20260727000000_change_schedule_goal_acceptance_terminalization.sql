-- Replacing an active plan through a goal acceptance invalidates every
-- Change Schedule proposal based on that source. Keep the scheduled queue
-- auditable by following the same stale-source terminalization sequence used
-- by activate_due_change_schedule.
create or replace function public.terminalize_change_schedule_for_replaced_plan(
  p_user_id uuid,
  p_source_plan_version_id text,
  p_terminalized_at timestamptz default now()
) returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_now timestamptz;
  v_activation public.change_schedule_activations%rowtype;
  v_proposal public.change_schedule_proposals%rowtype;
  v_scheduled_proposal_count integer;
  v_remaining_scheduled_proposal_id text;
begin
  if p_user_id is null then
    raise exception using
      message = 'change_schedule_user_missing',
      errcode = 'P0001';
  end if;

  if p_source_plan_version_id is null then
    raise exception using
      message = 'change_schedule_plan_version_id_missing',
      errcode = 'P0001';
  end if;

  -- This is intentionally the same per-user transaction lock used by every
  -- Change Schedule lifecycle RPC. The goal acceptance already holds it, but
  -- retaining it here makes the helper safe if it is reused by another
  -- authoritative plan-replacement path.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  v_now := coalesce(p_terminalized_at, pg_catalog.transaction_timestamp());

  -- A scheduled activation has to be terminalized before its proposal: the
  -- proposal integrity trigger requires a matching terminal activation. For
  -- legacy NULL-linked activations, only adopt one exact scheduled proposal;
  -- do not guess when the source/queued-plan/effective-date tuple is absent or
  -- ambiguous.
  for v_activation in
    select activation.*
      from public.change_schedule_activations as activation
     where activation.user_id = p_user_id
       and activation.source_plan_version_id = p_source_plan_version_id
       and activation.status = 'scheduled'
     order by activation.created_at, activation.id
     for update
  loop
    if v_activation.proposal_id is not null then
      select proposal.*
        into v_proposal
        from public.change_schedule_proposals as proposal
       where proposal.id = v_activation.proposal_id
         and proposal.user_id = p_user_id
         and proposal.status = 'scheduled'
         and proposal.source_plan_version_id = p_source_plan_version_id
         and proposal.scheduled_plan_version_id = v_activation.queued_candidate_plan_version_id
         and proposal.effective_from = v_activation.effective_from
       for update;

      if not found then
        raise exception using
          message = 'change_schedule_proposal_inconsistent',
          errcode = 'P0001';
      end if;
    else
      select count(*)
        into v_scheduled_proposal_count
        from public.change_schedule_proposals as proposal
       where proposal.user_id = p_user_id
         and proposal.status = 'scheduled'
         and proposal.source_plan_version_id = p_source_plan_version_id
         and proposal.scheduled_plan_version_id = v_activation.queued_candidate_plan_version_id
         and proposal.effective_from = v_activation.effective_from;

      if v_scheduled_proposal_count = 0 then
        raise exception using
          message = 'change_schedule_activation_not_found',
          errcode = 'P0001';
      elsif v_scheduled_proposal_count > 1 then
        raise exception using
          message = 'change_schedule_activation_proposal_ambiguous',
          errcode = 'P0001';
      end if;

      select proposal.*
        into v_proposal
        from public.change_schedule_proposals as proposal
       where proposal.user_id = p_user_id
         and proposal.status = 'scheduled'
         and proposal.source_plan_version_id = p_source_plan_version_id
         and proposal.scheduled_plan_version_id = v_activation.queued_candidate_plan_version_id
         and proposal.effective_from = v_activation.effective_from
       order by proposal.created_at desc, proposal.id desc
       limit 1
       for update;

      if not found then
        raise exception using
          message = 'change_schedule_activation_not_found',
          errcode = 'P0001';
      end if;

      update public.change_schedule_activations as activation
         set proposal_id = v_proposal.id
       where activation.id = v_activation.id
         and activation.status = 'scheduled'
         and activation.proposal_id is null;

      if not found then
        raise exception using
          message = 'change_schedule_proposal_inconsistent',
          errcode = 'P0001';
      end if;
    end if;

    update public.change_schedule_activations as activation
       set status = 'stale',
           stale_at = v_now,
           updated_at = v_now
     where activation.id = v_activation.id
       and activation.status = 'scheduled'
       and activation.proposal_id = v_proposal.id;

    if not found then
      raise exception using
        message = 'change_schedule_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    update public.change_schedule_proposals as proposal
       set status = 'superseded',
           scheduled_plan_version_id = null,
           superseded_at = v_now,
           updated_at = v_now
     where proposal.id = v_proposal.id
       and proposal.user_id = p_user_id
       and proposal.status = 'scheduled'
       and proposal.source_plan_version_id = p_source_plan_version_id
       and proposal.scheduled_plan_version_id = v_activation.queued_candidate_plan_version_id
       and proposal.effective_from = v_activation.effective_from;

    if not found then
      raise exception using
        message = 'change_schedule_proposal_inconsistent',
        errcode = 'P0001';
    end if;
  end loop;

  -- Never deactivate the source plan while an orphaned scheduled proposal is
  -- still visible. It has no safe trigger-valid terminalization path, so fail
  -- the enclosing transaction instead of leaving hydration to drop it.
  select proposal.id
    into v_remaining_scheduled_proposal_id
    from public.change_schedule_proposals as proposal
   where proposal.user_id = p_user_id
     and proposal.source_plan_version_id = p_source_plan_version_id
     and proposal.status = 'scheduled'
   order by proposal.created_at, proposal.id
   limit 1
   for update;

  if v_remaining_scheduled_proposal_id is not null then
    raise exception using
      message = 'change_schedule_activation_not_found',
      errcode = 'P0001';
  end if;

  update public.change_schedule_proposals as proposal
     set status = 'superseded',
         superseded_at = v_now,
         updated_at = v_now
   where proposal.user_id = p_user_id
     and proposal.source_plan_version_id = p_source_plan_version_id
     and proposal.status = 'pending';
end;
$function$;

revoke all on function public.terminalize_change_schedule_for_replaced_plan(
  uuid,
  text,
  timestamptz
) from public, anon, authenticated;

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

  perform public.terminalize_change_schedule_for_replaced_plan(
    p_user_id,
    v_source_plan_id,
    v_accepted_at
  );

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

  perform public.terminalize_change_schedule_for_replaced_plan(
    p_user_id,
    v_source_plan_id,
    v_accepted_at
  );

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
