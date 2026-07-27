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
select col_type_is('public', 'change_schedule_activations', 'proposal_id', 'text', 'activation proposal reference is text');
select col_type_is('public', 'change_schedule_activations', 'prior_active_plan_version_id', 'text', 'activation prior active plan snapshot is text');
select col_type_is('public', 'change_schedule_activations', 'prior_active_availability_version_id', 'text', 'activation prior active availability snapshot is text');
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
select has_index('public', 'change_schedule_activations', 'change_schedule_activations_proposal', 'activation proposal reference index exists');
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
        "same_day_run_strength_preference": "separate_sessions"
      }'::jsonb,
      'separate_sessions'
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
        "same_day_run_strength_preference": "separate_sessions"
      }'::jsonb,
      'separate_sessions'
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
        "same_day_run_strength_preference": "separate_sessions"
      }'::jsonb,
      'separate_sessions'
    )
  $$,
  'P0001',
  'change_schedule_availability_payload_target_running_days_mismatch',
  'available days mismatch with declared target count'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);

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
      '10000000-0000-0000-0000-000000000002',
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
      'avoid_same_day'
    )
  $$,
  'P0001',
  'change_schedule_availability_payload_same_day_preference_mismatch',
  'availability column and payload must use the same same-day preference'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

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
      "same_day_run_strength_preference": "separate_sessions"
      }'::jsonb,
      'separate_sessions'
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
         '"avoid_same_day"'::jsonb
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
        "same_day_run_strength_preference": "separate_sessions"
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
        "same_day_run_strength_preference": "separate_sessions"
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
        "same_day_run_strength_preference": "separate_sessions"
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
        "same_day_run_strength_preference": "separate_sessions"
      }'::jsonb,
      'separate_sessions'
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
        "same_day_run_strength_preference": "separate_sessions"
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
        "same_day_run_strength_preference": "separate_sessions"
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
        "same_day_run_strength_preference": "separate_sessions"
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
        "same_day_run_strength_preference": "separate_sessions"
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
        "same_day_run_strength_preference": "separate_sessions"
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
        "same_day_run_strength_preference": "separate_sessions"
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
           prior_active_plan_version_id = 'main-source',
           prior_active_availability_version_id = 'availability-active',
           activated_at = now()
     where id = 'activation-main'
  $$,
  'P0001',
  'change_schedule_activation_availability_state_mismatch',
  'scheduled activation still enforces active availability references'
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
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'service role rejects terminal activation without proposal reference'
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
  'change_schedule_activation_proposal_inconsistent',
  'service role rejects terminal activation without proposal reference (mismatched availability)'
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
      prior_active_plan_version_id,
      prior_active_availability_version_id,
      activated_at
    ) values (
      'activation-immediate',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
      'candidate-plan',
      'availability-active',
      (date_trunc('week', current_date)::date),
      'activated',
      'main-source',
      'availability-active',
      now()
    )
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'service role rejects activated row without proposal reference'
);

select is(
  (
    select count(*)::integer
      from public.change_schedule_activations
     where id = 'activation-immediate'
  ),
  0,
  'activated row without proposal reference is not persisted'
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
  'candidate-plan-linked-terminal',
  '10000000-0000-0000-0000-000000000001',
  '2026-01-02 09:00:00+00',
  'onboarding',
  false,
  1,
  '{"id":"candidate-plan-linked-terminal","weeks":[]}'::jsonb
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
) values (
	  'proposal-linked-terminal',
	  '10000000-0000-0000-0000-000000000001',
	  'main-source',
	  (select schema_version from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
	  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
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
  '{"id":"proposal-linked-candidate","weeks":[]}'::jsonb,
  '{}'::jsonb,
  date_trunc('week', '2026-01-02'::date),
  'scheduled',
  'candidate-plan-linked-terminal'
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
      cancelled_at,
      proposal_id
    ) values (
      'activation-linked-terminal',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
      'candidate-plan',
      'availability-scheduled-future',
      date_trunc('week', '2026-01-02'::date),
      'cancelled',
      now(),
      'proposal-linked-terminal'
    )
  $$,
  'P0001',
  'change_schedule_activation_terminal_status_rejects_proposal',
  'terminal activation rejects nonterminal proposal linkage on insert'
);
select is(
  (
    select count(*)::integer
      from public.change_schedule_activations
     where id = 'activation-linked-terminal'
  ),
  0,
  'rejected terminal activation with nonterminal proposal reference is not persisted'
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
      'activation-linked-terminal',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
      'candidate-plan',
      'availability-scheduled-future',
      date_trunc('week', '2026-01-02'::date),
      'cancelled',
      now()
    )
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'terminal activation without proposal reference is rejected'
);
select is(
  (
    select count(*)::integer
      from public.change_schedule_activations
     where id = 'activation-linked-terminal'
  ),
  0,
  'terminal activation without proposal reference is not persisted'
);

delete from public.change_schedule_proposals
 where id = 'proposal-linked-terminal';
