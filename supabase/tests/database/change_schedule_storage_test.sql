create extension if not exists pgtap with schema extensions;

set search_path to public, extensions;

begin;

select no_plan();

insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000001', 'change-schedule-main@example.test'),
  ('10000000-0000-0000-0000-000000000002', 'change-schedule-peer@example.test');

insert into runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000001',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    1,
    '2026-01-01 00:00:00+00',
    '{"goal":{"race":"5k"}}'::jsonb
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
    'main-source',
    '10000000-0000-0000-0000-000000000001',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"main-source","weeks":[]}'::jsonb
  ),
  (
    'candidate-plan',
    '10000000-0000-0000-0000-000000000001',
    '2026-07-02 09:00:00+00',
    'settings_update',
    false,
    1,
    '{"id":"candidate-plan","weeks":[]}'::jsonb
  ),
  (
    'peer-source',
    '10000000-0000-0000-0000-000000000002',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"peer-source","weeks":[]}'::jsonb
  );

-- Schema and security checks.
select has_table('public', 'change_schedule_availability_versions', 'availability versions table exists');
select has_table('public', 'change_schedule_drafts', 'draft table exists');
select has_table('public', 'change_schedule_proposals', 'proposal table exists');
select has_table('public', 'change_schedule_activations', 'activation table exists');
select col_not_null('public', 'change_schedule_availability_versions', 'id', 'availability version id is required');
select col_not_null('public', 'change_schedule_availability_versions', 'user_id', 'availability version owner is required');
select col_not_null('public', 'change_schedule_drafts', 'source_plan_version_id', 'draft source plan is required');
select col_not_null('public', 'change_schedule_proposals', 'source_plan_version_id', 'proposal source plan is required');
select col_not_null('public', 'change_schedule_proposals', 'source_profile_schema_version', 'proposal profile schema version is required');
select col_not_null('public', 'change_schedule_proposals', 'source_profile_updated_at', 'proposal profile timestamp is required');
select col_not_null('public', 'change_schedule_proposals', 'effective_from', 'proposal effective date is required');
select col_not_null('public', 'change_schedule_activations', 'queued_candidate_plan_version_id', 'activation needs candidate plan');
select col_type_is('public', 'activity_records', 'plan_version_id', 'text', 'activity_records plan version column exists as text');
select has_index('public', 'activity_records', 'activity_records_user_plan_version', 'plan_version_id index exists');

select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.change_schedule_drafts'::regclass
  ),
  true,
  'change schedule drafts are protected by RLS'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.change_schedule_proposals'::regclass
  ),
  true,
  'change schedule proposals are protected by RLS'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.change_schedule_activations'::regclass
  ),
  true,
  'change schedule activations are protected by RLS'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.change_schedule_availability_versions'::regclass
  ),
  true,
  'availability versions are protected by RLS'
);
select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and tablename = 'change_schedule_drafts'
      and policyname = 'Users manage own change schedule draft'
      and cmd = 'ALL'
  ),
  1,
  'the draft owner-manage policy exists'
);
select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and tablename = 'change_schedule_availability_versions'
      and policyname = 'Users manage own schedule availability versions'
      and cmd = 'ALL'
  ),
  1,
  'the availability owner-manage policy exists'
);
select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and tablename = 'change_schedule_proposals'
      and policyname = 'Users view own change schedule proposals'
      and cmd = 'SELECT'
  ),
  1,
  'the proposal owner-select policy exists'
);
select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and tablename = 'change_schedule_activations'
      and policyname = 'Users view own change schedule activations'
      and cmd = 'SELECT'
  ),
  1,
  'the activation owner-select policy exists'
);
select has_index('public', 'change_schedule_availability_versions', 'change_schedule_availability_versions_one_active_per_user', 'availability has at-most-one-active constraint');
select has_index('public', 'change_schedule_availability_versions', 'change_schedule_availability_versions_one_scheduled_per_user', 'availability has one-scheduled constraint');
select has_index('public', 'change_schedule_proposals', 'change_schedule_proposals_one_pending_per_user', 'proposal pending uniqueness index exists');
select has_index('public', 'change_schedule_activations', 'change_schedule_activations_one_scheduled_per_user', 'activation scheduled uniqueness index exists');
select has_index('public', 'change_schedule_proposals', 'change_schedule_proposals_user_created', 'proposal user-created index exists');

