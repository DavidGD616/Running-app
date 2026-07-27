create or replace function public.normalize_change_schedule_same_day_preference(
  p_preference text
) returns text
language sql
as $function$
  select case
    when p_preference in ('run_first', 'lift_first', 'it_depends') then 'separate_sessions'::text
    when p_preference in ('separate_sessions', 'avoid_same_day') then p_preference
    else null
  end;
$function$;

create or replace function public.normalize_change_schedule_same_day_preference_data()
returns void
language plpgsql
set search_path = ''
as $function$
begin
  update public.change_schedule_availability_versions as availability
     set same_day_run_strength_preference = normalized.normalized_preference,
         availability_data = jsonb_set(
           availability.availability_data,
           '{same_day_run_strength_preference}',
           to_jsonb(normalized.normalized_json_preference),
           true
         )
    from (
          select
            id,
            public.normalize_change_schedule_same_day_preference(same_day_run_strength_preference) as normalized_preference,
            public.normalize_change_schedule_same_day_preference(availability_data ->> 'same_day_run_strength_preference') as normalized_json_preference
          from public.change_schedule_availability_versions
         ) as normalized
   where availability.id = normalized.id
     and normalized.normalized_preference is not null
     and normalized.normalized_json_preference is not null
     and (
           availability.same_day_run_strength_preference is distinct from normalized.normalized_preference
           or availability.availability_data ->> 'same_day_run_strength_preference' is distinct from normalized.normalized_json_preference
         );
end;
$function$;

select public.normalize_change_schedule_same_day_preference_data();

-- Replace legacy validation and constraints with the current canonical pair.
alter table public.change_schedule_availability_versions
  drop constraint if exists change_schedule_availability_versions_same_day_preference_check;

alter table public.change_schedule_availability_versions
  add constraint change_schedule_availability_versions_same_day_preference_check
    check (same_day_run_strength_preference in ('separate_sessions', 'avoid_same_day'));

create or replace function public.validate_change_schedule_availability_payload(
  p_availability jsonb,
  p_target_running_days integer default null,
  p_primary_long_run_weekday integer default null,
  p_backup_long_run_weekday integer default null,
  p_same_day_run_strength_preference text default null
) returns void
language plpgsql
as $function$
declare
  v_days jsonb;
  v_entry jsonb;
  v_days_count integer;
  v_day integer;
  v_available boolean;
  v_max_duration integer;
  v_day_seen boolean[];
  v_day_available boolean[];
  v_available_count integer := 0;
  v_target_running_days integer;
  v_primary_long_run_weekday integer;
  v_backup_long_run_weekday integer;
  v_same_day_preference text;
  v_idx integer;
