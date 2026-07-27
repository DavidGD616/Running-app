create extension if not exists pgtap with schema extensions;

set search_path to public, extensions;

begin;

select no_plan();

insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000001', 'change-schedule-current-main@example.test'),
  ('10000000-0000-0000-0000-000000000002', 'change-schedule-current-stale@example.test'),
  ('10000000-0000-0000-0000-000000000003', 'change-schedule-current-rls@example.test'),
  ('10000000-0000-0000-0000-000000000004', 'change-schedule-current-chain@example.test');

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000001',
    4,
    '2026-07-01 00:00:00+00',
    '{"goal":{"race":"10k"},"marker":"main"}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    1,
    '2026-07-01 00:00:00+00',
    '{"goal":{"race":"5k"},"marker":"stale"}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000003',
    1,
    '2026-07-01 00:00:00+00',
    '{"goal":{"race":"half_marathon"},"marker":"rls"}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000004',
    4,
    '2026-07-01 00:00:00+00',
    '{"goal":{"race":"10k"},"marker":"chain"}'::jsonb
  );

insert into plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
)
values
  (
    'active-source-main',
    '10000000-0000-0000-0000-000000000001',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    4,
    '{"id":"active-source-main","weeks":[{"week":1}]}'::jsonb
  ),
  (
    'active-source-stale',
    '10000000-0000-0000-0000-000000000002',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"active-source-stale","weeks":[{"week":1}]}'::jsonb
  ),
  (
    'active-source-rls',
    '10000000-0000-0000-0000-000000000003',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"active-source-rls","weeks":[{"week":1}]}'::jsonb
  ),
  (
    'active-source-successor-main',
    '10000000-0000-0000-0000-000000000004',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    4,
    '{"id":"active-source-successor-main","weeks":[{"week":1}]}'::jsonb
  );

insert into public.change_schedule_availability_versions (
  id,
  user_id,
  lifecycle_state,
  effective_from,
  target_running_days,
  primary_long_run_weekday,
  same_day_run_strength_preference,
  availability_data
)
values
  (
    'active-availability-main',
    '10000000-0000-0000-0000-000000000001',
    'active',
    '2026-07-13',
    4,
    1,
    'separate_sessions',
    '{
      "days": [
        {"day":1,"available":true},
        {"day":2,"available":true},
        {"day":3,"available":true},
        {"day":4,"available":true},
        {"day":5,"available":false},
        {"day":6,"available":false},
        {"day":7,"available":false}
      ],
      "target_running_days": 4,
      "primary_long_run_weekday": 1,
      "same_day_run_strength_preference": "separate_sessions"
    }'::jsonb
  ),
  (
    'active-availability-rls',
    '10000000-0000-0000-0000-000000000003',
    'active',
    '2026-07-13',
    3,
    1,
    'avoid_same_day',
    '{
      "days": [
        {"day":1,"available":true},
        {"day":2,"available":true},
        {"day":3,"available":true},
        {"day":4,"available":false},
        {"day":5,"available":false},
        {"day":6,"available":false},
        {"day":7,"available":false}
      ],
      "target_running_days": 3,
      "primary_long_run_weekday": 1,
      "same_day_run_strength_preference": "avoid_same_day"
    }'::jsonb
  ),
  (
    'active-availability-successor-main',
    '10000000-0000-0000-0000-000000000004',
    'active',
    '2026-07-13',
    4,
    1,
    'separate_sessions',
    '{
      "days": [
        {"day":1,"available":true},
        {"day":2,"available":true},
        {"day":3,"available":true},
        {"day":4,"available":true},
        {"day":5,"available":false},
        {"day":6,"available":false},
        {"day":7,"available":false}
      ],
      "target_running_days": 4,
      "primary_long_run_weekday": 1,
      "same_day_run_strength_preference": "separate_sessions"
    }'::jsonb
  );

-- Migration-time normalization rewrites legacy same-day preference values.
set local role postgres;
select lives_ok(
  $$
    alter table public.change_schedule_availability_versions
      drop constraint if exists change_schedule_availability_versions_same_day_preference_check;
    alter table public.change_schedule_availability_versions
      disable trigger change_schedule_availability_versions_integrity;
  $$,
  'postgres can temporarily relax legacy normalization fixture constraints'
);

insert into public.change_schedule_availability_versions (
  id,
  user_id,
  lifecycle_state,
  effective_from,
  target_running_days,
  primary_long_run_weekday,
  same_day_run_strength_preference,
  availability_data
)
values
  (
    'legacy-availability-run-first',
    '10000000-0000-0000-0000-000000000001',
    'superseded',
    '2026-07-13',
    4,
    1,
    'run_first',
    '{
      "days": [
        {"day":1,"available":true},
        {"day":2,"available":true},
        {"day":3,"available":true},
        {"day":4,"available":true},
        {"day":5,"available":false},
        {"day":6,"available":false},
        {"day":7,"available":false}
      ],
      "target_running_days": 4,
      "primary_long_run_weekday": 1,
      "same_day_run_strength_preference": "run_first"
    }'::jsonb
  ),
  (
    'legacy-availability-lift-first',
    '10000000-0000-0000-0000-000000000001',
    'superseded',
    '2026-07-13',
    4,
    1,
    'lift_first',
    '{
      "days": [
        {"day":1,"available":true},
        {"day":2,"available":true},
        {"day":3,"available":true},
        {"day":4,"available":true},
        {"day":5,"available":false},
        {"day":6,"available":false},
        {"day":7,"available":false}
      ],
      "target_running_days": 4,
      "primary_long_run_weekday": 1,
      "same_day_run_strength_preference": "lift_first"
    }'::jsonb
  ),
  (
    'legacy-availability-it-depends',
    '10000000-0000-0000-0000-000000000001',
    'superseded',
    '2026-07-13',
    4,
    1,
    'it_depends',
    '{
      "days": [
        {"day":1,"available":true},
        {"day":2,"available":true},
        {"day":3,"available":true},
        {"day":4,"available":true},
        {"day":5,"available":false},
        {"day":6,"available":false},
        {"day":7,"available":false}
      ],
      "target_running_days": 4,
      "primary_long_run_weekday": 1,
      "same_day_run_strength_preference": "it_depends"
    }'::jsonb
  );

select lives_ok(
  $$
    select public.normalize_change_schedule_same_day_preference_data();
  $$,
  'legacy same-day preference values are normalized'
);

