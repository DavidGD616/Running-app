create table if not exists public.change_schedule_availability_versions (
  id                         text primary key,
  user_id                    uuid references auth.users(id) on delete cascade not null,
  lifecycle_state            text not null default 'scheduled',
  effective_from             date not null,
  target_running_days        integer not null,
  primary_long_run_weekday    integer not null,
  backup_long_run_weekday    integer,
  same_day_run_strength_preference text not null,
  availability_data          jsonb not null default '{}'::jsonb,
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now(),
  constraint change_schedule_availability_versions_lifecycle_state_check
    check (lifecycle_state in ('active', 'scheduled', 'superseded', 'cancelled')),
  constraint change_schedule_availability_versions_target_running_days_check
    check (target_running_days between 1 and 7),
  constraint change_schedule_availability_versions_primary_weekday_check
    check (primary_long_run_weekday between 1 and 7),
  constraint change_schedule_availability_versions_backup_weekday_check
    check (backup_long_run_weekday is null or backup_long_run_weekday between 1 and 7),
  constraint change_schedule_availability_versions_weekday_distinct_check
    check (backup_long_run_weekday is distinct from primary_long_run_weekday),
  constraint change_schedule_availability_versions_same_day_preference_check
    check (
      same_day_run_strength_preference in
        ('run_first', 'lift_first', 'separate_sessions', 'it_depends')
    ),
  constraint change_schedule_availability_versions_data_object_check
    check (jsonb_typeof(availability_data) = 'object'),
  constraint change_schedule_availability_versions_monday_check
    check (extract(isodow from effective_from) = 1)
);

create index if not exists change_schedule_availability_versions_user_state
  on public.change_schedule_availability_versions (user_id, lifecycle_state, effective_from desc);

create index if not exists change_schedule_availability_versions_user_effective
  on public.change_schedule_availability_versions (user_id, effective_from desc);

create unique index if not exists change_schedule_availability_versions_one_active_per_user
  on public.change_schedule_availability_versions (user_id)
  where lifecycle_state = 'active';

create unique index if not exists change_schedule_availability_versions_one_scheduled_per_user
  on public.change_schedule_availability_versions (user_id)
  where lifecycle_state = 'scheduled';

alter table public.change_schedule_availability_versions enable row level security;

drop policy if exists "Users manage own schedule availability versions"
  on public.change_schedule_availability_versions;

create policy "Users manage own schedule availability versions"
  on public.change_schedule_availability_versions
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on table public.change_schedule_availability_versions from public, anon;
grant select, insert, update, delete on table public.change_schedule_availability_versions to authenticated;
grant all on table public.change_schedule_availability_versions to service_role;

create table if not exists public.change_schedule_drafts (
  user_id                uuid references auth.users(id) on delete cascade primary key,
  source_plan_version_id text references public.plan_versions(id) on delete cascade not null,
  proposed_availability  jsonb not null default '{}'::jsonb,
  status                 text not null default 'editing',
  revision               integer not null default 1,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint change_schedule_drafts_status_check
    check (status in ('editing', 'assessment_pending', 'proposal_ready')),
  constraint change_schedule_drafts_revision_check
    check (revision > 0),
  constraint change_schedule_drafts_availability_object_check
    check (jsonb_typeof(proposed_availability) = 'object')
);

create index if not exists change_schedule_drafts_updated
  on public.change_schedule_drafts (updated_at desc);

alter table public.change_schedule_drafts enable row level security;

drop policy if exists "Users manage own change schedule draft"
  on public.change_schedule_drafts;

create policy "Users manage own change schedule draft"
  on public.change_schedule_drafts
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on table public.change_schedule_drafts from public, anon;
grant select, insert, update, delete on table public.change_schedule_drafts to authenticated;
grant all on table public.change_schedule_drafts to service_role;

