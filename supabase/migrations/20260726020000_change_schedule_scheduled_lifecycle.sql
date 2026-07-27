create or replace function public.schedule_change_schedule_proposal(
  p_user_id uuid,
  p_proposal_id text,
  p_plan_version_id text,
  p_availability_version_id text,
  p_scheduled_at timestamptz default now()
) returns table (
  proposal_id text,
  activation_id text,
  scheduled_plan_version_id text,
  scheduled_availability_version_id text,
  activation_status text
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_now timestamptz;
  v_current_week date;
  v_proposal public.change_schedule_proposals%rowtype;
  v_source_plan_id text;
  v_source_plan_schema_version integer;
  v_profile_schema_version integer;
  v_profile_updated_at timestamptz;
  v_payload jsonb;
  v_preferred text;
  v_target_running_days integer;
  v_primary_long_run_weekday integer;
  v_backup_long_run_weekday integer;
  v_plan_data jsonb;
  v_activation_id text;
  v_existing_activation public.change_schedule_activations%rowtype;
  v_existing_scheduled_match_count integer;
  v_existing_scheduled_proposal_id text;
begin
  if p_user_id is null then
    raise exception using
      message = 'change_schedule_user_missing',
      errcode = 'P0001';
  end if;

  if p_plan_version_id is null then
    raise exception using
      message = 'change_schedule_plan_version_id_missing',
      errcode = 'P0001';
  end if;

  if p_availability_version_id is null then
    raise exception using
      message = 'change_schedule_availability_id_missing',
      errcode = 'P0001';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  v_now := coalesce(p_scheduled_at, now());
  if v_now is null then
    raise exception using
      message = 'change_schedule_proposal_scheduled_timestamp_missing',
      errcode = 'P0001';
  end if;

  select proposal.*
    into v_proposal
    from public.change_schedule_proposals as proposal
   where proposal.user_id = p_user_id
     and proposal.id = p_proposal_id
   for update;

  if not found then
    raise exception using
      message = 'change_schedule_proposal_not_found',
      errcode = 'P0001';
  end if;

  if v_proposal.status = 'pending' then
    if v_proposal.expires_at <= v_now then
      raise exception using
        message = 'change_schedule_proposal_expired',
        errcode = 'P0001';
    end if;

    update public.change_schedule_proposals
       set status = 'expired'
     where user_id = p_user_id
       and status = 'pending'
       and id <> p_proposal_id
       and expires_at <= v_now;
  elsif v_proposal.status = 'expired' then
    raise exception using
      message = 'change_schedule_proposal_expired',
      errcode = 'P0001';
  end if;

  if v_proposal.status = 'scheduled' then
    if v_proposal.scheduled_plan_version_id is distinct from p_plan_version_id then
      raise exception using
        message = 'change_schedule_proposal_inconsistent',
        errcode = 'P0001';
    end if;

  select activation.*
      into v_existing_activation
      from public.change_schedule_activations as activation
     where activation.user_id = p_user_id
       and activation.status = 'scheduled'
       and activation.proposal_id = p_proposal_id
       and activation.queued_candidate_plan_version_id = v_proposal.scheduled_plan_version_id
       and activation.source_plan_version_id = v_proposal.source_plan_version_id
       and activation.effective_from = v_proposal.effective_from
     order by activation.created_at desc
     limit 1
     for share;

    if not found then
      select count(*)
        into v_existing_scheduled_match_count
        from public.change_schedule_activations as activation
       where activation.user_id = p_user_id
         and activation.status = 'scheduled'
         and activation.proposal_id is null
         and activation.queued_candidate_plan_version_id = v_proposal.scheduled_plan_version_id
         and activation.source_plan_version_id = v_proposal.source_plan_version_id
         and activation.effective_from = v_proposal.effective_from;

      if v_existing_scheduled_match_count = 0 then
        raise exception using
          message = 'change_schedule_proposal_inconsistent',
          errcode = 'P0001';
      elsif v_existing_scheduled_match_count > 1 then
        raise exception using
          message = 'change_schedule_activation_proposal_ambiguous',
          errcode = 'P0001';
      end if;

      select activation.*
        into v_existing_activation
        from public.change_schedule_activations as activation
       where activation.user_id = p_user_id
         and activation.status = 'scheduled'
         and activation.queued_candidate_plan_version_id = v_proposal.scheduled_plan_version_id
         and activation.source_plan_version_id = v_proposal.source_plan_version_id
         and activation.effective_from = v_proposal.effective_from
         and activation.proposal_id is null
       order by activation.created_at desc
       limit 1
       for share;
    end if;

    if not found then
      raise exception using
        message = 'change_schedule_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    if v_existing_activation.availability_version_id is distinct from p_availability_version_id then
      raise exception using
        message = 'change_schedule_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    return query
    select
      v_proposal.id,
      v_existing_activation.id,
      v_proposal.scheduled_plan_version_id,
      v_existing_activation.availability_version_id,
      v_existing_activation.status;
    return;
  end if;

  if v_proposal.status <> 'pending' then
    raise exception using
      message = 'change_schedule_proposal_not_pending',
      errcode = 'P0001';
  end if;

  if extract(isodow from v_proposal.effective_from) <> 1 then
    raise exception using
      message = 'change_schedule_proposal_effective_from_not_monday',
      errcode = 'P0001';
  end if;

  v_current_week := pg_catalog.date_trunc('week', v_now)::date;
  if v_proposal.effective_from <= v_current_week then
    raise exception using
      message = 'change_schedule_proposal_effective_from_not_future',
      errcode = 'P0001';
  end if;

  select plan.id,
         plan.schema_version
    into v_source_plan_id,
         v_source_plan_schema_version
    from public.plan_versions as plan
   where plan.user_id = p_user_id
     and plan.id = v_proposal.source_plan_version_id
     and plan.is_active = true
   for update;

  if v_source_plan_id is null then
    raise exception using
      message = 'change_schedule_source_plan_stale',
      errcode = 'P0001';
  end if;

  select profile.schema_version,
         profile.updated_at
    into v_profile_schema_version,
         v_profile_updated_at
    from public.runner_profiles as profile
   where profile.user_id = p_user_id
   for update;

  if not found then
    raise exception using
      message = 'change_schedule_proposal_profile_snapshot_missing',
      errcode = 'P0001';
  end if;

  if v_profile_schema_version is distinct from v_proposal.source_profile_schema_version then
    raise exception using
      message = 'change_schedule_proposal_source_profile_stale',
      errcode = 'P0001';
  end if;

  if v_profile_updated_at is distinct from v_proposal.source_profile_updated_at then
    raise exception using
      message = 'change_schedule_proposal_source_profile_stale',
      errcode = 'P0001';
  end if;

  v_payload := v_proposal.proposed_availability;
  v_preferred := public.normalize_change_schedule_same_day_preference(
    v_payload ->> 'same_day_run_strength_preference'
  );
  if v_preferred is null then
    raise exception using
      message = 'change_schedule_proposal_invalid_preference',
      errcode = 'P0001';
  end if;

  v_payload := jsonb_set(
    v_payload,
    '{same_day_run_strength_preference}',
    pg_catalog.to_jsonb(v_preferred),
    true
  );

  perform public.validate_change_schedule_availability_payload(v_payload);

  v_target_running_days := (v_payload ->> 'target_running_days')::int;
  v_primary_long_run_weekday := (v_payload ->> 'primary_long_run_weekday')::int;
  if v_payload ? 'backup_long_run_weekday'
     and pg_catalog.jsonb_typeof(v_payload -> 'backup_long_run_weekday') = 'number' then
    v_backup_long_run_weekday := (v_payload ->> 'backup_long_run_weekday')::int;
  else
    v_backup_long_run_weekday := null;
  end if;

  if exists (
    select 1
      from public.plan_versions as plan
     where plan.id = p_plan_version_id
  ) then
    raise exception using
      message = 'change_schedule_plan_version_id_conflict',
      errcode = 'P0001';
  end if;

  if exists (
    select 1
      from public.change_schedule_availability_versions as availability
     where availability.id = p_availability_version_id
  ) then
    raise exception using
      message = 'change_schedule_availability_id_conflict',
      errcode = 'P0001';
  end if;

  -- Any previously scheduled chain must be replaced before creating a new queue.
  select activation.*
    into v_existing_activation
   from public.change_schedule_activations as activation
   where activation.user_id = p_user_id
     and activation.status = 'scheduled'
   order by activation.created_at desc
   limit 1
   for update;

  if found then
    if v_existing_activation.proposal_id is null then
      select count(* )
        into v_existing_scheduled_match_count
        from public.change_schedule_proposals as proposal
       where proposal.user_id = p_user_id
         and proposal.status = 'scheduled'
         and proposal.scheduled_plan_version_id = v_existing_activation.queued_candidate_plan_version_id
         and proposal.source_plan_version_id = v_existing_activation.source_plan_version_id
         and proposal.effective_from = v_existing_activation.effective_from;

      if v_existing_scheduled_match_count = 0 then
        raise exception using
          message = 'change_schedule_proposal_inconsistent',
          errcode = 'P0001';
      elsif v_existing_scheduled_match_count > 1 then
        raise exception using
          message = 'change_schedule_activation_proposal_ambiguous',
          errcode = 'P0001';
      end if;

      select proposal.id
        into v_existing_scheduled_proposal_id
        from public.change_schedule_proposals as proposal
       where proposal.user_id = p_user_id
         and proposal.status = 'scheduled'
         and proposal.scheduled_plan_version_id = v_existing_activation.queued_candidate_plan_version_id
         and proposal.source_plan_version_id = v_existing_activation.source_plan_version_id
         and proposal.effective_from = v_existing_activation.effective_from
       order by proposal.created_at desc
       limit 1;

      if v_existing_scheduled_proposal_id is null then
        raise exception using
          message = 'change_schedule_proposal_inconsistent',
          errcode = 'P0001';
      end if;

      update public.change_schedule_activations as activation
         set proposal_id = v_existing_scheduled_proposal_id
       where activation.id = v_existing_activation.id
         and activation.status = 'scheduled'
         and activation.proposal_id is null;
    else
      select proposal.id
        into v_existing_scheduled_proposal_id
        from public.change_schedule_proposals as proposal
       where proposal.id = v_existing_activation.proposal_id
         and proposal.user_id = p_user_id
         and proposal.status = 'scheduled'
         and proposal.scheduled_plan_version_id = v_existing_activation.queued_candidate_plan_version_id
         and proposal.source_plan_version_id = v_existing_activation.source_plan_version_id
         and proposal.effective_from = v_existing_activation.effective_from
       limit 1;

      if v_existing_scheduled_proposal_id is null then
        raise exception using
          message = 'change_schedule_proposal_inconsistent',
          errcode = 'P0001';
      end if;
    end if;

    update public.change_schedule_activations
       set status = 'superseded',
           superseded_at = v_now,
           updated_at = v_now
     where id = v_existing_activation.id
       and status = 'scheduled';

  update public.change_schedule_proposals as proposal
     set status = 'superseded',
         scheduled_plan_version_id = null,
         superseded_at = v_now,
         updated_at = v_now
  where proposal.id = v_existing_scheduled_proposal_id
    and user_id = p_user_id
    and status = 'scheduled';
  end if;

  -- Replace orphaned scheduled availability rows instead of violating the per-user
  -- scheduled-availability uniqueness constraint.
  update public.change_schedule_availability_versions
     set lifecycle_state = 'superseded',
         updated_at = v_now
   where user_id = p_user_id
     and lifecycle_state = 'scheduled';

  v_plan_data := jsonb_set(
    coalesce(v_proposal.candidate_plan, '{}'::jsonb),
    '{id}',
    pg_catalog.to_jsonb(p_plan_version_id),
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
    p_plan_version_id,
    p_user_id,
    v_now,
    'change_schedule',
    false,
    v_source_plan_schema_version,
    v_plan_data
  );

  insert into public.change_schedule_availability_versions (
    id,
    user_id,
    lifecycle_state,
    effective_from,
    target_running_days,
    primary_long_run_weekday,
    backup_long_run_weekday,
    same_day_run_strength_preference,
    availability_data
  ) values (
    p_availability_version_id,
    p_user_id,
    'scheduled',
    v_proposal.effective_from,
    v_target_running_days,
    v_primary_long_run_weekday,
    v_backup_long_run_weekday,
    v_preferred,
    v_payload
  );

  update public.change_schedule_proposals
     set status = 'scheduled',
         scheduled_plan_version_id = p_plan_version_id,
         updated_at = v_now
   where user_id = p_user_id
     and id = p_proposal_id;

  v_activation_id := 'activation-' || md5(
    p_user_id::text || '|' || p_plan_version_id || '|' || p_availability_version_id
  );

  insert into public.change_schedule_activations (
    id,
    user_id,
    source_plan_version_id,
    queued_candidate_plan_version_id,
    availability_version_id,
    effective_from,
    status,
    proposal_id,
    created_at,
    updated_at
  ) values (
    v_activation_id,
    p_user_id,
    v_source_plan_id,
    p_plan_version_id,
    p_availability_version_id,
    v_proposal.effective_from,
    'scheduled',
    p_proposal_id,
    v_now,
    v_now
  );

  return query
  select
    p_proposal_id,
    v_activation_id,
    p_plan_version_id,
    p_availability_version_id,
    'scheduled'::text;
end;
$function$;

revoke all on function public.schedule_change_schedule_proposal(
  uuid,
  text,
  text,
  text,
  timestamptz
) from public, anon, authenticated;

grant execute on function public.schedule_change_schedule_proposal(
  uuid,
  text,
  text,
  text,
  timestamptz
) to service_role;

create or replace function public.cancel_scheduled_change_schedule_proposal(
  p_user_id uuid,
  p_proposal_id text,
  p_cancelled_at timestamptz default now()
) returns table (
  proposal_id text,
  proposal_status text,
  activation_id text,
  scheduled_plan_version_id text
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_now timestamptz;
  v_proposal public.change_schedule_proposals%rowtype;
  v_activation public.change_schedule_activations%rowtype;
  v_existing_scheduled_match_count integer;
begin
  if p_user_id is null then
    raise exception using
      message = 'change_schedule_user_missing',
      errcode = 'P0001';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  v_now := coalesce(p_cancelled_at, now());
  if v_now is null then
    raise exception using
      message = 'change_schedule_proposal_cancelled_timestamp_missing',
      errcode = 'P0001';
  end if;

  select proposal.*
    into v_proposal
    from public.change_schedule_proposals as proposal
   where proposal.user_id = p_user_id
     and proposal.id = p_proposal_id
   for update;

  if not found then
    raise exception using
      message = 'change_schedule_proposal_not_found',
      errcode = 'P0001';
  end if;

  if v_proposal.status = 'cancelled' then
    return query
    select
      v_proposal.id,
      v_proposal.status,
      null::text,
      null::text;
    return;
  end if;

  if v_proposal.status <> 'scheduled' then
    raise exception using
      message = 'change_schedule_proposal_not_scheduled',
      errcode = 'P0001';
  end if;

  if v_proposal.scheduled_plan_version_id is null then
    raise exception using
      message = 'change_schedule_proposal_inconsistent',
      errcode = 'P0001';
  end if;

  select activation.*
    into v_activation
    from public.change_schedule_activations as activation
   where activation.user_id = p_user_id
     and activation.status = 'scheduled'
     and activation.proposal_id = p_proposal_id
     and activation.queued_candidate_plan_version_id = v_proposal.scheduled_plan_version_id
     and activation.source_plan_version_id = v_proposal.source_plan_version_id
     and activation.effective_from = v_proposal.effective_from
   order by activation.created_at desc
   limit 1
   for update;

  if not found then
    select activation.*
      into v_activation
      from public.change_schedule_activations as activation
     where activation.user_id = p_user_id
       and activation.status = 'scheduled'
       and activation.proposal_id = p_proposal_id
     order by activation.created_at desc
     limit 1
     for update;

    if found then
      raise exception using
        message = 'change_schedule_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    select count(*)
      into v_existing_scheduled_match_count
      from public.change_schedule_proposals as proposal
     where proposal.user_id = p_user_id
       and proposal.status = 'scheduled'
       and proposal.scheduled_plan_version_id = v_proposal.scheduled_plan_version_id
       and proposal.source_plan_version_id = v_proposal.source_plan_version_id
       and proposal.effective_from = v_proposal.effective_from;

    if v_existing_scheduled_match_count = 0 then
      raise exception using
        message = 'change_schedule_activation_not_found',
        errcode = 'P0001';
    elsif v_existing_scheduled_match_count > 1 then
      raise exception using
        message = 'change_schedule_activation_proposal_ambiguous',
        errcode = 'P0001';
    end if;

    select activation.*
      into v_activation
      from public.change_schedule_activations as activation
     where activation.user_id = p_user_id
       and activation.status = 'scheduled'
       and activation.proposal_id is null
       and activation.queued_candidate_plan_version_id = v_proposal.scheduled_plan_version_id
       and activation.source_plan_version_id = v_proposal.source_plan_version_id
       and activation.effective_from = v_proposal.effective_from
     order by activation.created_at desc
     limit 1
     for update;

    if not found then
      raise exception using
        message = 'change_schedule_activation_not_found',
        errcode = 'P0001';
    end if;
  end if;

  if v_activation.proposal_id is null then
    update public.change_schedule_activations
       set proposal_id = p_proposal_id
     where id = v_activation.id
       and status = 'scheduled';
  end if;

  update public.change_schedule_activations
     set status = 'cancelled',
         cancelled_at = v_now,
         updated_at = v_now
   where id = v_activation.id
     and status = 'scheduled';

  update public.change_schedule_availability_versions
     set lifecycle_state = 'cancelled',
         updated_at = v_now
   where id = v_activation.availability_version_id
     and user_id = p_user_id;

  update public.change_schedule_proposals
     set status = 'cancelled',
         scheduled_plan_version_id = null,
         cancelled_at = v_now,
         updated_at = v_now
   where user_id = p_user_id
     and id = p_proposal_id;

  return query
  select
    p_proposal_id,
    'cancelled'::text,
    v_activation.id,
    null::text;
end;
$function$;

revoke all on function public.cancel_scheduled_change_schedule_proposal(
  uuid,
  text,
  timestamptz
) from public, anon, authenticated;

grant execute on function public.cancel_scheduled_change_schedule_proposal(
  uuid,
  text,
  timestamptz
) to service_role;

alter table public.change_schedule_activations
  add column if not exists prior_active_plan_version_id text references public.plan_versions(id) on delete restrict,
  add column if not exists prior_active_availability_version_id text references public.change_schedule_availability_versions(id) on delete restrict;

create or replace function public.activate_due_change_schedule(
  p_user_id uuid,
  p_activation_id text,
  p_activated_at timestamptz default now()
) returns table (
  proposal_id text,
  activation_id text,
  proposal_status text,
  accepted_plan_version_id text,
  prior_active_plan_version_id text,
  prior_active_availability_version_id text,
  accepted_availability_version_id text,
  activation_status text
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_now timestamptz;
  v_current_week date;
  v_activation public.change_schedule_activations%rowtype;
  v_proposal public.change_schedule_proposals%rowtype;
  v_source_plan_id text;
  v_profile_schema_version integer;
  v_profile_updated_at timestamptz;
  v_expected_terminal_proposal_status text;
  v_prior_active_plan_id text;
  v_prior_active_availability_id text;
  v_scheduled_match_count integer;
begin
  if p_user_id is null then
    raise exception using
      message = 'change_schedule_user_missing',
      errcode = 'P0001';
  end if;

  if p_activation_id is null then
    raise exception using
      message = 'change_schedule_activation_not_found',
      errcode = 'P0001';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  v_now := coalesce(p_activated_at, now());
  if v_now is null then
    raise exception using
      message = 'change_schedule_activation_timestamp_missing',
      errcode = 'P0001';
  end if;

  select activation.*
    into v_activation
    from public.change_schedule_activations as activation
   where activation.id = p_activation_id
     and activation.user_id = p_user_id
   for update;

  if not found then
    raise exception using
      message = 'change_schedule_activation_not_found',
      errcode = 'P0001';
  end if;

  if v_activation.status <> 'scheduled' then
    if v_activation.status = 'activated' then
      if v_activation.proposal_id is null then
        raise exception using
          message = 'change_schedule_activation_proposal_not_available',
          errcode = 'P0001';
      end if;

      select proposal.*
        into v_proposal
        from public.change_schedule_proposals as proposal
       where proposal.user_id = p_user_id
         and proposal.id = v_activation.proposal_id;

      if not found then
        raise exception using
          message = 'change_schedule_activation_proposal_not_available',
          errcode = 'P0001';
      end if;

      if v_proposal.status is distinct from 'accepted'
         or v_proposal.accepted_plan_version_id is distinct from v_activation.queued_candidate_plan_version_id
         or v_proposal.source_plan_version_id is distinct from v_activation.source_plan_version_id
         or v_proposal.effective_from is distinct from v_activation.effective_from then
        raise exception using
          message = 'change_schedule_activation_proposal_not_available',
          errcode = 'P0001';
      end if;

      return query
      select
        v_proposal.id,
        v_activation.id,
        'accepted'::text,
        v_proposal.accepted_plan_version_id,
        v_proposal.prior_active_plan_version_id,
        v_proposal.prior_active_availability_version_id,
        v_proposal.accepted_availability_version_id,
        v_activation.status;
      return;
    end if;

    if v_activation.status in ('stale', 'cancelled', 'superseded') then
      if v_activation.status = 'stale' then
        v_expected_terminal_proposal_status := 'superseded'::text;
      else
        v_expected_terminal_proposal_status := v_activation.status;
      end if;

      if v_activation.proposal_id is null then
        return query
        select
          null::text,
          v_activation.id,
          v_expected_terminal_proposal_status,
          null::text,
          null::text,
          null::text,
          null::text,
          v_activation.status;
        return;
      end if;

      select proposal.*
        into v_proposal
        from public.change_schedule_proposals as proposal
       where proposal.user_id = p_user_id
         and proposal.id = v_activation.proposal_id;

      if not found
         or v_proposal.status is distinct from v_expected_terminal_proposal_status
         or v_proposal.source_plan_version_id is distinct from v_activation.source_plan_version_id
         or v_proposal.effective_from is distinct from v_activation.effective_from
         or coalesce(v_proposal.candidate_plan ->> 'id', v_proposal.scheduled_plan_version_id) is distinct from v_activation.queued_candidate_plan_version_id then
        raise exception using
          message = 'change_schedule_activation_proposal_not_available',
          errcode = 'P0001';
      end if;

      return query
      select
        v_proposal.id,
        v_activation.id,
        v_expected_terminal_proposal_status,
        null::text,
        null::text,
        null::text,
        null::text,
        v_activation.status;
      return;
    end if;

    raise exception using
      message = 'change_schedule_activation_not_found',
      errcode = 'P0001';
  end if;

  if v_activation.proposal_id is null then
    select count(*)
      into v_scheduled_match_count
      from public.change_schedule_proposals as proposal
     where proposal.user_id = p_user_id
       and proposal.status = 'scheduled'
       and proposal.scheduled_plan_version_id = v_activation.queued_candidate_plan_version_id
       and proposal.source_plan_version_id = v_activation.source_plan_version_id
       and proposal.effective_from = v_activation.effective_from;

    if v_scheduled_match_count = 1 then
      select proposal.*
        into v_proposal
        from public.change_schedule_proposals as proposal
       where proposal.user_id = p_user_id
         and proposal.status = 'scheduled'
         and proposal.scheduled_plan_version_id = v_activation.queued_candidate_plan_version_id
         and proposal.source_plan_version_id = v_activation.source_plan_version_id
         and proposal.effective_from = v_activation.effective_from
       order by proposal.created_at desc
       for update;
    elsif v_scheduled_match_count > 1 then
      raise exception using
        message = 'change_schedule_activation_proposal_ambiguous',
        errcode = 'P0001';
    end if;
  else
    select proposal.*
      into v_proposal
      from public.change_schedule_proposals as proposal
     where proposal.user_id = p_user_id
       and proposal.id = v_activation.proposal_id
     for update;
  end if;

  if not found then
    raise exception using
      message = 'change_schedule_activation_proposal_not_available',
      errcode = 'P0001';
  end if;

  if v_proposal.status is distinct from 'scheduled'
     or v_proposal.scheduled_plan_version_id is distinct from v_activation.queued_candidate_plan_version_id
     or v_proposal.source_plan_version_id is distinct from v_activation.source_plan_version_id
     or v_proposal.effective_from is distinct from v_activation.effective_from then
    raise exception using
      message = 'change_schedule_activation_proposal_not_available',
      errcode = 'P0001';
  end if;

  if v_activation.proposal_id is null then
    update public.change_schedule_activations
       set proposal_id = v_proposal.id
     where id = v_activation.id
       and status = 'scheduled';

    v_activation.proposal_id := v_proposal.id;
  end if;

  v_current_week := pg_catalog.date_trunc('week', v_now)::date;
  if v_activation.effective_from > v_current_week then
    raise exception using
      message = 'change_schedule_activation_not_due',
      errcode = 'P0001';
  end if;

  select profile.schema_version,
         profile.updated_at
    into v_profile_schema_version,
         v_profile_updated_at
   from public.runner_profiles as profile
   where profile.user_id = p_user_id
   for update;

  if not found then
    update public.change_schedule_activations
       set status = 'stale',
           stale_at = v_now,
           updated_at = v_now
     where id = v_activation.id
       and status = 'scheduled';

    update public.change_schedule_proposals
       set status = 'superseded',
           scheduled_plan_version_id = null,
           superseded_at = v_now,
           updated_at = v_now
     where user_id = p_user_id
       and id = v_proposal.id
       and status = 'scheduled';

    return query
    select
      v_proposal.id,
      v_activation.id,
      'superseded'::text,
      null::text,
      null::text,
      null::text,
      null::text,
      'stale'::text;
    return;
  end if;

  if v_profile_schema_version is distinct from v_proposal.source_profile_schema_version
     or v_profile_updated_at is distinct from v_proposal.source_profile_updated_at then
    update public.change_schedule_activations
       set status = 'stale',
           stale_at = v_now,
           updated_at = v_now
     where id = v_activation.id
       and status = 'scheduled';

    update public.change_schedule_proposals
       set status = 'superseded',
           scheduled_plan_version_id = null,
           superseded_at = v_now,
           updated_at = v_now
     where user_id = p_user_id
       and id = v_proposal.id
       and status = 'scheduled';

    return query
    select
      v_proposal.id,
      v_activation.id,
      'superseded'::text,
      null::text,
      null::text,
      null::text,
      null::text,
      'stale'::text;
    return;
  end if;

  select plan.id
    into v_source_plan_id
    from public.plan_versions as plan
   where plan.user_id = p_user_id
     and plan.id = v_activation.source_plan_version_id
     and plan.is_active = true
   for update;

  if v_source_plan_id is null then
    update public.change_schedule_activations
       set status = 'stale',
           stale_at = v_now,
           updated_at = v_now
     where id = v_activation.id
       and status = 'scheduled';

    update public.change_schedule_proposals
       set status = 'superseded',
           scheduled_plan_version_id = null,
           superseded_at = v_now,
           updated_at = v_now
     where user_id = p_user_id
       and id = v_proposal.id
       and status = 'scheduled';

    return query
    select
      v_proposal.id,
      v_activation.id,
      'superseded'::text,
      null::text,
      null::text,
      null::text,
      null::text,
      'stale'::text;
    return;
  end if;

  perform public.acquire_change_schedule_plan_version_lock(
    p_user_id,
    v_activation.source_plan_version_id
  );
  perform public.acquire_change_schedule_plan_version_lock(
    p_user_id,
    v_activation.queued_candidate_plan_version_id
  );

  if v_activation.prior_active_plan_version_id is null then
    select plan.id
      into v_prior_active_plan_id
      from public.plan_versions as plan
     where plan.user_id = p_user_id
       and plan.is_active = true
     order by plan.generated_at desc
     limit 1
     for update;
  else
    select plan.id
      into v_prior_active_plan_id
      from public.plan_versions as plan
     where plan.user_id = p_user_id
       and plan.id = v_activation.prior_active_plan_version_id
     for update;
  end if;

  if v_prior_active_plan_id is null then
    raise exception using
      message = 'change_schedule_activate_prior_plan_missing',
      errcode = 'P0001';
  end if;

  if v_activation.prior_active_availability_version_id is null then
    select availability.id
      into v_prior_active_availability_id
     from public.change_schedule_availability_versions as availability
     where availability.user_id = p_user_id
       and availability.lifecycle_state = 'active'
     order by availability.effective_from desc
     limit 1
     for update;
  else
    select availability.id
      into v_prior_active_availability_id
     from public.change_schedule_availability_versions as availability
     where availability.user_id = p_user_id
       and availability.id = v_activation.prior_active_availability_version_id
     for update;
  end if;

  if v_prior_active_availability_id is null then
    raise exception using
      message = 'change_schedule_accept_prior_availability_not_found',
      errcode = 'P0001';
  end if;

  update public.change_schedule_availability_versions
     set lifecycle_state = 'superseded',
         updated_at = v_now
   where user_id = p_user_id
     and id = v_prior_active_availability_id
     and lifecycle_state = 'active';

  update public.change_schedule_availability_versions
     set lifecycle_state = 'active',
         updated_at = v_now
    where id = v_activation.availability_version_id
     and user_id = p_user_id;

  update public.change_schedule_activations
     set status = 'activated',
         activated_at = v_now,
         prior_active_plan_version_id = v_prior_active_plan_id,
         prior_active_availability_version_id = v_prior_active_availability_id,
         updated_at = v_now
   where id = v_activation.id
     and status = 'scheduled';

  update public.change_schedule_proposals
     set status = 'accepted',
         accepted_at = v_now,
         scheduled_plan_version_id = null,
         accepted_plan_version_id = v_activation.queued_candidate_plan_version_id,
         prior_active_plan_version_id = v_prior_active_plan_id,
         prior_active_availability_version_id = v_prior_active_availability_id,
         accepted_availability_version_id = v_activation.availability_version_id,
         updated_at = v_now
   where user_id = p_user_id
     and id = v_proposal.id
     and status = 'scheduled';

  update public.plan_versions
     set is_active = false
   where user_id = p_user_id
     and is_active = true;

  update public.plan_versions
     set is_active = true
   where user_id = p_user_id
      and id = v_activation.queued_candidate_plan_version_id;

  return query
  select
    v_proposal.id,
    v_activation.id,
    'accepted'::text,
    v_activation.queued_candidate_plan_version_id,
    v_prior_active_plan_id,
    v_prior_active_availability_id,
    v_activation.availability_version_id,
    'activated'::text;
end;
$function$;

revoke all on function public.activate_due_change_schedule(
  uuid,
  text,
  timestamptz
) from public, anon, authenticated;

grant execute on function public.activate_due_change_schedule(
  uuid,
  text,
  timestamptz
) to service_role;

create or replace function public.accept_change_schedule_proposal_now(
  p_user_id uuid,
  p_proposal_id text,
  p_plan_version_id text,
  p_availability_version_id text,
  p_generated_at timestamptz default now(),
  p_accepted_at timestamptz default now()
) returns table (
  accepted_plan_version_id text,
  plan_data jsonb,
  prior_active_plan_version_id text,
  prior_active_availability_version_id text,
  accepted_availability_version_id text
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_proposal public.change_schedule_proposals%rowtype;
  v_now timestamptz;
  v_source_plan_id text;
  v_source_plan_schema_version integer;
  v_profile_schema_version integer;
  v_profile_updated_at timestamptz;
  v_prior_active_plan_id text;
  v_prior_active_availability_id text;
  v_plan_data jsonb;
  v_payload jsonb;
  v_current_week date;
  v_raw_preference text;
  v_preferred text;
  v_target_running_days integer;
  v_primary_long_run_weekday integer;
  v_backup_long_run_weekday integer;
  v_generated_at timestamptz;
  v_scheduled_activation public.change_schedule_activations%rowtype;
  v_scheduled_proposal_id text;
  v_scheduled_match_count integer;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  v_now := coalesce(p_accepted_at, p_generated_at);
  v_generated_at := coalesce(p_generated_at, v_now);

  if v_now is null then
    raise exception using
      message = 'change_schedule_proposal_accepted_timestamp_missing',
      errcode = 'P0001';
  end if;

  select proposal.*
    into v_proposal
    from public.change_schedule_proposals as proposal
   where proposal.user_id = p_user_id
     and proposal.id = p_proposal_id
   for update;

  if not found then
    raise exception using
      message = 'change_schedule_proposal_not_found',
      errcode = 'P0001';
  end if;

  if v_proposal.status = 'accepted' then
    if v_proposal.accepted_plan_version_id is null
       or v_proposal.accepted_at is null then
      raise exception using
        message = 'change_schedule_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    select data
      into v_plan_data
      from public.plan_versions as plan
     where plan.id = v_proposal.accepted_plan_version_id
       and plan.user_id = p_user_id
       and plan.requested_by = 'change_schedule'
       and plan.data ->> 'id' = v_proposal.accepted_plan_version_id
     for share;

    if not found then
      raise exception using
        message = 'change_schedule_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    return query
    select
      v_proposal.accepted_plan_version_id,
      v_plan_data,
      v_proposal.prior_active_plan_version_id,
      v_proposal.prior_active_availability_version_id,
      v_proposal.accepted_availability_version_id;
    return;
  end if;

  if v_proposal.status = 'expired'
     or (v_proposal.status = 'pending' and v_proposal.expires_at <= v_now) then
    raise exception using
      message = 'change_schedule_proposal_expired',
      errcode = 'P0001';
  end if;

  if v_proposal.status <> 'pending' then
    raise exception using
      message = 'change_schedule_proposal_not_pending',
      errcode = 'P0001';
  end if;

  perform public.acquire_change_schedule_plan_version_lock(
    p_user_id,
    p_plan_version_id
  );

  v_current_week := pg_catalog.date_trunc('week', v_now)::date;
  if v_proposal.effective_from is distinct from v_current_week then
    raise exception using
      message = 'change_schedule_proposal_not_current_week',
      errcode = 'P0001';
  end if;

  select plan.id,
         plan.schema_version
    into v_source_plan_id,
         v_source_plan_schema_version
    from public.plan_versions as plan
   where plan.user_id = p_user_id
     and plan.id = v_proposal.source_plan_version_id
     and plan.is_active = true
   for update;

  if v_source_plan_id is null then
    raise exception using
      message = 'change_schedule_source_plan_stale',
      errcode = 'P0001';
  end if;

  v_prior_active_plan_id := v_source_plan_id;

  select activation.*
    into v_scheduled_activation
    from public.change_schedule_activations as activation
   where activation.user_id = p_user_id
     and activation.status = 'scheduled'
   order by activation.created_at desc
   limit 1
   for update;

  if v_scheduled_activation.id is not null then
    if v_scheduled_activation.proposal_id is not null then
      select proposal.id
        into v_scheduled_proposal_id
        from public.change_schedule_proposals as proposal
       where proposal.id = v_scheduled_activation.proposal_id
         and proposal.user_id = p_user_id
         and proposal.status = 'scheduled'
         and proposal.source_plan_version_id = v_scheduled_activation.source_plan_version_id
         and proposal.scheduled_plan_version_id = v_scheduled_activation.queued_candidate_plan_version_id
         and proposal.effective_from = v_scheduled_activation.effective_from;

      if v_scheduled_proposal_id is null then
        raise exception using
          message = 'change_schedule_proposal_inconsistent',
          errcode = 'P0001';
      end if;
    else
      select count(*)
        into v_scheduled_match_count
        from public.change_schedule_proposals as proposal
       where proposal.user_id = p_user_id
         and proposal.status = 'scheduled'
         and proposal.source_plan_version_id = v_scheduled_activation.source_plan_version_id
         and proposal.scheduled_plan_version_id = v_scheduled_activation.queued_candidate_plan_version_id
         and proposal.effective_from = v_scheduled_activation.effective_from;

      if v_scheduled_match_count = 0 then
        raise exception using
          message = 'change_schedule_proposal_inconsistent',
          errcode = 'P0001';
      elsif v_scheduled_match_count > 1 then
        raise exception using
          message = 'change_schedule_activation_proposal_ambiguous',
          errcode = 'P0001';
      elsif v_scheduled_match_count = 1 then
        select proposal.id
          into v_scheduled_proposal_id
          from public.change_schedule_proposals as proposal
         where proposal.user_id = p_user_id
           and proposal.status = 'scheduled'
           and proposal.source_plan_version_id = v_scheduled_activation.source_plan_version_id
           and proposal.scheduled_plan_version_id = v_scheduled_activation.queued_candidate_plan_version_id
           and proposal.effective_from = v_scheduled_activation.effective_from
         order by proposal.created_at desc
         limit 1;

        if v_scheduled_proposal_id is null then
          raise exception using
            message = 'change_schedule_proposal_inconsistent',
            errcode = 'P0001';
        end if;

        update public.change_schedule_activations
           set proposal_id = v_scheduled_proposal_id
         where id = v_scheduled_activation.id
           and status = 'scheduled'
           and proposal_id is null;

        v_scheduled_activation.proposal_id := v_scheduled_proposal_id;
      end if;
    end if;

    update public.change_schedule_activations
       set status = 'superseded',
           superseded_at = v_now,
           updated_at = v_now
     where user_id = p_user_id
       and id = v_scheduled_activation.id
       and status = 'scheduled';

    if v_scheduled_proposal_id is not null then
      update public.change_schedule_proposals
         set status = 'superseded',
             scheduled_plan_version_id = null,
             superseded_at = v_now
       where id = v_scheduled_proposal_id
         and status = 'scheduled';
    end if;
  end if;

  select profile.schema_version,
         profile.updated_at
    into v_profile_schema_version,
         v_profile_updated_at
   from public.runner_profiles as profile
   where profile.user_id = p_user_id
   for update;

  if not found then
    raise exception using
      message = 'change_schedule_accept_profile_not_found',
      errcode = 'P0001';
  end if;

  if v_profile_schema_version is distinct from v_proposal.source_profile_schema_version then
    raise exception using
      message = 'change_schedule_proposal_source_profile_stale',
      errcode = 'P0001';
  end if;

  if v_profile_updated_at is distinct from v_proposal.source_profile_updated_at then
    raise exception using
      message = 'change_schedule_proposal_source_profile_stale',
      errcode = 'P0001';
  end if;

  if p_plan_version_id is null then
    raise exception using
      message = 'change_schedule_accept_plan_id_missing',
      errcode = 'P0001';
  end if;

  if p_availability_version_id is null then
    raise exception using
      message = 'change_schedule_accept_availability_id_missing',
      errcode = 'P0001';
  end if;

  if exists (
    select 1
      from public.plan_versions as plan
     where plan.id = p_plan_version_id
  ) then
    raise exception using
      message = 'change_schedule_plan_version_id_conflict',
      errcode = 'P0001';
  end if;

  if exists (
    select 1
      from public.change_schedule_availability_versions as availability
     where availability.id = p_availability_version_id
  ) then
    raise exception using
      message = 'change_schedule_availability_id_conflict',
      errcode = 'P0001';
  end if;

  select availability.id
    into v_prior_active_availability_id
    from public.change_schedule_availability_versions as availability
   where availability.user_id = p_user_id
     and availability.lifecycle_state = 'active'
   order by availability.effective_from desc
   for update
   limit 1;

  if v_prior_active_availability_id is null then
    raise exception using
      message = 'change_schedule_accept_prior_availability_not_found',
      errcode = 'P0001';
  end if;

  update public.change_schedule_availability_versions
     set lifecycle_state = 'superseded',
         updated_at = v_now
   where user_id = p_user_id
     and id = v_prior_active_availability_id
     and lifecycle_state = 'active';

  v_payload := v_proposal.proposed_availability;
  v_raw_preference := v_payload ->> 'same_day_run_strength_preference';
  v_preferred := public.normalize_change_schedule_same_day_preference(v_raw_preference);

  if v_preferred is null then
    raise exception using
      message = 'change_schedule_proposal_invalid_preference',
      errcode = 'P0001';
  end if;

  v_payload := jsonb_set(
    v_payload,
    '{same_day_run_strength_preference}',
    pg_catalog.to_jsonb(v_preferred),
    true
  );

  perform public.validate_change_schedule_availability_payload(v_payload);

  v_target_running_days := (v_payload ->> 'target_running_days')::int;
  v_primary_long_run_weekday := (v_payload ->> 'primary_long_run_weekday')::int;
  if v_payload ? 'backup_long_run_weekday'
     and jsonb_typeof(v_payload -> 'backup_long_run_weekday') = 'number' then
    v_backup_long_run_weekday := (v_payload ->> 'backup_long_run_weekday')::int;
  else
    v_backup_long_run_weekday := null;
  end if;

  v_plan_data := jsonb_set(
    coalesce(v_proposal.candidate_plan, '{}'::jsonb),
    '{id}',
    pg_catalog.to_jsonb(p_plan_version_id),
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
    p_plan_version_id,
    p_user_id,
    v_generated_at,
    'change_schedule',
    false,
    v_source_plan_schema_version,
    v_plan_data
  );

  insert into public.change_schedule_availability_versions (
    id,
    user_id,
    lifecycle_state,
    effective_from,
    target_running_days,
    primary_long_run_weekday,
    backup_long_run_weekday,
    same_day_run_strength_preference,
    availability_data
  ) values (
    p_availability_version_id,
    p_user_id,
    'active',
    v_proposal.effective_from,
    v_target_running_days,
    v_primary_long_run_weekday,
    v_backup_long_run_weekday,
    v_preferred,
    v_payload
  );

  update public.change_schedule_proposals
     set status = 'accepted',
         accepted_at = v_now,
         accepted_plan_version_id = p_plan_version_id,
         prior_active_plan_version_id = v_prior_active_plan_id,
         prior_active_availability_version_id = v_prior_active_availability_id,
         accepted_availability_version_id = p_availability_version_id
   where user_id = p_user_id
     and id = p_proposal_id;

  update public.plan_versions
     set is_active = false
   where user_id = p_user_id
     and is_active = true;

  update public.plan_versions
     set is_active = true
   where user_id = p_user_id
     and id = p_plan_version_id;

  return query
  select
    p_plan_version_id,
    v_plan_data,
    v_prior_active_plan_id,
    v_prior_active_availability_id,
    p_availability_version_id;
end;
$function$;

revoke all on function public.accept_change_schedule_proposal_now(
  uuid,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) from public, anon, authenticated;

grant execute on function public.accept_change_schedule_proposal_now(
  uuid,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) to service_role;

create or replace function public.enforce_change_schedule_proposal_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile_schema_version integer;
  v_profile_updated_at timestamptz;
  v_reference_mutation boolean;
  v_terminalized_mutation boolean;
  v_accepted_mutation boolean;
  v_profile_snapshot_mutation boolean;
  v_terminalized_lineage_violation boolean;
  v_terminalized_activation public.change_schedule_activations%rowtype;
  v_prior_active_plan_version_id text;
  v_prior_active_availability_version_id text;
  v_scheduled_state_mutation boolean;
  v_scheduled_semantic_mutation boolean;
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and auth.uid() is distinct from NEW.user_id then
    raise exception using
      message = 'insufficient_privilege',
      errcode = '42501';
  end if;

  v_reference_mutation := TG_OP = 'INSERT';

  if TG_OP = 'UPDATE' then
    v_reference_mutation :=
      NEW.source_plan_version_id is distinct from OLD.source_plan_version_id
      or NEW.user_id is distinct from OLD.user_id
      or NEW.scheduled_plan_version_id is distinct from OLD.scheduled_plan_version_id
      or NEW.accepted_plan_version_id is distinct from OLD.accepted_plan_version_id
      or NEW.prior_active_plan_version_id is distinct from OLD.prior_active_plan_version_id
      or NEW.prior_active_availability_version_id is distinct from OLD.prior_active_availability_version_id
      or NEW.accepted_availability_version_id is distinct from OLD.accepted_availability_version_id;
  end if;

  v_scheduled_state_mutation :=
    TG_OP = 'UPDATE'
    and OLD.status = 'scheduled'
    and NEW.status = 'scheduled';

  v_scheduled_semantic_mutation :=
    v_scheduled_state_mutation
    and (
      NEW.user_id is distinct from OLD.user_id
      or NEW.source_plan_version_id is distinct from OLD.source_plan_version_id
      or NEW.source_profile_schema_version is distinct from OLD.source_profile_schema_version
      or NEW.source_profile_updated_at is distinct from OLD.source_profile_updated_at
      or NEW.effective_from is distinct from OLD.effective_from
      or NEW.expires_at is distinct from OLD.expires_at
      or NEW.proposed_availability is distinct from OLD.proposed_availability
      or NEW.candidate_plan is distinct from OLD.candidate_plan
      or NEW.impact is distinct from OLD.impact
      or NEW.created_at is distinct from OLD.created_at
      or NEW.scheduled_plan_version_id is distinct from OLD.scheduled_plan_version_id
      or NEW.accepted_plan_version_id is distinct from OLD.accepted_plan_version_id
      or NEW.prior_active_plan_version_id is distinct from OLD.prior_active_plan_version_id
      or NEW.prior_active_availability_version_id is distinct from OLD.prior_active_availability_version_id
      or NEW.accepted_availability_version_id is distinct from OLD.accepted_availability_version_id
      or NEW.accepted_at is distinct from OLD.accepted_at
      or NEW.superseded_at is distinct from OLD.superseded_at
      or NEW.cancelled_at is distinct from OLD.cancelled_at
    );

  if v_scheduled_semantic_mutation then
    raise exception using
      message = 'change_schedule_proposal_scheduled_rewrite_rejected',
      errcode = 'P0001';
  end if;

  v_terminalized_mutation :=
    TG_OP = 'UPDATE'
    and OLD.status = 'scheduled'
    and NEW.status in ('cancelled', 'superseded');

  v_accepted_mutation :=
    TG_OP = 'UPDATE'
    and OLD.status = 'scheduled'
    and NEW.status = 'accepted';

  v_terminalized_lineage_violation :=
    v_terminalized_mutation
    and (
      NEW.user_id is distinct from OLD.user_id
      or NEW.source_plan_version_id is distinct from OLD.source_plan_version_id
      or NEW.source_profile_schema_version is distinct from OLD.source_profile_schema_version
      or NEW.source_profile_updated_at is distinct from OLD.source_profile_updated_at
      or NEW.effective_from is distinct from OLD.effective_from
      or NEW.expires_at is distinct from OLD.expires_at
      or NEW.proposed_availability is distinct from OLD.proposed_availability
      or NEW.candidate_plan is distinct from OLD.candidate_plan
      or NEW.impact is distinct from OLD.impact
      or NEW.created_at is distinct from OLD.created_at
      or NEW.accepted_plan_version_id is distinct from OLD.accepted_plan_version_id
      or NEW.prior_active_plan_version_id is distinct from OLD.prior_active_plan_version_id
      or NEW.prior_active_availability_version_id is distinct from OLD.prior_active_availability_version_id
      or NEW.accepted_availability_version_id is distinct from OLD.accepted_availability_version_id
    );

  if v_terminalized_mutation and NEW.scheduled_plan_version_id is not null then
    raise exception using
      message = 'change_schedule_proposal_terminalization_requires_schedule_clear',
      errcode = 'P0001';
    end if;

  if v_terminalized_mutation and v_terminalized_lineage_violation then
    raise exception using
      message = 'change_schedule_proposal_terminalization_lineage_rewrite',
      errcode = 'P0001';
  end if;

  if v_terminalized_mutation then
    if NEW.status = 'cancelled' then
      select activation.*
        into v_terminalized_activation
        from public.change_schedule_activations as activation
       where activation.user_id = OLD.user_id
         and activation.source_plan_version_id = OLD.source_plan_version_id
         and activation.queued_candidate_plan_version_id = OLD.scheduled_plan_version_id
         and activation.effective_from = OLD.effective_from
         and activation.proposal_id = OLD.id
         and activation.status = 'cancelled'
       order by activation.created_at desc
       limit 1;
    elsif NEW.status = 'superseded' then
      select activation.*
        into v_terminalized_activation
        from public.change_schedule_activations as activation
       where activation.user_id = OLD.user_id
         and activation.source_plan_version_id = OLD.source_plan_version_id
         and activation.queued_candidate_plan_version_id = OLD.scheduled_plan_version_id
         and activation.effective_from = OLD.effective_from
         and activation.proposal_id = OLD.id
         and activation.status in ('superseded', 'stale')
       order by activation.created_at desc
       limit 1;
    end if;

    if not found then
      raise exception using
        message = 'change_schedule_proposal_terminalization_activation_not_found',
        errcode = 'P0001';
    end if;
  end if;

  if v_accepted_mutation then
    if NEW.scheduled_plan_version_id is not null then
      raise exception using
        message = 'change_schedule_proposal_acceptance_requires_activated_activation',
        errcode = 'P0001';
    end if;

    select activation.*
      into v_terminalized_activation
      from public.change_schedule_activations as activation
     where activation.user_id = OLD.user_id
       and activation.source_plan_version_id = OLD.source_plan_version_id
       and activation.queued_candidate_plan_version_id = OLD.scheduled_plan_version_id
       and activation.effective_from = OLD.effective_from
       and activation.proposal_id is not distinct from OLD.id
       and activation.status = 'activated'
     order by activation.created_at desc
     limit 1;

    if not found then
      raise exception using
        message = 'change_schedule_proposal_acceptance_requires_activated_activation',
        errcode = 'P0001';
    end if;

    if v_terminalized_activation.prior_active_plan_version_id is null then
      raise exception using
        message = 'change_schedule_accept_prior_plan_not_found',
        errcode = 'P0001';
    end if;

    v_prior_active_plan_version_id := v_terminalized_activation.prior_active_plan_version_id;

    if v_terminalized_activation.prior_active_availability_version_id is null then
      raise exception using
        message = 'change_schedule_accept_prior_availability_not_found',
        errcode = 'P0001';
    end if;

    v_prior_active_availability_version_id := v_terminalized_activation.prior_active_availability_version_id;

    if NEW.accepted_plan_version_id is distinct from OLD.scheduled_plan_version_id
       or NEW.accepted_at is null
       or NEW.accepted_plan_version_id is null
       or NEW.accepted_availability_version_id is distinct from v_terminalized_activation.availability_version_id
       or NEW.accepted_availability_version_id is null
       or NEW.prior_active_plan_version_id is distinct from v_prior_active_plan_version_id
       or NEW.prior_active_availability_version_id is distinct from v_prior_active_availability_version_id then
      raise exception using
        message = 'change_schedule_proposal_accepted_activation_context_mismatch',
        errcode = 'P0001';
    end if;
  end if;

  if v_reference_mutation and not (v_terminalized_mutation and NEW.scheduled_plan_version_id is null) then
    if not exists (
      select 1
        from public.plan_versions as plan
       where plan.id = NEW.source_plan_version_id
         and plan.user_id = NEW.user_id
         and plan.is_active = true
    ) then
      raise exception using
        message = 'change_schedule_proposal_source_plan_not_active',
        errcode = 'P0001';
    end if;
  end if;

  if NEW.prior_active_plan_version_id is not null then
    if not exists (
      select 1
        from public.plan_versions as plan
       where plan.id = NEW.prior_active_plan_version_id
         and plan.user_id = NEW.user_id
    ) then
      raise exception using
        message = 'change_schedule_proposal_prior_plan_not_owned',
        errcode = 'P0001';
    end if;
  end if;

  if NEW.prior_active_availability_version_id is not null then
    if not exists (
      select 1
        from public.change_schedule_availability_versions as availability
       where availability.id = NEW.prior_active_availability_version_id
         and availability.user_id = NEW.user_id
    ) then
      raise exception using
        message = 'change_schedule_proposal_prior_availability_not_owned',
        errcode = 'P0001';
    end if;
  end if;

  if NEW.accepted_availability_version_id is not null then
    if not exists (
      select 1
        from public.change_schedule_availability_versions as availability
       where availability.id = NEW.accepted_availability_version_id
         and availability.user_id = NEW.user_id
    ) then
      raise exception using
        message = 'change_schedule_proposal_accepted_availability_not_owned',
        errcode = 'P0001';
    end if;
  end if;

  v_profile_snapshot_mutation := TG_OP = 'INSERT';

  if TG_OP = 'UPDATE' then
    v_profile_snapshot_mutation :=
      NEW.source_profile_schema_version is distinct from OLD.source_profile_schema_version
      or NEW.source_profile_updated_at is distinct from OLD.source_profile_updated_at;
  end if;

  if v_profile_snapshot_mutation then
    select schema_version, updated_at
      into v_profile_schema_version, v_profile_updated_at
      from public.runner_profiles
     where user_id = NEW.user_id;

    if not found then
      raise exception using
        message = 'change_schedule_proposal_profile_not_found',
        errcode = 'P0001';
    end if;

    if v_profile_schema_version is distinct from NEW.source_profile_schema_version
       or v_profile_updated_at is distinct from NEW.source_profile_updated_at then
      raise exception using
        message = 'change_schedule_proposal_profile_snapshot_mismatch',
        errcode = 'P0001';
    end if;
  end if;

  perform public.validate_change_schedule_availability_payload(NEW.proposed_availability);

  if NEW.scheduled_plan_version_id is not null
     and not exists (
      select 1
        from public.plan_versions as plan
       where plan.id = NEW.scheduled_plan_version_id
         and plan.user_id = NEW.user_id
  ) then
    raise exception using
      message = 'change_schedule_proposal_scheduled_plan_not_owned',
      errcode = 'P0001';
  end if;

  if NEW.accepted_plan_version_id is not null
     and not exists (
      select 1
        from public.plan_versions as plan
       where plan.id = NEW.accepted_plan_version_id
         and plan.user_id = NEW.user_id
  ) then
    raise exception using
      message = 'change_schedule_proposal_accepted_plan_not_owned',
      errcode = 'P0001';
  end if;

  NEW.updated_at := now();
  return NEW;
end;
$function$;

drop trigger if exists change_schedule_proposals_integrity on public.change_schedule_proposals;
create trigger change_schedule_proposals_integrity
  before insert or update on public.change_schedule_proposals
  for each row execute function public.enforce_change_schedule_proposal_integrity();

alter table public.change_schedule_activations
  add column if not exists proposal_id text references public.change_schedule_proposals(id) on delete set null;

create index if not exists change_schedule_activations_proposal
  on public.change_schedule_activations (proposal_id)
  where proposal_id is not null;

with scheduled_backfill_matches as (
  select
    activation.id as activation_id,
    array_agg(proposal.id order by proposal.created_at desc) as proposal_ids
  from public.change_schedule_activations activation
  join public.change_schedule_proposals proposal
    on proposal.user_id = activation.user_id
   and proposal.status = 'scheduled'
   and proposal.scheduled_plan_version_id = activation.queued_candidate_plan_version_id
   and proposal.source_plan_version_id = activation.source_plan_version_id
   and proposal.effective_from = activation.effective_from
 where activation.proposal_id is null
   and activation.status = 'scheduled'
 group by activation.id
    having count(*) = 1
)
update public.change_schedule_activations as activation
   set proposal_id = scheduled_backfill_matches.proposal_ids[1]
  from scheduled_backfill_matches
 where activation.id = scheduled_backfill_matches.activation_id
   and activation.proposal_id is null
   and activation.status = 'scheduled';

with activated_backfill_matches as (
  select
    activation.id as activation_id,
    array_agg(proposal.id order by proposal.created_at desc) as proposal_ids
  from public.change_schedule_activations activation
  join public.change_schedule_proposals proposal
    on proposal.user_id = activation.user_id
   and proposal.status = 'accepted'
   and proposal.accepted_plan_version_id = activation.queued_candidate_plan_version_id
   and proposal.source_plan_version_id = activation.source_plan_version_id
   and proposal.effective_from = activation.effective_from
 where activation.proposal_id is null
   and activation.status = 'activated'
 group by activation.id
    having count(*) = 1
)
update public.change_schedule_activations as activation
   set proposal_id = activated_backfill_matches.proposal_ids[1]
  from activated_backfill_matches
 where activation.id = activated_backfill_matches.activation_id
   and activation.proposal_id is null
   and activation.status = 'activated';

create or replace function public.enforce_change_schedule_activation_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_reference_mutation boolean;
  v_requires_scheduled_check boolean;
  v_requires_activated_check boolean;
  v_snapshot_mutation boolean;
  v_snapshot_transition_init boolean;
  v_proposal public.change_schedule_proposals%rowtype;
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and auth.uid() is distinct from NEW.user_id then
    raise exception using
      message = 'insufficient_privilege',
      errcode = '42501';
  end if;

  v_reference_mutation := TG_OP = 'INSERT';
  v_requires_activated_check := NEW.status = 'activated'
    and (
      TG_OP = 'INSERT'
      or OLD.status is distinct from 'activated'
    );

  if TG_OP = 'UPDATE' then
    v_reference_mutation :=
      NEW.user_id is distinct from OLD.user_id
      or NEW.source_plan_version_id is distinct from OLD.source_plan_version_id
      or NEW.queued_candidate_plan_version_id is distinct from OLD.queued_candidate_plan_version_id
      or NEW.availability_version_id is distinct from OLD.availability_version_id
      or NEW.effective_from is distinct from OLD.effective_from;
    v_snapshot_mutation :=
      NEW.prior_active_plan_version_id is distinct from OLD.prior_active_plan_version_id
      or NEW.prior_active_availability_version_id is distinct from OLD.prior_active_availability_version_id;
    v_snapshot_transition_init :=
      OLD.status = 'scheduled'
      and NEW.status = 'activated'
      and OLD.prior_active_plan_version_id is null
      and OLD.prior_active_availability_version_id is null
      and NEW.prior_active_plan_version_id is not null
      and NEW.prior_active_availability_version_id is not null;
  end if;

  if NEW.status = 'activated' then
    if NEW.prior_active_plan_version_id is null then
      raise exception using
        message = 'change_schedule_activation_snapshot_plan_missing',
        errcode = 'P0001';
    end if;

    if NEW.prior_active_availability_version_id is null then
      raise exception using
        message = 'change_schedule_activation_snapshot_availability_missing',
        errcode = 'P0001';
    end if;

    if TG_OP = 'UPDATE'
       and v_snapshot_mutation
       and not v_snapshot_transition_init then
      raise exception using
        message = 'change_schedule_activation_snapshot_immutable',
        errcode = 'P0001';
    end if;
  end if;

  if TG_OP = 'INSERT'
     and NEW.status in ('stale', 'cancelled', 'superseded', 'activated')
     and NEW.proposal_id is null then
    raise exception using
      message = 'change_schedule_activation_proposal_inconsistent',
      errcode = 'P0001';
  end if;

  if NEW.proposal_id is not null then
    select proposal.*
      into v_proposal
      from public.change_schedule_proposals as proposal
     where proposal.id = NEW.proposal_id;

    if not found then
      raise exception using
        message = 'change_schedule_activation_proposal_not_found',
        errcode = 'P0001';
    end if;

    if v_proposal.user_id is distinct from NEW.user_id then
      raise exception using
        message = 'change_schedule_activation_proposal_not_owned',
        errcode = 'P0001';
    end if;

    if v_proposal.source_plan_version_id is distinct from NEW.source_plan_version_id then
      raise exception using
        message = 'change_schedule_activation_proposal_source_mismatch',
        errcode = 'P0001';
    end if;

    if v_proposal.effective_from is distinct from NEW.effective_from then
      raise exception using
        message = 'change_schedule_activation_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    if TG_OP = 'INSERT'
       and NEW.status in ('stale', 'cancelled', 'superseded') then
      raise exception using
        message = 'change_schedule_activation_terminal_status_rejects_proposal',
        errcode = 'P0001';
    end if;

    if TG_OP = 'INSERT'
       and NEW.status = 'activated' then
      raise exception using
        message = 'change_schedule_activation_proposal_inconsistent',
        errcode = 'P0001';
    end if;

    if TG_OP = 'UPDATE'
       and NEW.status <> 'scheduled'
       and NEW.proposal_id is distinct from OLD.proposal_id then
      raise exception using
        message = 'change_schedule_activation_proposal_inconsistent',
        errcode = 'P0001';
    end if;

  if NEW.status = 'scheduled' then
    if v_proposal.status = 'scheduled'
       and (v_proposal.scheduled_plan_version_id is distinct from NEW.queued_candidate_plan_version_id
       or v_proposal.effective_from is distinct from NEW.effective_from) then
      raise exception using
        message = 'change_schedule_activation_proposal_inconsistent',
        errcode = 'P0001';
    elsif v_proposal.status <> 'scheduled' then
      raise exception using
        message = 'change_schedule_activation_proposal_inconsistent',
        errcode = 'P0001';
    end if;
  elsif NEW.status = 'activated' then
    if v_proposal.status = 'accepted' then
      if v_proposal.accepted_plan_version_id is distinct from NEW.queued_candidate_plan_version_id then
        raise exception using
          message = 'change_schedule_activation_proposal_inconsistent',
          errcode = 'P0001';
      end if;
      if v_proposal.effective_from is distinct from NEW.effective_from then
        raise exception using
          message = 'change_schedule_activation_proposal_inconsistent',
          errcode = 'P0001';
      end if;
    elsif v_proposal.status = 'scheduled' then
      if TG_OP <> 'UPDATE'
        or OLD.status is distinct from 'scheduled'
        or NEW.proposal_id is distinct from OLD.proposal_id
        or v_proposal.scheduled_plan_version_id is distinct from NEW.queued_candidate_plan_version_id
        or v_proposal.effective_from is distinct from NEW.effective_from then
        raise exception using
          message = 'change_schedule_activation_proposal_inconsistent',
          errcode = 'P0001';
      end if;
    else
      raise exception using
        message = 'change_schedule_activation_proposal_inconsistent',
        errcode = 'P0001';
    end if;
  elsif NEW.status in ('stale', 'cancelled', 'superseded') then
    null;
  end if;
  elsif TG_OP = 'UPDATE'
    and NEW.status <> 'scheduled'
    and NEW.proposal_id is distinct from OLD.proposal_id then
    raise exception using
      message = 'change_schedule_activation_proposal_inconsistent',
      errcode = 'P0001';
  end if;

  if v_reference_mutation
     or v_requires_activated_check then
    if not exists (
      select 1
        from public.plan_versions as plan
       where plan.id = NEW.source_plan_version_id
         and plan.user_id = NEW.user_id
         and plan.is_active = true
    ) then
      raise exception using
        message = 'change_schedule_activation_source_plan_not_active',
        errcode = 'P0001';
    end if;
  end if;

  if not exists (
    select 1
      from public.plan_versions as plan
     where plan.id = NEW.queued_candidate_plan_version_id
       and plan.user_id = NEW.user_id
  ) then
    raise exception using
      message = 'change_schedule_activation_candidate_plan_not_owned',
      errcode = 'P0001';
  end if;

  if not exists (
    select 1
      from public.change_schedule_availability_versions as availability
     where availability.id = NEW.availability_version_id
       and availability.user_id = NEW.user_id
  ) then
    raise exception using
      message = 'change_schedule_activation_availability_not_owned',
      errcode = 'P0001';
  end if;

  v_requires_scheduled_check := NEW.status = 'scheduled';
  v_requires_activated_check := NEW.status = 'activated';

  if v_requires_scheduled_check then
    if not exists (
      select 1
        from public.change_schedule_availability_versions as availability
       where availability.id = NEW.availability_version_id
         and availability.user_id = NEW.user_id
         and availability.effective_from = NEW.effective_from
         and availability.lifecycle_state = 'scheduled'
    ) then
      raise exception using
        message = 'change_schedule_activation_availability_schedule_mismatch',
        errcode = 'P0001';
    end if;
  elsif v_requires_activated_check then
    if not exists (
      select 1
        from public.change_schedule_availability_versions as availability
       where availability.id = NEW.availability_version_id
         and availability.user_id = NEW.user_id
         and availability.lifecycle_state = 'active'
         and availability.effective_from = NEW.effective_from
    ) then
      raise exception using
        message = 'change_schedule_activation_availability_state_mismatch',
        errcode = 'P0001';
    end if;
  end if;

  if TG_OP = 'UPDATE'
     and NEW.status = 'activated'
     and OLD.status = 'scheduled'
     and NEW.proposal_id is null then
    raise exception using
      message = 'change_schedule_activation_proposal_inconsistent',
      errcode = 'P0001';
  end if;

  if TG_OP = 'UPDATE'
     and OLD.status = 'scheduled'
     and NEW.status in ('stale', 'cancelled', 'superseded')
     and NEW.proposal_id is null then
    raise exception using
      message = 'change_schedule_activation_proposal_inconsistent',
      errcode = 'P0001';
  end if;

  NEW.updated_at := now();
  return NEW;
end;
$function$;

drop trigger if exists change_schedule_activations_integrity on public.change_schedule_activations;
create trigger change_schedule_activations_integrity
  before insert or update on public.change_schedule_activations
  for each row execute function public.enforce_change_schedule_activation_integrity();