select ok(
  has_table_privilege('authenticated', 'public.change_schedule_drafts', 'SELECT,INSERT,UPDATE,DELETE'),
  'authenticated users may manage their own change-schedule draft'
);
select ok(
  not has_table_privilege('authenticated', 'public.change_schedule_proposals', 'INSERT,UPDATE,DELETE'),
  'authenticated users cannot mutate proposals directly'
);
select ok(
  has_table_privilege('authenticated', 'public.change_schedule_proposals', 'SELECT'),
  'authenticated users can read own proposals'
);
select ok(
  not has_table_privilege('authenticated', 'public.change_schedule_activations', 'INSERT,UPDATE,DELETE'),
  'authenticated users cannot mutate activations directly'
);
select ok(
  has_table_privilege('authenticated', 'public.change_schedule_activations', 'SELECT'),
  'authenticated users can read own activations'
);
select ok(
  has_table_privilege('authenticated', 'public.change_schedule_availability_versions', 'SELECT,INSERT,UPDATE,DELETE'),
  'authenticated users can manage their own availability versions'
);

select ok(
  has_table_privilege('service_role', 'public.change_schedule_proposals', 'INSERT,UPDATE,DELETE'),
  'service role can manage proposal rows'
);
select ok(
  has_table_privilege('service_role', 'public.change_schedule_activations', 'INSERT,UPDATE,DELETE'),
  'service role can manage activation rows'
);
select ok(
  has_table_privilege('service_role', 'public.change_schedule_availability_versions', 'INSERT,UPDATE,DELETE'),
  'service role can manage availability version rows'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

-- Availability validation and draft ownership checks.
select lives_ok(
  $$
    insert into public.change_schedule_availability_versions (
      id,
      user_id,
      lifecycle_state,
      effective_from,
      target_running_days,
      primary_long_run_weekday,
      availability_data,
      same_day_run_strength_preference
    ) values (
      'availability-active',
      '10000000-0000-0000-0000-000000000001',
      'active',
      date_trunc('week', current_date)::date,
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
        "same_day_run_strength_preference": "run_first"
      }'::jsonb,
      'run_first'
    )
  $$,
  'owner can insert an active availability version'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$
    insert into public.change_schedule_availability_versions (
      id,
      user_id,
      lifecycle_state,
      effective_from,
      target_running_days,
      primary_long_run_weekday,
      availability_data,
      same_day_run_strength_preference
    ) values (
      'availability-scheduled-today',
      '10000000-0000-0000-0000-000000000002',
      'scheduled',
      date_trunc('week', current_date)::date,
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
        "same_day_run_strength_preference": "run_first"
      }'::jsonb,
      'run_first'
    )
  $$,
  'owner can persist a scheduled availability with current-cycle effective date'
);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select throws_ok(
  $$
    insert into public.change_schedule_availability_versions (
      id,
      user_id,
      lifecycle_state,
      effective_from,
      target_running_days,
      primary_long_run_weekday,
      availability_data,
      same_day_run_strength_preference
    ) values (
      'availability-target-mismatch',
      '10000000-0000-0000-0000-000000000001',
      'active',
      date_trunc('week', current_date)::date,
      3,
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
        "target_running_days": 3,
        "primary_long_run_weekday": 1,
        "same_day_run_strength_preference": "run_first"
      }'::jsonb,
      'run_first'
    )
  $$,
  'P0001',
  'change_schedule_availability_payload_target_running_days_mismatch',
  'available days mismatch with declared target count'
);

select throws_ok(
  $$
    insert into public.change_schedule_availability_versions (
      id,
      user_id,
      lifecycle_state,
      effective_from,
      target_running_days,
      primary_long_run_weekday,
      availability_data,
      same_day_run_strength_preference
    ) values (
      'availability-preference-mismatch-insert',
      '10000000-0000-0000-0000-000000000001',
      'active',
      date_trunc('week', current_date)::date,
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
      'run_first'
    )
  $$,
  'P0001',
  'change_schedule_availability_payload_same_day_preference_mismatch',
  'availability column and payload must use the same same-day preference'
);

select lives_ok(
  $$
    insert into public.change_schedule_availability_versions (
      id,
      user_id,
      lifecycle_state,
      effective_from,
      target_running_days,
      primary_long_run_weekday,
      availability_data,
      same_day_run_strength_preference
    ) values (
      'availability-scheduled-future',
      '10000000-0000-0000-0000-000000000001',
      'scheduled',
      date_trunc('week', '2026-01-02'::date),
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
      "same_day_run_strength_preference": "run_first"
      }'::jsonb,
      'run_first'
    )
  $$,
  'owner can insert a scheduled availability version'
);

select throws_ok(
  $$
    update public.change_schedule_availability_versions
       set availability_data = jsonb_set(
         availability_data,
         '{same_day_run_strength_preference}',
         '"it_depends"'::jsonb
       )
     where id = 'availability-scheduled-future'
  $$,
  'P0001',
  'change_schedule_availability_payload_same_day_preference_mismatch',
  'availability updates keep column and payload preferences synchronized'
);