begin
  if p_availability is null or jsonb_typeof(p_availability) <> 'object' then
    raise exception using
      message = 'change_schedule_availability_payload_not_object',
      errcode = 'P0001';
  end if;

  if not (p_availability ? 'days') then
    raise exception using
      message = 'change_schedule_availability_payload_missing_days',
      errcode = 'P0001';
  end if;

  if jsonb_typeof(p_availability -> 'days') <> 'array' then
    raise exception using
      message = 'change_schedule_availability_payload_days_not_array',
      errcode = 'P0001';
  end if;

  v_days := p_availability -> 'days';
  v_days_count := jsonb_array_length(v_days);
  if v_days_count <> 7 then
    raise exception using
      message = 'change_schedule_availability_payload_day_count_invalid',
      errcode = 'P0001';
  end if;

  v_day_seen := array_fill(false, ARRAY[8]);
  v_day_available := array_fill(false, ARRAY[8]);

  for v_entry in
    select value from jsonb_array_elements(v_days)
  loop
    if jsonb_typeof(v_entry) <> 'object' then
      raise exception using
        message = 'change_schedule_availability_payload_day_not_object',
        errcode = 'P0001';
    end if;

    if not (v_entry ? 'day') then
      raise exception using
        message = 'change_schedule_availability_payload_day_missing_key',
        errcode = 'P0001';
    end if;
    if jsonb_typeof(v_entry -> 'day') <> 'number' then
      raise exception using
        message = 'change_schedule_availability_payload_day_invalid',
        errcode = 'P0001';
    end if;

    begin
      v_day := (v_entry ->> 'day')::int;
    exception
      when others then
        raise exception using
          message = 'change_schedule_availability_payload_day_invalid',
          errcode = 'P0001';
    end;

    if v_day < 1 or v_day > 7 then
      raise exception using
        message = 'change_schedule_availability_payload_day_invalid',
        errcode = 'P0001';
    end if;

    if v_day_seen[v_day] then
      raise exception using
        message = 'change_schedule_availability_payload_day_duplicate',
        errcode = 'P0001';
    end if;
    v_day_seen[v_day] := true;

    if not (v_entry ? 'available') then
      raise exception using
        message = 'change_schedule_availability_payload_available_missing',
        errcode = 'P0001';
    end if;

    if jsonb_typeof(v_entry -> 'available') <> 'boolean' then
      raise exception using
        message = 'change_schedule_availability_payload_available_invalid',
        errcode = 'P0001';
    end if;

    v_available := (v_entry ->> 'available')::boolean;
    v_day_available[v_day] := v_available;
    if v_available then
      v_available_count := v_available_count + 1;
    end if;

    if v_entry ? 'max_duration_minutes' then
      if jsonb_typeof(v_entry -> 'max_duration_minutes') not in ('null', 'number') then
        raise exception using
          message = 'change_schedule_availability_payload_duration_invalid',
          errcode = 'P0001';
      end if;

      if jsonb_typeof(v_entry -> 'max_duration_minutes') = 'number' then
        begin
          v_max_duration := (v_entry ->> 'max_duration_minutes')::int;
        exception
          when others then
            raise exception using
              message = 'change_schedule_availability_payload_duration_invalid',
              errcode = 'P0001';
        end;

        if v_max_duration <= 0 then
          raise exception using
            message = 'change_schedule_availability_payload_duration_invalid',
            errcode = 'P0001';
        end if;
      end if;
    end if;
  end loop;

  for v_idx in 1..7 loop
    if not v_day_seen[v_idx] then
      raise exception using
        message = 'change_schedule_availability_payload_day_missing',
        errcode = 'P0001';
    end if;
  end loop;

  if not (p_availability ? 'target_running_days') then
    raise exception using
      message = 'change_schedule_availability_payload_target_running_days_missing',
      errcode = 'P0001';
  end if;

  if jsonb_typeof(p_availability -> 'target_running_days') <> 'number' then
    raise exception using
      message = 'change_schedule_availability_payload_target_running_days_invalid',
      errcode = 'P0001';
  end if;

  begin
    v_target_running_days := (p_availability ->> 'target_running_days')::int;
  exception
    when others then
      raise exception using
        message = 'change_schedule_availability_payload_target_running_days_invalid',
        errcode = 'P0001';
  end;

  if v_target_running_days < 1 or v_target_running_days > 7 then
    raise exception using
      message = 'change_schedule_availability_payload_target_running_days_invalid',
      errcode = 'P0001';
  end if;

  if p_target_running_days is not null
     and p_target_running_days is distinct from v_target_running_days then
    raise exception using
      message = 'change_schedule_availability_payload_target_running_days_mismatch',
      errcode = 'P0001';
  end if;

  if v_target_running_days <> v_available_count then
    raise exception using
      message = 'change_schedule_availability_payload_target_running_days_mismatch',
      errcode = 'P0001';
  end if;

  if not (p_availability ? 'primary_long_run_weekday') then
    raise exception using
      message = 'change_schedule_availability_payload_primary_day_missing',
      errcode = 'P0001';
  end if;

  if jsonb_typeof(p_availability -> 'primary_long_run_weekday') <> 'number' then
    raise exception using
      message = 'change_schedule_availability_payload_primary_day_invalid',
      errcode = 'P0001';
  end if;

  begin
    v_primary_long_run_weekday := (p_availability ->> 'primary_long_run_weekday')::int;
  exception
    when others then
      raise exception using
        message = 'change_schedule_availability_payload_primary_day_invalid',
        errcode = 'P0001';
  end;

  if v_primary_long_run_weekday < 1 or v_primary_long_run_weekday > 7 then
    raise exception using
      message = 'change_schedule_availability_payload_primary_day_invalid',
      errcode = 'P0001';
  end if;

  if p_primary_long_run_weekday is not null
     and p_primary_long_run_weekday is distinct from v_primary_long_run_weekday then
    raise exception using
      message = 'change_schedule_availability_payload_primary_day_mismatch',
      errcode = 'P0001';
  end if;

  if not v_day_available[v_primary_long_run_weekday] then
    raise exception using
      message = 'change_schedule_availability_payload_primary_day_unavailable',
      errcode = 'P0001';
  end if;

  v_backup_long_run_weekday := null;
  if p_availability ? 'backup_long_run_weekday' then
    if jsonb_typeof(p_availability -> 'backup_long_run_weekday') = 'null' then
      v_backup_long_run_weekday := null;
    elsif jsonb_typeof(p_availability -> 'backup_long_run_weekday') <> 'number' then
      raise exception using
        message = 'change_schedule_availability_payload_backup_day_invalid',
        errcode = 'P0001';
    else
      begin
        v_backup_long_run_weekday := (p_availability ->> 'backup_long_run_weekday')::int;
      exception
        when others then
          raise exception using
            message = 'change_schedule_availability_payload_backup_day_invalid',
            errcode = 'P0001';
      end;

      if v_backup_long_run_weekday < 1 or v_backup_long_run_weekday > 7 then
        raise exception using
          message = 'change_schedule_availability_payload_backup_day_invalid',
          errcode = 'P0001';
      end if;

      if v_backup_long_run_weekday = v_primary_long_run_weekday then
        raise exception using
          message = 'change_schedule_availability_payload_long_run_weekday_conflict',
          errcode = 'P0001';
      end if;

      if not v_day_available[v_backup_long_run_weekday] then
        raise exception using
          message = 'change_schedule_availability_payload_backup_day_unavailable',
          errcode = 'P0001';
      end if;
    end if;
  end if;

  if p_backup_long_run_weekday is not null
     and p_backup_long_run_weekday is distinct from v_backup_long_run_weekday then
    raise exception using
      message = 'change_schedule_availability_payload_backup_day_mismatch',
      errcode = 'P0001';
  end if;

  if not (p_availability ? 'same_day_run_strength_preference') then
    raise exception using
      message = 'change_schedule_availability_payload_preference_missing',
      errcode = 'P0001';
  end if;

  if jsonb_typeof(p_availability -> 'same_day_run_strength_preference') <> 'string' then
    raise exception using
      message = 'change_schedule_availability_payload_preference_invalid',
      errcode = 'P0001';
  end if;

  v_same_day_preference := p_availability ->> 'same_day_run_strength_preference';
  if v_same_day_preference not in (
    'separate_sessions',
    'avoid_same_day'
  ) then
    raise exception using
      message = 'change_schedule_availability_payload_preference_invalid',
      errcode = 'P0001';
  end if;

  if p_same_day_run_strength_preference is not null
     and p_same_day_run_strength_preference is distinct from v_same_day_preference then
    raise exception using
      message = 'change_schedule_availability_payload_same_day_preference_mismatch',
      errcode = 'P0001';
  end if;