select lives_ok(
  $$
    alter table public.change_schedule_availability_versions
      enable trigger change_schedule_availability_versions_integrity;
  $$,
  'row-level integrity trigger is restored after normalization fixture setup'
);

select is(
  (
    select same_day_run_strength_preference
    from public.change_schedule_availability_versions
    where id = 'legacy-availability-run-first'
  ),
  'separate_sessions',
  'legacy run_first column value is normalized'
);
select is(
  (
    select availability_data ->> 'same_day_run_strength_preference'
    from public.change_schedule_availability_versions
    where id = 'legacy-availability-run-first'
  ),
  'separate_sessions',
  'legacy run_first availability payload is normalized'
);
select is(
  (
    select same_day_run_strength_preference
    from public.change_schedule_availability_versions
    where id = 'legacy-availability-lift-first'
  ),
  'separate_sessions',
  'legacy lift_first column value is normalized'
);
select is(
  (
    select availability_data ->> 'same_day_run_strength_preference'
    from public.change_schedule_availability_versions
    where id = 'legacy-availability-lift-first'
  ),
  'separate_sessions',
  'legacy lift_first availability payload is normalized'
);
select is(
  (
    select same_day_run_strength_preference
    from public.change_schedule_availability_versions
    where id = 'legacy-availability-it-depends'
  ),
  'separate_sessions',
  'legacy it_depends column value is normalized'
);
select is(
  (
    select availability_data ->> 'same_day_run_strength_preference'
    from public.change_schedule_availability_versions
    where id = 'legacy-availability-it-depends'
  ),
  'separate_sessions',
  'legacy it_depends availability payload is normalized'
);

select lives_ok(
  $$
    alter table public.change_schedule_availability_versions
      add constraint change_schedule_availability_versions_same_day_preference_check
      check (same_day_run_strength_preference in ('separate_sessions', 'avoid_same_day'))
  $$,
  'same-day preference constraint is restored after normalization fixture'
);

-- Legacy accepted proposals should be backfilled deterministically and remain retry-safe even when undo history is incomplete.
insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000005', 'change-schedule-legacy@example.test');

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000005',
    4,
    '2026-07-01 00:00:00+00',
    '{"goal":{"race":"5k"},"marker":"legacy"}'::jsonb
  );

insert into plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
)
values
  (
    'legacy-source-plan',
    '10000000-0000-0000-0000-000000000005',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    4,
    '{"id":"legacy-source-plan","weeks":[{"week":1}]}'::jsonb
  ),
  (
    'legacy-accepted-plan-restorable',
    '10000000-0000-0000-0000-000000000005',
    '2026-07-13 09:00:00+00',
    'change_schedule',
    false,
    4,
    '{"id":"legacy-accepted-plan-restorable","weeks":[{"week":1}]}'::jsonb
  ),
  (
    'legacy-accepted-plan-unrecoverable',
    '10000000-0000-0000-0000-000000000005',
    '2026-07-13 09:00:00+00',
    'change_schedule',
    false,
    4,
    '{"id":"legacy-accepted-plan-unrecoverable","weeks":[{"week":1}]}'::jsonb
  );

insert into public.change_schedule_availability_versions (
  id,
  user_id,
  lifecycle_state,
  effective_from,
  target_running_days,
  primary_long_run_weekday,
  same_day_run_strength_preference,
  availability_data
)
values
  (
    'legacy-active-availability-main',
    '10000000-0000-0000-0000-000000000005',
    'active',
    '2026-07-13',
    4,
    1,
    'separate_sessions',
    '{
      "days": [
        {"day":1,"available":true},
        {"day":2,"available":true},
        {"day":3,"available":true},
        {"day":4,"available":true},
        {"day":5,"available":false},
        {"day":6,"available":false},
        {"day":7,"available":false}
      ],
      "target_running_days": 4,
      "primary_long_run_weekday": 1,
      "same_day_run_strength_preference": "separate_sessions"
    }'::jsonb
  );

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
  accepted_plan_version_id,
  accepted_at,
  created_at
)
values
  (
    'legacy-proposal-restorable',
    '10000000-0000-0000-0000-000000000005',
    'legacy-source-plan',
    4,
    '2026-07-01 00:00:00+00',
    '{
      "days": [
        {"day":1,"available":true},
        {"day":2,"available":true},
        {"day":3,"available":true},
        {"day":4,"available":true},
        {"day":5,"available":false},
        {"day":6,"available":false},
        {"day":7,"available":false}
      ],
      "target_running_days": 4,
      "primary_long_run_weekday": 1,
      "same_day_run_strength_preference": "separate_sessions"
    }'::jsonb,
    '{"id":"legacy-accepted-plan-restorable","weeks":[{"week":1}]}'::jsonb,
    '{}'::jsonb,
    '2026-07-13',
    'accepted',
    'legacy-accepted-plan-restorable',
    '2026-07-13 09:00:00+00',
    '2026-07-13 09:00:00+00'
  ),
  (
    'legacy-proposal-unrecoverable',
    '10000000-0000-0000-0000-000000000005',
    'legacy-source-plan',
    4,
    '2026-07-01 00:00:00+00',
    '{
      "days": [
        {"day":1,"available":true},
        {"day":2,"available":true},
        {"day":3,"available":true},
        {"day":4,"available":true},
        {"day":5,"available":false},
        {"day":6,"available":false},
        {"day":7,"available":false}
      ],
      "target_running_days": 4,
      "primary_long_run_weekday": 1,
      "same_day_run_strength_preference": "separate_sessions"
    }'::jsonb,
    '{"id":"legacy-accepted-plan-unrecoverable","weeks":[{"week":1}]}'::jsonb,
    '{}'::jsonb,
    '2026-07-20',
    'accepted',
    'legacy-accepted-plan-unrecoverable',
    '2026-07-13 09:00:00+00',
    '2026-07-13 09:00:00+00'
  );

select public.backfill_change_schedule_legacy_accepted_proposal_links();

update public.plan_versions
   set is_active = (id = 'legacy-accepted-plan-unrecoverable')
 where id in (
   'legacy-source-plan',
   'legacy-accepted-plan-restorable',
   'legacy-accepted-plan-unrecoverable'
 );

select is(
  (
    select prior_active_plan_version_id
      from public.change_schedule_proposals
     where id = 'legacy-proposal-restorable'
  ),
  'legacy-source-plan',
  'legacy accepted backfill restores prior active source plan reference'
);
select is(
  (
    select accepted_availability_version_id
      from public.change_schedule_proposals
     where id = 'legacy-proposal-restorable'
  ),
  'legacy-active-availability-main',
  'legacy accepted backfill restores a deterministic accepted availability'
);
select is(
  (
    select accepted_availability_version_id
      from public.change_schedule_proposals
     where id = 'legacy-proposal-unrecoverable'
  ),
  null::text,
  'legacy accepted backfill leaves unavailable availability link unset'
);