select lives_ok(
  $$
    insert into public.change_schedule_drafts (
      user_id,
      source_plan_version_id,
      proposed_availability,
      status
    ) values (
      '10000000-0000-0000-0000-000000000001',
      'main-source',
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
      }'::jsonb,
      'editing'
    )
  $$,
  'owner can persist a change-schedule draft for an active source plan'
);
select throws_ok(
  $$
    insert into public.change_schedule_drafts (
      user_id,
      source_plan_version_id,
      proposed_availability
    ) values (
      '10000000-0000-0000-0000-000000000002',
      'main-source',
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
    )
  $$,
  '42501',
  'insufficient_privilege',
  'authenticated user cannot write another users'' draft'
);

select throws_ok(
  $$
    insert into public.change_schedule_drafts (
      user_id,
      source_plan_version_id,
      proposed_availability
    ) values (
      '10000000-0000-0000-0000-000000000002',
      'main-source',
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
  )
  $$,
  '42501',
  'insufficient_privilege',
  'authenticated writes enforce ownership before source-plan validation'
);

-- Proposals and activations are service-owned.
set local role service_role;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$
    insert into public.change_schedule_availability_versions (
      id,
      user_id,
      lifecycle_state,
      effective_from,
      target_running_days,
      primary_long_run_weekday,
      availability_data,
      same_day_run_strength_preference
    ) values (
      'availability-peer-restore',
      '10000000-0000-0000-0000-000000000002',
      'active',
      date_trunc('week', '2026-01-02'::date),
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
        "same_day_run_strength_preference": "run_first"
      }'::jsonb,
      'run_first'
    )
  $$,
  'service role can persist scheduled availability for restore workflows'
);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select lives_ok(
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
      status,
      scheduled_plan_version_id
    ) values (
      'proposal-restored-scheduled',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
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
        "same_day_run_strength_preference": "run_first"
      }'::jsonb,
      '{"id":"proposal-candidate-restored","weeks":[]}'::jsonb,
      '{}'::jsonb,
      date_trunc('week', '2026-01-02'::date),
      'scheduled',
      'candidate-plan'
    )
  $$,
  'service role can persist a historical scheduled proposal lifecycle row'
);

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
      status,
      scheduled_plan_version_id
    ) values (
      'proposal-restored-peer-source',
      '10000000-0000-0000-0000-000000000001',
      'peer-source',
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
        "same_day_run_strength_preference": "run_first"
      }'::jsonb,
      '{"id":"proposal-candidate-restored","weeks":[]}'::jsonb,
      '{}'::jsonb,
      date_trunc('week', '2026-01-02'::date),
      'scheduled',
      'candidate-plan'
  )
  $$,
  'P0001',
  'change_schedule_proposal_source_plan_not_active',
  'service role rejects proposal restores with non-owned source plans'
);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select throws_ok(
  $$
    insert into public.change_schedule_drafts (
      user_id,
      source_plan_version_id,
      proposed_availability
    ) values (
      '10000000-0000-0000-0000-000000000001',
      'peer-source',
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
    )
  $$,
  'P0001',
  'change_schedule_draft_source_plan_not_active',
  'service role enforces draft source-plan ownership'
);

select lives_ok(
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
      'proposal-pending',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
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
        "same_day_run_strength_preference": "run_first"
      }'::jsonb,
      '{"id":"proposal-candidate","weeks":[]}'::jsonb,
      '{}'::jsonb,
      (date_trunc('week', current_date)::date + interval '7 days'),
      'pending'
    )
  $$,
  'service role can create a pending proposal'
);
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
      'proposal-duplicate-pending',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
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
        "same_day_run_strength_preference": "run_first"
      }'::jsonb,
      '{"id":"proposal-candidate-2","weeks":[]}'::jsonb,
      '{}'::jsonb,
      (date_trunc('week', current_date)::date + interval '7 days'),
      'pending'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "change_schedule_proposals_one_pending_per_user"',
  'service role cannot insert a second pending proposal for the same user'
);

update runner_profiles
   set schema_version = 2
 where user_id = '10000000-0000-0000-0000-000000000001';

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
      'proposal-stale-profile',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
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
        "same_day_run_strength_preference": "run_first"
      }'::jsonb,
      '{"id":"proposal-candidate-3","weeks":[]}'::jsonb,
      '{}'::jsonb,
      (date_trunc('week', current_date)::date + interval '7 days'),
      'pending'
    )
  $$,
  'P0001',
  'change_schedule_proposal_profile_snapshot_mismatch',
  'proposal rejects stale profile snapshot'
);

