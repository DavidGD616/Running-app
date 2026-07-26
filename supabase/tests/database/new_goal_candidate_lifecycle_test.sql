create extension if not exists pgtap with schema extensions;

set search_path to public, extensions;

begin;

select no_plan();

-- Keep every fixture deterministic and roll the complete suite back at the end.
insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000001', 'new-goal-main@example.test'),
  ('10000000-0000-0000-0000-000000000002', 'new-goal-expired@example.test'),
  ('10000000-0000-0000-0000-000000000003', 'new-goal-stale@example.test'),
  ('10000000-0000-0000-0000-000000000004', 'new-goal-unique@example.test'),
  ('10000000-0000-0000-0000-000000000005', 'new-goal-rls-a@example.test'),
  ('10000000-0000-0000-0000-000000000006', 'new-goal-rls-b@example.test'),
  ('10000000-0000-0000-0000-000000000007', 'new-goal-draft@example.test');

insert into runner_profiles (user_id, schema_version, data)
values
  (
    '10000000-0000-0000-0000-000000000001',
    7,
    '{
      "goal": {"race": "10k", "targetSeconds": 3600},
      "acceptedRaceTarget": {"distance": "10k", "targetSeconds": 3600},
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
    '{"goal":{"race":"half_marathon"},"marker":"stale-original"}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000004',
    1,
    '{"goal":{"race":"5k"}}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000005',
    1,
    '{"goal":{"race":"10k"}}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000006',
    1,
    '{"goal":{"race":"10k"}}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000007',
    1,
    '{
      "goal":{"race":"half_marathon"},
      "marker":"draft-original",
      "displayName":"Draft Runner"
    }'::jsonb
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
    'main-history',
    '10000000-0000-0000-0000-000000000001',
    '2026-06-01 09:00:00+00',
    'onboarding',
    false,
    1,
    '{"id":"main-history","weeks":[{"week":1}]}'::jsonb
  ),
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
    'rls-source-a',
    '10000000-0000-0000-0000-000000000005',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"rls-source-a","weeks":[]}'::jsonb
  ),
  (
    'rls-source-b',
    '10000000-0000-0000-0000-000000000006',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"rls-source-b","weeks":[]}'::jsonb
  ),
  (
    'draft-source',
    '10000000-0000-0000-0000-000000000007',
    '2026-07-01 09:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"draft-source","weeks":[]}'::jsonb
  );

-- Table shape and security.
select has_table('public', 'new_goal_drafts', 'new_goal_drafts table exists');
select col_type_is('public', 'new_goal_drafts', 'user_id', 'uuid', 'draft owner is a UUID');
select col_not_null('public', 'new_goal_drafts', 'source_plan_version_id', 'draft source plan is required');
select col_not_null('public', 'new_goal_drafts', 'data', 'draft payload is required');
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.new_goal_drafts'::regclass
  ),
  true,
  'RLS is enabled on new goal drafts'
);
select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and tablename = 'new_goal_drafts'
      and policyname = 'Users manage own new goal draft'
      and cmd = 'ALL'
  ),
  1,
  'the draft owner-manage policy exists'
);

select has_table('public', 'new_goal_assessments', 'new_goal_assessments table exists');
select col_not_null('public', 'new_goal_assessments', 'kind', 'assessment kind is required');
select col_not_null('public', 'new_goal_assessments', 'scheduled_for', 'assessment date is required');
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.new_goal_assessments'::regclass
  ),
  true,
  'RLS is enabled on new goal assessments'
);
select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and tablename = 'new_goal_assessments'
      and policyname = 'Users manage own new goal assessments'
      and cmd = 'ALL'
  ),
  1,
  'the assessment owner-manage policy exists'
);