select is(
  (
    select count(*)::integer
      from public.change_schedule_activations
     where id = 'activation-linked-terminal'
  ),
  0,
  'terminal activation without proposal remains absent after linked proposal cleanup'
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
      proposal_id
    ) values (
      'activation-missing-proposal',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
      'candidate-plan',
      'availability-scheduled-future',
      date_trunc('week', current_date)::date + interval '14 days',
      'cancelled',
      'proposal-missing'
    )
  $$,
  'P0001',
  'change_schedule_activation_proposal_not_found',
  'terminal activations reject missing proposal references'
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
  'peer-linked-candidate',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-01 10:00:00+00',
  'onboarding',
  false,
  1,
	  '{"id":"peer-linked-candidate","weeks":[]}'::jsonb
	);

	select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
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
  'proposal-linked-cross-user',
  '10000000-0000-0000-0000-000000000002',
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
    "same_day_run_strength_preference": "separate_sessions"
  }'::jsonb,
  '{"id":"peer-linked-candidate","weeks":[]}'::jsonb,
  '{}'::jsonb,
  (date_trunc('week', current_date)::date + interval '14 days'),
  'cancelled'
);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

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
      proposal_id
    ) values (
      'activation-cross-user-proposal',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
      'candidate-plan',
      'availability-scheduled-future',
      date_trunc('week', current_date)::date + interval '14 days',
      'cancelled',
      'proposal-linked-cross-user'
    )
  $$,
  'P0001',
  'change_schedule_activation_proposal_not_owned',
  'terminal activation rejects proposal references owned by other users'
);

set local role service_role;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'queued-plan-scheduled-fallback',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-01 09:00:00+00',
  'change_schedule',
  false,
  1,
  '{"id":"queued-plan-scheduled-fallback","weeks":[]}'::jsonb
), (
  'queued-plan-scheduled-fallback-mismatch',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-01 10:00:00+00',
  'change_schedule',
  false,
  1,
  '{"id":"queued-plan-scheduled-fallback-mismatch","weeks":[]}'::jsonb
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
) values (
  'proposal-scheduled-fallback-accept',
  '10000000-0000-0000-0000-000000000002',
  'peer-source',
  (select schema_version from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
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
  '{"id":"queued-plan-main","weeks":[]}'::jsonb,
  '{}'::jsonb,
  date_trunc('week', current_date),
  'scheduled',
  'queued-plan-scheduled-fallback'
);

insert into public.change_schedule_activations (
  id,
  user_id,
  source_plan_version_id,
  queued_candidate_plan_version_id,
  availability_version_id,
  effective_from,
  status,
  proposal_id
) values (
  'activation-scheduled-fallback-link',
  '10000000-0000-0000-0000-000000000002',
  'peer-source',
  'queued-plan-scheduled-fallback',
  'availability-scheduled-today',
  date_trunc('week', current_date),
  'scheduled',
  null
);

select lives_ok(
  $$
    update public.change_schedule_activations
       set proposal_id = 'proposal-scheduled-fallback-accept'
     where id = 'activation-scheduled-fallback-link'
  $$,
  'service role can persist scheduled proposal link through activation update'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-scheduled-fallback-link'
  ),
  'proposal-scheduled-fallback-accept',
  'scheduled activation stores proposal reference when candidate matches'
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
  updated_at
) values (
  'proposal-scheduled-fallback-pending',
  '10000000-0000-0000-0000-000000000002',
  'peer-source',
  1,
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
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
  '{}'::jsonb,
  '{}'::jsonb,
  (date_trunc('week', current_date)::date + interval '14 days'),
  'pending',
  '2026-07-20 09:43:00+00',
  '2026-07-20 09:43:00+00'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set proposal_id = 'proposal-scheduled-fallback-pending'
     where id = 'activation-scheduled-fallback-link'
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'one-shot scheduled->scheduled relink to unrelated pending proposal is rejected'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-scheduled-fallback-link'
  ),
  'proposal-scheduled-fallback-accept',
  'scheduled activation rejects pending relink and keeps scheduled proposal'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-scheduled-fallback-link'
  ),
  'scheduled',
  'scheduled activation pending relink keeps status'
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
) values (
  'proposal-scheduled-fallback-mismatch',
  '10000000-0000-0000-0000-000000000002',
  'peer-source',
  (select schema_version from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
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
  '{}'::jsonb,
  '{}'::jsonb,
  (date_trunc('week', current_date)::date + interval '14 days'),
  'scheduled',
  'queued-plan-scheduled-fallback-mismatch'
);

update public.change_schedule_activations
   set status = 'cancelled',
       cancelled_at = now()
 where id = 'activation-scheduled-fallback-link';

select throws_ok(
  $$
    update public.change_schedule_activations
       set proposal_id = 'proposal-scheduled-fallback-mismatch'
     where id = 'activation-scheduled-fallback-link'
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'scheduled activation rejects mismatched proposal identity'
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
  'candidate-plan-storage-bypass-valid',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-01 10:30:00+00',
  'change_schedule',
  false,
  1,
  '{"id":"candidate-plan-storage-bypass-valid","weeks":[]}'::jsonb
),
(
  'candidate-plan-storage-bypass-unrelated',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-01 10:31:00+00',
  'change_schedule',
  false,
  1,
  '{"id":"candidate-plan-storage-bypass-unrelated","weeks":[]}'::jsonb
);

insert into public.change_schedule_activations (
  id,
  user_id,
  source_plan_version_id,
  queued_candidate_plan_version_id,
  availability_version_id,
  effective_from,
  status,
  prior_active_plan_version_id,
  prior_active_availability_version_id
) values (
  'activation-storage-bypass-link',
  '10000000-0000-0000-0000-000000000002',
  'peer-source',
  'candidate-plan-storage-bypass-valid',
  'availability-scheduled-today',
  date_trunc('week', current_date),
  'scheduled',
  'peer-source',
  'availability-scheduled-today'
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
) values (
  'proposal-storage-bypass-valid',
  '10000000-0000-0000-0000-000000000002',
  'peer-source',
  1,
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
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
  '{"id":"candidate-plan-storage-bypass-valid","weeks":[]}'::jsonb,
  '{}'::jsonb,
  date_trunc('week', current_date)::date,
  'scheduled',
  'candidate-plan-storage-bypass-valid'
),
(
  'proposal-storage-bypass-unrelated',
  '10000000-0000-0000-0000-000000000002',
  'peer-source',
  1,
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
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
  '{"id":"candidate-plan-storage-bypass-unrelated","weeks":[]}'::jsonb,
  '{}'::jsonb,
  date_trunc('week', current_date)::date,
  'scheduled',
  'candidate-plan-storage-bypass-unrelated'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set proposal_id = 'proposal-storage-bypass-unrelated',
           status = 'activated',
           availability_version_id = 'availability-peer-restore',
           activated_at = now()
     where id = 'activation-storage-bypass-link'
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'direct one-shot scheduled->activated relinking is blocked for storage rows'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-storage-bypass-link'
  ),
  'scheduled',
  'prohibited direct relink keeps terminal-status transition from happening'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
  where id = 'activation-storage-bypass-link'
  ),
  null::text,
  'prohibited direct relink keeps proposal_id null'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set status = 'activated',
           availability_version_id = 'availability-peer-restore',
           effective_from = date_trunc('week', '2026-01-02'::date),
           activated_at = now()
     where id = 'activation-storage-bypass-link'
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'direct one-shot scheduled->activated relink without proposal is blocked for storage rows'
);
select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-storage-bypass-link'
  ),
  'scheduled',
  'scheduled->activated null proposal relink keeps activation status unchanged for storage rows'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-storage-bypass-link'
  ),
  null::text,
  'scheduled->activated null proposal relink keeps proposal_id null for storage rows'
);

