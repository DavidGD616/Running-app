create extension if not exists pgtap with schema extensions;

set search_path to public, extensions;

begin;

select no_plan();

-- Keep every fixture deterministic and roll the complete suite back at the end.
insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000001', 'edit-goal-main@example.test'),
  ('10000000-0000-0000-0000-000000000002', 'edit-goal-expired@example.test'),
  ('10000000-0000-0000-0000-000000000003', 'edit-goal-stale@example.test'),
  ('10000000-0000-0000-0000-000000000004', 'edit-goal-unique@example.test'),
  ('10000000-0000-0000-0000-000000000005', 'edit-goal-inactive@example.test'),
  ('10000000-0000-0000-0000-000000000006', 'edit-goal-rls-a@example.test'),
  ('10000000-0000-0000-0000-000000000007', 'edit-goal-rls-b@example.test');

insert into runner_profiles (user_id, schema_version, data)
values
  (
    '10000000-0000-0000-0000-000000000001',
    7,
    '{
      "goal": {"race": "5k", "targetSeconds": 1800},
      "acceptedRaceTarget": {"distance": "5k", "targetSeconds": 1800},
      "preferences": {"units": "metric", "days": ["tue", "thu"]},
      "displayName": "Main Runner",
      "nested": {"preserve": true}
    }'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    1,
    '{"goal":{"race":"5k"},"marker":"expired-original"}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000003',
    1,
    '{"goal":{"race":"10k"},"marker":"stale-original"}'::jsonb
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
    '{"id":"main-source","weeks":[{"week":1}]}'::jsonb
  ),
  (
    'expired-source',
    '10000000-0000-0000-0000-000000000002',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"expired-source","weeks":[]}'::jsonb
  ),
  (
    'stale-source',
    '10000000-0000-0000-0000-000000000003',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"stale-source","weeks":[]}'::jsonb
  ),
  (
    'unique-source',
    '10000000-0000-0000-0000-000000000004',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"unique-source","weeks":[]}'::jsonb
  ),
  (
    'inactive-source',
    '10000000-0000-0000-0000-000000000005',
    '2026-07-01 09:00:00+00',
    'onboarding',
    false,
    1,
    '{"id":"inactive-source","weeks":[]}'::jsonb
  ),
  (
    'rls-source-a',
    '10000000-0000-0000-0000-000000000006',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"rls-source-a","weeks":[]}'::jsonb
  ),
  (
    'rls-source-b',
    '10000000-0000-0000-0000-000000000007',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"rls-source-b","weeks":[]}'::jsonb
  );

-- Schema, ownership, RLS, and grants.
select has_table('public', 'goal_edit_proposals', 'goal-edit proposals table exists');
select col_type_is('public', 'goal_edit_proposals', 'id', 'text', 'proposal ID is text');
select col_type_is('public', 'goal_edit_proposals', 'user_id', 'uuid', 'proposal owner is a UUID');
select col_not_null('public', 'goal_edit_proposals', 'user_id', 'proposal owner is required');
select col_not_null(
  'public',
  'goal_edit_proposals',
  'source_plan_version_id',
  'source plan is required'
);
select col_not_null(
  'public',
  'goal_edit_proposals',
  'candidate_plan',
  'candidate plan is required'
);
select col_not_null(
  'public',
  'goal_edit_proposals',
  'proposed_goal',
  'proposed goal is required'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.goal_edit_proposals'::regclass
  ),
  'RLS is enabled on goal-edit proposals'
);
select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and tablename = 'goal_edit_proposals'
      and policyname = 'Users view own goal edit proposals'
      and cmd = 'SELECT'
  ),
  1,
  'the owner-select RLS policy exists'
);
select ok(
  has_table_privilege('authenticated', 'public.goal_edit_proposals', 'SELECT'),
  'authenticated users may select proposals through RLS'
);
select ok(
  not has_table_privilege('authenticated', 'public.goal_edit_proposals', 'INSERT'),
  'authenticated users cannot insert proposals directly'
);
select ok(
  not has_table_privilege('anon', 'public.goal_edit_proposals', 'SELECT'),
  'anonymous users cannot read proposals'
);
select ok(
  has_table_privilege('service_role', 'public.goal_edit_proposals', 'INSERT,UPDATE,DELETE'),
  'service role owns the proposal write path'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.store_goal_edit_proposal(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb,integer,timestamptz,timestamptz)',
    'EXECUTE'
  ),
  'authenticated users cannot execute the proposal storage RPC'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.accept_goal_edit_proposal(uuid,text,text,timestamptz)',
    'EXECUTE'
  ),
  'anonymous users cannot execute the acceptance RPC'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.store_goal_edit_proposal(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb,integer,timestamptz,timestamptz)',
    'EXECUTE'
  ),
  'service role can execute the proposal storage RPC'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.accept_goal_edit_proposal(uuid,text,text,timestamptz)',
    'EXECUTE'
  ),
  'service role can execute the acceptance RPC'
);