select has_table('public', 'new_goal_proposals', 'new_goal_proposals table exists');
select col_type_is('public', 'new_goal_proposals', 'status', 'text', 'proposal status is text');
select col_not_null('public', 'new_goal_proposals', 'user_id', 'proposal owner is required');
select col_not_null(
  'public',
  'new_goal_proposals',
  'source_plan_version_id',
  'proposal source plan is required'
);
select col_not_null(
  'public',
  'new_goal_proposals',
  'source_profile_schema_version',
  'source profile schema version is required'
);
select col_type_is(
  'public',
  'new_goal_proposals',
  'source_profile_schema_version',
  'integer',
  'source profile schema version is an integer'
);
select col_not_null(
  'public',
  'new_goal_proposals',
  'source_profile_updated_at',
  'source profile timestamp is required'
);
select col_type_is(
  'public',
  'new_goal_proposals',
  'source_profile_updated_at',
  'timestamp with time zone',
  'source profile timestamp is a timestamptz'
);
select col_not_null(
  'public',
  'new_goal_proposals',
  'candidate_plan',
  'candidate plan is required'
);
select col_not_null(
  'public',
  'new_goal_proposals',
  'proposed_goal',
  'proposed goal is required'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.new_goal_proposals'::regclass
  ),
  true,
  'RLS is enabled on new goal proposals'
);
select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and tablename = 'new_goal_proposals'
      and policyname = 'Users view own new goal proposals'
      and cmd = 'SELECT'
  ),
  1,
  'the owner-select proposal RLS policy exists'
);

select ok(
  has_table_privilege('authenticated', 'public.new_goal_drafts', 'SELECT,INSERT,UPDATE,DELETE'),
  'authenticated users may fully manage own new goal drafts'
);
select ok(
  has_table_privilege('authenticated', 'public.new_goal_assessments', 'SELECT,INSERT,UPDATE,DELETE'),
  'authenticated users may fully manage own new goal assessments'
);
select ok(
  has_table_privilege('authenticated', 'public.new_goal_proposals', 'SELECT'),
  'authenticated users may read their own proposals via RLS'
);
select ok(
  not has_table_privilege('authenticated', 'public.new_goal_proposals', 'INSERT,UPDATE,DELETE'),
  'authenticated users cannot write proposals directly'
);
select ok(
  not has_table_privilege('anon', 'public.new_goal_proposals', 'SELECT'),
  'anonymous users cannot read proposals'
);
select ok(
  has_table_privilege('service_role', 'public.new_goal_proposals', 'INSERT,UPDATE,DELETE'),
  'service role may own proposal writes'
);
select ok(
  has_table_privilege('service_role', 'public.new_goal_drafts', 'INSERT,UPDATE,DELETE'),
  'service role can write drafts for migration tasks'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.store_new_goal_proposal(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb,integer,timestamptz,timestamptz,integer,timestamptz)',
    'EXECUTE'
  ),
  'authenticated users cannot execute the proposal storage RPC'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.accept_new_goal_proposal(uuid,text,text,timestamptz)',
    'EXECUTE'
  ),
  'authenticated users cannot execute the acceptance RPC'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.store_new_goal_proposal(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb,integer,timestamptz,timestamptz,integer,timestamptz)',
    'EXECUTE'
  ),
  'anonymous users cannot execute the proposal storage RPC'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.accept_new_goal_proposal(uuid,text,text,timestamptz)',
    'EXECUTE'
  ),
  'anonymous users cannot execute the acceptance RPC'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.store_new_goal_proposal(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb,integer,timestamptz,timestamptz,integer,timestamptz)',
    'EXECUTE'
  ),
  'service role can execute the proposal storage RPC'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.accept_new_goal_proposal(uuid,text,text,timestamptz)',
    'EXECUTE'
  ),
  'service role can execute the acceptance RPC'
);