delete from public.change_schedule_proposals
 where id in (
   'proposal-storage-bypass-valid',
   'proposal-storage-bypass-unrelated'
 );
delete from public.change_schedule_activations
 where id = 'activation-storage-bypass-link';
delete from public.plan_versions
 where id in (
   'candidate-plan-storage-bypass-valid',
   'candidate-plan-storage-bypass-unrelated'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'accepted-backfill-plan-storage',
  '10000000-0000-0000-0000-000000000001',
  '2026-07-02 09:30:00+00',
  'settings_update',
  false,
  1,
  '{"id":"accepted-backfill-plan-storage","weeks":[]}'::jsonb
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
  accepted_at
) values (
  'proposal-backfill-terminal-storage',
  '10000000-0000-0000-0000-000000000001',
  'main-source',
  (select schema_version from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
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
  '{"id":"accepted-backfill-candidate","weeks":[]}'::jsonb,
  '{}'::jsonb,
  date_trunc('week', current_date)::date,
  'accepted',
  'accepted-backfill-plan-storage',
  '2026-07-02 09:35:00+00'
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
  'activation-backfill-storage',
  '10000000-0000-0000-0000-000000000001',
  'main-source',
  'accepted-backfill-plan-storage',
  'availability-active',
  date_trunc('week', current_date)::date,
  'activated',
  '2026-07-02 09:40:00+00',
  '2026-07-02 09:40:00+00',
  '2026-07-02 09:40:00+00'
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
  'unmatched-backfill-plan-storage',
  '10000000-0000-0000-0000-000000000001',
  '2026-07-02 09:45:00+00',
  'settings_update',
  false,
  1,
  '{"id":"unmatched-backfill-plan-storage","weeks":[]}'::jsonb
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
  'accepted-backfill-plan-storage-mismatched-source',
  '10000000-0000-0000-0000-000000000001',
  '2026-07-02 09:46:00+00',
  'settings_update',
  false,
  1,
  '{"id":"accepted-backfill-plan-storage-mismatched-source","weeks":[]}'::jsonb
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
  'accepted-backfill-plan-storage-mismatched-effective',
  '10000000-0000-0000-0000-000000000001',
  '2026-07-02 09:57:00+00',
  'settings_update',
  false,
  1,
  '{"id":"accepted-backfill-plan-storage-mismatched-effective","weeks":[]}'::jsonb
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
  updated_at,
  activated_at
) values (
  'activation-backfill-storage-unmatched',
  '10000000-0000-0000-0000-000000000001',
  'main-source',
  'unmatched-backfill-plan-storage',
  'availability-active',
  date_trunc('week', current_date)::date,
  'activated',
  '2026-07-02 09:41:00+00',
  '2026-07-02 09:41:00+00',
  '2026-07-02 09:41:00+00'
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
  accepted_at
) values (
  'proposal-backfill-mismatched-source',
  '10000000-0000-0000-0000-000000000001',
  'main-source',
  (select schema_version from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
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
  '{"id":"accepted-backfill-candidate","weeks":[]}'::jsonb,
  '{"legacy":true}'::jsonb,
  (date_trunc('week', '2026-01-02'::date)::date),
  'accepted',
  'accepted-backfill-plan-storage-mismatched-source',
  '2026-07-02 09:45:00+00'
);

update public.plan_versions
   set is_active = false
 where id = 'main-source';
update public.plan_versions
   set is_active = true
 where id = 'accepted-backfill-plan-storage-mismatched-source';

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
  accepted_at
) values (
  'proposal-backfill-mismatched-effective',
  '10000000-0000-0000-0000-000000000001',
  'accepted-backfill-plan-storage-mismatched-source',
  (select schema_version from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
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
  '{"id":"accepted-backfill-plan-storage-mismatched-effective","weeks":[]}'::jsonb,
  '{}'::jsonb,
  (date_trunc('week', current_date) + interval '1 week')::date,
  'accepted',
  'accepted-backfill-plan-storage-mismatched-effective',
  '2026-07-02 09:58:00+00'
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
  updated_at,
  activated_at
) values (
  'activation-backfill-storage-mismatched-effective',
  '10000000-0000-0000-0000-000000000001',
  'accepted-backfill-plan-storage-mismatched-source',
  'accepted-backfill-plan-storage-mismatched-effective',
  'availability-active',
  date_trunc('week', current_date)::date,
  'activated',
  '2026-07-02 09:59:00+00',
  '2026-07-02 09:59:00+00',
  '2026-07-02 09:59:00+00'
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
  updated_at,
  activated_at
) values (
  'activation-backfill-storage-mismatched-source',
  '10000000-0000-0000-0000-000000000001',
  'accepted-backfill-plan-storage-mismatched-source',
  'accepted-backfill-plan-storage-mismatched-source',
  'availability-active',
  date_trunc('week', current_date)::date,
  'activated',
  '2026-07-02 09:50:00+00',
  '2026-07-02 09:50:00+00',
  '2026-07-02 09:50:00+00'
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

alter table public.change_schedule_activations enable trigger change_schedule_activations_integrity;
set role service_role;

select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-backfill-storage'
  ),
  'proposal-backfill-terminal-storage',
  'migration-time activated backfill links accepted historical row when deterministic'
);
select is(
  (
    select proposal_id
     from public.change_schedule_activations
     where id = 'activation-backfill-storage-unmatched'
  ),
  null::text,
  'activated historical row without deterministic accepted match stays unresolved'
);
select is(
  (
    select proposal_id
     from public.change_schedule_activations
     where id = 'activation-backfill-storage-mismatched-source'
  ),
  null::text,
  'activated historical row with source-plan mismatch remains unresolved'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-backfill-storage-mismatched-effective'
  ),
  null::text,
  'activated historical row with effective-week mismatch remains unresolved'
);