select lives_ok(
  $$
    create temporary table change_schedule_accept_legacy_retry as
    select *
      from public.accept_change_schedule_proposal_now(
        '10000000-0000-0000-0000-000000000005',
        'legacy-proposal-unrecoverable',
        'legacy-accepted-plan-unrecoverable',
        'legacy-active-availability-main',
        '2026-07-13 10:00:00+00',
        '2026-07-13 10:00:00+00'
      )
  $$,
  'legacy accepted proposals return known accepted data on idempotent retry'
);

select is(
  (
    select accepted_plan_version_id
      from change_schedule_accept_legacy_retry
  ),
  'legacy-accepted-plan-unrecoverable',
  'legacy idempotent acceptance returns prior accepted plan id'
);
select is(
  (
    select accepted_availability_version_id
      from change_schedule_accept_legacy_retry
  ),
  null::text,
  'legacy idempotent acceptance preserves missing accepted availability history'
);

select throws_ok(
  $$
    select * from public.undo_accepted_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000005',
      'legacy-proposal-unrecoverable',
      '2026-07-13 10:10:00+00'
    )
  $$,
  'P0001',
  'change_schedule_undo_not_available',
  'legacy accepted proposal without full rollback history cannot be undone'
);
select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'legacy-proposal-unrecoverable'
  ),
  'accepted',
  'legacy undo rejection leaves proposal status unchanged'
);
select is(
  (
    select is_active
      from public.plan_versions
     where id = 'legacy-accepted-plan-unrecoverable'
  ),
  true,
  'legacy undo rejection leaves accepted plan state unchanged'
);

set local role service_role;

select ok(
  not has_function_privilege(
    'authenticated',
    'public.store_change_schedule_proposal(uuid,text,text,jsonb,jsonb,jsonb,date,timestamptz,timestamptz,integer,timestamptz)',
    'EXECUTE'
  ),
  'authenticated users cannot execute the proposal storage RPC'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.accept_change_schedule_proposal_now(uuid,text,text,text,timestamptz,timestamptz)',
    'EXECUTE'
  ),
  'authenticated users cannot execute the acceptance RPC'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.undo_accepted_change_schedule_proposal(uuid,text,timestamptz)',
    'EXECUTE'
  ),
  'authenticated users cannot execute the undo RPC'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.store_change_schedule_proposal(uuid,text,text,jsonb,jsonb,jsonb,date,timestamptz,timestamptz,integer,timestamptz)',
    'EXECUTE'
  ),
  'service role can execute the proposal storage RPC'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.accept_change_schedule_proposal_now(uuid,text,text,text,timestamptz,timestamptz)',
    'EXECUTE'
  ),
  'service role can execute the acceptance RPC'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.undo_accepted_change_schedule_proposal(uuid,text,timestamptz)',
    'EXECUTE'
  ),
  'service role can execute the undo RPC'
);
select ok(
  exists(
    select 1
      from pg_trigger as tr
      join pg_class as rel on rel.oid = tr.tgrelid
     where rel.relname = 'activity_records'
       and tr.tgname = 'activity_records_change_schedule_plan_lock'
       and not tr.tgisinternal
  ),
  'activity_records has the deterministic change-schedule plan-lock trigger'
);
select is(
  (
    select tgname
      from (
        select tgname
          from pg_trigger as tr
          join pg_class as rel on rel.oid = tr.tgrelid
         where rel.relname = 'activity_records'
           and not tr.tgisinternal
           and tr.tgname in (
             'activity_records_change_schedule_plan_lock',
             'activity_records_plan_version_integrity'
           )
         order by tgname
      ) as ordered_triggers
     limit 1
  ),
  'activity_records_change_schedule_plan_lock',
  'activity plan-lock trigger runs before plan-version integrity trigger'
);
select ok(
  exists(
    select 1
     from pg_proc as proc
     join pg_namespace as ns on ns.oid = proc.pronamespace
     where ns.nspname = 'public'
       and proc.proname = 'undo_accepted_change_schedule_proposal'
       and pg_get_functiondef(proc.oid) like '%acquire_change_schedule_plan_version_lock%'
  ),
  'undo function acquires plan-version advisory lock for accepted proposals'
);

with undo_fn as (
  select pg_get_functiondef('public.undo_accepted_change_schedule_proposal(uuid,text,timestamptz)'::regprocedure) as source
)
select ok(
  (select source from undo_fn) like '%select proposal.%'
  and (select source from undo_fn) like '%for update;%'
  and (select source from undo_fn) like '%perform public.acquire_change_schedule_plan_version_lock%'
  and position('for update' in (select source from undo_fn))
      < position('perform public.acquire_change_schedule_plan_version_lock' in (select source from undo_fn)),
  'undo proposal lock is taken before plan-version advisory lock'
);

with undo_fn as (
  select pg_get_functiondef('public.undo_accepted_change_schedule_proposal(uuid,text,timestamptz)'::regprocedure) as source
)
select ok(
  (select source from undo_fn) like '%perform pg_catalog.pg_advisory_xact_lock%'
  and (select source from undo_fn) like '%hashtextextended(p_user_id::text, 0)%'
  and position('perform pg_catalog.pg_advisory_xact_lock' in (select source from undo_fn))
      < position('select proposal' in (select source from undo_fn))
  and position('perform pg_catalog.pg_advisory_xact_lock' in (select source from undo_fn))
      < position('perform public.acquire_change_schedule_plan_version_lock' in (select source from undo_fn)),
  'undo acquires per-user advisory lock before proposal and plan locks'
);

with lock_fn as (
  select pg_get_functiondef('public.enforce_change_schedule_activity_records_plan_lock()'::regprocedure) as source
)
select ok(
  (select source from lock_fn) like '%for v_lock_record in (%'
  and (select source from lock_fn) like '%select distinct%'
  and (select source from lock_fn) like '%values (NEW.user_id, NEW.plan_version_id)%'
  and (select source from lock_fn) like '%order by plan_pair.user_id, plan_pair.plan_version_id%',
  'change-schedule activity lock trigger evaluates only NEW attachment candidates in stable order'
);