end;
$function$;

create or replace function public.acquire_change_schedule_plan_version_lock(
  p_user_id uuid,
  p_plan_version_id text
) returns void
language plpgsql
set search_path = ''
as $function$
begin
  if p_user_id is null or p_plan_version_id is null then
    return;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext(p_user_id::text),
    pg_catalog.hashtext(p_plan_version_id)
  );
end;
$function$;

create or replace function public.enforce_change_schedule_activity_records_plan_lock()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_lock_record record;
  v_accepted_status text;
  v_accepted_plan_is_active boolean;
begin
  if TG_OP = 'UPDATE' then
    if NEW.user_id is not distinct from OLD.user_id
       and NEW.plan_version_id is not distinct from OLD.plan_version_id then
      return NEW;
    end if;
  end if;

  for v_lock_record in (
     select distinct plan_pair.user_id, plan_pair.plan_version_id
      from (
        values (NEW.user_id, NEW.plan_version_id)
      ) as plan_pair(user_id, plan_version_id)
     where plan_pair.user_id is not null
       and plan_pair.plan_version_id is not null
     order by plan_pair.user_id, plan_pair.plan_version_id
  ) loop
    select proposal.status
      into v_accepted_status
      from public.change_schedule_proposals as proposal
     where proposal.user_id = v_lock_record.user_id
       and proposal.accepted_plan_version_id = v_lock_record.plan_version_id
     for share;

    if v_accepted_status is not null then
      perform public.acquire_change_schedule_plan_version_lock(
        v_lock_record.user_id,
        v_lock_record.plan_version_id
      );

      select plan.is_active
        into v_accepted_plan_is_active
        from public.plan_versions as plan
       where plan.user_id = v_lock_record.user_id
         and plan.id = v_lock_record.plan_version_id
       for share;

      if v_accepted_status is distinct from 'accepted'
         or v_accepted_plan_is_active is distinct from true then
        raise exception using
          message = 'change_schedule_activity_plan_no_longer_accepted',
          errcode = 'P0001';
      end if;
    end if;
  end loop;

  return NEW;