delete from public.change_schedule_activations
 where id = 'activation-linked-terminal';
delete from public.change_schedule_activations
 where id in (
   'activation-backfill-storage',
   'activation-backfill-storage-unmatched'
 );
delete from public.change_schedule_proposals
 where id in (
   'proposal-linked-terminal',
   'proposal-backfill-terminal-storage',
   'proposal-backfill-mismatched-effective',
   'proposal-backfill-mismatched-source',
   'proposal-linked-cross-user'
 );
delete from public.plan_versions
 where id in (
   'peer-linked-candidate',
   'accepted-backfill-plan-storage',
   'unmatched-backfill-plan-storage'
 );

update public.plan_versions
   set is_active = false
 where id = 'accepted-backfill-plan-storage-mismatched-source';
update public.plan_versions
   set is_active = true
 where id = 'main-source';

delete from public.change_schedule_activations
 where id = 'activation-scheduled-fallback-link';
delete from public.change_schedule_proposals
 where id in (
   'proposal-scheduled-fallback-accept',
   'proposal-scheduled-fallback-mismatch',
   'proposal-scheduled-fallback-pending'
 );
delete from public.plan_versions
 where id in (
   'queued-plan-scheduled-fallback',
   'queued-plan-scheduled-fallback-mismatch'
);

select is(
  (
    select count(*)::integer
     from public.change_schedule_activations
     where user_id = '10000000-0000-0000-0000-000000000001'
       and id = 'activation-linked-terminal'
  ),
  0,
  'service role cleanup removes proposal-linked historical terminal activation'
);
select is(
  (
    select count(*)::integer
      from public.change_schedule_proposals
     where id in (
       'proposal-linked-terminal',
       'proposal-linked-cross-user'
     )
  ),
  0,
  'service role cleanup removes temporary proposal rows'
);

set local role authenticated;
set local role service_role;
update public.change_schedule_activations
   set proposal_id = 'proposal-restored-scheduled'
 where id = 'activation-main';
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
  'change_schedule_activation_proposal_inconsistent',
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
           prior_active_plan_version_id = 'main-source',
           prior_active_availability_version_id = 'availability-active',
           activated_at = now(),
           effective_from = date_trunc('week', current_date)::date,
           availability_version_id = 'availability-active'
     where id = 'activation-main'
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'activation cannot become activated when source plan is stale'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set status = 'activated',
           prior_active_plan_version_id = 'main-source',
           prior_active_availability_version_id = 'availability-active',
           activated_at = now(),
           effective_from = date_trunc('week', current_date)::date,
           availability_version_id = 'availability-active',
           source_plan_version_id = 'candidate-plan'
     where id = 'activation-main'
  $$,
  'P0001',
  'change_schedule_activation_proposal_source_mismatch',
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
  'change_schedule_activation_proposal_source_mismatch',
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