with lock_fn as (
  select pg_get_functiondef('public.enforce_change_schedule_activity_records_plan_lock()'::regprocedure) as source
)
select ok(
  (select source from lock_fn) like '%if TG_OP = ''UPDATE'' then%'
  and (select source from lock_fn) like '%NEW.user_id is not distinct from OLD.user_id%'
  and (select source from lock_fn) like '%NEW.plan_version_id is not distinct from OLD.plan_version_id%'
  and (select source from lock_fn) like '%return NEW;%',
  'activity-lock trigger bypasses stale-plan checks when attachment pair is unchanged on UPDATE'
);

with lock_fn as (
  select pg_get_functiondef('public.enforce_change_schedule_activity_records_plan_lock()'::regprocedure) as source
)
select ok(
  (select source from lock_fn) like '%order by plan_pair.user_id, plan_pair.plan_version_id%'
  and (select source from lock_fn) like '%for share%'
  and (select source from lock_fn) like '%proposal.accepted_plan_version_id = v_lock_record.plan_version_id%'
  and (select source from lock_fn) like '%v_accepted_status is not null%'
  and (select source from lock_fn) like '%change_schedule_activity_plan_no_longer_accepted%',
  'lock trigger includes proposal lock and accepted-plan status re-check'
);

-- Service role can store a proposal and replace any earlier pending one.
select lives_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000001',
      'proposal-first',
      'active-source-main',
      '{"id":"candidate-plan-first","weeks":[{"week":1}]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":true},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":4,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"separate_sessions"
      }'::jsonb,
      '2026-07-13',
      '2026-07-13 09:00:00+00',
      null,
      4,
      '2026-07-01 00:00:00+00'
    )
  $$,
  'service role stores first pending change-schedule proposal'
);

select lives_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000001',
      'proposal-second',
      'active-source-main',
      '{"id":"candidate-plan-second","weeks":[{"week":1}]}'::jsonb,
      '{"distanceChanged":true}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":true},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":4,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"separate_sessions"
      }'::jsonb,
      '2026-07-13',
      '2026-07-13 09:10:00+00',
      '2026-07-13 09:40:00+00',
      4,
      '2026-07-01 00:00:00+00'
    )
  $$,
  'service role supersedes earlier pending proposal with a newer one'
);

select is(
  (
    select status
    from public.change_schedule_proposals
    where id = 'proposal-first'
  ),
  'superseded',
  'earlier pending proposals are marked superseded when newer proposal arrives'
);
select is(
  (
    select is_active
    from public.plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and id = 'active-source-main'
  ),
  true,
  'precheck: active source plan remains active before stale-source checks'
);
select is(
  (
    select source_plan_version_id
    from public.change_schedule_proposals
    where id = 'proposal-second'
  ),
  'active-source-main',
  'precheck: proposal-second retains active source plan'
);
select is(
  (
    select superseded_at
    from public.change_schedule_proposals
    where id = 'proposal-first'
  ),
  (
    select created_at
    from public.change_schedule_proposals
    where id = 'proposal-second'
  ),
  'superseded proposals carry replacement timestamp'
);
select is(
  (
    select count(*)::integer
    from public.change_schedule_proposals
    where user_id = '10000000-0000-0000-0000-000000000001'
      and status = 'pending'
  ),
  1,
  'only one pending proposal remains per user'
);

select throws_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000002',
      'proposal-stale-profile',
      'active-source-stale',
      '{"id":"candidate-stale","weeks":[]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":false},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":3,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"run_first"
      }'::jsonb,
      '2026-07-13',
      '2026-07-13 09:00:00+00',
      null,
      1,
      '2026-07-01 00:00:00+00'
    )
  $$,
  'P0001',
  'change_schedule_availability_payload_preference_invalid',
  'legacy same-day preference values are rejected by validation'
);

update public.plan_versions
   set is_active = false
 where id = 'active-source-stale';

select throws_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000002',
      'proposal-stale-source',
      'active-source-stale',
      '{"id":"candidate-stale-source","weeks":[]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":true},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":4,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"separate_sessions"
      }'::jsonb,
      '2026-07-13',
      '2026-07-13 09:00:00+00',
      null,
      1,
      '2026-07-01 00:00:00+00'
    )
  $$,
  'P0001',
  'change_schedule_proposal_source_plan_not_active',
  'inactive source plan prevents proposal storage'
);

-- Updating the source plan's profile snapshot after the call-time capture
-- still rejects the stale snapshot.
select throws_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000001',
      'proposal-stale-profile-snapshot',
      'active-source-main',
      '{"id":"candidate-stale-profile","weeks":[{"week":1}]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":true},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":4,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"separate_sessions"
      }'::jsonb,
      '2026-07-13',
      '2026-07-13 09:00:00+00',
      null,
      2,
      '2025-01-01 00:00:00+00'
    )
  $$,
  'P0001',
  'change_schedule_proposal_profile_snapshot_mismatch',
  'stale profile schema and update timestamp reject proposal storage'
);

update public.plan_versions
   set is_active = false
 where id = 'active-source-stale';

select is(
  (
    select count(*)::integer
    from public.change_schedule_proposals
    where id = 'proposal-stale-source'
  ),
  0,
  'failed proposal storage does not insert rows'
);

update public.plan_versions
   set is_active = true
 where id = 'active-source-stale';

select lives_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000002',
      'proposal-no-active-availability',
      'active-source-stale',
      '{"id":"candidate-no-active-availability","weeks":[{"week":1}]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":true},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":4,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"separate_sessions"
      }'::jsonb,
      '2026-07-13',
      '2026-07-13 10:00:00+00',
      '2026-07-13 11:00:00+00',
      1,
      '2026-07-01 00:00:00+00'
    )
  $$,
  'service role stores proposal where user has no active availability'
);

select throws_ok(
  $$
    select public.accept_change_schedule_proposal_now(
      '10000000-0000-0000-0000-000000000002',
      'proposal-no-active-availability',
      'accepted-plan-no-active-avail',
      'accepted-availability-no-active-avail',
      '2026-07-13 10:30:00+00',
      '2026-07-13 10:30:00+00'
    )
  $$,
  'P0001',
  'change_schedule_accept_prior_availability_not_found',
  'acceptance is rejected when user has no active availability'
);

select is(
  (
    select count(*)::integer
    from public.plan_versions
    where id = 'accepted-plan-no-active-avail'
  ),
  0,
  'rejected acceptance does not persist accepted plan version'
);

