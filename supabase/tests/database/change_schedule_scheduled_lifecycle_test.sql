create extension if not exists pgtap with schema extensions;

set search_path to public, extensions;

begin;

select no_plan();

insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000002', 'change-schedule-peer-scheduled@example.test'),
  ('10000000-0000-0000-0000-000000000011', 'change-schedule-scheduled-main@example.test'),
  ('10000000-0000-0000-0000-000000000012', 'change-schedule-activated-main@example.test'),
  ('10000000-0000-0000-0000-000000000013', 'change-schedule-stale-source@example.test'),
  ('10000000-0000-0000-0000-000000000014', 'change-schedule-stale-profile@example.test'),
  ('10000000-0000-0000-0000-000000000015', 'change-schedule-guard@example.test');

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000002',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"5k"}}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000011',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000012',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"half_marathon"}}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000013',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"marathon"}}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000014',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"5k"}}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000015',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
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
    'scheduled-user1-active-plan',
    '10000000-0000-0000-0000-000000000011',
    '2026-07-20 08:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"scheduled-user1-active-plan","weeks":[]}'::jsonb
  ),
  (
    'activated-user2-active-plan',
    '10000000-0000-0000-0000-000000000012',
    '2026-07-20 08:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"activated-user2-active-plan","weeks":[]}'::jsonb
  ),
  (
    'scheduled-user3-active-plan',
    '10000000-0000-0000-0000-000000000013',
    '2026-07-20 08:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"scheduled-user3-active-plan","weeks":[]}'::jsonb
  ),
  (
    'scheduled-user4-active-plan',
    '10000000-0000-0000-0000-000000000014',
    '2026-07-20 08:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"scheduled-user4-active-plan","weeks":[]}'::jsonb
  ),
  (
    'guard-user5-active-plan',
    '10000000-0000-0000-0000-000000000015',
    '2026-07-20 08:30:00+00',
    'onboarding',
    true,
    1,
    '{"id":"guard-user5-active-plan","weeks":[]}'::jsonb
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
    'active-avail-user1',
    '10000000-0000-0000-0000-000000000011',
    'active',
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
  ),
  (
    'active-avail-user2',
    '10000000-0000-0000-0000-000000000012',
    'active',
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
  ),
  (
    'active-avail-user3',
    '10000000-0000-0000-0000-000000000013',
    'active',
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
  ),
  (
    'active-avail-user4',
    '10000000-0000-0000-0000-000000000014',
    'active',
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

select ok(
  to_regprocedure('public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz)') is not null,
  'scheduled change schedule proposal RPC uses exact signature'
);
select col_type_is('public', 'change_schedule_activations', 'prior_active_plan_version_id', 'text', 'activation prior active plan snapshot is text');
select col_type_is('public', 'change_schedule_activations', 'prior_active_availability_version_id', 'text', 'activation prior active availability snapshot is text');
select ok(
  to_regprocedure('public.cancel_scheduled_change_schedule_proposal(uuid,text,timestamptz)') is not null,
  'scheduled change schedule cancellation RPC uses exact signature'
);
select ok(
  to_regprocedure('public.activate_due_change_schedule(uuid,text,timestamptz)') is not null,
  'scheduled change schedule due-activation RPC uses exact signature'
);

select is(
  (
    select prosecdef
      from pg_proc p
     where p.oid = to_regprocedure('public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz)')
  ),
  true,
  'schedule RPC is SECURITY DEFINER'
);
select ok(
  exists(
    select 1
      from unnest(
        (
          select proconfig
            from pg_proc p
           where p.oid = to_regprocedure('public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz)')
        )
      ) as cfg
     where cfg like 'search_path=%'
  ),
  'schedule RPC sets explicit search_path'
);
select is(
  (
    select prosecdef
      from pg_proc p
     where p.oid = to_regprocedure('public.cancel_scheduled_change_schedule_proposal(uuid,text,timestamptz)')
  ),
  true,
  'cancel RPC is SECURITY DEFINER'
);
select ok(
  exists(
    select 1
      from unnest(
        (
          select proconfig
            from pg_proc p
           where p.oid = to_regprocedure('public.cancel_scheduled_change_schedule_proposal(uuid,text,timestamptz)')
        )
      ) as cfg
     where cfg like 'search_path=%'
  ),
  'cancel RPC sets explicit search_path'
);
select is(
  (
    select prosecdef
      from pg_proc p
     where p.oid = to_regprocedure('public.activate_due_change_schedule(uuid,text,timestamptz)')
  ),
  true,
  'due activation RPC is SECURITY DEFINER'
);
select ok(
  exists(
    select 1
      from unnest(
        (
          select proconfig
            from pg_proc p
           where p.oid = to_regprocedure('public.activate_due_change_schedule(uuid,text,timestamptz)')
        )
      ) as cfg
     where cfg like 'search_path=%'
  ),
  'due activation RPC sets explicit search_path'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz)',
    'EXECUTE'
  ),
  'service role can execute scheduled proposal queue RPC'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.cancel_scheduled_change_schedule_proposal(uuid,text,timestamptz)',
    'EXECUTE'
  ),
  'service role can execute scheduled proposal cancellation RPC'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.activate_due_change_schedule(uuid,text,timestamptz)',
    'EXECUTE'
  ),
  'service role can execute due activation RPC'
);

-- schedule creates queued activation rows and transitions proposal state.
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);

create temporary table scheduled_store_main as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000011',
    'proposal-schedule-main',
    'scheduled-user1-active-plan',
    '{"id":"candidate-plan-main","weeks":[]}'::jsonb,
    '{"impact":"baseline"}'::jsonb,
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
    '2026-07-27',
    '2026-07-20 09:00:00+00',
    null,
    1,
    '2026-01-01 00:00:00+00'
  );

create temporary table scheduled_enqueued_main as
select *
  from public.schedule_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000011',
    'proposal-schedule-main',
    'queued-plan-main',
    'queued-avail-main',
    '2026-07-20 09:05:00+00'
  );

select is(
  (select activation_status from scheduled_enqueued_main),
  'scheduled',
  'first scheduled proposal is created as scheduled'
);
select is(
  (select scheduled_plan_version_id from scheduled_enqueued_main),
  'queued-plan-main',
  'function-returned queue plan id matches requested queued plan id'
);
select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-schedule-main'
  ),
  'scheduled',
  'proposal status transitions to scheduled after queueing'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where id = (select activation_id from scheduled_enqueued_main)
  ),
  'scheduled',
  'activation row is created in scheduled state'
);

-- Queueing the same request again is idempotent and does not queue a second activation.
create temporary table scheduled_enqueued_main_retry as
select *
  from public.schedule_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000011',
    'proposal-schedule-main',
    'queued-plan-main',
    'queued-avail-main',
    '2026-07-20 09:06:00+00'
  );

select is(
  (select count(*)::integer from scheduled_enqueued_main_retry),
  1,
  'retrying an existing scheduled proposal returns one row'
);
select is(
  (select activation_id from scheduled_enqueued_main_retry),
  (select activation_id from scheduled_enqueued_main),
  'retrying the same scheduled proposal does not create a replacement activation'
);
select is(
  (
    select count(*)::integer
      from public.change_schedule_activations
     where user_id = '10000000-0000-0000-0000-000000000011'
  ),
  1,
  'scheduled proposal branch keeps a single activation row per user'
);
select is(
  (
    select same_day_run_strength_preference
      from public.change_schedule_availability_versions
     where id = 'queued-avail-main'
  ),
  'separate_sessions',
  'main scheduled queue stores canonical separate_sessions preference'
);

-- A new proposal supersedes the previous schedule and old queued rows are archived.
create temporary table scheduled_store_replacement as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000011',
    'proposal-schedule-replacement',
    'scheduled-user1-active-plan',
    '{"id":"candidate-plan-replacement","weeks":[]}'::jsonb,
    '{"impact":"replacement"}'::jsonb,
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
      "same_day_run_strength_preference": "avoid_same_day"
    }'::jsonb,
    '2026-07-27',
    '2026-07-20 09:07:00+00',
    null,
    1,
    '2026-01-01 00:00:00+00'
  );

create temporary table scheduled_enqueued_replacement as
select *
  from public.schedule_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000011',
    'proposal-schedule-replacement',
    'queued-plan-replacement',
    'queued-avail-replacement',
    '2026-07-20 09:08:00+00'
  );

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-schedule-main'
  ),
  'superseded',
  'previous scheduled proposal is superseded when a new queue is created'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where queued_candidate_plan_version_id = 'queued-plan-main'
  ),
  'superseded',
  'previous queued activation is superseded when replacement is queued'
);
select is(
  (
    select lifecycle_state
      from public.change_schedule_availability_versions
     where id = 'queued-avail-main'
  ),
  'superseded',
  'orphaned queued availability from previous schedule is superseded on replacement'
);
select is(
  (
    select lifecycle_state
      from public.change_schedule_availability_versions
     where id = 'queued-avail-replacement'
  ),
  'scheduled',
  'replacement queued availability is created as scheduled'
);
select is(
  (
    select same_day_run_strength_preference
      from public.change_schedule_availability_versions
     where id = 'queued-avail-replacement'
  ),
  'avoid_same_day',
  'replacement scheduled queue stores canonical avoid_same_day preference'
);

-- A non-null previous chain link that does not match queued lineage must be rejected.
savepoint scheduled_nonnull_link_mismatch_fixture;
set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;

insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000016', 'change-schedule-replacement-mismatch@example.test');

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000016',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
  );

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values
  (
    'source-plan-schedule-nonnull-mismatch',
    '10000000-0000-0000-0000-000000000016',
    '2026-12-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"source-plan-schedule-nonnull-mismatch","weeks":[]}'::jsonb
  );

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values
  (
    'candidate-plan-schedule-nonnull-mismatch-legacy',
    '10000000-0000-0000-0000-000000000016',
    '2026-12-01 09:05:00+00',
    'onboarding',
    false,
    1,
    '{"id":"candidate-plan-schedule-nonnull-mismatch-legacy","weeks":[]}'::jsonb
  ),
  (
    'candidate-plan-schedule-nonnull-mismatch-queued',
    '10000000-0000-0000-0000-000000000016',
    '2026-12-01 09:06:00+00',
    'onboarding',
    false,
    1,
    '{"id":"candidate-plan-schedule-nonnull-mismatch-queued","weeks":[]}'::jsonb
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
) values (
  'availability-schedule-nonnull-mismatch',
  '10000000-0000-0000-0000-000000000016',
  'scheduled',
  date_trunc('week', '2026-12-21'::timestamp)::date,
  4,
  1,
  'separate_sessions',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb
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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values (
  'proposal-schedule-nonnull-mismatch-old',
  '10000000-0000-0000-0000-000000000016',
  'source-plan-schedule-nonnull-mismatch',
  1,
  '2026-01-01 00:00:00+00',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb,
  '{"id":"candidate-plan-schedule-nonnull-mismatch-legacy","weeks":[]}'::jsonb,
  '{"impact":"legacy"}'::jsonb,
  date_trunc('week', '2026-12-21'::timestamp)::date,
  'scheduled',
  'candidate-plan-schedule-nonnull-mismatch-legacy',
  '2026-12-01 10:00:00+00',
  '2026-12-01 10:00:00+00',
  '2026-12-01 11:00:00+00'
),
  (
    'proposal-schedule-nonnull-mismatch-new',
    '10000000-0000-0000-0000-000000000016',
    'source-plan-schedule-nonnull-mismatch',
    1,
    '2026-01-01 00:00:00+00',
    '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"avoid_same_day"}'::jsonb,
    '{"id":"candidate-plan-schedule-nonnull-mismatch-new","weeks":[]}'::jsonb,
    '{"impact":"pending-replacement"}'::jsonb,
    date_trunc('week', '2026-12-21'::timestamp)::date,
    'pending',
    null,
    '2026-12-01 10:10:00+00',
    '2026-12-01 10:10:00+00',
    '2026-12-02 11:00:00+00'
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
  'activation-schedule-nonnull-mismatch',
  '10000000-0000-0000-0000-000000000016',
  'source-plan-schedule-nonnull-mismatch',
  'candidate-plan-schedule-nonnull-mismatch-queued',
  'availability-schedule-nonnull-mismatch',
  date_trunc('week', '2026-12-21'::timestamp)::date,
  'scheduled',
  'proposal-schedule-nonnull-mismatch-old',
  '2026-12-01 10:15:00+00',
  '2026-12-01 10:15:00+00'
);

set role service_role;

select throws_ok(
  $$
    select *
      from public.schedule_change_schedule_proposal(
        '10000000-0000-0000-0000-000000000016',
        'proposal-schedule-nonnull-mismatch-new',
        'queued-plan-schedule-nonnull-mismatch-replacement',
        'queued-avail-schedule-nonnull-mismatch-replacement',
        '2026-12-01 10:20:00+00'
      )
  $$,
  'P0001',
  'change_schedule_proposal_inconsistent',
  'scheduled chain replacement rejects mismatched non-null proposal lineage'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-schedule-nonnull-mismatch'
  ),
  'scheduled',
  'mismatched non-null replacement leaves legacy activation scheduled'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-schedule-nonnull-mismatch'
  ),
  'proposal-schedule-nonnull-mismatch-old',
  'mismatched non-null replacement keeps legacy activation proposal id unchanged'
);
select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-schedule-nonnull-mismatch-old'
  ),
  'scheduled',
  'legacy non-null chain proposal remains scheduled'
);
select is(
  (
    select lifecycle_state
      from public.change_schedule_availability_versions
     where id = 'availability-schedule-nonnull-mismatch'
  ),
  'scheduled',
  'mismatched non-null replacement does not cancel legacy scheduled availability'
);
select is(
  (select status from public.change_schedule_proposals where id = 'proposal-schedule-nonnull-mismatch-new'),
  'pending',
  'replacement call failure does not mutate target proposal status'
);
select is(
  (select count(*)::integer from public.plan_versions where id = 'queued-plan-schedule-nonnull-mismatch-replacement'),
  0,
  'replacement call failure does not create replacement queued plan'
);
select is(
  (select count(*)::integer from public.change_schedule_availability_versions where id = 'queued-avail-schedule-nonnull-mismatch-replacement'),
  0,
  'replacement call failure does not create replacement queued availability'
);

rollback to savepoint scheduled_nonnull_link_mismatch_fixture;

-- Expired pending proposal requests must return a dedicated expired-domain error
-- before any queued-chain write occurs.
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
  updated_at,
  scheduled_plan_version_id,
  expires_at
) values (
  'proposal-schedule-expired',
  '10000000-0000-0000-0000-000000000012',
  'activated-user2-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"candidate-expired-plan","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-08-03',
  'pending',
  '2026-07-22 09:00:00+00',
  '2026-07-22 09:00:00+00',
  null,
  '2026-07-22 09:05:00+00'
);

select throws_ok(
  $$
    select *
      from public.schedule_change_schedule_proposal(
        '10000000-0000-0000-0000-000000000012',
        'proposal-schedule-expired',
        'queued-plan-expired',
        'queued-avail-expired',
        '2026-07-22 09:10:00+00'
      )
  $$,
  'P0001',
  'change_schedule_proposal_expired',
  'expired pending proposals return canonical expired-domain error'
);

select is(
  (
    select status
     from public.change_schedule_proposals
     where id = 'proposal-schedule-expired'
  ),
  'pending',
  'expired scheduling failure leaves the request proposal pending'
);
select is(
  (
    select count(*)::integer
      from public.plan_versions
     where id = 'queued-plan-expired'
  ),
  0,
  'expired scheduling failure does not create queued plan version'
);
select is(
  (
    select count(*)::integer
     from public.change_schedule_availability_versions
     where id = 'queued-avail-expired'
  ),
  0,
  'expired scheduling failure does not create queued availability'
);