select lives_ok(
  $$
    insert into public.change_schedule_activations (
      id,
      user_id,
      source_plan_version_id,
      queued_candidate_plan_version_id,
      availability_version_id,
      effective_from,
      status
    ) values (
      'activation-main',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
      'candidate-plan',
      'availability-scheduled-future',
      date_trunc('week', '2026-01-02'::date),
      'scheduled'
    )
  $$,
  'service role can create a historically-scheduled activation'
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
      status
    ) values (
      'activation-scheduled-conflict',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
      'candidate-plan',
      'availability-scheduled-future',
      date_trunc('week', '2026-01-02'::date),
      'scheduled'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "change_schedule_activations_one_scheduled_per_user"',
  'activation scheduled uniqueness is enforced per user'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set status = 'activated',
           activated_at = now()
     where id = 'activation-main'
  $$,
  'P0001',
  'change_schedule_activation_availability_state_mismatch',
  'scheduled activation still enforces active availability references'
);

select lives_ok(
  $$
    insert into public.change_schedule_activations (
      id,
      user_id,
      source_plan_version_id,
      queued_candidate_plan_version_id,
      availability_version_id,
      effective_from,
      status,
      cancelled_at
    ) values (
      'activation-restored-cancelled',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
      'candidate-plan',
      'availability-scheduled-future',
      date_trunc('week', '2026-01-02'::date),
      'cancelled',
      now()
    )
  $$,
  'service role can persist a historical terminal activation row'
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
      cancelled_at
    ) values (
      'activation-restored-mismatched-availability',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
      'candidate-plan',
      'availability-peer-restore',
      date_trunc('week', '2026-01-02'::date),
      'cancelled',
      now()
    )
  $$,
  'P0001',
  'change_schedule_activation_availability_not_owned',
  'service role rejects terminal activation restores with non-owned availability'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set status = 'activated',
           activated_at = now(),
           effective_from = (date_trunc('week', current_date)::date),
           availability_version_id = 'availability-scheduled-future'
     where id = 'activation-main'
  $$,
  'P0001',
  'change_schedule_activation_availability_state_mismatch',
  'activated row must reference a matching active availability version'
);

select lives_ok(
  $$
    insert into public.change_schedule_activations (
      id,
      user_id,
      source_plan_version_id,
      queued_candidate_plan_version_id,
      availability_version_id,
      effective_from,
      status,
      activated_at
    ) values (
      'activation-immediate',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
      'candidate-plan',
      'availability-active',
      (date_trunc('week', current_date)::date),
      'activated',
      now()
    )
  $$,
  'service role can create an activated schedule when effective'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set effective_from = (date_trunc('week', current_date)::date - interval '7 days')
     where id = 'activation-immediate'
  $$,
  'P0001',
  'change_schedule_activation_availability_state_mismatch',
  'activated row cannot reference an active availability version from a different effective Monday'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is(
  (select count(*)::integer from public.change_schedule_proposals),
  2,
  'user can see owned proposals via RLS select path'
);
select is(
  (select count(*)::integer from public.change_schedule_activations),
  3,
  'user can read own scheduled and activated activations'
);
select throws_ok(
  $$
    insert into public.activity_records (
      id,
      user_id,
      recorded_at,
      data,
      plan_version_id
    ) values (
      'activity-cross-plan-fail',
      '10000000-0000-0000-0000-000000000001',
      now(),
      '{}'::jsonb,
      'peer-source'
    )
  $$,
  'P0001',
  'activity_record_plan_version_not_owned',
  'activity records cannot reference another users plan version'
);
select lives_ok(
  $$
    insert into public.activity_records (
      id,
      user_id,
      recorded_at,
      data,
      plan_version_id
    ) values (
      'activity-with-own-plan',
      '10000000-0000-0000-0000-000000000001',
      now(),
      '{}'::jsonb,
      'main-source'
    )
  $$,
  'authenticated users can link activities to own plan versions'
);
select lives_ok(
  $$
    insert into public.activity_records (
      id,
      user_id,
      recorded_at,
      data
    ) values (
      'activity-without-plan',
      '10000000-0000-0000-0000-000000000001',
      now(),
      '{}'::jsonb
    )
  $$,
  'authenticated users can store activity rows without a plan version'
);
select throws_ok(
  $$
    update public.activity_records
       set plan_version_id = 'peer-source'
     where id = 'activity-without-plan'
  $$,
  'P0001',
  'activity_record_plan_version_not_owned',
  'authenticated users cannot repoint activities to other users plans'
);
select lives_ok(
  $$
    update public.activity_records
       set plan_version_id = 'candidate-plan'
     where id = 'activity-without-plan'
  $$,
  'authenticated users can repoint activities to owned plan versions'
);
select lives_ok(
  $$
    update public.activity_records
       set data = '{"status":"updated"}'::jsonb
     where id = 'activity-without-plan'
  $$,
  'authenticated users can update activity metadata without changing ownership fields'
);
set local role service_role;
select throws_ok(
  $$
    update public.activity_records
       set user_id = '10000000-0000-0000-0000-000000000002'
     where id = 'activity-with-own-plan'
  $$,
  'P0001',
  'activity_record_plan_version_not_owned',
  'service-role reassignment to another user fails when plan version is retained'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select is(
  (select count(*)::integer from public.change_schedule_proposals),
  0,
  'RLS prevents cross-user proposal reads'
);
select is(
  (select count(*)::integer from public.change_schedule_activations),
  0,
  'RLS prevents cross-user activation reads'
);
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
      'unauthorized-proposal-write',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
      1,
      '2026-01-01 00:00:00+00',
      '{}'::jsonb,
      '{}'::jsonb,
      '{}'::jsonb,
      (date_trunc('week', current_date)::date + interval '7 days'),
      'pending'
  )
  $$,
  '42501',
  'permission denied for table change_schedule_proposals'
);