-- Exercise authorization as the same database roles used by Supabase clients.
select lives_ok(
  $$
    select public.store_goal_edit_proposal(
      '10000000-0000-0000-0000-000000000006',
      'rls-proposal-a',
      'rls-source-a',
      '{"id":"rls-candidate-a","weeks":[]}'::jsonb,
      '{"race":"10k"}'::jsonb,
      '{}'::jsonb,
      '{}'::jsonb,
      '[]'::jsonb,
      null,
      now(),
      now() + interval '30 minutes'
    )
  $$,
  'the service-owned write path stores the user A RLS fixture'
);
select lives_ok(
  $$
    select public.store_goal_edit_proposal(
      '10000000-0000-0000-0000-000000000007',
      'rls-proposal-b',
      'rls-source-b',
      '{"id":"rls-candidate-b","weeks":[]}'::jsonb,
      '{"race":"half_marathon"}'::jsonb,
      '{}'::jsonb,
      '{}'::jsonb,
      '[]'::jsonb,
      null,
      now(),
      now() + interval '30 minutes'
    )
  $$,
  'the service-owned write path stores the user B RLS fixture'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000006',
  true
);
select is(
  (
    select array_agg(id order by id)
    from public.goal_edit_proposals
  ),
  array['rls-proposal-a']::text[],
  'authenticated user A sees only its own proposal'
);
-- The local Supabase PostgreSQL image currently SIGSEGVs instead of returning
-- 42501 when either revoked RPC is parsed under SET ROLE (including EXPLAIN).
-- Assert the effective privilege from the client role until that engine bug is
-- fixed; owner isolation above remains a direct behavioral RLS query.
select ok(
  not has_function_privilege(
    current_user,
    'public.store_goal_edit_proposal(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb,integer,timestamptz,timestamptz)',
    'EXECUTE'
  ),
  'the authenticated client context cannot execute the storage RPC'
);
select ok(
  not has_function_privilege(
    current_user,
    'public.accept_goal_edit_proposal(uuid,text,text,timestamptz)',
    'EXECUTE'
  ),
  'the authenticated client context cannot execute the acceptance RPC'
);
reset role;
select set_config('request.jwt.claim.sub', '', true);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000007',
  true
);
select is(
  (
    select array_agg(id order by id)
    from public.goal_edit_proposals
  ),
  array['rls-proposal-b']::text[],
  'authenticated user B sees only its own proposal'
);
reset role;
select set_config('request.jwt.claim.sub', '', true);

set local role anon;
select throws_ok(
  $$ select count(*) from public.goal_edit_proposals $$,
  '42501',
  'permission denied for table goal_edit_proposals',
  'anonymous users cannot behaviorally read proposal rows'
);
select is(
  current_user,
  'anon',
  'anonymous authorization assertions run as the anon role'
);
select ok(
  not has_function_privilege(
    current_user,
    'public.store_goal_edit_proposal(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb,integer,timestamptz,timestamptz)',
    'EXECUTE'
  ),
  'the anonymous client context cannot execute the storage RPC'
);
select ok(
  not has_function_privilege(
    current_user,
    'public.accept_goal_edit_proposal(uuid,text,text,timestamptz)',
    'EXECUTE'
  ),
  'the anonymous client context cannot execute the acceptance RPC'
);
reset role;