select throws_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000001',
      'proposal-past-effective',
      'active-source-main',
      '{"id":"candidate-past","weeks":[]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":false},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":3,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"separate_sessions"
      }'::jsonb,
      '2026-07-06',
      '2026-07-13 10:00:00+00',
      null,
      4,
      '2026-07-01 00:00:00+00'
    )
  $$,
  'P0001',
  'change_schedule_proposal_effective_from_in_past',
  'past effective week is rejected'
);

-- Accept a pending proposal and verify activation/rollback links.
select lives_ok(
  $$
    create temporary table change_schedule_accept_response as
    select *
      from public.accept_change_schedule_proposal_now(
        '10000000-0000-0000-0000-000000000001',
        'proposal-second',
        'accepted-plan-main',
        'accepted-availability-main',
        '2026-07-13 09:20:00+00',
        '2026-07-13 09:20:00+00'
      );
  $$,
  'service role accepts a pending change-schedule proposal'
);

select is(
  (select accepted_plan_version_id from change_schedule_accept_response),
  'accepted-plan-main',
  'acceptance returns accepted plan id'
);
select is(
  (select prior_active_plan_version_id from change_schedule_accept_response),
  'active-source-main',
  'acceptance returns prior active plan id'
);
select is(
  (select prior_active_availability_version_id from change_schedule_accept_response),
  'active-availability-main',
  'acceptance returns prior active availability id'
);
select is(
  (select accepted_availability_version_id from change_schedule_accept_response),
  'accepted-availability-main',
  'acceptance returns accepted availability id'
);

select is(
  (
    select is_active
    from public.plan_versions
    where id = 'accepted-plan-main'
  ),
  true,
  'accepted candidate plan is marked active'
);
select is(
  (
    select is_active
    from public.plan_versions
    where id = 'active-source-main'
  ),
  false,
  'prior active source plan is deactivated'
);
select is(
  (
    select lifecycle_state
    from public.change_schedule_availability_versions
    where id = 'active-availability-main'
  ),
  'superseded',
  'prior active availability is superseded on acceptance'
);
select is(
  (
    select lifecycle_state
    from public.change_schedule_availability_versions
    where id = 'accepted-availability-main'
  ),
  'active',
  'accepted availability is active'
);
select is(
  (
    select status
    from public.change_schedule_proposals
    where id = 'proposal-second'
  ),
  'accepted',
  'proposal status updates to accepted'
);

-- Idempotent retry returns same accepted link values and does not write extras.
select is(
  (
    select count(*)::integer
    from public.plan_versions
    where id = 'accepted-plan-main'
  ),
  1,
  'accepted plan row is unique before idempotent retry'
);

select lives_ok(
  $$
    create temporary table change_schedule_accept_retry as
    select *
      from public.accept_change_schedule_proposal_now(
        '10000000-0000-0000-0000-000000000001',
        'proposal-second',
        'accepted-plan-main',
        'accepted-availability-main',
        '2026-07-13 09:30:00+00',
        '2026-07-13 09:30:00+00'
      )
  $$,
  'service role can retry acceptance and receive prior links'
);
select is(
  (select accepted_plan_version_id from change_schedule_accept_retry),
  'accepted-plan-main',
  'acceptance retry reuses accepted plan'
);
select is(
  (select accepted_availability_version_id from change_schedule_accept_retry),
  'accepted-availability-main',
  'acceptance retry reuses accepted availability'
);
select is(
  (
    select count(*)::integer
    from public.plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and id = 'accepted-plan-main'
  ),
  1,
  'idempotent retry does not recreate accepted plan row'
);
select is(
  (
    select count(*)::integer
    from public.plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  2,
  'idempotent retry does not create an additional plan row'
);

-- Accepting a successor proposal invalidates writes to the stale accepted plan while leaving the active successor writable.
select lives_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000004',
      'proposal-snapshot-base',
      'active-source-successor-main',
      '{"id":"accepted-plan-stale-base","weeks":[{"week":1}]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":true},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":4,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"separate_sessions"
      }'::jsonb,
      '2026-07-13',
      '2026-07-13 14:00:00+00',
      null,
      4,
      '2026-07-01 00:00:00+00'
    )
  $$,
  'service role stores base proposal for successor-chain acceptance test'
);

select lives_ok(
  $$
    create temporary table change_schedule_accept_chain_base as
    select *
      from public.accept_change_schedule_proposal_now(
        '10000000-0000-0000-0000-000000000004',
        'proposal-snapshot-base',
        'accepted-plan-stale-base',
        'accepted-availability-stale-base',
        '2026-07-13 14:10:00+00',
        '2026-07-13 14:10:00+00'
      )
  $$,
  'service role accepts base proposal to activate P1 in chain'
);

select lives_ok(
  $$
    insert into public.activity_records (
      id,
      user_id,
      recorded_at,
      data,
      plan_version_id
    )
    values (
      'activity-stale-base-mutable',
      '10000000-0000-0000-0000-000000000004',
      '2026-07-13 14:11:00+00',
      '{"type":"run","state":"captured-while-active"}'::jsonb,
      'accepted-plan-stale-base'
    )
  $$,
  'activity attached to P1 while P1 is active can be created before superseding'
);

select lives_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000004',
      'proposal-snapshot-successor',
      'accepted-plan-stale-base',
      '{"id":"accepted-plan-stale-successor","weeks":[{"week":1}]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":true},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":4,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"separate_sessions"
      }'::jsonb,
      '2026-07-13',
      '2026-07-13 14:20:00+00',
      null,
      4,
      '2026-07-01 00:00:00+00'
    )
  $$,
  'service role stores successor proposal sourced from accepted P1'
);

select lives_ok(
  $$
    create temporary table change_schedule_accept_chain_successor as
    select *
      from public.accept_change_schedule_proposal_now(
        '10000000-0000-0000-0000-000000000004',
        'proposal-snapshot-successor',
        'accepted-plan-stale-successor',
        'accepted-availability-stale-successor',
        '2026-07-13 14:30:00+00',
        '2026-07-13 14:30:00+00'
      )
  $$,
  'service role accepts P2 from accepted P1'
);

select lives_ok(
  $$
    update public.activity_records
       set data = '{"type":"run","state":"edited-after-successor"}'::jsonb
     where id = 'activity-stale-base-mutable'
  $$,
  'metadata-only update on historical activity tied to stale accepted P1 succeeds after P2 supersedes'
);

select lives_ok(
  $$
    update public.activity_records
       set plan_version_id = 'accepted-plan-stale-successor'
     where id = 'activity-stale-base-mutable'
  $$,
  'moving an edited historical activity from stale P1 to active P2 succeeds'
);