-- Expired proposals that are already marked as expired must fail with the dedicated
-- expired-domain error on immediate acceptance and preserve proposal/plan/availability state.
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
  updated_at,
  scheduled_plan_version_id,
  expires_at
) values (
  'proposal-already-expired-now',
  '10000000-0000-0000-0000-000000000011',
  'scheduled-user1-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"expired-candidate-plan","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-08-10',
  'expired',
  '2026-07-01 09:00:00+00',
  '2026-07-01 09:00:00+00',
  null,
  '2026-07-22 09:00:00+00'
);

select throws_ok(
  $$
    select public.accept_change_schedule_proposal_now(
      '10000000-0000-0000-0000-000000000011',
      'proposal-already-expired-now',
      'expired-accept-plan',
      'expired-accept-avail',
      '2026-08-01 10:00:00+00',
      '2026-08-01 10:00:00+00'
    )
  $$,
  'P0001',
  'change_schedule_proposal_expired',
  'expired immediate acceptance returns canonical expired-domain error'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-already-expired-now'
  ),
  'expired',
  'already expired proposal remains expired'
);
select is(
  (
    select accepted_plan_version_id is null
      from public.change_schedule_proposals
     where id = 'proposal-already-expired-now'
  ),
  true,
  'already expired proposal keeps pending acceptance payload unset'
);
select is(
  (
    select accepted_at is null
      from public.change_schedule_proposals
     where id = 'proposal-already-expired-now'
  ),
  true,
  'already expired proposal keeps accepted_at unset'
);
select is(
  (
    select is_active
      from public.plan_versions
     where id = 'scheduled-user1-active-plan'
  ),
  true,
  'already expired proposal acceptance preserves source plan activity'
);
select is(
  (
    select lifecycle_state
      from public.change_schedule_availability_versions
     where id = 'active-avail-user1'
  ),
  'active',
  'already expired proposal acceptance preserves source availability lifecycle'
);
select is(
  (
    select count(*)::integer
      from public.plan_versions
     where id in ('expired-accept-plan', 'expired-candidate-plan')
  ),
  0,
  'already expired proposal acceptance does not create or mutate accepted plan candidates'
);
select is(
  (
    select count(*)::integer
      from public.change_schedule_availability_versions
     where id = 'expired-accept-avail'
  ),
  0,
  'already expired proposal acceptance does not create accepted availability version'
);

-- cancellation updates activation and proposal lifecycle states.
create temporary table cancel_replacement as
select *
  from public.cancel_scheduled_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000011',
    'proposal-schedule-replacement',
    '2026-07-20 09:10:00+00'
  );

select is(
  (select proposal_status from cancel_replacement),
  'cancelled',
  'scheduled proposal cancellation returns cancelled status'
);
select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-schedule-replacement'
  ),
  'cancelled',
  'scheduled proposal is persisted as cancelled'
);
select is(
  (
    select lifecycle_state
      from public.change_schedule_availability_versions
     where id = 'queued-avail-replacement'
  ),
  'cancelled',
  'queued availability version is marked cancelled on proposal cancellation'
);

select is(
  (
    select status
     from public.change_schedule_activations
    where id = (select activation_id from scheduled_enqueued_replacement)
  ),
  'cancelled',
  'queued activation is marked cancelled when proposal is cancelled'
);

-- A cancel call with a wrong non-null scheduled chain link must be rejected.
savepoint cancel_nonnull_link_mismatch_fixture;
set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;

insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000024', 'change-schedule-cancel-nonnull-mismatch@example.test');

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000024',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
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
  'source-plan-cancel-nonnull-mismatch',
  '10000000-0000-0000-0000-000000000024',
  '2026-12-01 09:00:00+00',
  'onboarding',
  true,
  1,
  '{"id":"source-plan-cancel-nonnull-mismatch","weeks":[]}'::jsonb
);

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values
  (
    'candidate-plan-cancel-nonnull-mismatch',
    '10000000-0000-0000-0000-000000000024',
    '2026-12-01 09:05:00+00',
    'onboarding',
    false,
    1,
    '{"id":"candidate-plan-cancel-nonnull-mismatch","weeks":[]}'::jsonb
  ),
  (
    'candidate-plan-cancel-nonnull-mismatch-existing',
    '10000000-0000-0000-0000-000000000024',
    '2026-12-01 09:06:00+00',
    'onboarding',
    false,
    1,
    '{"id":"candidate-plan-cancel-nonnull-mismatch-existing","weeks":[]}'::jsonb
  ),
  (
    'candidate-plan-cancel-nonnull-mismatch-activation',
    '10000000-0000-0000-0000-000000000024',
    '2026-12-01 09:07:00+00',
    'onboarding',
    false,
    1,
    '{"id":"candidate-plan-cancel-nonnull-mismatch-activation","weeks":[]}'::jsonb
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
) values (
  'availability-cancel-nonnull-mismatch',
  '10000000-0000-0000-0000-000000000024',
  'scheduled',
  date_trunc('week', '2026-12-21'::timestamp)::date,
  4,
  1,
  'separate_sessions',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb
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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values (
  'proposal-cancel-nonnull-mismatch-target',
  '10000000-0000-0000-0000-000000000024',
  'source-plan-cancel-nonnull-mismatch',
  1,
  '2026-01-01 00:00:00+00',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb,
  '{"id":"candidate-plan-cancel-nonnull-mismatch","weeks":[]}'::jsonb,
  '{"impact":"cancel-target"}'::jsonb,
  date_trunc('week', '2026-12-21'::timestamp)::date,
  'scheduled',
  'candidate-plan-cancel-nonnull-mismatch',
  '2026-12-01 10:00:00+00',
  '2026-12-01 10:00:00+00',
  '2026-12-01 11:00:00+00'
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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values (
  'proposal-cancel-nonnull-mismatch-existing',
  '10000000-0000-0000-0000-000000000024',
  'source-plan-cancel-nonnull-mismatch',
  1,
  '2026-01-01 00:00:00+00',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb,
  '{"id":"candidate-plan-cancel-nonnull-mismatch-existing","weeks":[]}'::jsonb,
  '{"impact":"existing"}'::jsonb,
  date_trunc('week', '2026-12-21'::timestamp)::date,
  'scheduled',
  'candidate-plan-cancel-nonnull-mismatch-existing',
  '2026-12-01 10:10:00+00',
  '2026-12-01 10:10:00+00',
  '2026-12-01 11:00:00+00'
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
  'activation-cancel-nonnull-mismatch',
  '10000000-0000-0000-0000-000000000024',
  'source-plan-cancel-nonnull-mismatch',
  'candidate-plan-cancel-nonnull-mismatch-activation',
  'availability-cancel-nonnull-mismatch',
  date_trunc('week', '2026-12-21'::timestamp)::date,
  'scheduled',
  'proposal-cancel-nonnull-mismatch-target',
  '2026-12-01 10:20:00+00',
  '2026-12-01 10:20:00+00'
);

set role service_role;

select throws_ok(
  $$
    select *
      from public.cancel_scheduled_change_schedule_proposal(
        '10000000-0000-0000-0000-000000000024',
        'proposal-cancel-nonnull-mismatch-target',
        '2026-12-01 10:25:00+00'
      )
  $$,
  'P0001',
  'change_schedule_proposal_inconsistent',
  'scheduled cancel rejects mismatched non-null lineage before mutation'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-cancel-nonnull-mismatch-target'
  ),
  'scheduled',
  'cancel mismatch leaves target scheduled proposal unchanged'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-cancel-nonnull-mismatch'
  ),
  'scheduled',
  'cancel mismatch keeps activation scheduled'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-cancel-nonnull-mismatch'
  ),
  'proposal-cancel-nonnull-mismatch-target',
  'cancel mismatch keeps non-null proposal link on activation'
);

rollback to savepoint cancel_nonnull_link_mismatch_fixture;

-- Valid null-linked chains can still be resolved during cancellation.
savepoint cancel_null_link_fallback_fixture;
set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;

insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000025', 'change-schedule-cancel-null-fallback@example.test');

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000025',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
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
  'source-plan-cancel-null-fallback',
  '10000000-0000-0000-0000-000000000025',
  '2026-12-01 09:00:00+00',
  'onboarding',
  true,
  1,
  '{"id":"source-plan-cancel-null-fallback","weeks":[]}'::jsonb
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
  'candidate-plan-cancel-null-fallback',
  '10000000-0000-0000-0000-000000000025',
  '2026-12-01 09:05:00+00',
  'onboarding',
  false,
  1,
  '{"id":"candidate-plan-cancel-null-fallback","weeks":[]}'::jsonb
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
) values (
  'availability-cancel-null-fallback',
  '10000000-0000-0000-0000-000000000025',
  'scheduled',
  date_trunc('week', '2026-12-21'::timestamp)::date,
  4,
  1,
  'separate_sessions',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb
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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values (
  'proposal-cancel-null-fallback',
  '10000000-0000-0000-0000-000000000025',
  'source-plan-cancel-null-fallback',
  1,
  '2026-01-01 00:00:00+00',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb,
  '{"id":"candidate-plan-cancel-null-fallback","weeks":[]}'::jsonb,
  '{"impact":"cancel-null-fallback"}'::jsonb,
  date_trunc('week', '2026-12-21'::timestamp)::date,
  'scheduled',
  'candidate-plan-cancel-null-fallback',
  '2026-12-01 10:00:00+00',
  '2026-12-01 10:00:00+00',
  '2026-12-01 11:00:00+00'
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
  'activation-cancel-null-fallback',
  '10000000-0000-0000-0000-000000000025',
  'source-plan-cancel-null-fallback',
  'candidate-plan-cancel-null-fallback',
  'availability-cancel-null-fallback',
  date_trunc('week', '2026-12-21'::timestamp)::date,
  'scheduled',
  null,
  '2026-12-01 10:20:00+00',
  '2026-12-01 10:20:00+00'
);

set role service_role;

create temporary table cancel_null_fallback as
select *
  from public.cancel_scheduled_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000025',
    'proposal-cancel-null-fallback',
    '2026-12-01 10:26:00+00'
  );

select is(
  (select proposal_status from cancel_null_fallback),
  'cancelled',
  'scheduled cancel fallback resolves exact null-linked activation'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-cancel-null-fallback'
  ),
  'cancelled',
  'null-linked fallback cancellation marks activation cancelled'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-cancel-null-fallback'
  ),
  'proposal-cancel-null-fallback',
  'null-linked fallback writes target proposal id before cancelling'
);
select is(
  (
    select lifecycle_state
      from public.change_schedule_availability_versions
     where id = 'availability-cancel-null-fallback'
  ),
  'cancelled',
  'null-linked fallback cancels the scheduled availability'
);

rollback to savepoint cancel_null_link_fallback_fixture;

-- A call to scheduled activation on a non-due date throws.
create temporary table activation_store_main_due as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000012',
    'proposal-activate-due',
    'activated-user2-active-plan',
    '{"id":"candidate-plan-activate-due","weeks":[]}'::jsonb,
    '{"impact":"pending"}'::jsonb,
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
    '2026-08-03',
    '2026-07-22 09:00:00+00',
    null,
    1,
    '2026-01-01 00:00:00+00'
  );

create temporary table activation_enqueue as
select *
  from public.schedule_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000012',
    'proposal-activate-due',
    'queued-plan-activate',
    'queued-avail-activate',
    '2026-07-22 09:01:00+00'
  );

select throws_ok(
  $$
    select *
      from public.activate_due_change_schedule(
        '10000000-0000-0000-0000-000000000012',
        (select activation_id from activation_enqueue),
        '2026-08-01 00:00:00+00'
      )
  $$,
  'P0001',
  'change_schedule_activation_not_due',
  'scheduled activations cannot be activated before their effective Monday'
);

create temporary table activation_run as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000012',
    (select activation_id from activation_enqueue),
    '2026-08-03 00:00:00+00'
  );

select is(
  (select proposal_status from activation_run),
  'accepted',
  'activation routine transitions scheduled proposal to accepted when due'
);
select is(
  (select accepted_plan_version_id from activation_run),
  'queued-plan-activate',
  'activation routine returns accepted queued plan id'
);
select is(
  (
    select status
     from public.change_schedule_activations
     where id = (select activation_id from activation_run)
  ),
  'activated',
  'queued activation is marked activated'
);
select is(
  (
    select prior_active_plan_version_id
      from public.change_schedule_activations
     where id = (select activation_id from activation_run)
  ),
  'activated-user2-active-plan',
  'activation transition writes prior active plan snapshot'
);
select is(
  (
    select prior_active_availability_version_id
      from public.change_schedule_activations
     where id = (select activation_id from activation_run)
  ),
  'active-avail-user2',
  'activation transition writes prior active availability snapshot'
);
select is(
  (
    select is_active
      from public.plan_versions
     where id = 'activated-user2-active-plan'
  ),
  false,
  'previous active plan is retired after due activation'
);
select is(
  (
    select is_active
      from public.plan_versions
     where id = 'queued-plan-activate'
  ),
  true,
  'queued plan becomes active after due activation'
);
select is(
  (
    select prior_active_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-activate-due'
  ),
  'activated-user2-active-plan',
  'accepted proposal stores prior active plan id'
);
select is(
  (
    select prior_active_availability_version_id
      from public.change_schedule_proposals
     where id = 'proposal-activate-due'
  ),
  'active-avail-user2',
  'accepted proposal stores prior active availability id'
);
select is(
  (
    select accepted_availability_version_id
      from public.change_schedule_proposals
     where id = 'proposal-activate-due'
  ),
  'queued-avail-activate',
  'accepted proposal stores accepted availability id'
);
select is(
  (
    select count(*)::integer
      from public.plan_versions
     where user_id = '10000000-0000-0000-0000-000000000012'
       and is_active = true
  ),
  1,
  'successful activation leaves exactly one active plan'
);
select is(
  (
    select count(*)::integer
      from public.change_schedule_availability_versions
     where user_id = '10000000-0000-0000-0000-000000000012'
       and lifecycle_state = 'active'
  ),
  1,
  'successful activation leaves exactly one active availability'
);
select is(
  (
    select same_day_run_strength_preference
      from public.change_schedule_availability_versions
     where id = 'queued-avail-activate'
  ),
  'separate_sessions',
  'activated availability stores canonical separate_sessions preference'
);
select is(
  (
    select lifecycle_state
      from public.change_schedule_availability_versions
     where id = 'queued-avail-activate'
  ),
  'active',
  'activated availability transitions to active state'
);

create temporary table activation_run_again as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000012',
    (select activation_id from activation_enqueue),
    '2026-08-03 01:00:00+00'
  );

select is(
  (select activation_status from activation_run_again),
  'activated',
  'calling activation again is idempotent for already active schedule'
);
select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-activate-due'
  ),
  'accepted',
  'proposal remains accepted after idempotent due activation'
);

select is(
  (
    select count(*)::integer
     from public.change_schedule_availability_versions
     where user_id = '10000000-0000-0000-0000-000000000012'
     and lifecycle_state = 'active'
  ),
  1,
  'scheduled lifecycle always keeps at most one active availability version'
);