set local role service_role;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$
    update public.change_schedule_activations
       set availability_version_id = 'availability-active'
     where id = 'activation-main'
  $$,
  'P0001',
  'change_schedule_activation_availability_schedule_mismatch',
  'scheduled activation cannot switch to unscheduled availability versions'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set effective_from = (date_trunc('week', current_date)::date + interval '14 days')
     where id = 'activation-main'
  $$,
  'P0001',
  'change_schedule_activation_availability_schedule_mismatch',
  'scheduled activation cannot use mismatched effective date'
);

update public.plan_versions
   set is_active = false
 where id = 'main-source';

select lives_ok(
  $$
    update public.change_schedule_proposals
       set status = 'expired'
     where id = 'proposal-pending'
  $$,
  'proposal pending row can move to expired after source plan is stale'
);
select lives_ok(
  $$
    update public.change_schedule_proposals
       set status = 'superseded'
     where id = 'proposal-pending'
  $$,
  'proposal pending row can move to superseded after source plan is stale'
);
select lives_ok(
  $$
    update public.change_schedule_proposals
       set status = 'cancelled'
     where id = 'proposal-pending'
  $$,
  'proposal pending row can move to cancelled after source plan is stale'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set source_plan_version_id = 'candidate-plan'
     where id = 'proposal-pending'
  $$,
  'P0001',
  'change_schedule_proposal_source_plan_not_active',
  'proposal source plan cannot be swapped to a stale plan'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set status = 'activated',
           activated_at = now(),
           effective_from = date_trunc('week', current_date)::date,
           availability_version_id = 'availability-active'
     where id = 'activation-main'
  $$,
  'P0001',
  'change_schedule_activation_source_plan_not_active',
  'activation cannot become activated when source plan is stale'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set status = 'activated',
           activated_at = now(),
           effective_from = date_trunc('week', current_date)::date,
           availability_version_id = 'availability-active',
           source_plan_version_id = 'candidate-plan'
     where id = 'activation-main'
  $$,
  'P0001',
  'change_schedule_activation_source_plan_not_active',
  'activation cannot become activated after replacing with another stale source'
);

select lives_ok(
  $$
    update public.change_schedule_activations
       set status = 'cancelled',
           cancelled_at = now()
     where id = 'activation-main'
  $$,
  'activation with a stale source can move to cancelled'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set source_plan_version_id = 'candidate-plan'
     where id = 'activation-main'
  $$,
  'P0001',
  'change_schedule_activation_source_plan_not_active',
  'activation source plan cannot be reassigned while stale'
);

select lives_ok(
  $$
    update public.change_schedule_activations
       set status = 'cancelled',
           cancelled_at = now()
     where id = 'activation-main'
  $$,
  'activation with a stale source can move to cancelled'
);

select lives_ok(
  $$
    update public.change_schedule_activations
       set status = 'stale',
           stale_at = now(),
           activated_at = null,
           cancelled_at = null,
           superseded_at = null
     where id = 'activation-main'
  $$,
  'activation with a stale source can move to stale'
);

select lives_ok(
  $$
    update public.change_schedule_activations
       set status = 'superseded',
           superseded_at = now(),
           stale_at = null
     where id = 'activation-main'
  $$,
  'activation with a stale source can move to superseded'
);

select * from finish();

rollback;