select lives_ok(
  $$
    update public.activity_records
       set plan_version_id = null
     where id = 'activity-stale-base-mutable'
  $$,
  'moving an edited historical activity from stale P1 to null succeeds'
);

select throws_ok(
  $$
    insert into public.activity_records (
      id,
      user_id,
      recorded_at,
      data,
      plan_version_id
    )
    values (
      'activity-stale-accepted-rejected',
      '10000000-0000-0000-0000-000000000004',
      '2026-07-13 15:00:00+00',
      '{"type":"run"}'::jsonb,
      'accepted-plan-stale-base'
    )
  $$,
  'P0001',
  'change_schedule_activity_plan_no_longer_accepted',
  'activity writes to stale accepted P1 are rejected after successor acceptance'
);

select lives_ok(
  $$
    insert into public.activity_records (
      id,
      user_id,
      recorded_at,
      data,
      plan_version_id
    )
    values (
      'activity-successor-allowed',
      '10000000-0000-0000-0000-000000000004',
      '2026-07-13 15:00:10+00',
      '{"type":"run"}'::jsonb,
      'accepted-plan-stale-successor'
    )
  $$,
  'activity writes to active successor plan are still allowed'
);

select throws_ok(
  $$
    update public.activity_records
       set plan_version_id = 'accepted-plan-stale-base'
     where id = 'activity-successor-allowed'
  $$,
  'P0001',
  'change_schedule_activity_plan_no_longer_accepted',
  'moving a live activity from active P2 back to stale P1 is still rejected'
);

select lives_ok(
  $$
    insert into public.activity_records (
      id,
      user_id,
      recorded_at,
      data,
      plan_version_id
    )
    values (
      'activity-unrelated-historical-allowed',
      '10000000-0000-0000-0000-000000000004',
      '2026-07-13 15:00:20+00',
      '{"type":"run"}'::jsonb,
      'active-source-successor-main'
    )
  $$,
  'activity writes to unrelated historical plan remain allowed'
);

delete from public.activity_records
 where id in (
   'activity-stale-accepted-rejected',
   'activity-successor-allowed',
   'activity-stale-base-mutable',
   'activity-unrelated-historical-allowed'
 );

-- Undo must fail while accepted plan already has activity records.
insert into public.activity_records (
  id,
  user_id,
  recorded_at,
  data,
  plan_version_id
)
values (
  'activity-blocking-undo',
  '10000000-0000-0000-0000-000000000001',
  '2026-07-13 10:00:00+00',
  '{"type":"run"}'::jsonb,
  'accepted-plan-main'
);

select throws_ok(
  $$
    select * from public.undo_accepted_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000001',
      'proposal-second',
      '2026-07-13 11:00:00+00'
    )
  $$,
  'P0001',
  'change_schedule_undo_blocked_by_activity',
  'undo is blocked while activities exist for accepted plan'
);

delete from public.activity_records
 where id = 'activity-blocking-undo';

select lives_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000001',
      'proposal-from-undone-plan',
      'accepted-plan-main',
      '{"id":"candidate-undone-source","weeks":[{"week":1}]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":true},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":4,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"separate_sessions"
      }'::jsonb,
      '2026-07-13',
      '2026-07-13 11:00:00+00',
      null,
      4,
      '2026-07-01 00:00:00+00'
    )
  $$,
  'service role stores a pending proposal sourced from the accepted plan before undo'
);

select is(
  (select status from public.change_schedule_proposals where id = 'proposal-from-undone-plan'),
  'pending',
  'proposal sourced from the accepted plan is pending before undo'
);

select lives_ok(
  $$
    select * from public.undo_accepted_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000001',
      'proposal-second',
      '2026-07-13 11:00:00+00'
    )
  $$,
  'service role can undo a clean acceptance'
);

select is(
  (
    select status
    from public.change_schedule_proposals
    where id = 'proposal-second'
  ),
  'cancelled',
  'undo marks proposal as cancelled'
);

select is(
  (
    select status
    from public.change_schedule_proposals
    where id = 'proposal-from-undone-plan'
  ),
  'superseded',
  'undo supersedes pending proposals sourced from the reverted accepted plan'
);

select is(
  (
    select superseded_at
    from public.change_schedule_proposals
    where id = 'proposal-from-undone-plan'
  ),
  '2026-07-13 11:00:00+00'::timestamptz,
  'stale pending proposal is terminally superseded by undo'
);
select is(
  (
    select is_active
    from public.plan_versions
    where id = 'active-source-main'
  ),
  true,
  'undo restores prior plan as active'
);
select is(
  (
    select is_active
    from public.plan_versions
    where id = 'accepted-plan-main'
  ),
  false,
  'undo deactivates accepted plan'
);
select lives_ok(
  $$
    insert into public.activity_records (
      id,
      user_id,
      recorded_at,
      data,
      plan_version_id
    )
    values (
      'activity-historical-plan-allowed',
      '10000000-0000-0000-0000-000000000001',
      '2026-07-13 11:30:00+00',
      '{"type":"run"}'::jsonb,
      'active-source-main'
    )
  $$,
  'activity writes to an unrelated historical plan version remain allowed after undo'
);
select throws_ok(
  $$
    insert into public.activity_records (
      id,
      user_id,
      recorded_at,
      data,
      plan_version_id
    )
    values (
      'activity-reverted-plan-rejected',
      '10000000-0000-0000-0000-000000000001',
      '2026-07-13 11:30:10+00',
      '{"type":"run"}'::jsonb,
      'accepted-plan-main'
    )
  $$,
  'P0001',
  'change_schedule_activity_plan_no_longer_accepted',
  'activity writes to a reverted accepted plan are rejected after undo'
);
delete from public.activity_records
 where id in ('activity-historical-plan-allowed', 'activity-reverted-plan-rejected');

select is(
  (
    select lifecycle_state
    from public.change_schedule_availability_versions
    where id = 'active-availability-main'
  ),
  'active',
  'undo restores prior availability'
);
select is(
  (
    select lifecycle_state
    from public.change_schedule_availability_versions
    where id = 'accepted-availability-main'
  ),
  'cancelled',
  'undo marks accepted availability as cancelled'
);

select lives_ok(
  $$
    select * from public.undo_accepted_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000001',
      'proposal-second',
      '2026-07-13 11:05:00+00'
    )
  $$,
  'undo remains idempotent after first execution'
);

