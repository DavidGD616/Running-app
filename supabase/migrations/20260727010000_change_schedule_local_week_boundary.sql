-- Change Schedule dates are selected in the runner's calendar, not the
-- database session's calendar. Keep the legacy timestamp-derived week only
-- while older clients omit p_local_date during the rollout.
--
-- Each lifecycle function below is copied from the already-applied function
-- definition before its old identity is dropped. That preserves the audited
-- transactional, locking, idempotency, RLS, and lineage behavior while making
-- the bounded local-week substitution explicit. A static CREATE OR REPLACE
-- cannot change an input signature, so this also prevents competing overloads.

do $migration$
declare
  v_old_definition text;
  v_returns_position integer;
  v_old_assignment constant text := $old$
  v_monday := pg_catalog.date_trunc('week', p_created_at)::date;
$old$;
  v_new_assignment constant text := $new$
  v_monday := case
    when p_local_date is null then pg_catalog.date_trunc('week', p_created_at)::date
    else p_local_date - (extract(isodow from p_local_date)::integer - 1)
  end;
$new$;
  v_old_check constant text := $old$
  if p_effective_from < v_monday then
$old$;
  v_new_check constant text := $new$
  if (
    p_local_date is null
    and p_effective_from < v_monday
  ) or (
    p_local_date is not null
    and p_effective_from is distinct from v_monday
    and p_effective_from is distinct from (v_monday + 7)
  ) then
$new$;
begin
  if pg_catalog.to_regprocedure(
    'public.store_change_schedule_proposal(uuid,text,text,jsonb,jsonb,jsonb,date,timestamptz,timestamptz,integer,timestamptz)'
  ) is not null then
    select pg_catalog.pg_get_functiondef(
      'public.store_change_schedule_proposal(uuid,text,text,jsonb,jsonb,jsonb,date,timestamptz,timestamptz,integer,timestamptz)'::regprocedure
    ) into v_old_definition;

    v_returns_position := position('RETURNS ' in v_old_definition);
    if v_returns_position = 0
       or position(v_old_assignment in v_old_definition) = 0
       or position(v_old_check in v_old_definition) = 0 then
      raise exception 'change_schedule_local_week_store_definition_unexpected';
    end if;

    v_old_definition := replace(
      v_old_definition,
      v_old_assignment,
      v_new_assignment
    );
    v_old_definition := replace(
      v_old_definition,
      v_old_check,
      v_new_check
    );
    v_old_definition :=
      'CREATE OR REPLACE FUNCTION public.store_change_schedule_proposal(' || E'\n'
      || '  p_user_id uuid,' || E'\n'
      || '  p_proposal_id text,' || E'\n'
      || '  p_source_plan_version_id text,' || E'\n'
      || '  p_candidate_plan jsonb,' || E'\n'
      || '  p_impact jsonb,' || E'\n'
      || '  p_proposed_availability jsonb,' || E'\n'
      || '  p_effective_from date,' || E'\n'
      || '  p_created_at timestamptz default now(),' || E'\n'
      || '  p_expires_at timestamptz default null,' || E'\n'
      || '  p_source_profile_schema_version integer default null,' || E'\n'
      || '  p_source_profile_updated_at timestamptz default null,' || E'\n'
      || '  p_local_date date default null' || E'\n'
      || ')' || E'\n'
      || substring(v_old_definition from v_returns_position);

    execute 'drop function public.store_change_schedule_proposal(uuid,text,text,jsonb,jsonb,jsonb,date,timestamptz,timestamptz,integer,timestamptz)';
    execute v_old_definition;
  elsif pg_catalog.to_regprocedure(
    'public.store_change_schedule_proposal(uuid,text,text,jsonb,jsonb,jsonb,date,timestamptz,timestamptz,integer,timestamptz,date)'
  ) is null then
    raise exception 'change_schedule_local_week_store_function_missing';
  end if;
end;
$migration$;

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
  timestamptz,
  date
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
  timestamptz,
  date
) to service_role;

do $migration$
declare
  v_old_definition text;
  v_returns_position integer;
  v_old_assignment constant text := $old$
  v_current_week := pg_catalog.date_trunc('week', v_now)::date;
$old$;
  v_new_assignment constant text := $new$
  v_current_week := case
    when p_local_date is null then pg_catalog.date_trunc('week', v_now)::date
    else p_local_date - (extract(isodow from p_local_date)::integer - 1)
  end;
$new$;
begin
  if pg_catalog.to_regprocedure(
    'public.accept_change_schedule_proposal_now(uuid,text,text,text,timestamptz,timestamptz)'
  ) is not null then
    select pg_catalog.pg_get_functiondef(
      'public.accept_change_schedule_proposal_now(uuid,text,text,text,timestamptz,timestamptz)'::regprocedure
    ) into v_old_definition;

    v_returns_position := position('RETURNS ' in v_old_definition);
    if v_returns_position = 0
       or position(v_old_assignment in v_old_definition) = 0 then
      raise exception 'change_schedule_local_week_accept_definition_unexpected';
    end if;

    v_old_definition := replace(
      v_old_definition,
      v_old_assignment,
      v_new_assignment
    );
    v_old_definition :=
      'CREATE OR REPLACE FUNCTION public.accept_change_schedule_proposal_now(' || E'\n'
      || '  p_user_id uuid,' || E'\n'
      || '  p_proposal_id text,' || E'\n'
      || '  p_plan_version_id text,' || E'\n'
      || '  p_availability_version_id text,' || E'\n'
      || '  p_generated_at timestamptz default now(),' || E'\n'
      || '  p_accepted_at timestamptz default now(),' || E'\n'
      || '  p_local_date date default null' || E'\n'
      || ')' || E'\n'
      || substring(v_old_definition from v_returns_position);

    execute 'drop function public.accept_change_schedule_proposal_now(uuid,text,text,text,timestamptz,timestamptz)';
    execute v_old_definition;
  elsif pg_catalog.to_regprocedure(
    'public.accept_change_schedule_proposal_now(uuid,text,text,text,timestamptz,timestamptz,date)'
  ) is null then
    raise exception 'change_schedule_local_week_accept_function_missing';
  end if;