-- Direct scheduled->terminal updates must keep immutable lineage unchanged.
insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'source-plan-lineage-rewrite-storage',
  '10000000-0000-0000-0000-000000000001',
  '2026-07-01 08:55:00+00',
  'settings_update',
  true,
  1,
  '{"id":"source-plan-lineage-rewrite-storage","weeks":[]}'::jsonb
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
  'queued-plan-lineage-rewrite-storage',
  '10000000-0000-0000-0000-000000000001',
  '2026-07-01 09:00:00+00',
  'settings_update',
  false,
  1,
  '{"id":"queued-plan-lineage-rewrite-storage","weeks":[]}'::jsonb
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
  'queued-plan-lineage-rewrite-storage-stale',
  '10000000-0000-0000-0000-000000000001',
  '2026-07-01 09:05:00+00',
  'settings_update',
  false,
  1,
  '{"id":"queued-plan-lineage-rewrite-storage-stale","weeks":[]}'::jsonb
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
  scheduled_plan_version_id
  ) values (
  'proposal-storage-terminal-lineage-rewrite',
  '10000000-0000-0000-0000-000000000001',
  'source-plan-lineage-rewrite-storage',
  (select schema_version from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
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
  '{"id":"candidate-lineage-terminal","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-07-27',
  'scheduled',
  '2026-07-01 09:00:00+00',
  '2026-07-01 09:00:00+00',
  'queued-plan-lineage-rewrite-storage'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'cancelled',
           scheduled_plan_version_id = null,
           source_plan_version_id = 'main-source',
           cancelled_at = '2026-07-01 09:15:00+00'
     where id = 'proposal-storage-terminal-lineage-rewrite'
  $$,
  'P0001',
  'change_schedule_proposal_terminalization_lineage_rewrite',
  'scheduled terminalization rewrite is rejected'
);

select is(
  (
    select status
     from public.change_schedule_proposals
     where id = 'proposal-storage-terminal-lineage-rewrite'
  ),
  'scheduled',
  'lineage rewrite rejection keeps proposal status scheduled'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set candidate_plan = '{"id":"candidate-lineage-terminal-mutated","weeks":[]}'::jsonb,
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
             "target_running_days": 5,
             "primary_long_run_weekday": 1,
             "same_day_run_strength_preference": "avoid_same_day"
           }'::jsonb
     where id = 'proposal-storage-terminal-lineage-rewrite'
  $$,
  'P0001',
  'change_schedule_proposal_scheduled_rewrite_rejected',
  'storage scheduled same-state rewrite of candidate/audit/availability is rejected'
);

select is(
  (
    select candidate_plan ->> 'id'
      from public.change_schedule_proposals
     where id = 'proposal-storage-terminal-lineage-rewrite'
  ),
  'candidate-lineage-terminal',
  'storage scheduled rewrite rejection preserves candidate_plan'
);

select is(
  (
    select proposed_availability ->> 'same_day_run_strength_preference'
      from public.change_schedule_proposals
     where id = 'proposal-storage-terminal-lineage-rewrite'
  ),
  'separate_sessions',
  'storage scheduled rewrite rejection preserves availability preference'
);

select is(
  (
    select impact::text
      from public.change_schedule_proposals
     where id = 'proposal-storage-terminal-lineage-rewrite'
  ),
  '{}'::text,
  'storage scheduled rewrite rejection preserves impact payload'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set scheduled_plan_version_id = 'queued-plan-lineage-rewrite-storage-mutated'
     where id = 'proposal-storage-terminal-lineage-rewrite'
  $$,
  'P0001',
  'change_schedule_proposal_scheduled_rewrite_rejected',
  'storage scheduled same-state rewrite of scheduled_plan_version_id is rejected'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-terminal-lineage-rewrite'
  ),
  'queued-plan-lineage-rewrite-storage',
  'storage scheduled rewrite rejection preserves scheduled_plan_version_id'
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
  scheduled_plan_version_id
) values (
  'proposal-storage-terminal-lineage-stale',
  '10000000-0000-0000-0000-000000000001',
  'source-plan-lineage-rewrite-storage',
  (select schema_version from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
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
  '{"id":"candidate-lineage-terminal-stale","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-07-27',
  'scheduled',
  '2026-07-01 09:05:00+00',
  '2026-07-01 09:05:00+00',
  'queued-plan-lineage-rewrite-storage-stale'
);

update public.plan_versions
   set is_active = false
 where id = 'source-plan-lineage-rewrite-storage';

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'superseded',
           scheduled_plan_version_id = null,
           superseded_at = '2026-07-01 09:10:00+00'
     where id = 'proposal-storage-terminal-lineage-stale'
  $$,
  'P0001',
  'change_schedule_proposal_terminalization_activation_not_found',
  'scheduled proposal terminalization is rejected when no exact terminal activation exists'
);

select is(
  (
    select status
     from public.change_schedule_proposals
     where id = 'proposal-storage-terminal-lineage-stale'
  ),
  'scheduled',
  'scheduled proposal terminalization without terminal activation keeps proposal scheduled'
);

update public.plan_versions
   set is_active = false
 where user_id = '10000000-0000-0000-0000-000000000002'
   and is_active = true;

set local role service_role;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);

update public.change_schedule_availability_versions
   set lifecycle_state = 'superseded'
 where user_id = '10000000-0000-0000-0000-000000000002'
   and lifecycle_state = 'scheduled';

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'storage-direct-source',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-01 09:20:00+00',
  'onboarding',
  true,
  1,
  '{"id":"storage-direct-source","weeks":[]}'::jsonb
),
(
  'storage-direct-candidate',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-01 09:21:00+00',
  'settings_update',
  false,
  1,
  '{"id":"storage-direct-candidate","weeks":[]}'::jsonb
);