select is(
  (
    select count(*)::integer
    from public.plan_versions
    where requested_by = 'change_schedule'
      and user_id = '10000000-0000-0000-0000-000000000001'
  ),
  1,
  'undo leaves no duplicate accepted change-schedule plans'
);

-- Undoing a prior accepted change is blocked once a newer accepted plan is active.
select lives_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000001',
      'proposal-successor-base',
      'active-source-main',
      '{"id":"accepted-plan-successor-base","weeks":[{"week":1}]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":true},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":4,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"separate_sessions"
      }'::jsonb,
      '2026-07-13',
      '2026-07-13 12:00:00+00',
      null,
      4,
      '2026-07-01 00:00:00+00'
    );
  $$,
  'service role stores base proposal for an active successor chain'
);

select lives_ok(
  $$
    create temporary table change_schedule_accept_successor_base as
    select *
      from public.accept_change_schedule_proposal_now(
        '10000000-0000-0000-0000-000000000001',
        'proposal-successor-base',
        'accepted-plan-successor-base',
        'accepted-availability-successor-base',
        '2026-07-13 12:10:00+00',
        '2026-07-13 12:10:00+00'
      );
  $$,
  'service role accepts base proposal in active-successor chain'
);

select is(
  (
    select status
    from public.change_schedule_proposals
    where id = 'proposal-successor-base'
  ),
  'accepted',
  'base proposal is accepted'
);

select lives_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000001',
      'proposal-successor-next',
      'accepted-plan-successor-base',
      '{"id":"accepted-plan-successor-next","weeks":[{"week":1}]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":false},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
      ],
      "target_running_days":3,
      "primary_long_run_weekday":1,
      "same_day_run_strength_preference":"separate_sessions"
    }'::jsonb,
      '2026-07-13',
      '2026-07-13 12:15:00+00',
      null,
      4,
      '2026-07-01 00:00:00+00'
    );
  $$,
  'service role stores successor proposal from the accepted base plan'
);

select lives_ok(
  $$
    create temporary table change_schedule_accept_successor_next as
    select *
      from public.accept_change_schedule_proposal_now(
        '10000000-0000-0000-0000-000000000001',
        'proposal-successor-next',
        'accepted-plan-successor-next',
        'accepted-availability-successor-next',
        '2026-07-13 12:20:00+00',
        '2026-07-13 12:20:00+00'
      );
  $$,
  'service role accepts successor proposal from the accepted base plan'
);

select throws_ok(
  $$
    select * from public.undo_accepted_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000001',
      'proposal-successor-base',
      '2026-07-13 12:30:00+00'
    )
  $$,
  'P0001',
  'change_schedule_undo_plan_not_active',
  'service role rejects undo when accepted plan is no longer active'
);

select is(
  (
    select count(*)::integer
    from public.plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and is_active = true
  ),
  1,
  'undo rejection preserves a single active plan'
);
select is(
  (
    select id
    from public.plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and is_active = true
  ),
  'accepted-plan-successor-next',
  'latest successor plan remains the active plan'
);
select is(
  (
    select lifecycle_state
    from public.change_schedule_availability_versions
    where id = 'accepted-availability-successor-next'
  ),
  'active',
  'latest successor availability remains active'
);
select is(
  (
    select status
    from public.change_schedule_proposals
    where id = 'proposal-successor-base'
  ),
  'accepted',
  'base proposal remains accepted after guarded undo rejection'
);
select is(
  (
    select status
    from public.change_schedule_proposals
    where id = 'proposal-successor-next'
  ),
  'accepted',
  'successor proposal remains accepted after base undo attempt'
);
select is(
  (
    select accepted_plan_version_id
    from public.change_schedule_proposals
    where id = 'proposal-successor-base'
  ),
  'accepted-plan-successor-base',
  'base proposal acceptance target is unchanged'
);

-- Current-week acceptance succeeds when a scheduled future availability already exists.
insert into public.change_schedule_availability_versions (
  id,
  user_id,
  lifecycle_state,
  effective_from,
  target_running_days,
  primary_long_run_weekday,
  same_day_run_strength_preference,
  availability_data
)
values (
  'scheduled-future-conflict-availability',
  '10000000-0000-0000-0000-000000000001',
  'scheduled',
  '2026-07-20',
  4,
  1,
  'separate_sessions',
  '{
    "days": [
      {"day":1,"available":true},
      {"day":2,"available":true},
      {"day":3,"available":true},
      {"day":4,"available":true},
      {"day":5,"available":false},
      {"day":6,"available":false},
      {"day":7,"available":false}
    ],
    "target_running_days": 4,
    "primary_long_run_weekday": 1,
    "same_day_run_strength_preference": "separate_sessions"
  }'::jsonb
);

select lives_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000001',
      'proposal-current-week-future-scheduled-conflict',
      'accepted-plan-successor-next',
      '{"id":"candidate-plan-main-conflict","weeks":[{"week":1}]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":true},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":4,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"separate_sessions"
      }'::jsonb,
      '2026-07-13',
      '2026-07-13 09:00:00+00',
      null,
      4,
      '2026-07-01 00:00:00+00'
    )
  $$,
  'service role stores a pending proposal while a future scheduled availability exists'
);

select lives_ok(
  $$
    create temporary table change_schedule_accept_with_future_schedule as
    select *
      from public.accept_change_schedule_proposal_now(
        '10000000-0000-0000-0000-000000000001',
        'proposal-current-week-future-scheduled-conflict',
        'accepted-plan-main-conflict',
        'accepted-availability-main-conflict',
        '2026-07-13 09:20:00+00',
        '2026-07-13 09:20:00+00'
      );
  $$,
  'service role accepts a pending proposal without clashing with existing future scheduled availability'
);

select is(
  (
    select count(*)::integer
    from public.change_schedule_availability_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and lifecycle_state = 'active'
  ),
  1,
  'current-week acceptance preserves a single active availability'
);

select is(
  (
    select lifecycle_state
    from public.change_schedule_availability_versions
    where id = 'scheduled-future-conflict-availability'
  ),
  'scheduled',
  'future scheduled availability remains scheduled after acceptance'
);

select is(
  (
    select lifecycle_state
    from public.change_schedule_availability_versions
    where id = 'accepted-availability-main-conflict'
  ),
  'active',
  'accepted availability is immediately active'
);

select is(
  (
    select status
    from public.change_schedule_proposals
    where id = 'proposal-current-week-future-scheduled-conflict'
  ),
  'accepted',
  'proposal moves to accepted when current-week acceptance succeeds'
);