-- Activation records preserve exact proposal-chain metadata.
set local role postgres;
insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000016', 'change-schedule-proposal-effective-mismatch@example.test');

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000016',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
  );

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values
  (
    'source-plan-scheduled-effectiveness',
    '10000000-0000-0000-0000-000000000016',
    '2026-11-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"source-plan-scheduled-effectiveness","weeks":[]}'::jsonb
  ),
  (
    'candidate-plan-scheduled-effectiveness',
    '10000000-0000-0000-0000-000000000016',
    '2026-11-01 09:30:00+00',
    'onboarding',
    false,
    1,
    '{"id":"candidate-plan-scheduled-effectiveness","weeks":[]}'::jsonb
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
) values (
  'availability-scheduled-effectiveness-mismatch',
  '10000000-0000-0000-0000-000000000016',
  'scheduled',
  (date_trunc('week', '2026-11-08'::timestamp)::date),
  4,
  1,
  'separate_sessions',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb
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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values (
  'proposal-scheduled-effective-mismatch',
  '10000000-0000-0000-0000-000000000016',
  'source-plan-scheduled-effectiveness',
  1,
  '2026-01-01 00:00:00+00',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb,
  '{"id":"candidate-plan-scheduled-effectiveness","weeks":[]}'::jsonb,
  '{"impact":"baseline"}'::jsonb,
  (date_trunc('week', '2026-11-01'::timestamp)::date),
  'scheduled',
  'candidate-plan-scheduled-effectiveness',
  '2026-11-01 10:00:00+00',
  '2026-11-01 10:00:00+00',
  '2026-11-01 11:00:00+00'
);

select throws_ok(
  $$
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
      'activation-scheduled-effective-mismatch',
      '10000000-0000-0000-0000-000000000016',
      'source-plan-scheduled-effectiveness',
      'candidate-plan-scheduled-effectiveness',
      'availability-scheduled-effectiveness-mismatch',
      (date_trunc('week', '2026-11-08'::timestamp)::date),
      'scheduled',
      'proposal-scheduled-effective-mismatch',
      '2026-11-08 09:00:00+00',
      '2026-11-08 09:00:00+00'
    )
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'scheduled activation rejects proposal with non-matching effective Monday'
);

select is(
  (
    select count(*)::integer
      from public.change_schedule_activations
     where id = 'activation-scheduled-effective-mismatch'
  ),
  0,
  'scheduled activation with mismatched proposal effective week is not persisted'
);

-- Ambiguous legacy fallback should be rejected safely before mutating a scheduled activation.
set local role postgres;
insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000017', 'change-schedule-proposal-ambiguity@example.test');

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000017',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"5k"}}'::jsonb
  );

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values
  (
    'source-plan-scheduled-ambiguity',
    '10000000-0000-0000-0000-000000000017',
    '2026-12-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"source-plan-scheduled-ambiguity","weeks":[]}'::jsonb
  ),
  (
    'candidate-plan-scheduled-ambiguity',
    '10000000-0000-0000-0000-000000000017',
    '2026-12-01 09:30:00+00',
    'onboarding',
    false,
    1,
    '{"id":"candidate-plan-scheduled-ambiguity","weeks":[]}'::jsonb
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
) values (
  'availability-scheduled-ambiguity',
  '10000000-0000-0000-0000-000000000017',
  'scheduled',
  (date_trunc('week', '2026-12-14'::timestamp)::date),
  4,
  1,
  'separate_sessions',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb
);

-- Temporarily relax scheduled proposal uniqueness to construct a deterministic ambiguous fixture.
savepoint scheduled_ambiguity_fixture;
drop index if exists public.change_schedule_proposals_one_scheduled_plan_per_user;

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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values
  (
    'proposal-scheduled-ambiguity-a',
    '10000000-0000-0000-0000-000000000017',
    'source-plan-scheduled-ambiguity',
    1,
    '2026-01-01 00:00:00+00',
    '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb,
    '{"id":"candidate-plan-scheduled-ambiguity","weeks":[]}'::jsonb,
    '{"impact":"ambiguity-a"}'::jsonb,
    (date_trunc('week', '2026-12-14'::timestamp)::date),
    'scheduled',
    'candidate-plan-scheduled-ambiguity',
    '2026-12-01 10:00:00+00',
    '2026-12-01 10:00:00+00',
    '2026-12-01 11:00:00+00'
  ),
  (
    'proposal-scheduled-ambiguity-b',
    '10000000-0000-0000-0000-000000000017',
    'source-plan-scheduled-ambiguity',
    1,
    '2026-01-01 00:00:00+00',
    '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb,
    '{"id":"candidate-plan-scheduled-ambiguity","weeks":[]}'::jsonb,
    '{"impact":"ambiguity-b"}'::jsonb,
    (date_trunc('week', '2026-12-14'::timestamp)::date),
    'scheduled',
    'candidate-plan-scheduled-ambiguity',
    '2026-12-01 10:05:00+00',
    '2026-12-01 10:05:00+00',
    '2026-12-01 11:00:00+00'
  );

set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;

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
  'activation-scheduled-ambiguity',
  '10000000-0000-0000-0000-000000000017',
  'source-plan-scheduled-ambiguity',
  'candidate-plan-scheduled-ambiguity',
  'availability-scheduled-ambiguity',
  (date_trunc('week', '2026-12-14'::timestamp)::date),
  'scheduled',
  null,
  '2026-12-01 10:10:00+00',
  '2026-12-01 10:10:00+00'
);

select throws_ok(
  $$
    select *
      from public.activate_due_change_schedule(
        '10000000-0000-0000-0000-000000000017',
        'activation-scheduled-ambiguity',
        '2026-12-15 00:00:00+00'
      )
  $$,
  'P0001',
  'change_schedule_activation_proposal_ambiguous',
  'activate_due rejects ambiguous scheduled fallback chains'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-scheduled-ambiguity'
  ),
  'scheduled',
  'ambiguous scheduled fallback rejection preserves activation status'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-scheduled-ambiguity'
  ),
  null::text,
  'ambiguous scheduled fallback rejection preserves null proposal binding'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-scheduled-ambiguity'
  ),
  'scheduled',
  'activation for activate_due ambiguity is unchanged'
);
select is(
  (
    select count(*)
      from public.change_schedule_proposals
     where id in ('proposal-scheduled-ambiguity-a', 'proposal-scheduled-ambiguity-b')
  )::bigint,
  2::bigint,
  'ambiguous fixture keeps both scheduled proposals intact'
);
select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-scheduled-ambiguity-a'
  ),
  'candidate-plan-scheduled-ambiguity',
  'ambiguity candidate-a retains queued scheduled plan id'
);
select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-scheduled-ambiguity-b'
  ),
  'candidate-plan-scheduled-ambiguity',
  'ambiguity candidate-b retains queued scheduled plan id'
);

-- Ambiguous scheduled cancellation fallback should also be rejected safely.
set local role postgres;
insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000018', 'change-schedule-cancel-ambiguity@example.test');

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000018',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
  );

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values
  (
    'source-plan-scheduled-cancel-ambiguity',
    '10000000-0000-0000-0000-000000000018',
    '2026-12-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"source-plan-scheduled-cancel-ambiguity","weeks":[]}'::jsonb
  ),
  (
    'candidate-plan-scheduled-cancel-ambiguity',
    '10000000-0000-0000-0000-000000000018',
    '2026-12-01 09:30:00+00',
    'onboarding',
    false,
    1,
    '{"id":"candidate-plan-scheduled-cancel-ambiguity","weeks":[]}'::jsonb
  ),
  (
    'candidate-plan-scheduled-cancel-ambiguity-mismatch',
    '10000000-0000-0000-0000-000000000018',
    '2026-12-01 09:45:00+00',
    'onboarding',
    false,
    1,
    '{"id":"candidate-plan-scheduled-cancel-ambiguity-mismatch","weeks":[]}'::jsonb
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
) values (
  'availability-scheduled-cancel-ambiguity',
  '10000000-0000-0000-0000-000000000018',
  'scheduled',
  date_trunc('week', '2026-12-21'::timestamp)::date,
  4,
  1,
  'separate_sessions',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb
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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values
  (
    'proposal-scheduled-cancel-ambiguity-a',
    '10000000-0000-0000-0000-000000000018',
    'source-plan-scheduled-cancel-ambiguity',
    1,
    '2026-01-01 00:00:00+00',
    '{
      "days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"
    }'::jsonb,
    '{"id":"candidate-plan-scheduled-cancel-ambiguity","weeks":[]}'::jsonb,
    '{"impact":"cancel-ambiguity-a"}'::jsonb,
    date_trunc('week', '2026-12-21'::timestamp)::date,
    'scheduled',
    'candidate-plan-scheduled-cancel-ambiguity',
    '2026-12-01 10:00:00+00',
    '2026-12-01 10:00:00+00',
    '2026-12-01 11:00:00+00'
  ),
  (
    'proposal-scheduled-cancel-ambiguity-b',
    '10000000-0000-0000-0000-000000000018',
    'source-plan-scheduled-cancel-ambiguity',
    1,
    '2026-01-01 00:00:00+00',
    '{
      "days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"
    }'::jsonb,
    '{"id":"candidate-plan-scheduled-cancel-ambiguity","weeks":[]}'::jsonb,
    '{"impact":"cancel-ambiguity-b"}'::jsonb,
    date_trunc('week', '2026-12-21'::timestamp)::date,
    'scheduled',
    'candidate-plan-scheduled-cancel-ambiguity',
    '2026-12-01 10:05:00+00',
    '2026-12-01 10:05:00+00',
    '2026-12-01 11:00:00+00'
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
  'activation-scheduled-cancel-ambiguity',
  '10000000-0000-0000-0000-000000000018',
  'source-plan-scheduled-cancel-ambiguity',
  'candidate-plan-scheduled-cancel-ambiguity-mismatch',
  'availability-scheduled-cancel-ambiguity',
  date_trunc('week', '2026-12-21'::timestamp)::date,
  'scheduled',
  null,
  '2026-12-01 10:10:00+00',
  '2026-12-01 10:10:00+00'
);

select throws_ok(
  $$
    select *
      from public.cancel_scheduled_change_schedule_proposal(
        '10000000-0000-0000-0000-000000000018',
        'proposal-scheduled-cancel-ambiguity-a',
        '2026-12-02 09:00:00+00'
      )
  $$,
  'P0001',
  'change_schedule_activation_proposal_ambiguous',
  'cancel_scheduled rejects ambiguous scheduled fallback chains'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-scheduled-cancel-ambiguity'
  ),
  'scheduled',
  'ambiguous cancellation fallback rejection keeps activation scheduled'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-scheduled-cancel-ambiguity'
  ),
  null::text,
  'ambiguous cancellation fallback rejection keeps proposal binding null'
);
rollback to savepoint scheduled_ambiguity_fixture;

-- Legacy scheduled replacements only adopt the exact source/week legacy row for the same queued candidate.
insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000019', 'change-schedule-replacement-mismatch@example.test');

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000019',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
  );

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values
  (
    'source-plan-scheduled-replacement-mismatch',
    '10000000-0000-0000-0000-000000000019',
    '2026-12-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"source-plan-scheduled-replacement-mismatch","weeks":[]}'::jsonb
  ),
  (
    'candidate-plan-scheduled-replacement-mismatch',
    '10000000-0000-0000-0000-000000000019',
    '2026-12-01 09:30:00+00',
    'onboarding',
    false,
    1,
    '{"id":"candidate-plan-scheduled-replacement-mismatch","weeks":[]}'::jsonb
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
) values (
  'availability-scheduled-replacement-mismatch',
  '10000000-0000-0000-0000-000000000019',
  'scheduled',
  date_trunc('week', '2026-12-21'::timestamp)::date,
  4,
  1,
  'separate_sessions',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb
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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values
  (
    'proposal-scheduled-replacement-mismatch-legacy',
    '10000000-0000-0000-0000-000000000019',
    'source-plan-scheduled-replacement-mismatch',
    1,
    '2026-01-01 00:00:00+00',
    '{
      "days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"
    }'::jsonb,
    '{"id":"candidate-plan-scheduled-replacement-mismatch","weeks":[]}'::jsonb,
    '{"impact":"replacement-mismatch-legacy"}'::jsonb,
    date_trunc('week', '2026-12-14'::timestamp)::date,
    'scheduled',
    'candidate-plan-scheduled-replacement-mismatch',
    '2026-12-01 10:00:00+00',
    '2026-12-01 10:00:00+00',
    '2026-12-01 11:00:00+00'
  );

savepoint legacy_user4_activation_history;
set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;

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
  'activation-scheduled-replacement-mismatch',
  '10000000-0000-0000-0000-000000000019',
  'source-plan-scheduled-replacement-mismatch',
  'candidate-plan-scheduled-replacement-mismatch',
  'availability-scheduled-replacement-mismatch',
  date_trunc('week', '2026-12-21'::timestamp)::date,
  'scheduled',
  null,
  '2026-12-01 10:10:00+00',
  '2026-12-01 10:10:00+00'
);

create temporary table scheduled_store_replacement_mismatch as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000019',
    'proposal-scheduled-replacement-mismatch',
    'source-plan-scheduled-replacement-mismatch',
    '{"id":"candidate-plan-scheduled-replacement-mismatch-requested","weeks":[]}'::jsonb,
    '{"impact":"replacement-mismatch-request"}'::jsonb,
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
    '2026-12-21',
    '2026-12-01 10:15:00+00',
    null,
    1,
    '2026-01-01 00:00:00+00'
  );

select throws_ok(
  $$
    select *
      from public.schedule_change_schedule_proposal(
        '10000000-0000-0000-0000-000000000019',
        'proposal-scheduled-replacement-mismatch',
        'queued-plan-scheduled-replacement-mismatch',
        'queued-avail-scheduled-replacement-mismatch',
        '2026-12-01 10:20:00+00'
      )
  $$,
  'P0001',
  'change_schedule_proposal_inconsistent',
  'replacement rejects mismatched legacy row without source/week exactness'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-scheduled-replacement-mismatch'
  ),
  'scheduled',
  'mismatched legacy replacement keeps null proposal binding after rejected replacement'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-scheduled-replacement-mismatch'
  ),
  null::text,
  'legacy replacement mismatch does not adopt non-matching source plan week'
);

-- Legacy scheduled replacements must also keep exact source/effective lineage with a candidate-match.
insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000021', 'change-schedule-replacement-source-mismatch@example.test');

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000021',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
  );

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values
  (
    'source-plan-scheduled-replacement-source-mismatch-legacy',
    '10000000-0000-0000-0000-000000000021',
    '2026-12-22 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"source-plan-scheduled-replacement-source-mismatch-legacy","weeks":[]}'::jsonb
  ),
  (
    'source-plan-scheduled-replacement-source-mismatch-queued',
    '10000000-0000-0000-0000-000000000021',
    '2026-12-22 09:10:00+00',
    'onboarding',
    false,
    1,
    '{"id":"source-plan-scheduled-replacement-source-mismatch-queued","weeks":[]}'::jsonb
  ),
  (
    'candidate-plan-scheduled-replacement-source-mismatch',
    '10000000-0000-0000-0000-000000000021',
    '2026-12-22 09:30:00+00',
    'onboarding',
    false,
    1,
    '{"id":"candidate-plan-scheduled-replacement-source-mismatch","weeks":[]}'::jsonb
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
) values (
  'availability-scheduled-replacement-source-mismatch',
  '10000000-0000-0000-0000-000000000021',
  'scheduled',
  date_trunc('week', '2026-12-29'::timestamp)::date,
  4,
  1,
  'separate_sessions',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb
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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values
  (
    'proposal-scheduled-replacement-source-mismatch',
    '10000000-0000-0000-0000-000000000021',
    'source-plan-scheduled-replacement-source-mismatch-legacy',
    1,
    '2026-01-01 00:00:00+00',
    '{
      "days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"
    }'::jsonb,
    '{"id":"candidate-plan-scheduled-replacement-source-mismatch","weeks":[]}'::jsonb,
    '{"impact":"replacement-source-mismatch"}'::jsonb,
    date_trunc('week', '2026-12-29'::timestamp)::date,
    'scheduled',
    'candidate-plan-scheduled-replacement-source-mismatch',
    '2026-12-22 10:00:00+00',
    '2026-12-22 10:00:00+00',
  '2026-12-22 11:00:00+00'
  );