update public.change_schedule_availability_versions
   set lifecycle_state = 'superseded'
 where user_id = '10000000-0000-0000-0000-000000000002'
   and lifecycle_state = 'active';

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
  'storage-direct-avail',
  '10000000-0000-0000-0000-000000000002',
  'scheduled',
  '2026-08-03',
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
  'proposal-storage-direct-only',
  '10000000-0000-0000-0000-000000000002',
  'storage-direct-source',
  (select schema_version from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
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
  '{"id":"storage-direct-candidate","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-08-03',
  'scheduled',
  '2026-07-01 09:20:00+00',
  '2026-07-01 09:20:00+00',
  null,
  null,
  'storage-direct-candidate'
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
  'activation-storage-direct-only',
  '10000000-0000-0000-0000-000000000002',
  'storage-direct-source',
  'storage-direct-candidate',
  'storage-direct-avail',
  '2026-08-03',
  'scheduled',
  'proposal-storage-direct-only',
  '2026-07-01 09:20:00+00',
  '2026-07-01 09:20:00+00'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'cancelled',
           scheduled_plan_version_id = null,
           cancelled_at = '2026-07-01 09:21:00+00'
     where id = 'proposal-storage-direct-only'
  $$,
  'P0001',
  'change_schedule_proposal_terminalization_activation_not_found',
  'proposal-only scheduled cancellation is rejected without terminal activation'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  'scheduled',
  'proposal-only scheduled cancellation keeps status scheduled'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  'storage-direct-candidate',
  'proposal-only scheduled cancellation does not clear scheduled linkage'
);