-- Immediate acceptance retires scheduled plan lifecycle rows while keeping scheduled availability alive.
insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
)
values (
  'scheduled-candidate-plan-immediate-retire',
  '10000000-0000-0000-0000-000000000003',
  '2026-07-13 09:00:00+00',
  'onboarding',
  false,
  1,
  '{"id":"scheduled-candidate-plan-immediate-retire","weeks":[{"week":1}]}'::jsonb
);

insert into public.change_schedule_availability_versions (
  id,
  user_id,
  lifecycle_state,
  effective_from,
  target_running_days,
  primary_long_run_weekday,
  same_day_run_strength_preference,
  availability_data
)
values (
  'scheduled-availability-immediate-retire',
  '10000000-0000-0000-0000-000000000003',
  'scheduled',
  '2026-07-20',
  4,
  1,
  'separate_sessions',
  '{
    "days": [
      {"day":1,"available":true},
      {"day":2,"available":true},
      {"day":3,"available":true},
      {"day":4,"available":true},
      {"day":5,"available":false},
      {"day":6,"available":false},
      {"day":7,"available":false}
    ],
    "target_running_days": 4,
    "primary_long_run_weekday": 1,
    "same_day_run_strength_preference": "separate_sessions"
  }'::jsonb
);

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
  scheduled_plan_version_id
)
values (
  'proposal-immediate-chain-retire',
  '10000000-0000-0000-0000-000000000003',
  'active-source-rls',
  1,
  '2026-07-01 00:00:00+00',
  '{
    "days": [
      {"day":1,"available":true},
      {"day":2,"available":true},
      {"day":3,"available":true},
      {"day":4,"available":true},
      {"day":5,"available":false},
      {"day":6,"available":false},
      {"day":7,"available":false}
    ],
    "target_running_days": 4,
    "primary_long_run_weekday": 1,
    "same_day_run_strength_preference": "separate_sessions"
  }'::jsonb,
  '{"id":"candidate-scheduled-chain-retire","weeks":[{"week":1}]}'::jsonb,
  '{}'::jsonb,
  '2026-07-20',
  'scheduled',
  'scheduled-candidate-plan-immediate-retire'
);

insert into public.change_schedule_activations (
  id,
  user_id,
  source_plan_version_id,
  queued_candidate_plan_version_id,
  availability_version_id,
  effective_from,
  status
)
values (
  'activation-immediate-retire',
  '10000000-0000-0000-0000-000000000003',
  'active-source-rls',
  'scheduled-candidate-plan-immediate-retire',
  'scheduled-availability-immediate-retire',
  '2026-07-20',
  'scheduled'
);

select lives_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000003',
        'proposal-current-week-now-with-scheduled-chain',
        'active-source-rls',
      '{"id":"candidate-current-week-now-immediate-retire","weeks":[{"week":1}]}'::jsonb,
      '{}'::jsonb,
      '{
        "days":[
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":true},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days":4,
        "primary_long_run_weekday":1,
        "same_day_run_strength_preference":"separate_sessions"
      }'::jsonb,
      '2026-07-13',
        '2026-07-13 09:40:00+00',
        null,
        1,
        '2026-07-01 00:00:00+00'
    )
  $$,
  'service role stores a pending proposal while a scheduled chain is queued'
);

select lives_ok(
  $$
    create temporary table change_schedule_accept_with_scheduled_chain_retire as
    select *
      from public.accept_change_schedule_proposal_now(
        '10000000-0000-0000-0000-000000000003',
        'proposal-current-week-now-with-scheduled-chain',
        'accepted-plan-immediate-retire',
        'accepted-availability-immediate-retire',
        '2026-07-13 09:45:00+00',
        '2026-07-13 09:45:00+00'
      );
  $$,
  'service role accepts pending current-week proposal while retiring scheduled chain'
);

select is(
  (
    select status
    from public.change_schedule_activations
    where id = 'activation-immediate-retire'
  ),
  'superseded',
  'scheduled activation is terminally superseded when current-week acceptance runs'
);

select ok(
  (
    select superseded_at is not null
    from public.change_schedule_activations
    where id = 'activation-immediate-retire'
  ),
  'scheduled activation is timestamped as superseded'
);

select is(
  (
    select status
    from public.change_schedule_proposals
    where id = 'proposal-immediate-chain-retire'
  ),
  'superseded',
  'linked scheduled proposal is terminally superseded'
);

select is(
  (
    select scheduled_plan_version_id
    from public.change_schedule_proposals
    where id = 'proposal-immediate-chain-retire'
  ),
  null::text,
  'linked scheduled proposal clears scheduled plan reference'
);

select is(
  (
    select lifecycle_state
    from public.change_schedule_availability_versions
    where id = 'scheduled-availability-immediate-retire'
  ),
  'scheduled',
  'scheduled availability remains scheduled after current-week acceptance'
);

select is(
    (
    select count(*)::integer
    from public.change_schedule_activations
    where user_id = '10000000-0000-0000-0000-000000000003'
      and status = 'scheduled'
  ),
  0,
  'scheduled activations are retired after immediate acceptance'
);

select is(
  (
    select is_active
    from public.plan_versions
    where id = 'active-source-rls'
  ),
  false,
  'source plan is deactivated during current-week acceptance'
);

select is(
  (
    select is_active
    from public.plan_versions
    where id = 'accepted-plan-immediate-retire'
  ),
  true,
  'newly accepted plan is active after immediate acceptance'
);

-- RLS remains owner-scoped.
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-000000000003', true);
select throws_ok(
  $$
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
      status
    ) values (
      'rls-forbidden-proposal',
      '10000000-0000-0000-0000-000000000003',
      'active-source-rls',
      1,
      '2026-07-01 00:00:00+00',
      '{
        "days": [
          {"day":1,"available":true},
          {"day":2,"available":true},
          {"day":3,"available":true},
          {"day":4,"available":false},
          {"day":5,"available":false},
          {"day":6,"available":false},
          {"day":7,"available":false}
        ],
        "target_running_days": 3,
        "primary_long_run_weekday": 1,
        "same_day_run_strength_preference": "separate_sessions"
      }'::jsonb,
      '{"id":"rls-candidate","weeks":[]}'::jsonb,
      '{}'::jsonb,
      '2026-07-20',
      'pending'
    )
  $$,
  '42501',
  'permission denied for table change_schedule_proposals',
  'authenticated users cannot mutate service-owned proposal rows'
);
reset role;

select * from finish();

rollback;