end;
$function$;

drop trigger if exists change_schedule_activity_records_plan_lock on public.activity_records;
create trigger activity_records_change_schedule_plan_lock
  before insert or update on public.activity_records
  for each row execute function public.enforce_change_schedule_activity_records_plan_lock();

alter table public.change_schedule_proposals
  add column if not exists prior_active_plan_version_id text references public.plan_versions(id) on delete restrict,
  add column if not exists prior_active_availability_version_id text references public.change_schedule_availability_versions(id) on delete restrict,
  add column if not exists accepted_availability_version_id text references public.change_schedule_availability_versions(id) on delete restrict;

alter table public.change_schedule_proposals
  drop constraint if exists change_schedule_proposals_plan_state_check;

alter table public.change_schedule_proposals
  add constraint change_schedule_proposals_plan_state_check
    check (
      (
        status = 'accepted'
        and accepted_plan_version_id is not null
        and scheduled_plan_version_id is null
      )
      or (
        status = 'scheduled'
        and scheduled_plan_version_id is not null
        and accepted_plan_version_id is null
      )
      or (
        status in ('pending', 'expired', 'superseded')
        and accepted_plan_version_id is null
        and scheduled_plan_version_id is null
      )
      or (
        status = 'cancelled'
        and scheduled_plan_version_id is null
      )
    );

create or replace function public.backfill_change_schedule_legacy_accepted_proposal_links()
returns void
language plpgsql
set search_path = ''
as $function$
declare
  v_proposal public.change_schedule_proposals%rowtype;
  v_accepted_availability_id text;
  v_active_availability_count integer;