create table if not exists public.change_schedule_proposals (
  id                           text primary key,
  user_id                      uuid references auth.users(id) on delete cascade not null,
  source_plan_version_id       text references public.plan_versions(id) on delete cascade not null,
  source_profile_schema_version integer not null,
  source_profile_updated_at     timestamptz not null,
  proposed_availability        jsonb not null default '{}'::jsonb,
  candidate_plan               jsonb not null,
  impact                       jsonb not null default '{}'::jsonb,
  effective_from               date not null,
  status                       text not null default 'pending',
  created_at                   timestamptz not null default now(),
  updated_at                   timestamptz not null default now(),
  expires_at                   timestamptz not null default (now() + interval '30 minutes'),
  accepted_plan_version_id      text references public.plan_versions(id) on delete restrict,
  scheduled_plan_version_id     text references public.plan_versions(id) on delete restrict,
  accepted_at                  timestamptz,
  superseded_at                timestamptz,
  cancelled_at                 timestamptz,
  constraint change_schedule_proposals_status_check
    check (status in ('pending', 'accepted', 'scheduled', 'expired', 'superseded', 'cancelled')),
  constraint change_schedule_proposals_candidate_plan_object_check
    check (jsonb_typeof(candidate_plan) = 'object'),
  constraint change_schedule_proposals_impact_object_check
    check (jsonb_typeof(impact) = 'object'),
  constraint change_schedule_proposals_availability_object_check
    check (jsonb_typeof(proposed_availability) = 'object'),
  constraint change_schedule_proposals_effective_from_monday_check
    check (extract(isodow from effective_from) = 1),
  constraint change_schedule_proposals_expiry_check
    check (expires_at > created_at),
  constraint change_schedule_proposals_plan_state_check
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
        status not in ('accepted', 'scheduled')
        and accepted_plan_version_id is null
        and scheduled_plan_version_id is null
      )
    )
);

create index if not exists change_schedule_proposals_user_created
  on public.change_schedule_proposals (user_id, created_at desc);

create index if not exists change_schedule_proposals_user_status
  on public.change_schedule_proposals (user_id, status);

create unique index if not exists change_schedule_proposals_one_pending_per_user
  on public.change_schedule_proposals (user_id)
  where status = 'pending';

create unique index if not exists change_schedule_proposals_one_accepted_plan_per_user
  on public.change_schedule_proposals (accepted_plan_version_id)
  where accepted_plan_version_id is not null;

create unique index if not exists change_schedule_proposals_one_scheduled_plan_per_user
  on public.change_schedule_proposals (scheduled_plan_version_id)
  where scheduled_plan_version_id is not null;

alter table public.change_schedule_proposals enable row level security;

drop policy if exists "Users view own change schedule proposals"
  on public.change_schedule_proposals;

create policy "Users view own change schedule proposals"
  on public.change_schedule_proposals
  for select
  using ((select auth.uid()) = user_id);

revoke all on table public.change_schedule_proposals from public, anon, authenticated;
grant select on table public.change_schedule_proposals to authenticated;
grant all on table public.change_schedule_proposals to service_role;

create table if not exists public.change_schedule_activations (
  id                             text primary key,
  user_id                        uuid references auth.users(id) on delete cascade not null,
  source_plan_version_id          text references public.plan_versions(id) on delete cascade not null,
  queued_candidate_plan_version_id text references public.plan_versions(id) on delete restrict not null,
  availability_version_id         text references public.change_schedule_availability_versions(id) on delete restrict not null,
  effective_from                 date not null,
  status                         text not null default 'scheduled',
  created_at                     timestamptz not null default now(),
  updated_at                     timestamptz not null default now(),
  activated_at                   timestamptz,
  cancelled_at                   timestamptz,
  stale_at                       timestamptz,
  superseded_at                  timestamptz,
  constraint change_schedule_activations_status_check
    check (status in ('scheduled', 'activated', 'cancelled', 'stale', 'superseded')),
  constraint change_schedule_activations_effective_from_monday_check
    check (extract(isodow from effective_from) = 1),
  constraint change_schedule_activations_status_timing_check
    check (
      (
        status = 'scheduled'
        and activated_at is null
        and cancelled_at is null
        and stale_at is null
        and superseded_at is null
      )
      or (
        status = 'activated'
        and activated_at is not null
        and cancelled_at is null
        and stale_at is null
        and superseded_at is null
      )
      or (
        status = 'cancelled'
        and cancelled_at is not null
        and activated_at is null
        and stale_at is null
        and superseded_at is null
      )
      or (
        status = 'stale'
        and stale_at is not null
        and activated_at is null
        and cancelled_at is null
        and superseded_at is null
      )
      or (
        status = 'superseded'
        and superseded_at is not null
        and activated_at is null
        and cancelled_at is null
        and stale_at is null
      )
    )
);

create index if not exists change_schedule_activations_user_created
  on public.change_schedule_activations (user_id, created_at desc);