update public.plan_versions
  set is_active = false
 where id = 'source-plan-scheduled-replacement-source-mismatch-legacy';
update public.plan_versions
  set is_active = true
 where id = 'source-plan-scheduled-replacement-source-mismatch-queued';

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
  'activation-scheduled-replacement-source-mismatch',
  '10000000-0000-0000-0000-000000000021',
  'source-plan-scheduled-replacement-source-mismatch-queued',
  'candidate-plan-scheduled-replacement-source-mismatch',
  'availability-scheduled-replacement-source-mismatch',
  date_trunc('week', '2026-12-29'::timestamp)::date,
  'scheduled',
  null,
  '2026-12-22 10:10:00+00',
  '2026-12-22 10:10:00+00'
);

select throws_ok(
  $$
    select *
      from public.schedule_change_schedule_proposal(
        '10000000-0000-0000-0000-000000000021',
        'proposal-scheduled-replacement-source-mismatch',
        'candidate-plan-scheduled-replacement-source-mismatch',
        'availability-scheduled-replacement-source-mismatch',
        '2026-12-22 10:20:00+00'
      )
  $$,
  'P0001',
  'change_schedule_proposal_inconsistent',
  'replacement rejects candidate-match legacy chain with mismatched source lineage'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-scheduled-replacement-source-mismatch'
  ),
  'scheduled',
  'source-lineage mismatch keeps scheduled activation status'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-scheduled-replacement-source-mismatch'
  ),
  null::text,
  'source-lineage mismatch keeps proposal binding null'
);

insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000020', 'change-schedule-replacement-exact@example.test');

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000020',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
  );

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values
  (
    'source-plan-scheduled-replacement-exact',
    '10000000-0000-0000-0000-000000000020',
    '2026-12-22 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"source-plan-scheduled-replacement-exact","weeks":[]}'::jsonb
  ),
  (
    'candidate-plan-scheduled-replacement-exact',
    '10000000-0000-0000-0000-000000000020',
    '2026-12-22 09:30:00+00',
    'onboarding',
    false,
    1,
    '{"id":"candidate-plan-scheduled-replacement-exact","weeks":[]}'::jsonb
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
) values (
  'availability-scheduled-replacement-exact',
  '10000000-0000-0000-0000-000000000020',
  'scheduled',
  date_trunc('week', '2026-12-21'::timestamp)::date,
  4,
  1,
  'separate_sessions',
  '{"days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"}'::jsonb
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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values
  (
    'proposal-scheduled-replacement-exact-legacy',
    '10000000-0000-0000-0000-000000000020',
    'source-plan-scheduled-replacement-exact',
    1,
    '2026-01-01 00:00:00+00',
    '{
      "days":[{"day":1,"available":true},{"day":2,"available":true},{"day":3,"available":true},{"day":4,"available":true},{"day":5,"available":false},{"day":6,"available":false},{"day":7,"available":false}],"target_running_days":4,"primary_long_run_weekday":1,"same_day_run_strength_preference":"separate_sessions"
    }'::jsonb,
    '{"id":"candidate-plan-scheduled-replacement-exact","weeks":[]}'::jsonb,
    '{"impact":"replacement-exact-legacy"}'::jsonb,
    date_trunc('week', '2026-12-21'::timestamp)::date,
    'scheduled',
    'candidate-plan-scheduled-replacement-exact',
    '2026-12-01 10:30:00+00',
    '2026-12-01 10:30:00+00',
    '2026-12-01 11:00:00+00'
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
  'activation-scheduled-replacement-exact',
  '10000000-0000-0000-0000-000000000020',
  'source-plan-scheduled-replacement-exact',
  'candidate-plan-scheduled-replacement-exact',
  'availability-scheduled-replacement-exact',
  date_trunc('week', '2026-12-21'::timestamp)::date,
  'scheduled',
  null,
  '2026-12-01 10:35:00+00',
  '2026-12-01 10:35:00+00'
);

create temporary table scheduled_store_replacement_exact as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000020',
    'proposal-scheduled-replacement-exact',
    'source-plan-scheduled-replacement-exact',
    '{"id":"candidate-plan-scheduled-replacement-exact-requested","weeks":[]}'::jsonb,
    '{"impact":"replacement-exact-request"}'::jsonb,
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
    '2026-12-21',
    '2026-12-01 10:40:00+00',
    null,
    1,
    '2026-01-01 00:00:00+00'
  );

create temporary table scheduled_enqueued_replacement_exact as
select *
  from public.schedule_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000020',
    'proposal-scheduled-replacement-exact',
    'queued-plan-scheduled-replacement-exact',
    'queued-avail-scheduled-replacement-exact',
    '2026-12-01 10:45:00+00'
  );

select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-scheduled-replacement-exact'
  ),
  'proposal-scheduled-replacement-exact-legacy',
  'exact-match legacy fallback is adopted during replacement'
);

delete from public.change_schedule_activations
 where id = 'activation-scheduled-ambiguity';
delete from public.change_schedule_proposals
 where id in ('proposal-scheduled-ambiguity-a', 'proposal-scheduled-ambiguity-b');
delete from public.change_schedule_availability_versions
 where id = 'availability-scheduled-ambiguity';
delete from public.plan_versions
 where id in (
   'source-plan-scheduled-ambiguity',
   'candidate-plan-scheduled-ambiguity'
 );
delete from public.runner_profiles
 where user_id = '10000000-0000-0000-0000-000000000017';
delete from auth.users
 where id = '10000000-0000-0000-0000-000000000017';
delete from public.change_schedule_activations
 where id = 'activation-scheduled-cancel-ambiguity';
delete from public.change_schedule_proposals
 where id in ('proposal-scheduled-cancel-ambiguity-a', 'proposal-scheduled-cancel-ambiguity-b');
delete from public.change_schedule_availability_versions
 where id = 'availability-scheduled-cancel-ambiguity';
delete from public.change_schedule_activations
 where id = 'activation-scheduled-replacement-mismatch';
delete from public.change_schedule_proposals
 where id in (
   'proposal-scheduled-replacement-mismatch-legacy',
   'proposal-scheduled-replacement-mismatch'
 );
delete from public.change_schedule_availability_versions
 where id = 'availability-scheduled-replacement-mismatch';
delete from public.change_schedule_availability_versions
 where id = 'queued-avail-scheduled-replacement-mismatch';
delete from public.plan_versions
 where id in (
   'source-plan-scheduled-replacement-mismatch',
   'candidate-plan-scheduled-replacement-mismatch'
 );
delete from public.change_schedule_activations
 where id = 'activation-scheduled-replacement-exact';
delete from public.change_schedule_activations
 where availability_version_id in (
   'queued-avail-scheduled-replacement-mismatch',
   'queued-avail-scheduled-replacement-exact'
 );
delete from public.change_schedule_proposals
 where id in (
   'proposal-scheduled-replacement-exact-legacy',
   'proposal-scheduled-replacement-exact'
 );
delete from public.change_schedule_availability_versions
 where id = 'availability-scheduled-replacement-exact';
delete from public.change_schedule_availability_versions
 where id = 'queued-avail-scheduled-replacement-exact';
delete from public.plan_versions
 where id in (
   'source-plan-scheduled-replacement-exact',
   'candidate-plan-scheduled-replacement-exact'
 );
delete from public.plan_versions
 where id in (
   'source-plan-scheduled-cancel-ambiguity',
   'candidate-plan-scheduled-cancel-ambiguity',
   'candidate-plan-scheduled-cancel-ambiguity-mismatch'
 );
delete from public.runner_profiles
 where user_id = '10000000-0000-0000-0000-000000000018';
delete from auth.users
 where id = '10000000-0000-0000-0000-000000000018';
delete from public.runner_profiles
 where user_id = '10000000-0000-0000-0000-000000000019';
delete from auth.users
 where id = '10000000-0000-0000-0000-000000000019';
delete from public.runner_profiles
 where user_id = '10000000-0000-0000-0000-000000000020';
delete from auth.users
 where id = '10000000-0000-0000-0000-000000000020';
delete from public.change_schedule_activations
 where id = 'activation-scheduled-replacement-source-mismatch';
delete from public.change_schedule_proposals
 where id = 'proposal-scheduled-replacement-source-mismatch';
delete from public.change_schedule_availability_versions
 where id = 'availability-scheduled-replacement-source-mismatch';
delete from public.plan_versions
 where id in (
   'source-plan-scheduled-replacement-source-mismatch-legacy',
   'source-plan-scheduled-replacement-source-mismatch-queued',
   'candidate-plan-scheduled-replacement-source-mismatch'
 );
delete from public.runner_profiles
 where user_id = '10000000-0000-0000-0000-000000000021';
delete from auth.users
 where id = '10000000-0000-0000-0000-000000000021';

set local role postgres;
create unique index if not exists change_schedule_proposals_one_scheduled_plan_per_user
  on public.change_schedule_proposals (scheduled_plan_version_id)
  where scheduled_plan_version_id is not null;

-- Cleanup temporary fixtures from the effective-week mismatch case.
delete from public.change_schedule_proposals
 where id = 'proposal-scheduled-effective-mismatch';
delete from public.change_schedule_activations
 where id = 'activation-scheduled-effective-mismatch';
delete from public.change_schedule_availability_versions
 where id = 'availability-scheduled-effectiveness-mismatch';
delete from public.plan_versions
 where id in ('source-plan-scheduled-effectiveness', 'candidate-plan-scheduled-effectiveness');
delete from public.runner_profiles
 where user_id = '10000000-0000-0000-0000-000000000016';
delete from auth.users
 where id = '10000000-0000-0000-0000-000000000016';

set local role service_role;
set local role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;
set local role service_role;

-- Orphaned and terminal proposals cannot activate a scheduled chain or mutate plan state.
insert into public.change_schedule_availability_versions (
  id,
  user_id,
  lifecycle_state,
  effective_from,
  target_running_days,
  primary_long_run_weekday,
  same_day_run_strength_preference,
  availability_data
) values (
  'guard-orphaned-due-avail',
  '10000000-0000-0000-0000-000000000015',
  'scheduled',
  '2026-10-12',
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

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'candidate-plan-orphaned-due',
  '10000000-0000-0000-0000-000000000015',
  '2026-10-12 08:00:00+00',
  'onboarding',
  false,
  1,
  '{"id":"candidate-plan-orphaned-due","weeks":[]}'::jsonb
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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values (
  'proposal-orphaned-due-terminal',
  '10000000-0000-0000-0000-000000000015',
  'guard-user5-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"candidate-plan-orphaned-due","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-10-12',
  'scheduled',
  'candidate-plan-orphaned-due',
  '2026-10-12 08:10:00+00',
  '2026-10-12 08:10:00+00',
  '2026-10-12 09:10:00+00'
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
  'activation-orphaned-due-scheduled',
  '10000000-0000-0000-0000-000000000015',
  'guard-user5-active-plan',
  'candidate-plan-orphaned-due',
  'guard-orphaned-due-avail',
  '2026-10-12',
  'scheduled',
  'proposal-orphaned-due-terminal',
  '2026-10-12 08:11:00+00',
  '2026-10-12 08:11:00+00'
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
  updated_at,
  cancelled_at
) values (
  'activation-orphaned-due-terminal',
  '10000000-0000-0000-0000-000000000015',
  'guard-user5-active-plan',
  'candidate-plan-orphaned-due',
  'guard-orphaned-due-avail',
  '2026-10-12',
  'cancelled',
  'proposal-orphaned-due-terminal',
  '2026-10-12 08:12:00+00',
  '2026-10-12 08:12:00+00',
  '2026-10-12 08:12:00+00'
);
set local role postgres;
alter table public.change_schedule_activations enable trigger change_schedule_activations_integrity;
set local role service_role;
set role service_role;

update public.change_schedule_proposals
   set status = 'cancelled',
       scheduled_plan_version_id = null,
       cancelled_at = '2026-10-12 08:13:00+00',
       updated_at = '2026-10-12 08:13:00+00'
 where id = 'proposal-orphaned-due-terminal';

select throws_ok(
  $$
    select *
      from public.activate_due_change_schedule(
        '10000000-0000-0000-0000-000000000015',
        'activation-orphaned-due-scheduled',
        '2026-10-12 00:00:00+00'
      )
  $$,
  'P0001',
  'change_schedule_activation_proposal_not_available',
  'terminal proposal linked to a scheduled activation is rejected by due activation'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-orphaned-due-scheduled'
  ),
  'scheduled',
  'terminal proposal rejection leaves scheduled activation state unchanged'
);
select is(
  (
    select status
     from public.change_schedule_proposals
     where id = 'proposal-orphaned-due-terminal'
  ),
  'cancelled',
  'terminal proposal remains terminal when due activation is rejected'
);

-- Missing terminalized activation snapshots reject scheduled proposal acceptance.
insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'candidate-plan-missing-terminal-snapshot',
  '10000000-0000-0000-0000-000000000015',
  '2026-10-16 09:00:00+00',
  'onboarding',
  false,
  1,
  '{"id":"candidate-plan-missing-terminal-snapshot","weeks":[]}'::jsonb
);

-- Reuse existing user5 scheduled availability fixture (`guard-orphaned-due-avail`) for this scenario

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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values (
  'proposal-missing-terminal-snapshot',
  '10000000-0000-0000-0000-000000000015',
  'guard-user5-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"candidate-plan-missing-terminal-snapshot","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-10-12',
  'scheduled',
  'candidate-plan-missing-terminal-snapshot',
  '2026-10-16 09:10:00+00',
  '2026-10-16 09:10:00+00',
  '2026-10-16 10:10:00+00'
);

-- Reuse the existing user5 scheduled activation row for this scenario to avoid one-scheduled-per-user
-- conflicts with the earlier orphaned-due fixture.
update public.change_schedule_activations
   set queued_candidate_plan_version_id = 'candidate-plan-missing-terminal-snapshot',
       availability_version_id = 'guard-orphaned-due-avail',
       proposal_id = 'proposal-missing-terminal-snapshot',
       updated_at = '2026-10-16 09:11:00+00'
 where id = 'activation-orphaned-due-scheduled';

set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;
update public.change_schedule_availability_versions
   set lifecycle_state = 'active'
 where id = 'guard-orphaned-due-avail'
   and user_id = '10000000-0000-0000-0000-000000000015';

update public.change_schedule_activations
   set status = 'activated',
       activated_at = '2026-10-16 00:00:00+00',
       updated_at = '2026-10-16 00:00:00+00'
 where id = 'activation-orphaned-due-scheduled';
alter table public.change_schedule_activations enable trigger change_schedule_activations_integrity;
set role service_role;

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'accepted',
           scheduled_plan_version_id = null,
           accepted_plan_version_id = 'candidate-plan-missing-terminal-snapshot',
           accepted_at = '2026-10-16 00:00:00+00',
           accepted_availability_version_id = 'guard-orphaned-due-avail'
     where id = 'proposal-missing-terminal-snapshot'
  $$,
  'P0001',
  'change_schedule_accept_prior_plan_not_found',
  'scheduled proposal acceptance is rejected when terminal activation snapshot is missing'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-missing-terminal-snapshot'
  ),
  'scheduled',
  'missing-snapshot proposal remains scheduled when acceptance is rejected'
);