begin
  for v_proposal in (
    select proposal.*
      from public.change_schedule_proposals as proposal
     where proposal.status = 'accepted'
       and proposal.accepted_plan_version_id is not null
       and (
             proposal.prior_active_plan_version_id is null
             or proposal.accepted_availability_version_id is null
       )
  ) loop
    if v_proposal.prior_active_plan_version_id is null
       and v_proposal.source_plan_version_id is not null then
      update public.change_schedule_proposals
         set prior_active_plan_version_id = v_proposal.source_plan_version_id
       where id = v_proposal.id;
    end if;

    if v_proposal.accepted_availability_version_id is null then
      select count(*)
        into v_active_availability_count
        from public.change_schedule_availability_versions as availability
       where availability.user_id = v_proposal.user_id
         and availability.lifecycle_state = 'active'
         and availability.effective_from = v_proposal.effective_from;

      if v_active_availability_count = 1 then
        select availability.id
          into v_accepted_availability_id
          from public.change_schedule_availability_versions as availability
         where availability.user_id = v_proposal.user_id
           and availability.lifecycle_state = 'active'
           and availability.effective_from = v_proposal.effective_from
         order by availability.updated_at desc
         limit 1;

        update public.change_schedule_proposals
           set accepted_availability_version_id = v_accepted_availability_id
         where id = v_proposal.id;
      end if;
    end if;
  end loop;
end;
$function$;

select public.backfill_change_schedule_legacy_accepted_proposal_links();

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
  v_profile_snapshot_mutation boolean;
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

  if v_reference_mutation then
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

create or replace function public.store_change_schedule_proposal(
  p_user_id uuid,
  p_proposal_id text,
  p_source_plan_version_id text,
  p_candidate_plan jsonb,
  p_impact jsonb,
  p_proposed_availability jsonb,
  p_effective_from date,
  p_created_at timestamptz default now(),
  p_expires_at timestamptz default null,
  p_source_profile_schema_version integer default null,
  p_source_profile_updated_at timestamptz default null
) returns public.change_schedule_proposals
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_source_plan_id text;
  v_source_plan_schema_version integer;
  v_profile_schema_version integer;
  v_profile_updated_at timestamptz;
  v_expires_at timestamptz;
  v_monday date;
  v_proposal public.change_schedule_proposals%rowtype;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  if p_created_at is null then
    raise exception using
      message = 'change_schedule_proposal_invalid_created_at',
      errcode = 'P0001';
  end if;

  if extract(isodow from p_effective_from) <> 1 then
    raise exception using
      message = 'change_schedule_proposal_effective_from_not_monday',
      errcode = 'P0001';
  end if;

  v_monday := pg_catalog.date_trunc('week', p_created_at)::date;
  if p_effective_from < v_monday then
    raise exception using
      message = 'change_schedule_proposal_effective_from_in_past',
      errcode = 'P0001';
  end if;

  select plan.id,
         plan.schema_version
    into v_source_plan_id,
         v_source_plan_schema_version
    from public.plan_versions as plan
   where plan.user_id = p_user_id
     and plan.id = p_source_plan_version_id
     and plan.is_active = true
   for update;

  if v_source_plan_id is null then
    raise exception using
      message = 'change_schedule_proposal_source_plan_not_active',
      errcode = 'P0001';
  end if;

  v_expires_at := coalesce(
    p_expires_at,
    p_created_at + interval '30 minutes'
  );
  if v_expires_at <= p_created_at then
    raise exception using
      message = 'change_schedule_proposal_invalid_expiry',
      errcode = 'P0001';
  end if;

  if p_source_profile_schema_version is null
     or p_source_profile_updated_at is null then
    raise exception using
      message = 'change_schedule_proposal_profile_snapshot_missing',
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
      message = 'change_schedule_proposal_profile_not_found',
      errcode = 'P0001';
  end if;

  if p_source_profile_schema_version is distinct from v_profile_schema_version then
    raise exception using
      message = 'change_schedule_proposal_profile_snapshot_mismatch',
      errcode = 'P0001';
  end if;

  if p_source_profile_updated_at is distinct from v_profile_updated_at then
    raise exception using
      message = 'change_schedule_proposal_profile_snapshot_mismatch',
      errcode = 'P0001';
  end if;

  perform public.validate_change_schedule_availability_payload(
    p_proposed_availability
  );

  update public.change_schedule_proposals
     set status = 'expired'
   where user_id = p_user_id
     and status = 'pending'
     and expires_at <= p_created_at;

  update public.change_schedule_proposals
     set status = 'superseded',
         superseded_at = p_created_at
   where user_id = p_user_id
     and status = 'pending';

  insert into public.change_schedule_proposals (
    id,
    user_id,
    source_plan_version_id,
    source_profile_schema_version,
    source_profile_updated_at,
    proposed_availability,
    candidate_plan,
    impact,
    effective_from,
    status,
    created_at,
    expires_at
  ) values (
    p_proposal_id,
    p_user_id,
    p_source_plan_version_id,
    v_profile_schema_version,
    v_profile_updated_at,
    p_proposed_availability,
    p_candidate_plan,
    p_impact,
    p_effective_from,
    'pending',
    p_created_at,
    v_expires_at
  )
  returning * into v_proposal;

  return v_proposal;