-- Storage defaults to 30 minutes, and a newer proposal supersedes the old one.
select lives_ok(
  $$
    select public.store_goal_edit_proposal(
      '10000000-0000-0000-0000-000000000001',
      'main-proposal-old',
      'main-source',
      '{"id":"candidate-placeholder","weeks":[{"week":1},{"week":2}]}'::jsonb,
      '{"race":"10k","targetSeconds":3600}'::jsonb,
      '{"acceptedRaceTarget":{"distance":"10k","targetSeconds":3600}}'::jsonb,
      '{"distanceChanged":true}'::jsonb,
      '["volume_increase"]'::jsonb,
      3600,
      now() - interval '10 minutes',
      null
    )
  $$,
  'an active source plan can store a proposal'
);
select is(
  (
    select expires_at - created_at
    from goal_edit_proposals
    where id = 'main-proposal-old'
  ),
  interval '30 minutes',
  'proposal expiry defaults to exactly 30 minutes'
);
select lives_ok(
  $$
    select public.store_goal_edit_proposal(
      '10000000-0000-0000-0000-000000000001',
      'main-proposal',
      'main-source',
      '{"id":"candidate-placeholder","weeks":[{"week":1},{"week":2}]}'::jsonb,
      '{"race":"half_marathon","targetSeconds":7200}'::jsonb,
      '{"acceptedRaceTarget":{"distance":"half_marathon","targetSeconds":7200}}'::jsonb,
      '{"distanceChanged":true,"scheduleChanged":false}'::jsonb,
      '["volume_increase"]'::jsonb,
      7200,
      now() - interval '5 minutes',
      now() + interval '25 minutes'
    )
  $$,
  'a newer proposal can replace the pending proposal'
);
select is(
  (select status from goal_edit_proposals where id = 'main-proposal-old'),
  'superseded',
  'the older pending proposal is superseded'
);
select is(
  (
    select superseded_at
    from goal_edit_proposals
    where id = 'main-proposal-old'
  ),
  (select created_at from goal_edit_proposals where id = 'main-proposal'),
  'supersession records the new proposal timestamp'
);
select is(
  (
    select count(*)::integer
    from goal_edit_proposals
    where user_id = '10000000-0000-0000-0000-000000000001'
      and status = 'pending'
  ),
  1,
  'only one pending proposal remains for a user'
);
select throws_ok(
  $$
    insert into goal_edit_proposals (
      id,
      user_id,
      source_plan_version_id,
      candidate_plan,
      proposed_goal,
      status
    ) values (
      'main-proposal-conflict',
      '10000000-0000-0000-0000-000000000001',
      'main-source',
      '{}'::jsonb,
      '{}'::jsonb,
      'pending'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "goal_edit_proposals_one_pending_per_user"',
  'the partial unique index rejects a second pending proposal'
);
select throws_ok(
  $$
    select public.store_goal_edit_proposal(
      '10000000-0000-0000-0000-000000000005',
      'inactive-proposal',
      'inactive-source',
      '{}'::jsonb,
      '{}'::jsonb,
      '{}'::jsonb,
      '{}'::jsonb,
      '[]'::jsonb,
      null,
      now(),
      now() + interval '30 minutes'
    )
  $$,
  'P0001',
  'goal_edit_source_plan_not_active',
  'proposal storage rejects an inactive source plan'
);

-- Acceptance atomically changes the profile, plan set, and proposal state.
select lives_ok(
  $$
    create temporary table main_acceptance_response_snapshot as
    select *
      from public.accept_goal_edit_proposal(
        '10000000-0000-0000-0000-000000000001',
        'main-proposal',
        'main-accepted-plan',
        '2026-07-14 11:00:00+00'
      )
  $$,
  'a pending proposal with an active source plan is accepted'
);
select is(
  (
    select data -> 'goal'
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  '{"race":"half_marathon","targetSeconds":7200}'::jsonb,
  'acceptance replaces only the goal value'
);
select is(
  (
    select data -> 'acceptedRaceTarget'
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  '{"distance":"half_marathon","targetSeconds":7200}'::jsonb,
  'acceptance replaces the accepted race target'
);
select is(
  (
    select data - 'goal' - 'acceptedRaceTarget' - 'updatedAt'
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  '{
    "preferences":{"units":"metric","days":["tue","thu"]},
    "displayName":"Main Runner",
    "nested":{"preserve":true}
  }'::jsonb,
  'acceptance preserves every unrelated profile field'
);
select is(
  (
    select data ->> 'updatedAt'
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  (
    select to_jsonb(updated_at) #>> '{}'
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  'the embedded profile timestamp matches the row timestamp'
);
select is(
  (
    select schema_version
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  7,
  'acceptance preserves unrelated profile columns'
);
select is(
  (select is_active from plan_versions where id = 'main-source'),
  false,
  'the source plan is deactivated'
);
select is(
  (select requested_by from plan_versions where id = 'main-accepted-plan'),
  'edit_goal',
  'the accepted candidate records edit_goal as its origin'
);
select is(
  (select is_active from plan_versions where id = 'main-accepted-plan'),
  true,
  'the accepted candidate is active'
);
select is(
  (select data ->> 'id' from plan_versions where id = 'main-accepted-plan'),
  'main-accepted-plan',
  'the accepted candidate embeds its immutable plan ID'
);
select is(
  (
    select count(*)::integer
    from plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and is_active
  ),
  1,
  'exactly one active plan remains after acceptance'
);
select is(
  (select status from goal_edit_proposals where id = 'main-proposal'),
  'accepted',
  'the proposal is marked accepted'
);
select ok(
  (
    select accepted_at is not null
      and accepted_plan_version_id = 'main-accepted-plan'
    from goal_edit_proposals
    where id = 'main-proposal'
  ),
  'accepted proposal stores its timestamp and immutable plan link'
);

create temporary table main_acceptance_snapshot as
select
  proposal.accepted_at,
  profile.data as profile_data,
  profile.updated_at as profile_updated_at,
  plan.id as active_plan_id,
  plan.generated_at as active_plan_generated_at,
  plan.data as active_plan_data
from goal_edit_proposals as proposal
join runner_profiles as profile
  on profile.user_id = proposal.user_id
join plan_versions as plan
  on plan.user_id = proposal.user_id
 and plan.is_active = true
where proposal.id = 'main-proposal';

-- A retry is deterministic: it returns the first plan and creates no second plan.
select is(
  (
    select to_jsonb(retry_response)
    from public.accept_goal_edit_proposal(
      '10000000-0000-0000-0000-000000000001',
      'main-proposal',
      'main-retry-response-must-not-exist',
      '2026-07-14 13:00:00+00'
    ) as retry_response
  ),
  (
    select to_jsonb(first_response)
    from main_acceptance_response_snapshot as first_response
  ),
  'duplicate acceptance returns the immutable canonical acceptance response'
);
select is(
  (
    select new_plan_version_id
    from public.accept_goal_edit_proposal(
      '10000000-0000-0000-0000-000000000001',
      'main-proposal',
      'main-retry-must-not-exist',
      '2026-07-14 12:00:00+00'
    )
  ),
  'main-accepted-plan',
  'duplicate acceptance returns the original accepted plan'
);
select is(
  (select accepted_at from goal_edit_proposals where id = 'main-proposal'),
  (select accepted_at from main_acceptance_snapshot),
  'duplicate acceptance preserves the original acceptance timestamp'
);
select is(
  (
    select data
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  (select profile_data from main_acceptance_snapshot),
  'duplicate acceptance does not mutate profile data'
);
select is(
  (
    select updated_at
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  (select profile_updated_at from main_acceptance_snapshot),
  'duplicate acceptance preserves the profile timestamp'
);
select is(
  (
    select id
    from plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and is_active = true
  ),
  (select active_plan_id from main_acceptance_snapshot),
  'duplicate acceptance preserves the active plan identity'
);
select is(
  (
    select generated_at
    from plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and is_active = true
  ),
  (select active_plan_generated_at from main_acceptance_snapshot),
  'duplicate acceptance ignores the retry generation timestamp'
);
select is(
  (
    select data
    from plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and is_active = true
  ),
  (select active_plan_data from main_acceptance_snapshot),
  'duplicate acceptance does not mutate active plan data'
);
select is(
  (
    select count(*)::integer
    from plan_versions
    where id in ('main-accepted-plan', 'main-retry-must-not-exist')
  ),
  1,
  'duplicate acceptance cannot create a second candidate plan'
);

-- The active-plan index is the final deterministic guard against competing writers.
select throws_ok(
  $$
    insert into plan_versions (
      id,
      user_id,
      generated_at,
      requested_by,
      is_active,
      schema_version,
      data
    ) values (
      'unique-conflicting-active',
      '10000000-0000-0000-0000-000000000004',
      now(),
      'test',
      true,
      1,
      '{"id":"unique-conflicting-active"}'::jsonb
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "plan_versions_one_active_per_user"',
  'the database rejects two active plans for one user'
);

-- Expiration fails before any profile or plan mutation.
select lives_ok(
  $$
    select public.store_goal_edit_proposal(
      '10000000-0000-0000-0000-000000000002',
      'expired-proposal',
      'expired-source',
      '{"id":"expired-candidate","weeks":[]}'::jsonb,
      '{"race":"marathon"}'::jsonb,
      '{}'::jsonb,
      '{}'::jsonb,
      '[]'::jsonb,
      null,
      now() - interval '60 minutes',
      now() - interval '30 minutes'
    )
  $$,
  'an already elapsed proposal can be stored for expiry-path testing'
);
select throws_ok(
  $$
    select *
    from public.accept_goal_edit_proposal(
      '10000000-0000-0000-0000-000000000002',
      'expired-proposal',
      'expired-candidate',
      now()
    )
  $$,
  'P0001',
  'goal_edit_proposal_expired',
  'expired acceptance is rejected'
);
select is(
  (
    select data
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000002'
  ),
  '{"goal":{"race":"5k"},"marker":"expired-original"}'::jsonb,
  'expired acceptance leaves the profile unchanged'
);
select is(
  (select is_active from plan_versions where id = 'expired-source'),
  true,
  'expired acceptance leaves the source plan active'
);
select is(
  (select count(*)::integer from plan_versions where id = 'expired-candidate'),
  0,
  'expired acceptance inserts no candidate plan'
);
select is(
  (select status from goal_edit_proposals where id = 'expired-proposal'),
  'pending',
  'failed expired acceptance does not partially update the proposal'
);

-- A plan that changed after preview makes the proposal stale, with no partial mutation.
select lives_ok(
  $$
    select public.store_goal_edit_proposal(
      '10000000-0000-0000-0000-000000000003',
      'stale-proposal',
      'stale-source',
      '{"id":"stale-candidate","weeks":[]}'::jsonb,
      '{"race":"marathon"}'::jsonb,
      '{}'::jsonb,
      '{}'::jsonb,
      '[]'::jsonb,
      null,
      now(),
      now() + interval '30 minutes'
    )
  $$,
  'a proposal can be stored before its source becomes stale'
);
update plan_versions set is_active = false where id = 'stale-source';
insert into plan_versions (
  id,
  user_id,
  generated_at,
  requested_by,
  is_active,
  schema_version,
  data
)
values (
  'stale-replacement',
  '10000000-0000-0000-0000-000000000003',
  now(),
  'settings_update',
  true,
  1,
  '{"id":"stale-replacement","weeks":[]}'::jsonb
);
select throws_ok(
  $$
    select *
    from public.accept_goal_edit_proposal(
      '10000000-0000-0000-0000-000000000003',
      'stale-proposal',
      'stale-candidate',
      now()
    )
  $$,
  'P0001',
  'goal_edit_source_plan_stale',
  'acceptance rejects a proposal whose source is no longer active'
);
select is(
  (
    select data
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000003'
  ),
  '{"goal":{"race":"10k"},"marker":"stale-original"}'::jsonb,
  'stale acceptance leaves the profile unchanged'
);
select is(
  (select is_active from plan_versions where id = 'stale-replacement'),
  true,
  'stale acceptance leaves the replacement plan active'
);
select is(
  (select count(*)::integer from plan_versions where id = 'stale-candidate'),
  0,
  'stale acceptance inserts no candidate plan'
);
select is(
  (select status from goal_edit_proposals where id = 'stale-proposal'),
  'pending',
  'failed stale acceptance does not partially update the proposal'
);

-- Replacing a plan through Edit Goal terminalizes pending and queued Change
-- Schedule state based on that source in the same transaction.
insert into auth.users (id, email)
values (
  '10000000-0000-0000-0000-000000000008',
  'edit-goal-change-schedule-terminalization@example.test'
);

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000008', true);

insert into runner_profiles (user_id, schema_version, updated_at, data)
values (
  '10000000-0000-0000-0000-000000000008',
  1,
  '2026-07-20 08:00:00+00',
  '{"goal":{"race":"10k"},"marker":"edit-goal-change-schedule"}'::jsonb
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
values (
  'edit-goal-change-schedule-source',
  '10000000-0000-0000-0000-000000000008',
  '2026-07-20 08:00:00+00',
  'onboarding',
  true,
  1,
  '{"id":"edit-goal-change-schedule-source","weeks":[]}'::jsonb
);

select lives_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000008',
      'edit-goal-change-schedule-scheduled',
      'edit-goal-change-schedule-source',
      '{"id":"edit-goal-change-schedule-queued-plan","weeks":[]}'::jsonb,
      '{"impact":"scheduled"}'::jsonb,
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
      '2026-08-10',
      '2026-07-20 09:00:00+00',
      '2026-08-01 09:00:00+00',
      1,
      '2026-07-20 08:00:00+00'
    )
  $$,
  'edit-goal fixture stores an old-source Change Schedule proposal'
);

select lives_ok(
  $$
    select *
      from public.schedule_change_schedule_proposal(
        '10000000-0000-0000-0000-000000000008',
        'edit-goal-change-schedule-scheduled',
        'edit-goal-change-schedule-queued-plan',
        'edit-goal-change-schedule-queued-availability',
        '2026-07-20 09:05:00+00'
      )
  $$,
  'edit-goal fixture queues the old-source Change Schedule proposal'
);

select lives_ok(
  $$
    select public.store_change_schedule_proposal(
      '10000000-0000-0000-0000-000000000008',
      'edit-goal-change-schedule-pending',
      'edit-goal-change-schedule-source',
      '{"id":"edit-goal-change-schedule-pending-candidate","weeks":[]}'::jsonb,
      '{"impact":"pending"}'::jsonb,
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
      '2026-08-17',
      '2026-07-20 09:10:00+00',
      '2026-08-01 09:10:00+00',
      1,
      '2026-07-20 08:00:00+00'
    )
  $$,
  'edit-goal fixture stores an old-source pending Change Schedule proposal'
);

select lives_ok(
  $$
    select public.store_goal_edit_proposal(
      '10000000-0000-0000-0000-000000000008',
      'edit-goal-change-schedule-replacement',
      'edit-goal-change-schedule-source',
      '{"id":"edit-goal-change-schedule-replacement-plan","weeks":[]}'::jsonb,
      '{"race":"half_marathon","targetSeconds":7200}'::jsonb,
      '{}'::jsonb,
      '{"goalChanged":true}'::jsonb,
      '[]'::jsonb,
      7200,
      now(),
      now() + interval '30 minutes'
    )
  $$,
  'edit-goal fixture stores the plan-replacement proposal'
);

select lives_ok(
  $$
    select *
      from public.accept_goal_edit_proposal(
        '10000000-0000-0000-0000-000000000008',
        'edit-goal-change-schedule-replacement',
        'edit-goal-change-schedule-replacement-plan',
        now()
      )
  $$,
  'edit-goal acceptance terminalizes old-source Change Schedule state'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'edit-goal-change-schedule-pending'
  ),
  'superseded',
  'edit-goal acceptance supersedes the old-source pending Change Schedule proposal'
);

select ok(
  (
    select source_plan_version_id = 'edit-goal-change-schedule-source'
       and superseded_at is not null
      from public.change_schedule_proposals
     where id = 'edit-goal-change-schedule-pending'
  ),
  'edit-goal pending terminalization retains source audit data'
);

select is(
  (
    select status
      from public.change_schedule_proposals
     where id = 'edit-goal-change-schedule-scheduled'
  ),
  'superseded',
  'edit-goal acceptance supersedes the old-source scheduled Change Schedule proposal'
);

select is(
  (
    select scheduled_plan_version_id
      from public.change_schedule_proposals
     where id = 'edit-goal-change-schedule-scheduled'
  ),
  null::text,
  'edit-goal scheduled terminalization clears only the active queue link'
);

select ok(
  (
    select status = 'stale'
       and proposal_id = 'edit-goal-change-schedule-scheduled'
       and stale_at is not null
      from public.change_schedule_activations
     where user_id = '10000000-0000-0000-0000-000000000008'
  ),
  'edit-goal acceptance marks its scheduled activation stale before proposal terminalization'
);

select is(
  (
    select is_active
      from plan_versions
     where id = 'edit-goal-change-schedule-queued-plan'
  ),
  false,
  'edit-goal stale-source terminalization does not activate the queued candidate plan'
);

select is(
  (
    select lifecycle_state
      from public.change_schedule_availability_versions
     where id = 'edit-goal-change-schedule-queued-availability'
  ),
  'scheduled',
  'edit-goal stale-source terminalization preserves queued availability audit state'
);

select is(
  (
    select count(*)::integer
      from public.change_schedule_proposals
     where user_id = '10000000-0000-0000-0000-000000000008'
       and source_plan_version_id = 'edit-goal-change-schedule-source'
       and status in ('pending', 'scheduled')
  ),
  0,
  'edit-goal acceptance leaves no pending or scheduled old-source Change Schedule proposal'
);

select * from finish();

rollback;