select is(
  (
    select prior_active_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-missing-terminal-snapshot'
  ),
  null::text,
  'missing-snapshot proposal keeps prior active plan unset'
);

select is(
  (
    select prior_active_availability_version_id
      from public.change_schedule_proposals
     where id = 'proposal-missing-terminal-snapshot'
  ),
  null::text,
  'missing-snapshot proposal keeps prior active availability unset'
);

update public.change_schedule_availability_versions
   set lifecycle_state = 'scheduled'
 where id = 'guard-orphaned-due-avail';

-- Guard against one-shot terminal relinking while activating a scheduled row.
update public.change_schedule_availability_versions
   set lifecycle_state = 'cancelled'
 where id = 'guard-orphaned-due-avail';

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values
(
  'candidate-plan-guard-valid',
  '10000000-0000-0000-0000-000000000015',
  '2026-07-20 09:30:00+00',
  'onboarding',
  false,
  1,
  '{"id":"candidate-plan-guard-valid","weeks":[]}'::jsonb
),
(
  'candidate-plan-guard-unrelated',
  '10000000-0000-0000-0000-000000000015',
  '2026-07-20 09:31:00+00',
  'onboarding',
  false,
  1,
  '{"id":"candidate-plan-guard-unrelated","weeks":[]}'::jsonb
),
(
  'candidate-plan-guard-direct-activated',
  '10000000-0000-0000-0000-000000000015',
  '2026-07-20 09:32:00+00',
  'onboarding',
  false,
  1,
  '{"id":"candidate-plan-guard-direct-activated","weeks":[]}'::jsonb
)
;

insert into public.change_schedule_availability_versions (
  id,
  user_id,
  lifecycle_state,
  effective_from,
  target_running_days,
  primary_long_run_weekday,
  same_day_run_strength_preference,
  availability_data
) values
(
  'guard-scheduled-avail',
  '10000000-0000-0000-0000-000000000015',
  'scheduled',
  '2026-08-10',
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
  'guard-active-avail',
  '10000000-0000-0000-0000-000000000015',
  'active',
  '2026-08-10',
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
  scheduled_plan_version_id,
  created_at,
  updated_at,
  expires_at
) values
(
  'proposal-guard-valid',
  '10000000-0000-0000-0000-000000000015',
  'guard-user5-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"candidate-plan-guard-valid","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-08-10',
  'scheduled',
  'candidate-plan-guard-valid',
  '2026-07-20 09:32:00+00',
  '2026-07-20 09:32:00+00',
  '2026-08-10 09:00:00+00'
),
(
  'proposal-guard-unrelated',
  '10000000-0000-0000-0000-000000000015',
  'guard-user5-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"candidate-plan-guard-unrelated","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-08-10',
  'scheduled',
  'candidate-plan-guard-unrelated',
  '2026-07-20 09:33:00+00',
  '2026-07-20 09:33:00+00',
  '2026-08-10 09:00:00+00'
);

insert into public.change_schedule_activations (
  id,
  user_id,
  source_plan_version_id,
  queued_candidate_plan_version_id,
  availability_version_id,
  effective_from,
  status,
  created_at,
  updated_at
) values (
  'activation-guard-bypass',
  '10000000-0000-0000-0000-000000000015',
  'guard-user5-active-plan',
  'candidate-plan-guard-valid',
  'guard-scheduled-avail',
  '2026-08-10',
  'scheduled',
  '2026-07-20 09:34:00+00',
  '2026-07-20 09:34:00+00'
);

set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;
update public.change_schedule_activations
   set status = 'scheduled',
       proposal_id = null,
       activated_at = null,
       cancelled_at = null,
       stale_at = null,
       availability_version_id = 'guard-scheduled-avail',
       prior_active_plan_version_id = 'guard-user5-active-plan',
       prior_active_availability_version_id = 'guard-scheduled-avail',
       updated_at = '2026-07-20 09:34:00+00'
 where id = 'activation-guard-bypass';
alter table public.change_schedule_activations enable trigger change_schedule_activations_integrity;
set role service_role;

select throws_ok(
  $$
    update public.change_schedule_activations
       set status = 'activated',
           availability_version_id = 'guard-active-avail',
           prior_active_plan_version_id = 'guard-user5-active-plan',
           prior_active_availability_version_id = 'guard-scheduled-avail',
           activated_at = '2026-08-10 10:00:00+00'
     where id = 'activation-guard-bypass'
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'one-shot scheduled->activated null proposal relink is rejected'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-guard-bypass'
  ),
  'scheduled',
  'scheduled->activated null proposal relink keeps activation status unchanged'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-guard-bypass'
  ),
  null::text,
  'scheduled->activated null proposal relink keeps proposal_id unset'
);
select is(
  (
    select availability_version_id
      from public.change_schedule_activations
     where id = 'activation-guard-bypass'
  ),
  'guard-scheduled-avail',
  'scheduled->activated null proposal relink keeps scheduled availability reference'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set proposal_id = 'proposal-guard-unrelated',
           status = 'activated',
           availability_version_id = 'guard-active-avail',
           activated_at = '2026-08-10 10:00:00+00'
     where id = 'activation-guard-bypass'
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'one-shot scheduled->activated update cannot reassign a terminal proposal link'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-guard-bypass'
  ),
  'scheduled',
  'scheduled->activated one-shot proposal relink is rejected without mutating activation status'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-guard-bypass'
  ),
  null::text,
  'scheduled->activated one-shot proposal relink keeps proposal_id unset'
);
select is(
  (
    select availability_version_id
      from public.change_schedule_activations
     where id = 'activation-guard-bypass'
  ),
  'guard-scheduled-avail',
  'scheduled->activated one-shot proposal relink keeps scheduled availability reference'
);

delete from public.change_schedule_activations
 where id = 'activation-guard-bypass';

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
  updated_at
) values (
  'proposal-guard-direct-pending',
  '10000000-0000-0000-0000-000000000015',
  'guard-user5-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"candidate-plan-guard-direct-pending","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-08-10',
  'pending',
  '2026-07-20 09:41:00+00',
  '2026-07-20 09:41:00+00'
);

insert into public.change_schedule_activations (
  id,
  user_id,
  source_plan_version_id,
  queued_candidate_plan_version_id,
  availability_version_id,
  effective_from,
  status,
  created_at,
  updated_at
) values (
  'activation-guard-direct-pending-update',
  '10000000-0000-0000-0000-000000000015',
  'guard-user5-active-plan',
  'guard-user5-active-plan',
  'guard-scheduled-avail',
  '2026-08-10',
  'scheduled',
  '2026-07-20 09:42:00+00',
  '2026-07-20 09:42:00+00'
);

select throws_ok(
  $$
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
      'activation-guard-direct-pending-insert',
      '10000000-0000-0000-0000-000000000015',
      'guard-user5-active-plan',
      'guard-user5-active-plan',
      'guard-scheduled-avail',
      '2026-08-10',
      'scheduled',
      'proposal-guard-direct-pending',
      '2026-07-20 09:43:00+00',
      '2026-07-20 09:43:00+00'
    )
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'direct scheduled activation insert rejects unrelated pending proposal'
);
select is(
  (
    select count(*)::integer
      from public.change_schedule_activations
     where id = 'activation-guard-direct-pending-insert'
  ),
  0,
  'scheduled activation insert with unrelated pending proposal does not persist'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set proposal_id = 'proposal-guard-direct-pending'
     where id = 'activation-guard-direct-pending-update'
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'direct scheduled activation update rejects unrelated pending proposal'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-guard-direct-pending-update'
  ),
  null::text,
  'scheduled activation update to pending proposal keeps proposal_id unset'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-guard-direct-pending-update'
  ),
  'scheduled',
  'scheduled activation update to pending proposal keeps status'
);

-- Legacy scheduled rows with null proposal links are preserved on replacement and
-- terminalization binds the historical activation to the exact pre-existing proposal.
insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'legacy-null-replace-candidate-old',
  '10000000-0000-0000-0000-000000000014',
  '2026-09-07 08:00:00+00',
  'onboarding',
  false,
  1,
  '{"id":"legacy-null-replace-candidate-old","weeks":[]}'::jsonb
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
) values (
  'legacy-null-replace-avail-old',
  '10000000-0000-0000-0000-000000000014',
  'scheduled',
  '2026-09-14',
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
  created_at,
  updated_at,
  scheduled_plan_version_id,
  expires_at
) values (
  'proposal-null-replace-old',
  '10000000-0000-0000-0000-000000000014',
  'scheduled-user4-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"legacy-null-replace-candidate-old","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-09-14',
  'scheduled',
  '2026-09-07 08:20:00+00',
  '2026-09-07 08:20:00+00',
  'legacy-null-replace-candidate-old',
  '2026-09-13 08:00:00+00'
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
  'activation-null-replace-legacy',
  '10000000-0000-0000-0000-000000000014',
  'scheduled-user4-active-plan',
  'legacy-null-replace-candidate-old',
  'legacy-null-replace-avail-old',
  '2026-09-14',
  'scheduled',
  null,
  '2026-09-07 08:25:00+00',
  '2026-09-07 08:25:00+00'
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
  created_at,
  updated_at,
  scheduled_plan_version_id,
  expires_at
) values (
  'proposal-null-replace-new',
  '10000000-0000-0000-0000-000000000014',
  'scheduled-user4-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"legacy-null-replace-candidate-new","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-09-14',
  'pending',
  '2026-09-07 08:30:00+00',
  '2026-09-07 08:30:00+00',
  null,
  '2026-09-13 08:00:00+00'
);

create temporary table legacy_null_replacement as
select *
  from public.schedule_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000014',
    'proposal-null-replace-new',
    'legacy-null-replace-candidate-new',
    'legacy-null-replace-avail-new',
    '2026-09-07 09:00:00+00'
  );

select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-null-replace-legacy'
  ),
  'proposal-null-replace-old',
  'legacy replacement preserves null-link scheduled activation proposal_id before terminalization'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-null-replace-legacy'
  ),
  'superseded',
  'legacy replacement terminalizes old scheduled activation'
);

create temporary table legacy_null_replacement_retry as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000014',
    'activation-null-replace-legacy',
    '2026-09-14 00:00:00+00'
  );

select is(
  (select activation_status from legacy_null_replacement),
  'scheduled',
  'legacy scheduled replacement queues a replacement chain'
);
select is(
  (select proposal_id from legacy_null_replacement_retry),
  'proposal-null-replace-old',
  'legacy scheduled replacement retry returns exact historical proposal id'
);
select is(
  (select proposal_status from legacy_null_replacement_retry),
  'superseded',
  'legacy scheduled replacement retry preserves exact terminal status'
);

delete from public.change_schedule_activations
 where id = 'activation-guard-direct-pending-update';

create temporary table scheduled_store_guard as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000015',
    'proposal-guard-rpc-success',
    'guard-user5-active-plan',
    '{"id":"candidate-plan-guard-rpc-success","weeks":[]}'::jsonb,
    '{}'::jsonb,
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
    '2026-08-17',
    '2026-07-20 09:40:00+00',
    null,
    1,
    '2026-01-01 00:00:00+00'
  );

create temporary table scheduled_enqueued_guard as
select *
  from public.schedule_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000015',
    'proposal-guard-rpc-success',
    'queued-plan-guard-rpc-success',
    'queued-avail-guard-rpc-success',
    '2026-07-20 09:41:00+00'
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
  created_at,
  updated_at,
  accepted_plan_version_id,
  accepted_at
) values (
  'proposal-guard-rpc-success-alt',
  '10000000-0000-0000-0000-000000000015',
  'guard-user5-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"candidate-plan-guard-direct-activated","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-08-17',
  'accepted',
  '2026-07-20 09:50:00+00',
  '2026-07-20 09:50:00+00',
  'candidate-plan-guard-unrelated',
  '2026-07-20 09:50:00+00'
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
  created_at,
  updated_at,
  accepted_plan_version_id,
  accepted_at
) values (
  'proposal-guard-direct-activated',
  '10000000-0000-0000-0000-000000000015',
  'guard-user5-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"candidate-plan-guard-direct-activated","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-08-10',
  'accepted',
  '2026-07-20 09:50:00+00',
  '2026-07-20 09:50:00+00',
  'candidate-plan-guard-direct-activated',
  '2026-07-20 09:50:00+00'
);

select throws_ok(
  $$
insert into public.change_schedule_activations (
      id,
      user_id,
      source_plan_version_id,
      queued_candidate_plan_version_id,
      availability_version_id,
      effective_from,
      status,
      proposal_id,
      prior_active_plan_version_id,
      prior_active_availability_version_id,
      created_at,
      updated_at,
      activated_at
    ) values (
      'activation-guard-direct-activated',
      '10000000-0000-0000-0000-000000000015',
      'guard-user5-active-plan',
      'candidate-plan-guard-direct-activated',
      'guard-active-avail',
      '2026-08-10',
      'activated',
      'proposal-guard-direct-activated',
      'guard-user5-active-plan',
      'guard-active-avail',
      '2026-07-20 09:52:00+00',
      '2026-07-20 09:52:00+00',
      '2026-08-10 10:00:00+00'
    )
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'service role insert of activated activation with accepted proposal is rejected'
);
select is(
  (
    select count(*)::integer
      from public.change_schedule_activations
     where id = 'activation-guard-direct-activated'
  ),
  0,
  'rejected activated activation insert with accepted proposal does not persist'
);

create temporary table activation_guard_run as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000015',
    (select activation_id from scheduled_enqueued_guard),
    '2026-08-17 00:00:00+00'
  );

select is(
  (select proposal_status from activation_guard_run),
  'accepted',
  'normal scheduled activation remains accepted with stricter activation integrity'
);
select is(
  (select activation_status from activation_guard_run),
  'activated',
  'normal scheduled activation remains activated with stricter activation integrity'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = (select activation_id from scheduled_enqueued_guard)
  ),
  'proposal-guard-rpc-success',
  'normal scheduled activation keeps exactly the scheduled proposal link'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set proposal_id = 'proposal-guard-rpc-success-alt'
     where id = (select activation_id from scheduled_enqueued_guard)
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'activated chain relinking is rejected even for accepted candidates'
);
select is(
  (
    select proposal_id
     from public.change_schedule_activations
       where id = (select activation_id from scheduled_enqueued_guard)
  ),
  'proposal-guard-rpc-success',
  'activated relink attempt keeps original scheduled proposal id'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set proposal_id = null
     where id = (select activation_id from scheduled_enqueued_guard)
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'activated chain relinking cannot clear proposal_id'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = (select activation_id from scheduled_enqueued_guard)
  ),
  'proposal-guard-rpc-success',
  'activated relinking cannot clear proposal_id'
);