end;
$function$;

revoke all on function public.store_change_schedule_proposal(
  uuid,
  text,
  text,
  jsonb,
  jsonb,
  jsonb,
  date,
  timestamptz,
  timestamptz,
  integer,
  timestamptz
) from public, anon, authenticated;

grant execute on function public.store_change_schedule_proposal(
  uuid,
  text,
  text,
  jsonb,
  jsonb,
  jsonb,
  date,
  timestamptz,
  timestamptz,
  integer,
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
  v_scheduled_activation_id text;
  v_scheduled_candidate_plan_version_id text;
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

  if v_proposal.status <> 'pending' then
    raise exception using
      message = 'change_schedule_proposal_not_pending',
      errcode = 'P0001';
  end if;

  if v_proposal.status = 'expired'
     or v_proposal.expires_at <= v_now then
    raise exception using
      message = 'change_schedule_proposal_expired',
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

  select activation.id,
         activation.queued_candidate_plan_version_id
    into v_scheduled_activation_id,
         v_scheduled_candidate_plan_version_id
    from public.change_schedule_activations as activation
   where activation.user_id = p_user_id
     and activation.status = 'scheduled'
   order by activation.created_at desc
   for update;

  if v_scheduled_activation_id is not null then
    update public.change_schedule_activations
       set status = 'superseded',
           superseded_at = v_now,
           updated_at = v_now
     where user_id = p_user_id
       and id = v_scheduled_activation_id
       and status = 'scheduled';

    update public.change_schedule_proposals
       set status = 'superseded',
           scheduled_plan_version_id = null,
           superseded_at = v_now
     where user_id = p_user_id
       and status = 'scheduled'
       and scheduled_plan_version_id = v_scheduled_candidate_plan_version_id;
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

  update public.change_schedule_availability_versions
     set lifecycle_state = 'superseded',
         updated_at = v_now
   where user_id = p_user_id
     and id = v_prior_active_availability_id
     and lifecycle_state = 'active';

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

create or replace function public.undo_accepted_change_schedule_proposal(
  p_user_id uuid,
  p_proposal_id text,
  p_undone_at timestamptz default now()
) returns table (
  proposal_id text,
  prior_plan_version_id text,
  prior_availability_version_id text,
  restored_plan_version_id text,
  restored_availability_version_id text
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_proposal public.change_schedule_proposals%rowtype;
  v_plan_version_id text;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  if p_undone_at is null then
    raise exception using
      message = 'change_schedule_undo_timestamp_missing',
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
      v_proposal.prior_active_plan_version_id,
      v_proposal.prior_active_availability_version_id,
      v_proposal.accepted_plan_version_id,
      v_proposal.accepted_availability_version_id;
    return;
  end if;

  if v_proposal.status <> 'accepted' then
    raise exception using
      message = 'change_schedule_proposal_not_accepted',
      errcode = 'P0001';
  end if;

  if v_proposal.accepted_plan_version_id is null then
    raise exception using
      message = 'change_schedule_undo_not_available',
      errcode = 'P0001';
  end if;

  perform public.acquire_change_schedule_plan_version_lock(
    v_proposal.user_id,
    v_proposal.accepted_plan_version_id
  );

  select plan.id
    into v_plan_version_id
    from public.plan_versions as plan
   where plan.id = v_proposal.accepted_plan_version_id
     and plan.user_id = p_user_id
     and plan.is_active = true
   for update;

  if v_plan_version_id is null then
    raise exception using
      message = 'change_schedule_undo_plan_not_active',
      errcode = 'P0001';
  end if;

  if v_proposal.prior_active_plan_version_id is null
     or v_proposal.prior_active_availability_version_id is null
     or v_proposal.accepted_availability_version_id is null then
    raise exception using
      message = 'change_schedule_undo_not_available',
      errcode = 'P0001';
  end if;

  if not exists (
    select 1
      from public.plan_versions as plan
     where plan.id = v_proposal.prior_active_plan_version_id
       and plan.user_id = p_user_id
  ) then
    raise exception using
      message = 'change_schedule_undo_not_available',
      errcode = 'P0001';
  end if;

  if not exists (
    select 1
      from public.change_schedule_availability_versions as availability
     where availability.id = v_proposal.prior_active_availability_version_id
       and availability.user_id = p_user_id
  ) then
    raise exception using
      message = 'change_schedule_undo_not_available',
      errcode = 'P0001';
  end if;

  if not exists (
    select 1
      from public.change_schedule_availability_versions as availability
     where availability.id = v_proposal.accepted_availability_version_id
       and availability.user_id = p_user_id
  ) then
    raise exception using
      message = 'change_schedule_undo_not_available',
      errcode = 'P0001';
  end if;

  update public.change_schedule_proposals
     set status = 'superseded',
         superseded_at = p_undone_at
   where user_id = p_user_id
     and status = 'pending'
     and source_plan_version_id = v_proposal.accepted_plan_version_id;

  if exists (
    select 1
      from public.activity_records as activity
     where activity.user_id = p_user_id
       and activity.plan_version_id = v_proposal.accepted_plan_version_id
  ) then
    raise exception using
      message = 'change_schedule_undo_blocked_by_activity',
      errcode = 'P0001';
  end if;

  if v_proposal.prior_active_plan_version_id is not null then
    select id
      into v_plan_version_id
      from public.plan_versions
     where id = v_proposal.prior_active_plan_version_id
       and user_id = p_user_id
     limit 1;

    if v_plan_version_id is null then
      raise exception using
        message = 'change_schedule_undo_prior_plan_missing',
        errcode = 'P0001';
    end if;
  end if;

  update public.plan_versions
     set is_active = false
   where user_id = p_user_id
     and is_active = true;

  if v_proposal.prior_active_plan_version_id is not null then
    update public.plan_versions
       set is_active = true
     where id = v_proposal.prior_active_plan_version_id
       and user_id = p_user_id;
  end if;

  if v_proposal.accepted_availability_version_id is null then
    raise exception using
      message = 'change_schedule_proposal_inconsistent',
      errcode = 'P0001';
  end if;

  update public.change_schedule_availability_versions
     set lifecycle_state = 'cancelled',
         updated_at = p_undone_at
   where id = v_proposal.accepted_availability_version_id
     and user_id = p_user_id;

  update public.change_schedule_availability_versions
     set lifecycle_state = 'active',
         updated_at = p_undone_at
   where id = v_proposal.prior_active_availability_version_id
     and user_id = p_user_id;

  update public.change_schedule_proposals
     set status = 'cancelled',
         cancelled_at = p_undone_at
   where user_id = p_user_id
     and id = p_proposal_id;

  return query
  select
    v_proposal.id,
    v_proposal.prior_active_plan_version_id,
    v_proposal.prior_active_availability_version_id,
    v_proposal.accepted_plan_version_id,
    v_proposal.accepted_availability_version_id;
end;
$function$;

revoke all on function public.undo_accepted_change_schedule_proposal(
  uuid,
  text,
  timestamptz
) from public, anon, authenticated;

grant execute on function public.undo_accepted_change_schedule_proposal(
  uuid,
  text,
  timestamptz
) to service_role;