-- Draft and assessment RLS scope.
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000007', true);
select lives_ok(
  $$
    insert into public.new_goal_drafts (user_id, source_plan_version_id, data, status)
    values ('10000000-0000-0000-0000-000000000007', 'draft-source', '{"stage":"draft-owner"}'::jsonb, 'editing')
  $$,
  'draft fixtures can be stored by owners'
);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000005', true);
select lives_ok(
  $$
    insert into public.new_goal_drafts (user_id, source_plan_version_id, data)
    values ('10000000-0000-0000-0000-000000000005', 'rls-source-a', '{"from":"a"}'::jsonb)
  $$,
  'authenticated user A can insert its own draft'
);
select throws_ok(
  $$
    insert into public.new_goal_drafts (user_id, source_plan_version_id, data)
    values ('10000000-0000-0000-0000-000000000006', 'rls-source-b', '{"from":"blocked"}'::jsonb)
  $$,
  '42501',
  'insufficient_privilege',
  'authenticated user A cannot insert another user''s draft with a known victim plan'
);
select throws_ok(
  $$
    insert into public.new_goal_drafts (user_id, source_plan_version_id, data)
    values ('10000000-0000-0000-0000-000000000006', 'nonexistent-source', '{"from":"blocked-unknown-plan"}'::jsonb)
  $$,
  '42501',
  'insufficient_privilege',
  'authenticated user A cannot insert another user''s draft with an unknown plan'
);
select throws_ok(
  $$
    insert into public.new_goal_drafts (
      user_id,
      source_plan_version_id,
      data
    ) values (
      '10000000-0000-0000-0000-000000000005',
      'rls-source-b',
      '{"from":"cross-plan-blocked-upsert"}'::jsonb
  )
    on conflict (user_id)
    do update set
      source_plan_version_id = excluded.source_plan_version_id,
      data = excluded.data
  $$,
  '42501',
  'new_goal_draft_source_plan_not_owned',
  'authenticated user A cannot upsert with another user''s source plan'
);
select throws_ok(
  $$
    update public.new_goal_drafts
       set source_plan_version_id = 'rls-source-b',
           data = '{"from":"direct-update-blocked"}'::jsonb
     where user_id = '10000000-0000-0000-0000-000000000005'
  $$,
  '42501',
  'new_goal_draft_source_plan_not_owned',
  'authenticated user A cannot switch its draft to another user''s source plan via direct UPDATE'
);
select lives_ok(
  $$
    insert into public.new_goal_drafts (
      user_id,
      source_plan_version_id,
      data
    ) values (
      '10000000-0000-0000-0000-000000000005',
      'rls-source-a',
      '{"from":"owned-upsert"}'::jsonb
    )
    on conflict (user_id)
    do update set
      source_plan_version_id = excluded.source_plan_version_id,
      data = excluded.data
  $$,
  'authenticated user A can upsert its own draft using its source plan'
);
select throws_ok(
  $$
    insert into public.new_goal_assessments (
      id,
      user_id,
      draft_user_id,
      kind,
      scheduled_for,
      status
    ) values (
      'a-draft-assessment-blocked',
      '10000000-0000-0000-0000-000000000006',
      '10000000-0000-0000-0000-000000000007',
      'five_k_run',
      '2026-07-24',
      'scheduled'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "new_goal_assessments"',
  'authenticated user A cannot create another user''s assessment draft'
);
select lives_ok(
  $$
    insert into public.new_goal_assessments (
      id,
      user_id,
      draft_user_id,
      kind,
      scheduled_for,
      safe_dates,
      status
    ) values (
      'a-draft-assessment',
      '10000000-0000-0000-0000-000000000005',
      '10000000-0000-0000-0000-000000000005',
      'five_k_run',
      '2026-07-24',
      '[]'::jsonb,
      'scheduled'
    )
  $$,
  'authenticated user A can create its own assessment'
);
select is(
  (
    select user_id::text
    from public.new_goal_drafts
    where data ->> 'from' = 'owned-upsert'
  ),
  '10000000-0000-0000-0000-000000000005',
  'draft write uses authenticated identity'
);

select throws_ok(
  $$
    insert into public.new_goal_assessments (
      id,
      user_id,
      draft_user_id,
      kind,
      scheduled_for,
      safe_dates
    ) values (
      'a-invalid-kind',
      '10000000-0000-0000-0000-000000000005',
      '10000000-0000-0000-0000-000000000005',
      'invalid-kind',
      '2026-07-24',
      '[]'::jsonb
    )
  $$,
  '23514',
  'new row for relation "new_goal_assessments" violates check constraint "new_goal_assessments_kind_check"',
  'invalid assessment kind is rejected'
);

-- Proposal storage lifecycle and user scope.
reset role;
set local role service_role;
select lives_ok(
  $$
    select public.store_new_goal_proposal(
      '10000000-0000-0000-0000-000000000005',
      'rls-proposal-a',
      'rls-source-a',
      '{"id":"rls-candidate-a","weeks":[]}'::jsonb,
      '{"race":"10k"}'::jsonb,
      '{"acceptedRaceTarget":{"distance":"10k","targetSeconds":3900}}'::jsonb,
      '{"distanceChanged":true}'::jsonb,
      '[]'::jsonb,
      null,
      now(),
      now() + interval '30 minutes'
    )
  $$,
  'service role stores user A proposal'
);
select lives_ok(
  $$
    select public.store_new_goal_proposal(
      '10000000-0000-0000-0000-000000000006',
      'rls-proposal-b',
      'rls-source-b',
      '{"id":"rls-candidate-b","weeks":[]}'::jsonb,
      '{"race":"half_marathon"}'::jsonb,
      '{"acceptedRaceTarget":{"distance":"half_marathon","targetSeconds":9000}}'::jsonb,
      '{"distanceChanged":true}'::jsonb,
      '[]'::jsonb,
      null,
      now(),
      now() + interval '30 minutes'
    )
  $$,
  'service role stores user B proposal'
);

select is(
  (
    select array_agg(id order by id)
    from public.new_goal_proposals
  ),
  array['rls-proposal-a','rls-proposal-b']::text[],
  'service-role inserted proposal rows are present'
);

set local role authenticated;
select is(
  (
    select array_agg(id order by id)
    from public.new_goal_proposals
  ),
  array['rls-proposal-a']::text[],
  'authenticated user A sees only its own proposal'
);

select is(
  (select count(*)::integer from public.new_goal_proposals where user_id = '10000000-0000-0000-0000-000000000005'),
  1,
  'authenticated proposal query is scoped to owner'
);
reset role;
select set_config('request.jwt.claim.sub', '', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000006', true);
select is(
  (
    select array_agg(id order by id)
    from public.new_goal_proposals
  ),
  array['rls-proposal-b']::text[],
  'authenticated user B sees only its own proposal'
);
reset role;
select set_config('request.jwt.claim.sub', '', true);

set local role anon;
select throws_ok(
  $$ select count(*) from public.new_goal_proposals $$,
  '42501',
  'permission denied for table new_goal_proposals',
  'anonymous users cannot read proposal rows'
);
select is(current_user, 'anon', 'anonymous assertions run as anon');
  select ok(
    not has_function_privilege(
      current_user,
      'public.store_new_goal_proposal(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb,integer,timestamptz,timestamptz,integer,timestamptz)',
      'EXECUTE'
    ),
    'the anonymous client context cannot execute the storage RPC'
  );
select ok(
  not has_function_privilege(
    current_user,
    'public.accept_new_goal_proposal(uuid,text,text,timestamptz)',
    'EXECUTE'
  ),
  'the anonymous client context cannot execute the acceptance RPC'
);
reset role;
select set_config('request.jwt.claim.sub', '', true);

-- Storage defaults to 30 minutes, and a newer proposal supersedes the old one.
select lives_ok(
  $$
    select public.store_new_goal_proposal(
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
    from new_goal_proposals
    where id = 'main-proposal-old'
  ),
  interval '30 minutes',
  'proposal expiry defaults to exactly 30 minutes'
);
select lives_ok(
  $$
    select public.store_new_goal_proposal(
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
  (select status from new_goal_proposals where id = 'main-proposal-old'),
  'superseded',
  'the older pending proposal is superseded'
);
select is(
  (
    select superseded_at
    from new_goal_proposals
    where id = 'main-proposal-old'
  ),
  (select created_at from new_goal_proposals where id = 'main-proposal'),
  'supersession records the replacement timestamp'
);
select is(
  (
    select count(*)::integer
    from new_goal_proposals
    where user_id = '10000000-0000-0000-0000-000000000001'
      and status = 'pending'
  ),
  1,
  'only one pending proposal remains for a user'
);
select throws_ok(
  $$
  insert into new_goal_proposals (
    id,
    user_id,
    source_plan_version_id,
    source_profile_schema_version,
    source_profile_updated_at,
    candidate_plan,
    proposed_goal,
    status
  ) values (
    'main-proposal-conflict',
    '10000000-0000-0000-0000-000000000001',
    'main-source',
    1,
    now() - interval '15 minutes',
    '{}'::jsonb,
    '{}'::jsonb,
    'pending'
  )
  $$,
  '23505',
  'duplicate key value violates unique constraint "new_goal_proposals_one_pending_per_user"',
  'the partial unique index rejects a second pending proposal'
);
select throws_ok(
  $$
    select public.store_new_goal_proposal(
      '10000000-0000-0000-0000-000000000002',
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
  'new_goal_source_plan_not_active',
  'proposal storage rejects an inactive source plan'
);
select throws_ok(
  $$
    select public.store_new_goal_proposal(
      '10000000-0000-0000-0000-000000000007',
      'draft-profile-fragment-rejected',
      'draft-source',
      '{"id":"draft-fragment-candidate","weeks":[]}'::jsonb,
      '{"race":"half_marathon","targetSeconds":12000}'::jsonb,
      '{"acceptedRaceTarget":{"distance":"half_marathon","targetSeconds":12000},"identity":{"tamper":true}}'::jsonb,
      '{}'::jsonb,
      '[]'::jsonb,
      null,
      now(),
      now() + interval '15 minutes'
    )
  $$,
  'P0001',
  'new_goal_profile_fragment_restricted',
  'proposal storage rejects disallowed profile fragment keys'
);
select throws_ok(
  $$
    select public.store_new_goal_proposal(
      '10000000-0000-0000-0000-000000000007',
      'draft-profile-stale-storage',
      'draft-source',
      '{"id":"draft-stale-storage-candidate","weeks":[]}'::jsonb,
      '{"race":"marathon"}'::jsonb,
      '{}'::jsonb,
      '{}'::jsonb,
      '[]'::jsonb,
      null,
      now(),
      now() + interval '15 minutes',
      1,
      '2000-01-01 00:00:00+00'::timestamptz
    )
  $$,
  'P0001',
  'new_goal_source_profile_stale',
  'proposal storage rejects a stale profile snapshot'
);
select lives_ok(
  $$
    select public.store_new_goal_proposal(
      '10000000-0000-0000-0000-000000000007',
      'draft-profile-fields',
      'draft-source',
      '{"id":"draft-fields-candidate","weeks":[]}'::jsonb,
      '{"race":"marathon","targetSeconds":12000}'::jsonb,
      '{
        "acceptedRaceTarget":{"distance":"marathon","targetSeconds":12000},
        "schedule":{"days":["mon","fri"],"timezone":"America/Los_Angeles"},
        "trainingPreferences":{"intervalsPerWeek":2,"notes":"marathon prep"},
        "health":{"restingHR":48}
      }'::jsonb,
      '{}'::jsonb,
      '[]'::jsonb,
      null,
      now(),
      now() + interval '15 minutes'
    )
  $$,
  'a proposal with only allowed profile fragment keys is accepted by storage'
);
select lives_ok(
  $$
    select *
      from public.accept_new_goal_proposal(
        '10000000-0000-0000-0000-000000000007',
        'draft-profile-fields',
        'draft-fields-plan',
        '2026-07-15 12:00:00+00'
      )
  $$,
  'draft profile fragment fields are accepted with a pending proposal'
);
select is(
  (
    select data -> 'goal'
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000007'
  ),
  '{"race":"marathon","targetSeconds":12000}'::jsonb,
  'draft profile acceptance updates goal'
);
select is(
  (
    select data -> 'acceptedRaceTarget'
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000007'
  ),
  '{"distance":"marathon","targetSeconds":12000}'::jsonb,
  'draft profile acceptance updates acceptedRaceTarget'
);
select is(
  (
    select data -> 'schedule'
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000007'
  ),
  '{"days":["mon","fri"],"timezone":"America/Los_Angeles"}'::jsonb,
  'draft profile acceptance updates schedule'
);
select is(
  (
    select data -> 'trainingPreferences'
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000007'
  ),
  '{"intervalsPerWeek":2,"notes":"marathon prep"}'::jsonb,
  'draft profile acceptance updates trainingPreferences'
);
select is(
  (
    select data -> 'health'
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000007'
  ),
  '{"restingHR":48}'::jsonb,
  'draft profile acceptance updates health'
);
select is(
  (
    select data - 'goal' - 'acceptedRaceTarget' - 'schedule' - 'trainingPreferences' - 'health' - 'updatedAt'
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000007'
  ),
  '{"marker":"draft-original","displayName":"Draft Runner"}'::jsonb,
  'draft profile acceptance preserves unrelated profile fields'
);
select lives_ok(
  $$
    select public.store_new_goal_proposal(
      '10000000-0000-0000-0000-000000000007',
      'draft-profile-stale-accept',
      'draft-fields-plan',
      '{"id":"draft-stale-accept-candidate","weeks":[]}'::jsonb,
      '{"race":"5k"}'::jsonb,
      '{}'::jsonb,
      '{}'::jsonb,
      '[]'::jsonb,
      null,
      now(),
      now() + interval '20 minutes'
    )
  $$,
  'a proposal can be stored before its source profile changes'
);
update runner_profiles
  set schema_version = schema_version + 1
  where user_id = '10000000-0000-0000-0000-000000000007';
select throws_ok(
  $$
    select * from public.accept_new_goal_proposal(
      '10000000-0000-0000-0000-000000000007',
      'draft-profile-stale-accept',
      'draft-stale-accept-plan',
      now()
    )
  $$,
  'P0001',
  'new_goal_source_profile_stale',
  'acceptance rejects a proposal after source profile schema changes'
);
select is(
  (
    select status from new_goal_proposals where id = 'draft-profile-stale-accept'
  ),
  'pending',
  'failed stale-profile acceptance does not change proposal status'
);
select is(
  (
    select count(*)::integer
    from plan_versions
    where id = 'draft-stale-accept-plan'
  ),
  0,
  'stale-profile acceptance inserts no candidate plan'
);

-- Acceptance atomically changes profile, plan set, and proposal state.
select lives_ok(
  $$
    create temporary table new_goal_main_acceptance_response as
    select *
      from public.accept_new_goal_proposal(
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
  '{"preferences":{"units":"metric","days":["tue","thu"]},"displayName":"Main Runner","nested":{"preserve":true}}'::jsonb,
  'acceptance preserves unrelated profile fields'
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
  'embedded profile timestamp matches the row timestamp'
);
select is(
  (
    select data -> 'nested'
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  '{"preserve":true}'::jsonb,
  'acceptance preserves nested profile values'
);
select is(
  (select requested_by from plan_versions where id = 'main-accepted-plan'),
  'new_goal',
  'the accepted candidate records new_goal as its origin'
);
select is(
  (select is_active from plan_versions where id = 'main-accepted-plan'),
  true,
  'the accepted candidate is active'
);
select is(
  (select is_active from plan_versions where id = 'main-source'),
  false,
  'the source plan is deactivated'
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
  (select count(*)::integer from plan_versions where user_id = '10000000-0000-0000-0000-000000000001'),
  3,
  'plan history rows are preserved'
);
select is(
  (select status from new_goal_proposals where id = 'main-proposal'),
  'accepted',
  'the proposal is marked accepted'
);
select ok(
  (
    select accepted_at is not null
      and accepted_plan_version_id = 'main-accepted-plan'
    from new_goal_proposals
    where id = 'main-proposal'
  ),
  'accepted proposal stores timestamp and immutable plan link'
);

create temporary table new_goal_main_acceptance_snapshot as
select
  proposal.accepted_at,
  proposal.status as proposal_status,
  profile.data as profile_data,
  profile.updated_at as profile_updated_at,
  plan.id as active_plan_id,
  plan.generated_at as active_plan_generated_at,
  plan.data as active_plan_data
from new_goal_proposals as proposal
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
    from public.accept_new_goal_proposal(
      '10000000-0000-0000-0000-000000000001',
      'main-proposal',
      'main-retry-response-must-not-exist',
      '2026-07-14 13:00:00+00'
    ) as retry_response
  ),
  (select to_jsonb(first_response) from new_goal_main_acceptance_response as first_response),
  'duplicate acceptance returns the immutable canonical acceptance response'
);
select is(
  (
    select new_plan_version_id
    from public.accept_new_goal_proposal(
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
  (select accepted_at from new_goal_proposals where id = 'main-proposal'),
  (select accepted_at from new_goal_main_acceptance_snapshot),
  'duplicate acceptance preserves the original acceptance timestamp'
);
select is(
  (
    select data
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  (select profile_data from new_goal_main_acceptance_snapshot),
  'duplicate acceptance does not mutate profile data'
);
select is(
  (
    select updated_at
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  (select profile_updated_at from new_goal_main_acceptance_snapshot),
  'duplicate acceptance preserves profile timestamp'
);
select is(
  (
    select id
    from plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and is_active = true
  ),
  (select active_plan_id from new_goal_main_acceptance_snapshot),
  'duplicate acceptance preserves active plan identity'
);
select is(
  (
    select generated_at
    from plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and is_active = true
  ),
  (select active_plan_generated_at from new_goal_main_acceptance_snapshot),
  'duplicate acceptance ignores retry generation timestamp'
);
select is(
  (
    select data
    from plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and is_active = true
  ),
  (select active_plan_data from new_goal_main_acceptance_snapshot),
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
select is(
  (
    select count(*)::integer
    from plan_versions
    where user_id = '10000000-0000-0000-0000-000000000001'
      and is_active = true
  ),
  1,
  'exactly one active plan remains after duplicate acceptance'
);

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
  'database rejects two active plans for one user'
);

select throws_ok(
  $$
    select public.accept_new_goal_proposal(
      '10000000-0000-0000-0000-000000000002',
      'main-proposal',
      'main-retry-cross-user',
      now()
    )
  $$,
  'P0001',
  'new_goal_proposal_not_found',
  'cross-user proposal acceptance is not authorized'
);

-- Expiration fails before any profile or plan mutation.
select lives_ok(
  $$
    select public.store_new_goal_proposal(
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
    select * from public.accept_new_goal_proposal(
      '10000000-0000-0000-0000-000000000002',
      'expired-proposal',
      'expired-candidate',
      now()
    )
  $$,
  'P0001',
  'new_goal_proposal_expired',
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
  (select status from new_goal_proposals where id = 'expired-proposal'),
  'pending',
  'failed expired acceptance does not partially update proposal'
);

-- A plan that changed after preview makes the proposal stale, with no partial mutation.
select lives_ok(
  $$
    select public.store_new_goal_proposal(
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
    select * from public.accept_new_goal_proposal(
      '10000000-0000-0000-0000-000000000003',
      'stale-proposal',
      'stale-candidate',
      now()
    )
  $$,
  'P0001',
  'new_goal_source_plan_stale',
  'acceptance rejects a proposal whose source is no longer active'
);
select is(
  (
    select data
    from runner_profiles
    where user_id = '10000000-0000-0000-0000-000000000003'
  ),
  '{"goal":{"race":"half_marathon"},"marker":"stale-original"}'::jsonb,
  'stale acceptance leaves the profile unchanged'
);
select is(
  (select is_active from plan_versions where id = 'stale-replacement'),
  true,
  'stale acceptance leaves replacement active'
);
select is(
  (select count(*)::integer from plan_versions where id = 'stale-candidate'),
  0,
  'stale acceptance inserts no candidate plan'
);
select is(
  (select status from new_goal_proposals where id = 'stale-proposal'),
  'pending',
  'failed stale acceptance does not partially update the proposal'
);

select * from finish();

rollback;