update public.change_schedule_availability_versions
   set lifecycle_state = 'cancelled'
 where id = 'queued-avail-guard-rpc-success'
   and user_id = '10000000-0000-0000-0000-000000000015';

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'candidate-plan-guard-mismatch-context',
  '10000000-0000-0000-0000-000000000015',
  '2026-07-20 10:00:00+00',
  'onboarding',
  false,
  1,
  '{"id":"candidate-plan-guard-mismatch-context","weeks":[]}'::jsonb
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
) values (
  'availability-guard-mismatch-context',
  '10000000-0000-0000-0000-000000000015',
  'scheduled',
  '2026-09-28',
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

update public.plan_versions
   set is_active = false
 where user_id = '10000000-0000-0000-0000-000000000015'
   and id <> 'guard-user5-active-plan';

update public.plan_versions
   set is_active = true
 where id = 'guard-user5-active-plan'
   and user_id = '10000000-0000-0000-0000-000000000015';

create temporary table proposal_context_mismatch_store as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000015',
    'proposal-guard-context-mismatch',
    'guard-user5-active-plan',
    '{"id":"candidate-plan-guard-mismatch-context","weeks":[]}'::jsonb,
    '{}'::jsonb,
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
    '2026-09-28',
    '2026-07-20 10:01:00+00',
    null,
    1,
    '2026-01-01 00:00:00+00'
  );

create temporary table proposal_context_mismatch_enqueue as
select *
  from public.schedule_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000015',
    'proposal-guard-context-mismatch',
    'queued-plan-guard-mismatch-context',
    'queued-avail-guard-mismatch-context',
    '2026-07-20 10:02:00+00'
  );

update public.change_schedule_availability_versions
   set lifecycle_state = 'active'
 where id = 'queued-avail-guard-mismatch-context'
   and user_id = '10000000-0000-0000-0000-000000000015';

update public.change_schedule_activations
   set status = 'activated',
       prior_active_plan_version_id = 'guard-user5-active-plan',
       prior_active_availability_version_id = 'availability-guard-mismatch-context',
       activated_at = '2026-09-28 00:00:00+00',
       updated_at = '2026-09-28 00:00:00+00'
 where id = (select activation_id from proposal_context_mismatch_enqueue);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'accepted',
           scheduled_plan_version_id = null,
           accepted_plan_version_id = 'candidate-plan-guard-mismatch-context',
           accepted_at = '2026-09-28 00:00:00+00',
           prior_active_plan_version_id = 'guard-user5-active-plan',
           prior_active_availability_version_id = 'availability-guard-mismatch-context',
           accepted_availability_version_id = 'availability-guard-mismatch-context'
     where id = 'proposal-guard-context-mismatch'
  $$,
  'P0001',
  'change_schedule_proposal_accepted_activation_context_mismatch',
  'scheduled acceptance with mismatched prior availability context is rejected'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-guard-context-mismatch'
  ),
  'scheduled',
  'mismatched prior availability acceptance attempt keeps proposal scheduled'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-guard-context-mismatch'
  ),
  'queued-plan-guard-mismatch-context',
  'mismatched prior availability acceptance attempt keeps scheduled proposal linkage'
);

select is(
  (
    select accepted_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-guard-context-mismatch'
  ),
  null::text,
  'mismatched prior availability acceptance attempt does not populate accepted plan'
);

select is(
  (
    select accepted_at
      from public.change_schedule_proposals
     where id = 'proposal-guard-context-mismatch'
  ),
  null::timestamptz,
  'mismatched prior availability acceptance attempt does not populate accepted timestamp'
);

select is(
  (
    select prior_active_availability_version_id
      from public.change_schedule_proposals
     where id = 'proposal-guard-context-mismatch'
  ),
  null::text,
  'mismatched prior availability acceptance attempt does not persist prior availability'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = (select activation_id from proposal_context_mismatch_enqueue)
  ),
  'activated',
  'mismatched proposal acceptance attempt leaves activation terminal state'
);

update public.change_schedule_availability_versions
   set lifecycle_state = 'cancelled'
 where id = 'queued-avail-guard-mismatch-context'
   and user_id = '10000000-0000-0000-0000-000000000015';

update public.plan_versions
   set is_active = false
 where id = 'guard-user5-active-plan'
   and user_id = '10000000-0000-0000-0000-000000000015';

-- Terminalized activation snapshots remain authoritative when source plan becomes inactive.
insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'guard-immutable-source',
  '10000000-0000-0000-0000-000000000015',
  '2026-07-20 10:30:00+00',
  'onboarding',
  true,
  1,
  '{"id":"guard-immutable-source","weeks":[]}'::jsonb
),
(
  'guard-immutable-candidate',
  '10000000-0000-0000-0000-000000000015',
  '2026-07-20 10:31:00+00',
  'settings_update',
  false,
  1,
  '{"id":"guard-immutable-candidate","weeks":[]}'::jsonb
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
) values (
  'guard-immutable-prior-avail',
  '10000000-0000-0000-0000-000000000015',
  'cancelled',
  '2026-09-21',
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
  'guard-immutable-queued-avail',
  '10000000-0000-0000-0000-000000000015',
  'scheduled',
  '2026-10-05',
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
  'guard-immutable-activated-avail',
  '10000000-0000-0000-0000-000000000015',
  'active',
  '2026-10-05',
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
  created_at,
  updated_at,
  accepted_plan_version_id,
  accepted_at,
  scheduled_plan_version_id
) values (
  'proposal-guard-immutable-context',
  '10000000-0000-0000-0000-000000000015',
  'guard-immutable-source',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"guard-immutable-candidate","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-10-05',
  'scheduled',
  '2026-07-20 10:30:00+00',
  '2026-07-20 10:30:00+00',
  null,
  null,
  'guard-immutable-candidate'
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
  'activation-guard-immutable-context',
  '10000000-0000-0000-0000-000000000015',
  'guard-immutable-source',
  'guard-immutable-candidate',
  'guard-immutable-queued-avail',
  '2026-10-05',
  'scheduled',
  'proposal-guard-immutable-context',
  '2026-07-20 10:30:00+00',
  '2026-07-20 10:30:00+00'
);

update public.change_schedule_activations
   set status = 'activated',
       availability_version_id = 'guard-immutable-activated-avail',
       activated_at = '2026-10-05 00:00:00+00',
       prior_active_plan_version_id = 'guard-immutable-source',
       prior_active_availability_version_id = 'guard-immutable-prior-avail',
       updated_at = '2026-10-05 00:00:00+00'
 where id = 'activation-guard-immutable-context';

select lives_ok(
  $$
    update public.change_schedule_proposals
       set status = 'accepted',
           scheduled_plan_version_id = null,
           accepted_plan_version_id = 'guard-immutable-candidate',
           accepted_at = '2026-10-05 00:00:00+00',
           prior_active_plan_version_id = 'guard-immutable-source',
           prior_active_availability_version_id = 'guard-immutable-prior-avail',
           accepted_availability_version_id = 'guard-immutable-activated-avail'
     where id = 'proposal-guard-immutable-context'
  $$,
  'scheduled proposal with stale source context accepts using immutable terminal activation snapshots'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-guard-immutable-context'
  ),
  'accepted',
  'scheduled proposal with immutable snapshots transitions to accepted'
);

select is(
  (
    select prior_active_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-guard-immutable-context'
  ),
  'guard-immutable-source',
  'scheduled proposal stores immutable prior active plan snapshot from terminal activation'
);

select is(
  (
    select prior_active_availability_version_id
      from public.change_schedule_proposals
     where id = 'proposal-guard-immutable-context'
  ),
  'guard-immutable-prior-avail',
  'scheduled proposal stores immutable prior active availability snapshot from terminal activation'
);

update public.plan_versions
   set is_active = false
 where id = 'guard-immutable-source';

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-guard-immutable-context'
  ),
  'activated',
  'snapshot-protected scheduled accepted leaves activation terminal'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set prior_active_plan_version_id = 'guard-immutable-candidate'
     where id = 'activation-guard-immutable-context'
  $$,
  'P0001',
  'change_schedule_activation_snapshot_immutable',
  'activated activation row blocks prior active plan snapshot mutation'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set prior_active_availability_version_id = 'guard-immutable-activated-avail'
     where id = 'activation-guard-immutable-context'
  $$,
  'P0001',
  'change_schedule_activation_snapshot_immutable',
  'activated activation row blocks prior active availability snapshot mutation'
);

select is(
  (
    select prior_active_plan_version_id
      from public.change_schedule_activations
     where id = 'activation-guard-immutable-context'
  ),
  'guard-immutable-source',
  'immutable context retains terminal prior active plan snapshot'
);

select is(
  (
    select prior_active_availability_version_id
      from public.change_schedule_activations
     where id = 'activation-guard-immutable-context'
  ),
  'guard-immutable-prior-avail',
  'immutable context retains terminal prior active availability snapshot'
);

update public.change_schedule_availability_versions
   set lifecycle_state = 'cancelled'
 where id in (
  'guard-immutable-prior-avail',
  'guard-immutable-activated-avail'
) and user_id = '10000000-0000-0000-0000-000000000015';

-- Legacy restored scheduled rows can be scheduled with a null proposal link and should persist
-- the deterministic proposal identity on first terminalization.
insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'candidate-plan-null-activate',
  '10000000-0000-0000-0000-000000000011',
  '2026-07-20 09:20:00+00',
  'onboarding',
  false,
  1,
  '{"id":"candidate-plan-null-activate","weeks":[]}'::jsonb
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
) values (
  'queued-avail-null-activate',
  '10000000-0000-0000-0000-000000000011',
  'scheduled',
  '2026-08-17',
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
  created_at,
  updated_at,
  scheduled_plan_version_id,
  expires_at
) values (
  'proposal-null-activate',
  '10000000-0000-0000-0000-000000000011',
  'scheduled-user1-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"candidate-plan-null-activate","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-08-17',
  'scheduled',
  '2026-08-01 09:00:00+00',
  '2026-08-01 09:00:00+00',
  'candidate-plan-null-activate',
  '2026-08-16 09:00:00+00'
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
  'activation-null-proposal-link',
  '10000000-0000-0000-0000-000000000011',
  'scheduled-user1-active-plan',
  'candidate-plan-null-activate',
  'queued-avail-null-activate',
  '2026-08-17',
  'scheduled',
  null,
  '2026-08-01 09:05:00+00',
  '2026-08-01 09:05:00+00'
);

create temporary table legacy_null_activate as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000011',
    'activation-null-proposal-link',
    '2026-08-17 00:00:00+00'
  );

select is(
  (select proposal_id from legacy_null_activate),
  'proposal-null-activate',
  'scheduled null proposal_id activation persists deterministic proposal link on first activate'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-null-proposal-link'
  ),
  'proposal-null-activate',
  'scheduled null proposal_id activation stores proposal_id during activate terminalization'
);

create temporary table legacy_null_activate_retry as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000011',
    'activation-null-proposal-link',
    '2026-08-17 01:00:00+00'
  );

select is(
  (select proposal_id from legacy_null_activate_retry),
  'proposal-null-activate',
  'legacy scheduled activate retry returns exact accepted proposal id'
);
select is(
  (select activation_status from legacy_null_activate_retry),
  'activated',
  'legacy scheduled activate retry preserves activated terminal status'
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
  'candidate-plan-null-cancel',
  '10000000-0000-0000-0000-000000000011',
  '2026-07-20 09:21:00+00',
  'onboarding',
  false,
  1,
  '{"id":"candidate-plan-null-cancel","weeks":[]}'::jsonb
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
) values (
  'queued-avail-null-cancel',
  '10000000-0000-0000-0000-000000000011',
  'scheduled',
  '2026-08-24',
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
  created_at,
  updated_at,
  scheduled_plan_version_id,
  expires_at
) values (
  'proposal-null-cancel',
  '10000000-0000-0000-0000-000000000011',
  'candidate-plan-null-activate',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"candidate-plan-null-cancel","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-08-24',
  'scheduled',
  '2026-08-02 09:00:00+00',
  '2026-08-02 09:00:00+00',
  'candidate-plan-null-cancel',
  '2026-08-23 09:00:00+00'
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
  'activation-null-cancel',
  '10000000-0000-0000-0000-000000000011',
  'candidate-plan-null-activate',
  'candidate-plan-null-cancel',
  'queued-avail-null-cancel',
  '2026-08-24',
  'scheduled',
  null,
  '2026-08-02 09:05:00+00',
  '2026-08-02 09:05:00+00'
);

create temporary table legacy_null_cancel as
select *
  from public.cancel_scheduled_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000011',
    'proposal-null-cancel',
    '2026-08-02 10:00:00+00'
  );

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-null-cancel'
  ),
  'cancelled',
  'scheduled null proposal_id activation terminalizes as cancelled'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-null-cancel'
  ),
  'proposal-null-cancel',
  'scheduled null proposal_id activation stores proposal_id during cancel terminalization'
);

create temporary table legacy_null_cancel_retry as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000011',
    'activation-null-cancel',
    '2026-08-24 00:00:00+00'
  );

select is(
  (select proposal_id from legacy_null_cancel_retry),
  'proposal-null-cancel',
  'scheduled null proposal_id cancellation retry resolves exact cancelled proposal id'
);
select is(
  (select proposal_status from legacy_null_cancel_retry),
  'cancelled',
  'scheduled null proposal_id cancellation retry returns cancelled proposal status'
);

-- Retry queries on terminalized chains use activation id directly and should not be ambiguous
-- when multiple terminal rows share source/effective metadata.
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
    'terminal-user3-candidate-cancelled',
    '10000000-0000-0000-0000-000000000013',
    '2026-07-20 08:30:00+00',
    'settings_update',
    false,
    1,
    '{"id":"terminal-user3-candidate-cancelled","weeks":[]}'::jsonb
  ),
  (
    'terminal-user3-candidate-superseded',
    '10000000-0000-0000-0000-000000000013',
    '2026-07-20 08:40:00+00',
    'settings_update',
    false,
    1,
    '{"id":"terminal-user3-candidate-superseded","weeks":[]}'::jsonb
  );

insert into public.change_schedule_availability_versions (
  id,
  user_id,
  lifecycle_state,
  effective_from,
  target_running_days,
  primary_long_run_weekday,
  availability_data,
  same_day_run_strength_preference
)
values
  (
    'terminal-avail-cancelled',
    '10000000-0000-0000-0000-000000000013',
    'scheduled',
    '2026-08-03',
    4,
    1,
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
    'separate_sessions'
  ),
  (
    'terminal-avail-superseded',
    '10000000-0000-0000-0000-000000000013',
    'cancelled',
    '2026-08-03',
    4,
    1,
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
      "same_day_run_strength_preference": "avoid_same_day"
    }'::jsonb,
    'avoid_same_day'
  ),
  (
    'terminal-avail-legacy',
    '10000000-0000-0000-0000-000000000013',
    'cancelled',
    '2026-08-03',
    4,
    1,
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
    'separate_sessions'
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
  created_at,
  updated_at,
  accepted_plan_version_id,
  accepted_at,
  scheduled_plan_version_id,
  prior_active_plan_version_id,
  prior_active_availability_version_id,
  accepted_availability_version_id
  ) values
(
  'proposal-terminal-cancelled',
  '10000000-0000-0000-0000-000000000013',
  'scheduled-user3-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"terminal-user3-candidate-cancelled","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-08-03',
  'scheduled',
  '2026-07-20 09:00:00+00',
  '2026-07-20 09:00:00+00',
  null,
  null,
  'terminal-user3-candidate-cancelled',
  null,
  null,
  null
),
(
  'proposal-terminal-superseded',
  '10000000-0000-0000-0000-000000000013',
  'scheduled-user3-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
    "same_day_run_strength_preference": "avoid_same_day"
  }'::jsonb,
  '{"id":"terminal-user3-candidate-superseded","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-08-03',
  'scheduled',
  '2026-07-20 09:05:00+00',
  '2026-07-20 09:05:00+00',
  null,
  null,
  'terminal-user3-candidate-superseded',
  null,
  null,
  null
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
  cancelled_at,
  superseded_at,
  stale_at,
  activated_at,
  created_at,
  updated_at
)
values
(
  'activation-terminal-cancelled',
  '10000000-0000-0000-0000-000000000013',
  'scheduled-user3-active-plan',
  'terminal-user3-candidate-cancelled',
  'terminal-avail-cancelled',
  '2026-08-03',
  'scheduled',
  'proposal-terminal-cancelled',
  null,
  null,
  null,
  null,
  '2026-08-10 09:00:00+00',
  '2026-08-10 09:00:00+00'
);