select is(
  (
    select accepted_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  null::text,
  'proposal-only scheduled cancellation does not populate accepted plan'
);

select is(
  (
    select accepted_at
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  null::timestamptz,
  'proposal-only scheduled cancellation does not populate accepted timestamp'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-storage-direct-only'
  ),
  'scheduled',
  'proposal-only scheduled cancellation keeps activation scheduled'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'cancelled',
           scheduled_plan_version_id = null,
           cancelled_at = '2026-07-01 09:23:00+00'
     where id = 'proposal-storage-direct-only'
  $$,
  'P0001',
  'change_schedule_proposal_terminalization_activation_not_found',
  'proposal-only scheduled cancellation is rejected with mismatched terminal chain'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  'scheduled',
  'mismatched terminal activation does not alter proposal status'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'superseded',
           scheduled_plan_version_id = null,
           superseded_at = '2026-07-01 09:22:00+00'
     where id = 'proposal-storage-direct-only'
  $$,
  'P0001',
  'change_schedule_proposal_terminalization_activation_not_found',
  'proposal-only scheduled superseded is rejected without terminal activation'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  'scheduled',
  'proposal-only scheduled superseded keeps status scheduled'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  'storage-direct-candidate',
  'proposal-only scheduled superseded does not clear scheduled linkage'
);

select is(
  (
    select accepted_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  null::text,
  'proposal-only scheduled superseded does not populate accepted plan'
);

select throws_ok(
  $$
    update public.change_schedule_proposals
       set status = 'accepted',
           scheduled_plan_version_id = null
     where id = 'proposal-storage-direct-only'
  $$,
  'P0001',
  'change_schedule_proposal_acceptance_requires_activated_activation',
  'proposal-only scheduled accepted is rejected without activated activation'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  'scheduled',
  'proposal-only scheduled accepted keeps status scheduled'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  'storage-direct-candidate',
  'proposal-only scheduled accepted does not clear scheduled linkage'
);

select is(
  (
    select accepted_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  null::text,
  'proposal-only scheduled accepted does not populate accepted plan'
);

select is(
  (
    select accepted_at
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  null::timestamptz,
  'proposal-only scheduled accepted does not populate accepted timestamp'
);

select is(
  (
    select prior_active_availability_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only'
  ),
  null::text,
  'proposal-only scheduled accepted does not populate prior active availability'
);

  select is(
  (
    select status
     from public.change_schedule_activations
    where id = 'activation-storage-direct-only'
   ),
   'scheduled',
  'proposal-only scheduled accepted keeps activation scheduled'
  );

update public.change_schedule_availability_versions
   set lifecycle_state = 'superseded'
 where id = 'availability-peer-restore'
   and user_id = '10000000-0000-0000-0000-000000000002';

update public.change_schedule_activations
   set status = 'cancelled',
       cancelled_at = '2026-07-01 09:20:00+00',
       activated_at = null,
       stale_at = null,
       superseded_at = null,
       updated_at = '2026-07-01 09:20:00+00'
 where id = 'activation-storage-direct-only'
   and status = 'scheduled';

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
  'storage-direct-avail-active',
  '10000000-0000-0000-0000-000000000002',
  'active',
  '2026-08-03',
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
  'activation-storage-direct-bootstrap',
  '10000000-0000-0000-0000-000000000002',
  'storage-direct-source',
  'storage-direct-candidate',
  'storage-direct-avail',
  '2026-08-03',
  'scheduled',
  'proposal-storage-direct-only',
  '2026-07-01 09:20:00+00',
  '2026-07-01 09:20:00+00'
);

select lives_ok(
  $$
    update public.change_schedule_activations
       set status = 'activated',
           prior_active_plan_version_id = 'storage-direct-source',
           prior_active_availability_version_id = 'availability-scheduled-today',
           availability_version_id = 'storage-direct-avail-active',
           activated_at = '2026-08-03 10:00:00+00'
     where id = 'activation-storage-direct-bootstrap'
  $$,
  'service role can complete scheduled->activated transition and initialize snapshots'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-storage-direct-bootstrap'
  ),
  'activated',
  'service-role transition initializes activated status'
);

select is(
  (
    select prior_active_plan_version_id
      from public.change_schedule_activations
     where id = 'activation-storage-direct-bootstrap'
  ),
  'storage-direct-source',
  'service-role transition preserves prior active plan snapshot'
);

select is(
  (
    select prior_active_availability_version_id
      from public.change_schedule_activations
     where id = 'activation-storage-direct-bootstrap'
  ),
  'availability-scheduled-today',
  'service-role transition preserves prior active availability snapshot'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set proposal_id = null
     where id = 'activation-storage-direct-bootstrap'
  $$,
  'P0001',
  'change_schedule_activation_proposal_inconsistent',
  'activated storage activation proposal relink cannot be cleared'
);
select is(
  (
    select proposal_id
      from public.change_schedule_activations
     where id = 'activation-storage-direct-bootstrap'
  ),
  'proposal-storage-direct-only',
  'activated storage activation relinking cannot clear proposal_id'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set prior_active_plan_version_id = 'storage-direct-candidate'
     where id = 'activation-storage-direct-bootstrap'
  $$,
  'P0001',
  'change_schedule_activation_snapshot_immutable',
  'service role rejects prior active plan snapshot rewrite after activation'
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
  'activation-storage-direct-missing-snapshot',
  '10000000-0000-0000-0000-000000000002',
  'storage-direct-source',
  'storage-direct-candidate',
  'storage-direct-avail',
  '2026-08-03',
  'scheduled',
  'proposal-storage-direct-only',
  '2026-07-01 09:20:00+00',
  '2026-07-01 09:20:00+00'
);

select throws_ok(
  $$
    update public.change_schedule_activations
       set status = 'activated',
           prior_active_plan_version_id = 'storage-direct-source',
           availability_version_id = 'storage-direct-avail-active',
           activated_at = '2026-08-03 10:15:00+00'
     where id = 'activation-storage-direct-missing-snapshot'
  $$,
  'P0001',
  'change_schedule_activation_snapshot_availability_missing',
  'service role rejects scheduled->activated transition with missing prior snapshot availability'
);

update public.change_schedule_activations
   set status = 'cancelled',
       cancelled_at = '2026-08-03 10:30:00+00',
       activated_at = null,
       stale_at = null,
       superseded_at = null,
       updated_at = '2026-08-03 10:30:00+00'
 where id = 'activation-storage-direct-missing-snapshot';

update public.change_schedule_activations
   set status = 'cancelled',
       cancelled_at = '2026-07-01 10:00:00+00',
       activated_at = null,
       stale_at = null,
       superseded_at = null,
       updated_at = '2026-07-01 10:00:00+00'
 where id = 'activation-storage-direct-only';

insert into public.plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
) values (
  'storage-direct-candidate-mismatch-context',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-20 10:00:00+00',
  'onboarding',
  false,
  1,
  '{"id":"storage-direct-candidate-mismatch-context","weeks":[]}'::jsonb
);

update public.change_schedule_availability_versions
   set lifecycle_state = 'superseded'
 where user_id = '10000000-0000-0000-0000-000000000002'
   and lifecycle_state = 'active';

update public.change_schedule_availability_versions
   set lifecycle_state = 'superseded'
 where user_id = '10000000-0000-0000-0000-000000000002'
   and lifecycle_state = 'scheduled';

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
  'storage-direct-active-mismatch-context',
  '10000000-0000-0000-0000-000000000002',
  'superseded',
  '2026-08-03',
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

update public.change_schedule_availability_versions
   set lifecycle_state = 'superseded'
 where user_id = '10000000-0000-0000-0000-000000000002'
   and lifecycle_state = 'scheduled'
   and id = 'storage-direct-avail';

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
  'availability-direct-mismatch-context',
  '10000000-0000-0000-0000-000000000002',
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
  'availability-direct-mismatch-context-activated',
  '10000000-0000-0000-0000-000000000002',
  'active',
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
  'proposal-storage-direct-only-mismatch-context',
  '10000000-0000-0000-0000-000000000002',
  'storage-direct-source',
  (select schema_version from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
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
  '{"id":"storage-direct-candidate-mismatch-context","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-09-28',
  'scheduled',
  '2026-07-20 10:00:00+00',
  '2026-07-20 10:00:00+00',
  null,
  null,
  'storage-direct-candidate-mismatch-context'
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
  'activation-storage-direct-only-mismatch-context',
  '10000000-0000-0000-0000-000000000002',
  'storage-direct-source',
  'storage-direct-candidate-mismatch-context',
  'availability-direct-mismatch-context',
  '2026-09-28',
  'scheduled',
  'proposal-storage-direct-only-mismatch-context',
  '2026-07-20 10:00:00+00',
  '2026-07-20 10:00:00+00'
);

update public.change_schedule_activations
   set status = 'activated',
       prior_active_plan_version_id = 'storage-direct-source',
       availability_version_id = 'availability-direct-mismatch-context-activated',
       prior_active_availability_version_id = 'availability-direct-mismatch-context',
       activated_at = '2026-09-28 00:00:00+00',
       updated_at = '2026-09-28 00:00:00+00'
 where id = 'activation-storage-direct-only-mismatch-context';

select throws_ok(
  $$
    update public.change_schedule_proposals
  set status = 'accepted',
           scheduled_plan_version_id = null,
           accepted_plan_version_id = 'storage-direct-candidate-mismatch-context',
           accepted_at = '2026-09-28 00:00:00+00',
           prior_active_plan_version_id = 'storage-direct-source',
           prior_active_availability_version_id = 'availability-direct-mismatch-context-activated',
           accepted_availability_version_id = 'availability-direct-mismatch-context-activated'
     where id = 'proposal-storage-direct-only-mismatch-context'
  $$,
  'P0001',
  'change_schedule_proposal_accepted_activation_context_mismatch',
  'proposal-only scheduled acceptance with mismatched prior availability context is rejected in storage path'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only-mismatch-context'
  ),
  'scheduled',
  'mismatched prior availability keeps storage proposal scheduled'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only-mismatch-context'
  ),
  'storage-direct-candidate-mismatch-context',
  'mismatched prior availability keeps storage proposal linkage'
);