end;
$migration$;

revoke all on function public.accept_change_schedule_proposal_now(
  uuid,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  date
) from public, anon, authenticated;

grant execute on function public.accept_change_schedule_proposal_now(
  uuid,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  date
) to service_role;

do $migration$
declare
  v_old_definition text;
  v_returns_position integer;
  v_old_assignment constant text := $old$
  v_current_week := pg_catalog.date_trunc('week', v_now)::date;
$old$;
  v_new_assignment constant text := $new$
  v_current_week := case
    when p_local_date is null then pg_catalog.date_trunc('week', v_now)::date
    else p_local_date - (extract(isodow from p_local_date)::integer - 1)
  end;
$new$;
  v_old_check constant text := $old$
  if v_proposal.effective_from <= v_current_week then
$old$;
  v_new_check constant text := $new$
  if (
    p_local_date is null
    and v_proposal.effective_from <= v_current_week
  ) or (
    p_local_date is not null
    and v_proposal.effective_from is distinct from (v_current_week + 7)
  ) then
$new$;
begin
  if pg_catalog.to_regprocedure(
    'public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz)'
  ) is not null then
    select pg_catalog.pg_get_functiondef(
      'public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz)'::regprocedure
    ) into v_old_definition;

    v_returns_position := position('RETURNS ' in v_old_definition);
    if v_returns_position = 0
       or position(v_old_assignment in v_old_definition) = 0
       or position(v_old_check in v_old_definition) = 0 then
      raise exception 'change_schedule_local_week_schedule_definition_unexpected';
    end if;

    v_old_definition := replace(
      v_old_definition,
      v_old_assignment,
      v_new_assignment
    );
    v_old_definition := replace(
      v_old_definition,
      v_old_check,
      v_new_check
    );
    v_old_definition :=
      'CREATE OR REPLACE FUNCTION public.schedule_change_schedule_proposal(' || E'\n'
      || '  p_user_id uuid,' || E'\n'
      || '  p_proposal_id text,' || E'\n'
      || '  p_plan_version_id text,' || E'\n'
      || '  p_availability_version_id text,' || E'\n'
      || '  p_scheduled_at timestamptz default now(),' || E'\n'
      || '  p_local_date date default null' || E'\n'
      || ')' || E'\n'
      || substring(v_old_definition from v_returns_position);

    execute 'drop function public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz)';
    execute v_old_definition;
  elsif pg_catalog.to_regprocedure(
    'public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz,date)'
  ) is null then
    raise exception 'change_schedule_local_week_schedule_function_missing';
  end if;
end;
$migration$;

revoke all on function public.schedule_change_schedule_proposal(
  uuid,
  text,
  text,
  text,
  timestamptz,
  date
) from public, anon, authenticated;

grant execute on function public.schedule_change_schedule_proposal(
  uuid,
  text,
  text,
  text,
  timestamptz,
  date
) to service_role;

do $migration$
declare
  v_old_definition text;
  v_returns_position integer;
  v_old_assignment constant text := $old$
  v_current_week := pg_catalog.date_trunc('week', v_now)::date;
$old$;
  v_new_assignment constant text := $new$
  v_current_week := case
    when p_local_date is null then pg_catalog.date_trunc('week', v_now)::date
    else p_local_date - (extract(isodow from p_local_date)::integer - 1)
  end;
$new$;
begin
  if pg_catalog.to_regprocedure(
    'public.activate_due_change_schedule(uuid,text,timestamptz)'
  ) is not null then
    select pg_catalog.pg_get_functiondef(
      'public.activate_due_change_schedule(uuid,text,timestamptz)'::regprocedure
    ) into v_old_definition;

    v_returns_position := position('RETURNS ' in v_old_definition);
    if v_returns_position = 0
       or position(v_old_assignment in v_old_definition) = 0 then
      raise exception 'change_schedule_local_week_activate_definition_unexpected';
    end if;

    v_old_definition := replace(
      v_old_definition,
      v_old_assignment,
      v_new_assignment
    );
    v_old_definition :=
      'CREATE OR REPLACE FUNCTION public.activate_due_change_schedule(' || E'\n'
      || '  p_user_id uuid,' || E'\n'
      || '  p_activation_id text,' || E'\n'
      || '  p_activated_at timestamptz default now(),' || E'\n'
      || '  p_local_date date default null' || E'\n'
      || ')' || E'\n'
      || substring(v_old_definition from v_returns_position);

    execute 'drop function public.activate_due_change_schedule(uuid,text,timestamptz)';
    execute v_old_definition;
  elsif pg_catalog.to_regprocedure(
    'public.activate_due_change_schedule(uuid,text,timestamptz,date)'
  ) is null then
    raise exception 'change_schedule_local_week_activate_function_missing';
  end if;
end;
$migration$;

revoke all on function public.activate_due_change_schedule(
  uuid,
  text,
  timestamptz,
  date
) from public, anon, authenticated;

grant execute on function public.activate_due_change_schedule(
  uuid,
  text,
  timestamptz,
  date
) to service_role;