create index if not exists change_schedule_activations_user_status
  on public.change_schedule_activations (user_id, status);

create unique index if not exists change_schedule_activations_one_scheduled_per_user
  on public.change_schedule_activations (user_id)
  where status = 'scheduled';

alter table public.change_schedule_activations enable row level security;

drop policy if exists "Users view own change schedule activations"
  on public.change_schedule_activations;

create policy "Users view own change schedule activations"
  on public.change_schedule_activations
  for select
  using ((select auth.uid()) = user_id);

revoke all on table public.change_schedule_activations from public, anon, authenticated;
grant select on table public.change_schedule_activations to authenticated;
grant all on table public.change_schedule_activations to service_role;

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
        message = 'change_schedule_availability_payload_day_out_of_range',
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
    'run_first',
    'lift_first',
    'separate_sessions',
    'it_depends'
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

create or replace function public.enforce_change_schedule_availability_version_integrity()
returns trigger
language plpgsql
as $function$
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and auth.uid() is distinct from NEW.user_id then
    raise exception using
      message = 'insufficient_privilege',
      errcode = '42501';
  end if;

  perform public.validate_change_schedule_availability_payload(
    NEW.availability_data,
    NEW.target_running_days,
    NEW.primary_long_run_weekday,
    NEW.backup_long_run_weekday,
    NEW.same_day_run_strength_preference
  );

  NEW.updated_at := now();
  return NEW;
end;
$function$;

drop trigger if exists change_schedule_availability_versions_integrity on public.change_schedule_availability_versions;
create trigger change_schedule_availability_versions_integrity
  before insert or update on public.change_schedule_availability_versions
  for each row execute function public.enforce_change_schedule_availability_version_integrity();

create or replace function public.enforce_change_schedule_draft_integrity()
returns trigger
language plpgsql
as $function$
begin
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
       and plan.is_active = true
  ) then
    raise exception using
      message = 'change_schedule_draft_source_plan_not_active',
      errcode = 'P0001';
  end if;

  perform public.validate_change_schedule_availability_payload(NEW.proposed_availability);

  NEW.updated_at := now();
  return NEW;
end;
$function$;

drop trigger if exists change_schedule_drafts_integrity on public.change_schedule_drafts;
create trigger change_schedule_drafts_integrity
  before insert or update on public.change_schedule_drafts
  for each row execute function public.enforce_change_schedule_draft_integrity();

create or replace function public.enforce_change_schedule_proposal_integrity()
returns trigger
language plpgsql
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
      or NEW.accepted_plan_version_id is distinct from OLD.accepted_plan_version_id;
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

create or replace function public.enforce_change_schedule_activation_integrity()
returns trigger
language plpgsql
as $function$
declare
  v_reference_mutation boolean;
  v_requires_scheduled_check boolean;
  v_requires_activated_check boolean;
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

  NEW.updated_at := now();
  return NEW;
end;
$function$;

drop trigger if exists change_schedule_activations_integrity on public.change_schedule_activations;
create trigger change_schedule_activations_integrity
  before insert or update on public.change_schedule_activations
  for each row execute function public.enforce_change_schedule_activation_integrity();

create or replace function public.enforce_activity_record_plan_version_integrity()
returns trigger
language plpgsql
as $function$
declare
  v_plan_version_mutation boolean;
begin
  v_plan_version_mutation := TG_OP = 'INSERT';

  if TG_OP = 'UPDATE' then
    v_plan_version_mutation :=
      NEW.plan_version_id is distinct from OLD.plan_version_id
      or NEW.user_id is distinct from OLD.user_id;
  end if;

  if not v_plan_version_mutation then
    return NEW;
  end if;

  if NEW.plan_version_id is not null
     and not exists (
       select 1
         from public.plan_versions as plan
        where plan.id = NEW.plan_version_id
          and plan.user_id = NEW.user_id
     ) then
    raise exception using
      message = 'activity_record_plan_version_not_owned',
      errcode = 'P0001';
  end if;

  return NEW;
end;
$function$;

drop trigger if exists activity_records_plan_version_integrity on public.activity_records;
create trigger activity_records_plan_version_integrity
  before insert or update on public.activity_records
  for each row execute function public.enforce_activity_record_plan_version_integrity();

alter table public.activity_records
  add column if not exists plan_version_id text references public.plan_versions(id) on delete set null;

create index if not exists activity_records_user_plan_version
  on public.activity_records (user_id, plan_version_id);