select is(
  (
    select accepted_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only-mismatch-context'
  ),
  null::text,
  'mismatched prior availability does not persist accepted plan in storage path'
);

select is(
  (
    select accepted_at
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only-mismatch-context'
  ),
  null::timestamptz,
  'mismatched prior availability does not persist accepted timestamp in storage path'
);

select is(
  (
    select prior_active_availability_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only-mismatch-context'
  ),
  null::text,
  'mismatched prior availability does not persist prior availability in storage path'
);

select is(
  (
    select status
     from public.change_schedule_activations
     where id = 'activation-storage-direct-only-mismatch-context'
  ),
  'activated',
  'storage mismatch attempt leaves activation activated'
);

-- Terminalized activation snapshots should remain authoritative if source plan becomes inactive.
update public.plan_versions
  set is_active = false
 where id = 'storage-direct-source'
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
  'storage-direct-source-immutable-context',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-01 09:30:00+00',
  'onboarding',
  true,
  1,
  '{"id":"storage-direct-source-immutable-context","weeks":[]}'::jsonb
),
(
  'storage-direct-candidate-immutable-context',
  '10000000-0000-0000-0000-000000000002',
  '2026-07-01 09:31:00+00',
  'settings_update',
  false,
  1,
  '{"id":"storage-direct-candidate-immutable-context","weeks":[]}'::jsonb
);

update public.change_schedule_availability_versions
   set lifecycle_state = 'superseded'
 where user_id = '10000000-0000-0000-0000-000000000002'
   and lifecycle_state = 'active';

update public.change_schedule_availability_versions
   set lifecycle_state = 'superseded'
 where user_id = '10000000-0000-0000-0000-000000000002'
   and lifecycle_state = 'scheduled';

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
  'availability-direct-prior-immutable-context',
  '10000000-0000-0000-0000-000000000002',
  'superseded',
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
  'availability-direct-queued-immutable-context',
  '10000000-0000-0000-0000-000000000002',
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
  'availability-direct-activated-immutable-context',
  '10000000-0000-0000-0000-000000000002',
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
  'proposal-storage-direct-only-immutable-context',
  '10000000-0000-0000-0000-000000000002',
  'storage-direct-source-immutable-context',
  (select schema_version from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
  (select updated_at from public.runner_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
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
  '{"id":"storage-direct-candidate-immutable-context","weeks":[]}'::jsonb,
  '{}'::jsonb,
  '2026-10-05',
  'scheduled',
  '2026-07-01 09:30:00+00',
  '2026-07-01 09:30:00+00',
  null,
  null,
  'storage-direct-candidate-immutable-context'
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
  'activation-storage-direct-only-immutable-context',
  '10000000-0000-0000-0000-000000000002',
  'storage-direct-source-immutable-context',
  'storage-direct-candidate-immutable-context',
  'availability-direct-queued-immutable-context',
  '2026-10-05',
  'scheduled',
  'proposal-storage-direct-only-immutable-context',
  '2026-07-01 09:30:00+00',
  '2026-07-01 09:30:00+00'
);

update public.change_schedule_activations
   set status = 'activated',
       availability_version_id = 'availability-direct-activated-immutable-context',
       activated_at = '2026-10-05 00:00:00+00',
       prior_active_plan_version_id = 'storage-direct-source-immutable-context',
       prior_active_availability_version_id = 'availability-direct-prior-immutable-context',
       updated_at = '2026-10-01 00:00:00+00'
 where id = 'activation-storage-direct-only-immutable-context';

update public.change_schedule_availability_versions
   set lifecycle_state = 'cancelled'
 where id in (
  'availability-direct-prior-immutable-context',
  'availability-direct-activated-immutable-context'
 ) and user_id = '10000000-0000-0000-0000-000000000002';

select lives_ok(
  $$
    update public.change_schedule_proposals
       set status = 'accepted',
           scheduled_plan_version_id = null,
           accepted_plan_version_id = 'storage-direct-candidate-immutable-context',
           accepted_at = '2026-10-05 00:00:00+00',
           prior_active_plan_version_id = 'storage-direct-source-immutable-context',
           prior_active_availability_version_id = 'availability-direct-prior-immutable-context',
           accepted_availability_version_id = 'availability-direct-activated-immutable-context'
     where id = 'proposal-storage-direct-only-immutable-context'
  $$,
  'proposal-only scheduled accepted with stale source context passes using immutable terminal activation snapshots'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only-immutable-context'
  ),
  'accepted',
  'proposal-only scheduled accepted with immutable snapshots transitions to accepted'
);

select is(
  (
    select accepted_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only-immutable-context'
  ),
  'storage-direct-candidate-immutable-context',
  'proposal-only scheduled accepted stores accepted plan with immutable snapshot context'
);

select is(
  (
    select prior_active_plan_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only-immutable-context'
  ),
  'storage-direct-source-immutable-context',
  'proposal-only scheduled accepted stores immutable prior active plan snapshot'
);

select is(
  (
    select prior_active_availability_version_id
      from public.change_schedule_proposals
     where id = 'proposal-storage-direct-only-immutable-context'
  ),
  'availability-direct-prior-immutable-context',
  'proposal-only scheduled accepted stores immutable prior active availability snapshot'
);

select is(
  (
    select status
      from public.change_schedule_activations
     where id = 'activation-storage-direct-only-immutable-context'
  ),
  'activated',
  'snapshot-protected scheduled accepted attempt leaves activation terminal'
);

select * from finish();

rollback;