set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;

update public.change_schedule_activations
   set status = 'cancelled',
       cancelled_at = '2026-08-10 09:00:00+00'
 where id = 'activation-terminal-cancelled';

insert into public.change_schedule_activations (
  id,
  user_id,
  source_plan_version_id,
  queued_candidate_plan_version_id,
  availability_version_id,
  effective_from,
  status,
  proposal_id,
  cancelled_at,
  superseded_at,
  stale_at,
  activated_at,
  created_at,
  updated_at
) values
  (
    'activation-terminal-superseded',
    '10000000-0000-0000-0000-000000000013',
    'scheduled-user3-active-plan',
    'terminal-user3-candidate-superseded',
    'terminal-avail-cancelled',
  '2026-08-03',
  'scheduled',
  'proposal-terminal-superseded',
  null,
  null,
  null,
  null,
  '2026-08-10 09:00:00+00',
  '2026-08-10 09:00:00+00'
);

update public.change_schedule_activations
   set status = 'superseded',
       superseded_at = '2026-08-10 09:00:00+00'
 where id = 'activation-terminal-superseded';

insert into public.change_schedule_activations (
  id,
  user_id,
  source_plan_version_id,
  queued_candidate_plan_version_id,
  availability_version_id,
  effective_from,
  status,
  proposal_id,
  cancelled_at,
  superseded_at,
  stale_at,
  activated_at,
  created_at,
  updated_at
) values
(
  'activation-terminal-legacy',
  '10000000-0000-0000-0000-000000000013',
  'scheduled-user3-active-plan',
  'terminal-user3-candidate-cancelled',
  'terminal-avail-legacy',
  '2026-08-03',
  'cancelled',
  null,
  '2026-08-10 09:00:00+00',
  null,
  null,
  null,
  '2026-08-10 09:00:00+00',
  '2026-08-10 09:00:00+00'
 );

alter table public.change_schedule_activations enable trigger change_schedule_activations_integrity;
set role service_role;

update public.change_schedule_proposals
   set status = 'cancelled',
       scheduled_plan_version_id = null,
       cancelled_at = '2026-08-10 09:00:00+00',
       updated_at = '2026-08-10 09:00:00+00'
 where id = 'proposal-terminal-cancelled'
   and user_id = '10000000-0000-0000-0000-000000000013';
update public.change_schedule_proposals
   set status = 'superseded',
       scheduled_plan_version_id = null,
       superseded_at = '2026-08-10 09:00:00+00',
       updated_at = '2026-08-10 09:00:00+00'
 where id = 'proposal-terminal-superseded'
   and user_id = '10000000-0000-0000-0000-000000000013';

create temporary table terminal_activation_retry_cancelled as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000013',
    'activation-terminal-cancelled',
    '2026-08-10 10:00:00+00'
  );

select is(
  (select proposal_id from terminal_activation_retry_cancelled),
  'proposal-terminal-cancelled',
  'retrying cancelled terminal chain resolves proposal by activation id'
);
select is(
  (select proposal_status from terminal_activation_retry_cancelled),
  'cancelled',
  'retrying cancelled terminal chain resolves proposal_status as cancelled'
);
select is(
  (select activation_status from terminal_activation_retry_cancelled),
  'cancelled',
  'retrying cancelled terminal chain preserves terminal activation status'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-terminal-cancelled'
  ),
  'proposal-terminal-cancelled',
  'cancelled terminal activation row preserves exact linked proposal_id'
);

create temporary table terminal_activation_retry_superseded as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000013',
    'activation-terminal-superseded',
    '2026-08-10 10:00:00+00'
  );

select is(
  (select proposal_id from terminal_activation_retry_superseded),
  'proposal-terminal-superseded',
  'retrying superseded terminal chain resolves proposal by activation id'
);
select is(
  (select proposal_status from terminal_activation_retry_superseded),
  'superseded',
  'retrying superseded terminal chain resolves proposal_status as superseded'
);
select is(
  (select activation_status from terminal_activation_retry_superseded),
  'superseded',
  'retrying superseded terminal chain preserves terminal activation status'
);
select is(
  (
    select proposal_id
     from public.change_schedule_activations
     where id = 'activation-terminal-superseded'
  ),
  'proposal-terminal-superseded',
  'superseded terminal activation row preserves exact linked proposal_id'
);

-- Malformed terminal links must not be tolerated on retry for terminalized nonnull proposals.
set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;

update public.change_schedule_activations
   set proposal_id = 'proposal-terminal-superseded'
 where id = 'activation-terminal-cancelled';

update public.change_schedule_activations
   set proposal_id = 'proposal-terminal-cancelled'
 where id = 'activation-terminal-superseded';

alter table public.change_schedule_activations enable trigger change_schedule_activations_integrity;
set role service_role;

select throws_ok(
  $$
    select *
      from public.activate_due_change_schedule(
        '10000000-0000-0000-0000-000000000013',
        'activation-terminal-cancelled',
        '2026-08-10 10:05:00+00'
      )
  $$,
  'P0001',
  'change_schedule_activation_proposal_not_available',
  'retrying cancelled terminal chain rejects nonnull malformed proposal lineage'
);
select throws_ok(
  $$
    select *
      from public.activate_due_change_schedule(
        '10000000-0000-0000-0000-000000000013',
        'activation-terminal-superseded',
        '2026-08-10 10:05:00+00'
      )
  $$,
  'P0001',
  'change_schedule_activation_proposal_not_available',
  'retrying superseded terminal chain rejects nonnull malformed proposal lineage'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-terminal-cancelled'
  ),
  'cancelled'::text,
  'cancelled terminal activation keeps cancelled status after malformed retry rejection'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-terminal-cancelled'
  ),
  'proposal-terminal-superseded'::text,
  'cancelled terminal activation keeps malformed nonnull proposal_id and does not adopt another proposal'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-terminal-superseded'
  ),
  'superseded'::text,
  'superseded terminal activation keeps superseded status after malformed retry rejection'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-terminal-superseded'
  ),
  'proposal-terminal-cancelled'::text,
  'superseded terminal activation keeps malformed nonnull proposal_id and does not adopt another proposal'
);

-- Historical accepted activation for user3 to confirm stale retries target exact activation id.
insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values
(
  'legacy-accepted-plan-user3',
  '10000000-0000-0000-0000-000000000013',
  '2026-07-20 08:00:00+00',
  'onboarding',
  false,
  1,
  '{"id":"legacy-accepted-plan-user3","weeks":[]}'::jsonb
);

set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;

insert into public.change_schedule_activations (
  id,
  user_id,
  source_plan_version_id,
  queued_candidate_plan_version_id,
  availability_version_id,
  effective_from,
  status,
  created_at,
  updated_at,
  activated_at
) values
(
  'legacy-activation-user3',
  '10000000-0000-0000-0000-000000000013',
  'scheduled-user3-active-plan',
  'legacy-accepted-plan-user3',
  'active-avail-user3',
  '2026-07-20',
  'activated',
  '2026-07-20 08:10:00+00',
  '2026-07-20 08:10:00+00',
	  '2026-07-20 08:10:00+00'
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
  created_at,
  updated_at,
  accepted_plan_version_id,
  accepted_at
) values
(
  'proposal-stale-source-legacy-history',
  '10000000-0000-0000-0000-000000000013',
  'scheduled-user3-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"legacy-candidate-plan-user3","weeks":[]}'::jsonb,
  '{"legacy":true}'::jsonb,
  '2026-07-20',
  'accepted',
  '2026-07-20 08:09:00+00',
  '2026-07-20 08:10:00+00',
  'legacy-accepted-plan-user3',
  '2026-07-20 08:10:00+00'
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
  'legacy-unmatched-accepted-plan-user3',
  '10000000-0000-0000-0000-000000000013',
  '2026-07-20 08:15:00+00',
  'onboarding',
  false,
  1,
  '{"id":"legacy-unmatched-accepted-plan-user3","weeks":[]}'::jsonb
);

set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;

insert into public.change_schedule_activations (
  id,
  user_id,
  source_plan_version_id,
  queued_candidate_plan_version_id,
  availability_version_id,
  effective_from,
  status,
  created_at,
  updated_at,
  activated_at
) values (
  'activation-legacy-unlinkable',
  '10000000-0000-0000-0000-000000000013',
  'scheduled-user3-active-plan',
  'legacy-unmatched-accepted-plan-user3',
  'active-avail-user3',
  '2026-07-20',
  'activated',
  '2026-07-20 08:15:00+00',
  '2026-07-20 08:15:00+00',
  '2026-07-20 08:15:00+00'
);

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

alter table public.change_schedule_activations enable trigger change_schedule_activations_integrity;
set role service_role;

select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'legacy-activation-user3'
  ),
  'proposal-stale-source-legacy-history',
  'historical accepted activation for user3 backfills to exact matching accepted proposal'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-legacy-unlinkable'
  ),
  null::text,
  'historical activated chain without deterministic accepted match remains unresolved'
);

create temporary table terminal_activation_retry_legacy_cancelled as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000013',
    'activation-terminal-legacy',
    '2026-08-10 10:00:00+00'
  );

select is(
  (select proposal_id from terminal_activation_retry_legacy_cancelled),
  null::text,
  'legacy terminal activation with null proposal_id does not get bound to an unrelated proposal'
);
select is(
  (select proposal_status from terminal_activation_retry_legacy_cancelled),
  'cancelled',
  'legacy terminal retry falls back to terminal proposal status'
);

create temporary table terminal_activation_retry_legacy as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000013',
    'legacy-activation-user3',
    '2026-08-10 10:00:00+00'
  );

select is(
  (select proposal_id from terminal_activation_retry_legacy),
  'proposal-stale-source-legacy-history',
  'retrying accepted historical activated row resolves exact linked proposal'
);
select is(
  (select proposal_status from terminal_activation_retry_legacy),
  'accepted',
  'historical activated retry surfaces accepted proposal status'
);
select is(
  (select activation_status from terminal_activation_retry_legacy),
  'activated',
  'historical activated retry preserves terminal activation status'
);

create temporary table terminal_activation_retry_legacy_again as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000013',
    'legacy-activation-user3',
    '2026-08-10 10:05:00+00'
  );

select is(
  (select proposal_id from terminal_activation_retry_legacy_again),
  'proposal-stale-source-legacy-history',
  'retrying accepted historical activated row remains exact linked proposal'
);

select throws_ok(
  $$
    select *
      from public.activate_due_change_schedule(
        '10000000-0000-0000-0000-000000000013',
        'activation-legacy-unlinkable',
        '2026-08-10 10:05:00+00'
      )
  $$,
  'P0001',
  'change_schedule_activation_proposal_not_available',
  'historical activated chain with unresolved proposal mapping errors explicitly'
);

select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-legacy-unlinkable'
  ),
  null::text,
  'unresolvable historical activated retry keeps proposal_id null'
);

-- A scheduled chain whose source plan is no longer active should become stale while retaining candidate links as pending replacement state.
create temporary table stale_source_store as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000013',
    'proposal-stale-source',
    'scheduled-user3-active-plan',
  '{"id":"queued-plan-stale-source","weeks":[]}'::jsonb,
    '{"impact":"stale-source"}'::jsonb,
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
      "same_day_run_strength_preference": "avoid_same_day"
    }'::jsonb,
    '2026-07-27',
    '2026-07-20 09:11:00+00',
    null,
    1,
    '2026-01-01 00:00:00+00'
  );

create temporary table stale_source_enqueue as
select *
  from public.schedule_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000013',
    'proposal-stale-source',
    'queued-plan-stale-source',
    'queued-avail-stale-source',
    '2026-07-20 09:12:00+00'
  );

update public.plan_versions
   set is_active = false
 where id = 'scheduled-user3-active-plan';

create temporary table stale_source_activate as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000013',
    (select activation_id from stale_source_enqueue),
    '2026-07-27 00:00:00+00'
  );

select is(
  (select activation_status from stale_source_activate),
  'stale',
  'stale source plan activation returns stale status'
);
select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-stale-source'
  ),
  'superseded',
  'proposal with stale source plan is superseded'
);
select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-stale-source'
  ),
  null::text,
  'proposal with stale source plan drops queued plan link'
);
select is(
  (
    select lifecycle_state
      from public.change_schedule_availability_versions
     where id = 'queued-avail-stale-source'
  ),
  'scheduled',
  'stale source terminalization keeps queued availability scheduled'
);
select is(
  (
    select is_active
      from public.plan_versions
     where id = 'queued-plan-stale-source'
  ),
  false,
  'stale source terminalization does not activate queued plan'
);

create temporary table stale_source_activate_retry as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000013',
    (select activation_id from stale_source_enqueue),
    '2026-07-27 01:00:00+00'
  );

select is(
  (select activation_status from stale_source_activate_retry),
  'stale',
  'retry after stale source activation returns stale against exact activation'
);
select is(
  (select proposal_id from stale_source_activate_retry),
  (select proposal_id from stale_source_activate),
  'stale source retry returns same proposal id for exact activation'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = (select activation_id from stale_source_activate)
  ),
  'proposal-stale-source',
  'stale source activation preserves exact proposal link after first terminalization'
);

set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;

update public.change_schedule_activations
   set proposal_id = 'proposal-terminal-superseded'
 where id = (select activation_id from stale_source_activate);

alter table public.change_schedule_activations enable trigger change_schedule_activations_integrity;
set role service_role;

select throws_ok(
  $$
    select *
      from public.activate_due_change_schedule(
        '10000000-0000-0000-0000-000000000013',
        (select activation_id from stale_source_activate),
        '2026-07-27 02:00:00+00'
      )
  $$,
  'P0001',
  'change_schedule_activation_proposal_not_available',
  'stale terminal retry rejects nonnull malformed proposal lineage'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where id = (select activation_id from stale_source_activate)
  ),
  'stale'::text,
  'stale terminal activation keeps stale status after malformed retry rejection'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = (select activation_id from stale_source_activate)
  ),
  'proposal-terminal-superseded'::text,
  'stale terminal activation keeps malformed nonnull proposal_id and does not adopt unrelated proposal'
);

-- A scheduled chain with stale profile snapshot should become stale and preserve queued availability state.
insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values
(
  'legacy-accepted-plan-user4',
  '10000000-0000-0000-0000-000000000014',
  '2026-07-20 08:20:00+00',
  'onboarding',
  false,
  1,
  '{"id":"legacy-accepted-plan-user4","weeks":[]}'::jsonb
);

savepoint legacy_user4_activation_history;
set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;

insert into public.change_schedule_activations (
  id,
  user_id,
  source_plan_version_id,
  queued_candidate_plan_version_id,
  availability_version_id,
  effective_from,
  status,
  created_at,
  updated_at,
  activated_at
) values
(
  'legacy-activation-user4',
  '10000000-0000-0000-0000-000000000014',
  'scheduled-user4-active-plan',
  'legacy-accepted-plan-user4',
  'active-avail-user4',
  '2026-07-20',
  'activated',
  '2026-07-20 08:20:00+00',
  '2026-07-20 08:20:00+00',
  '2026-07-20 08:20:00+00'
);
alter table public.change_schedule_activations enable trigger change_schedule_activations_integrity;
set role service_role;

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
  updated_at,
  accepted_plan_version_id,
  accepted_at
) values
(
  'proposal-stale-profile-legacy-history',
  '10000000-0000-0000-0000-000000000014',
  'scheduled-user4-active-plan',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"legacy-candidate-plan-user4","weeks":[]}'::jsonb,
  '{"legacy":true}'::jsonb,
  '2026-07-20',
  'accepted',
  '2026-07-20 08:21:00+00',
  '2026-07-20 08:22:00+00',
  'legacy-accepted-plan-user4',
  '2026-07-20 08:22:00+00'
);

create temporary table stale_profile_store as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000014',
    'proposal-stale-profile',
    'scheduled-user4-active-plan',
  '{"id":"queued-plan-stale-profile","weeks":[]}'::jsonb,
    '{"impact":"stale-profile"}'::jsonb,
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
    '2026-07-27',
    '2026-07-20 09:13:00+00',
    null,
    1,
    '2026-01-01 00:00:00+00'
  );

create temporary table stale_profile_enqueue as
select *
  from public.schedule_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000014',
    'proposal-stale-profile',
    'queued-plan-stale-profile',
    'queued-avail-stale-profile',
    '2026-07-20 09:14:00+00'
  );

update public.runner_profiles
   set updated_at = '2026-01-02 00:00:00+00'
 where user_id = '10000000-0000-0000-0000-000000000014';

create temporary table stale_profile_activate as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000014',
    (select activation_id from stale_profile_enqueue),
    '2026-07-27 00:00:00+00'
  );

select is(
  (select activation_status from stale_profile_activate),
  'stale',
  'stale profile snapshot activation returns stale status'
);
select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-stale-profile'
  ),
  'superseded',
  'proposal with stale profile snapshot is superseded'
);
select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-stale-profile'
  ),
  null::text,
  'proposal with stale profile snapshot drops queued plan link'
);
select is(
  (
    select lifecycle_state
      from public.change_schedule_availability_versions
     where id = 'queued-avail-stale-profile'
  ),
  'scheduled',
  'stale profile terminalization keeps queued availability scheduled'
);
select is(
  (
    select is_active
      from public.plan_versions
     where id = 'queued-plan-stale-profile'
  ),
  false,
  'stale profile terminalization does not activate queued plan'
);
select is(
  (
    select is_active
      from public.plan_versions
     where id = 'scheduled-user4-active-plan'
  ),
  true,
  'stale profile terminalization keeps source plan active'
);

create temporary table stale_profile_activate_retry as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000014',
    (select activation_id from stale_profile_enqueue),
    '2026-07-27 01:00:00+00'
  );

select is(
  (select activation_status from stale_profile_activate_retry),
  'stale',
  'retry after stale profile activation returns stale against exact activation'
);
select is(
  (select proposal_id from stale_profile_activate_retry),
  (select proposal_id from stale_profile_activate),
  'stale profile retry returns same proposal id for exact activation'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = (select activation_id from stale_profile_activate)
  ),
  'proposal-stale-profile',
  'stale profile activation preserves exact proposal link after first terminalization'
);

-- Direct scheduled terminalization is constrained to immutable proposal lineage.
insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'queued-plan-lineage-rewrite',
  '10000000-0000-0000-0000-000000000011',
  '2026-07-20 09:00:00+00',
  'settings_update',
  false,
  1,
  '{"id":"queued-plan-lineage-rewrite","weeks":[]}'::jsonb
);

update public.plan_versions
   set is_active = false
 where user_id = '10000000-0000-0000-0000-000000000011'
   and is_active = true;

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'source-plan-lineage-rewrite',
  '10000000-0000-0000-0000-000000000011',
  '2026-07-20 09:10:00+00',
  'settings_update',
  true,
  1,
  '{"id":"source-plan-lineage-rewrite","weeks":[]}'::jsonb
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
  created_at,
  updated_at,
  expires_at,
  scheduled_plan_version_id
) values (
  'proposal-terminal-lineage-rewrite',
  '10000000-0000-0000-0000-000000000011',
  'source-plan-lineage-rewrite',
  1,
  '2026-01-01 00:00:00+00',
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
    "same_day_run_strength_preference": "avoid_same_day"
  }'::jsonb,
  '{"id":"candidate-lineage-guard","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-07-27',
  'scheduled',
  '2026-07-20 10:00:00+00',
  '2026-07-20 10:00:00+00',
  '2026-07-20 10:30:00+00',
  'queued-plan-lineage-rewrite'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set candidate_plan = '{"id":"candidate-lineage-guard-mutated","weeks":[]}'::jsonb,
           impact = '{"mutated":true}'::jsonb,
           proposed_availability = '{
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
     where id = 'proposal-terminal-lineage-rewrite'
  $$,
  'P0001',
  'change_schedule_proposal_scheduled_rewrite_rejected',
  'same-state scheduled updates cannot rewrite candidate/availability/audit payload fields'
);

select is(
  (
    select candidate_plan ->> 'id'
      from public.change_schedule_proposals
     where id = 'proposal-terminal-lineage-rewrite'
  ),
  'candidate-lineage-guard',
  'scheduled proposal rewrite rejection preserves candidate_plan'
);

select is(
  (
    select proposed_availability ->> 'same_day_run_strength_preference'
      from public.change_schedule_proposals
     where id = 'proposal-terminal-lineage-rewrite'
  ),
  'avoid_same_day',
  'scheduled proposal rewrite rejection preserves availability preference'
);

select is(
  (
    select impact::text
      from public.change_schedule_proposals
     where id = 'proposal-terminal-lineage-rewrite'
  ),
  '{}'::text,
  'scheduled proposal rewrite rejection preserves impact payload'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set scheduled_plan_version_id = 'queued-plan-lineage-rewrite-mutated'
     where id = 'proposal-terminal-lineage-rewrite'
  $$,
  'P0001',
  'change_schedule_proposal_scheduled_rewrite_rejected',
  'same-state scheduled updates cannot rewrite scheduled plan chain linkage'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-terminal-lineage-rewrite'
  ),
  'queued-plan-lineage-rewrite',
  'scheduled rewrite rejection preserves scheduled_plan_version_id'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'cancelled',
           scheduled_plan_version_id = null,
           user_id = '10000000-0000-0000-0000-000000000011',
           source_plan_version_id = 'scheduled-user1-active-plan',
           source_profile_schema_version = 1,
           source_profile_updated_at = '2026-01-01 00:00:00+00',
           cancelled_at = '2026-07-20 10:10:00+00'
     where id = 'proposal-terminal-lineage-rewrite'
  $$,
  'P0001',
  'change_schedule_proposal_terminalization_lineage_rewrite',
  'scheduled terminalization rejects lineage rewrite to a valid active source'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-terminal-lineage-rewrite'
  ),
  'scheduled',
  'lineage rewrite rejection keeps proposal status scheduled'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-terminal-lineage-rewrite'
  ),
  'queued-plan-lineage-rewrite',
  'lineage rewrite rejection does not clear scheduled_plan_version_id'
);

update public.plan_versions
   set is_active = false
 where id = 'source-plan-lineage-rewrite';

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'superseded',
           scheduled_plan_version_id = null,
           superseded_at = '2026-07-20 10:15:00+00'
     where id = 'proposal-terminal-lineage-rewrite'
  $$,
  'P0001',
  'change_schedule_proposal_terminalization_activation_not_found',
  'scheduled proposal terminalization is rejected when no exact terminal activation exists'
);

select is(
  (
    select status
     from public.change_schedule_proposals
     where id = 'proposal-terminal-lineage-rewrite'
  ),
  'scheduled',
  'proposal terminalization without terminal activation keeps status scheduled'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-terminal-lineage-rewrite'
  ),
  'queued-plan-lineage-rewrite',
  'proposal terminalization without terminal activation keeps scheduled plan link'
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
  'direct-activation-source',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-20 11:00:00+00',
  'onboarding',
  true,
  1,
  '{"id":"direct-activation-source","weeks":[]}'::jsonb
),
(
  'direct-activation-candidate',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-20 11:01:00+00',
  'onboarding',
  false,
  1,
  '{"id":"direct-activation-candidate","weeks":[]}'::jsonb
),
(
  'direct-activation-candidate-mismatch',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-20 11:02:00+00',
  'onboarding',
  false,
  1,
  '{"id":"direct-activation-candidate-mismatch","weeks":[]}'::jsonb
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
) values (
  'direct-activation-avail',
  '10000000-0000-0000-0000-000000000002',
  'scheduled',
  '2026-09-21',
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
  created_at,
  updated_at,
  accepted_plan_version_id,
  accepted_at,
  scheduled_plan_version_id
) values (
  'proposal-terminal-direct-only',
  '10000000-0000-0000-0000-000000000002',
  'direct-activation-source',
  1,
  '2026-01-01 00:00:00+00',
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
  '{"id":"direct-activation-candidate","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-09-21',
  'scheduled',
  '2026-07-20 11:10:00+00',
  '2026-07-20 11:10:00+00',
  null,
  null,
  'direct-activation-candidate'
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
  'activation-direct-terminal-only',
  '10000000-0000-0000-0000-000000000002',
  'direct-activation-source',
  'direct-activation-candidate',
  'direct-activation-avail',
  '2026-09-21',
  'scheduled',
  'proposal-terminal-direct-only',
  '2026-07-20 11:10:00+00',
  '2026-07-20 11:10:00+00'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'cancelled',
           scheduled_plan_version_id = null,
           cancelled_at = '2026-09-20 11:20:00+00'
     where id = 'proposal-terminal-direct-only'
  $$,
  'P0001',
  'change_schedule_proposal_terminalization_activation_not_found',
  'proposal-only scheduled cancellation is rejected when activation is not terminalized'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  'scheduled',
  'proposal-only scheduled cancellation keeps proposal scheduled'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  'direct-activation-candidate',
  'proposal-only scheduled cancellation does not clear scheduled linkage'
);

select is(
  (
    select accepted_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  null::text,
  'proposal-only scheduled cancellation does not populate accepted plan'
);

select is(
  (
    select accepted_at
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  null::timestamptz,
  'proposal-only scheduled cancellation does not populate accepted timestamp'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-direct-terminal-only'
  ),
  'scheduled',
  'proposal-only scheduled cancellation keeps activation scheduled'
);

savepoint direct_terminal_only_legacy_rows;
set role postgres;
alter table public.change_schedule_activations disable trigger change_schedule_activations_integrity;

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
  updated_at,
  cancelled_at
) values (
  'activation-direct-terminal-only-mismatch',
  '10000000-0000-0000-0000-000000000002',
  'direct-activation-source',
  'direct-activation-candidate-mismatch',
  'direct-activation-avail',
  '2026-09-21',
  'cancelled',
  null,
  '2026-07-20 11:11:00+00',
  '2026-07-20 11:11:00+00',
  '2026-07-20 11:11:00+00'
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
  updated_at,
  cancelled_at
) values (
  'activation-direct-terminal-only-null',
  '10000000-0000-0000-0000-000000000002',
  'direct-activation-source',
  'direct-activation-candidate',
  'direct-activation-avail',
  '2026-09-21',
  'cancelled',
  null,
  '2026-07-20 11:12:00+00',
  '2026-07-20 11:12:00+00',
  '2026-07-20 11:12:00+00'
);
alter table public.change_schedule_activations enable trigger change_schedule_activations_integrity;
set role service_role;

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'cancelled',
           scheduled_plan_version_id = null,
           cancelled_at = '2026-09-20 11:23:00+00'
     where id = 'proposal-terminal-direct-only'
  $$,
  'P0001',
  'change_schedule_proposal_terminalization_activation_not_found',
  'proposal-only scheduled cancellation is rejected when terminal activation is legacy null-linked'
);

select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-direct-terminal-only-null'
  ),
  null::text,
  'legacy terminalized activation is not retroactively linked during scheduled cancellation'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'cancelled',
           scheduled_plan_version_id = null,
           cancelled_at = '2026-09-20 11:22:00+00'
     where id = 'proposal-terminal-direct-only'
  $$,
  'P0001',
  'change_schedule_proposal_terminalization_activation_not_found',
  'proposal-only scheduled cancellation is rejected when terminal activation chain is mismatched'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  'scheduled',
  'mismatched terminal activation does not alter proposal scheduled state'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'superseded',
           scheduled_plan_version_id = null,
           superseded_at = '2026-09-20 11:21:00+00'
     where id = 'proposal-terminal-direct-only'
  $$,
  'P0001',
  'change_schedule_proposal_terminalization_activation_not_found',
  'proposal-only scheduled superseded is rejected when activation is not terminalized'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  'scheduled',
  'proposal-only scheduled superseded keeps proposal scheduled'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  'direct-activation-candidate',
  'proposal-only scheduled superseded does not clear scheduled linkage'
);

select is(
  (
    select accepted_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  null::text,
  'proposal-only scheduled superseded does not populate accepted plan'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'accepted',
           scheduled_plan_version_id = null
     where id = 'proposal-terminal-direct-only'
  $$,
  'P0001',
  'change_schedule_proposal_acceptance_requires_activated_activation',
  'proposal-only scheduled accepted is rejected without activated activation'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  'scheduled',
  'proposal-only scheduled accepted keeps proposal scheduled'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  'direct-activation-candidate',
  'proposal-only scheduled accepted does not clear scheduled linkage'
);

select is(
  (
    select accepted_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  null::text,
  'proposal-only scheduled accepted does not populate accepted plan'
);

select is(
  (
    select accepted_at
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  null::timestamptz,
  'proposal-only scheduled accepted does not populate accepted timestamp'
);

select is(
  (
    select prior_active_availability_version_id
      from public.change_schedule_proposals
     where id = 'proposal-terminal-direct-only'
  ),
  null::text,
  'proposal-only scheduled accepted does not populate prior active availability'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-direct-terminal-only'
  ),
  'scheduled',
  'proposal-only scheduled accepted keeps activation scheduled'
);

-- Permissions: only service role can execute scheduled lifecycle RPCs.
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz)',
    'EXECUTE'
  ),
  'authenticated users cannot execute queue scheduling RPC'
);
select ok(
  not has_function_privilege(
    'public',
    'public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz)',
    'EXECUTE'
  ),
  'public role cannot execute queue scheduling RPC'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz)',
    'EXECUTE'
  ),
  'anon role cannot execute queue scheduling RPC'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.cancel_scheduled_change_schedule_proposal(uuid,text,timestamptz)',
    'EXECUTE'
  ),
  'authenticated users cannot execute queue cancel RPC'
);
select ok(
  not has_function_privilege(
    'public',
    'public.cancel_scheduled_change_schedule_proposal(uuid,text,timestamptz)',
    'EXECUTE'
  ),
  'public role cannot execute queue cancellation RPC'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.cancel_scheduled_change_schedule_proposal(uuid,text,timestamptz)',
    'EXECUTE'
  ),
  'anon role cannot execute queue cancellation RPC'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.activate_due_change_schedule(uuid,text,timestamptz)',
    'EXECUTE'
  ),
  'authenticated users cannot execute activation due RPC'
);
select ok(
  not has_function_privilege(
    'public',
    'public.activate_due_change_schedule(uuid,text,timestamptz)',
    'EXECUTE'
  ),
  'public role cannot execute activation due RPC'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.activate_due_change_schedule(uuid,text,timestamptz)',
    'EXECUTE'
  ),
  'anon role cannot execute activation due RPC'
);

select * from finish();

rollback;
