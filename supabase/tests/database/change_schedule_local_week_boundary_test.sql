create extension if not exists pgtap with schema extensions;

set search_path to public, extensions;

begin;

select no_plan();

set local role postgres;
select set_config('request.jwt.claim.role', 'service_role', true);

select ok(
  to_regprocedure('public.store_change_schedule_proposal(uuid,text,text,jsonb,jsonb,jsonb,date,timestamptz,timestamptz,integer,timestamptz,date)') is not null,
  'store proposal RPC has the local-date signature'
);
select ok(
  to_regprocedure('public.accept_change_schedule_proposal_now(uuid,text,text,text,timestamptz,timestamptz,date)') is not null,
  'accept-now RPC has the local-date signature'
);
select ok(
  to_regprocedure('public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz,date)') is not null,
  'schedule RPC has the local-date signature'
);
select ok(
  to_regprocedure('public.activate_due_change_schedule(uuid,text,timestamptz,date)') is not null,
  'activate-due RPC has the local-date signature'
);
select ok(
  to_regprocedure('public.store_change_schedule_proposal(uuid,text,text,jsonb,jsonb,jsonb,date,timestamptz,timestamptz,integer,timestamptz)') is null,
  'store proposal does not retain a competing legacy overload'
);
select ok(
  to_regprocedure('public.accept_change_schedule_proposal_now(uuid,text,text,text,timestamptz,timestamptz)') is null,
  'accept-now does not retain a competing legacy overload'
);
select ok(
  to_regprocedure('public.schedule_change_schedule_proposal(uuid,text,text,text,timestamptz)') is null,
  'schedule does not retain a competing legacy overload'
);
select ok(
  to_regprocedure('public.activate_due_change_schedule(uuid,text,timestamptz)') is null,
  'activate-due does not retain a competing legacy overload'
);

insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000101', 'change-schedule-local-store@example.test'),
  ('10000000-0000-0000-0000-000000000102', 'change-schedule-local-accept@example.test'),
  ('10000000-0000-0000-0000-000000000103', 'change-schedule-local-schedule@example.test');

insert into public.runner_profiles (user_id, schema_version, updated_at, data)
values
  (
    '10000000-0000-0000-0000-000000000101',
    1,
    '2026-07-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000102',
    1,
    '2026-07-01 00:00:00+00',
    '{"goal":{"race":"10k"}}'::jsonb
  ),
  (
    '10000000-0000-0000-0000-000000000103',
    1,
    '2026-07-01 00:00:00+00',
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
)
values
  (
    'local-store-source',
    '10000000-0000-0000-0000-000000000101',
    '2026-07-01 00:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"local-store-source","weeks":[]}'::jsonb
  ),
  (
    'local-accept-source',
    '10000000-0000-0000-0000-000000000102',
    '2026-07-01 00:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"local-accept-source","weeks":[]}'::jsonb
  ),
  (
    'local-schedule-source',
    '10000000-0000-0000-0000-000000000103',
    '2026-07-01 00:00:00+00',
    'onboarding',
    true,
    1,
    '{"id":"local-schedule-source","weeks":[]}'::jsonb
  );

create temporary table local_week_payload as
select
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
    "target_running_days":4,
    "primary_long_run_weekday":1,
    "same_day_run_strength_preference":"separate_sessions"
  }'::jsonb as availability;

grant select on local_week_payload to service_role;

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
select
  'local-accept-active-availability',
  '10000000-0000-0000-0000-000000000102'::uuid,
  'active',
  '2026-07-06'::date,
  4,
  1,
  'separate_sessions',
  availability
from local_week_payload
union all
select
  'local-schedule-active-availability',
  '10000000-0000-0000-0000-000000000103'::uuid,
  'active',
  '2026-07-06'::date,
  4,
  1,
  'separate_sessions',
  availability
from local_week_payload;

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);

-- At UTC Monday 00:30, a runner may still be on local Sunday. The local
-- current Monday is July 6 and the local next Monday is July 13.
create temporary table local_store_current as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000101',
    'local-store-current',
    'local-store-source',
    '{"id":"local-store-current-candidate","weeks":[]}'::jsonb,
    '{}'::jsonb,
    (select availability from local_week_payload),
    '2026-07-06',
    '2026-07-13 00:30:00+00',
    null,
    1,
    '2026-07-01 00:00:00+00',
    '2026-07-12'
  );

select is(
  (select effective_from from local_store_current),
  '2026-07-06'::date,
  'store permits the prior local Monday at a UTC-Monday boundary'
);

create temporary table local_store_next as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000101',
    'local-store-next',
    'local-store-source',
    '{"id":"local-store-next-candidate","weeks":[]}'::jsonb,
    '{}'::jsonb,
    (select availability from local_week_payload),
    '2026-07-13',
    '2026-07-13 00:30:00+00',
    null,
    1,
    '2026-07-01 00:00:00+00',
    '2026-07-12'
  );

select is(
  (select effective_from from local_store_next),
  '2026-07-13'::date,
  'store permits the next local Monday'
);

select throws_ok(
  $$
    select *
      from public.store_change_schedule_proposal(
        '10000000-0000-0000-0000-000000000101',
        'local-store-far-future',
        'local-store-source',
        '{"id":"local-store-far-future-candidate","weeks":[]}'::jsonb,
        '{}'::jsonb,
        (select availability from local_week_payload),
        '2026-07-20',
        '2026-07-13 00:30:00+00',
        null,
        1,
        '2026-07-01 00:00:00+00',
        '2026-07-12'
      )
  $$,
  'P0001',
  'change_schedule_proposal_effective_from_in_past',
  'store rejects any supplied-local-date week beyond current or next'
);

create temporary table local_accept_store as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000102',
    'local-accept-proposal',
    'local-accept-source',
    '{"id":"local-accept-candidate","weeks":[]}'::jsonb,
    '{}'::jsonb,
    (select availability from local_week_payload),
    '2026-07-06',
    '2026-07-13 00:30:00+00',
    null,
    1,
    '2026-07-01 00:00:00+00',
    '2026-07-12'
  );

create temporary table local_accept_result as
select *
  from public.accept_change_schedule_proposal_now(
    '10000000-0000-0000-0000-000000000102',
    'local-accept-proposal',
    'local-accept-plan',
    'local-accept-availability',
    '2026-07-13 00:31:00+00',
    '2026-07-13 00:31:00+00',
    '2026-07-12'
  );

select is(
  (select accepted_plan_version_id from local_accept_result),
  'local-accept-plan',
  'accept-now uses the supplied local current Monday rather than server Monday'
);

create temporary table local_schedule_store as
select *
  from public.store_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000103',
    'local-schedule-proposal',
    'local-schedule-source',
    '{"id":"local-schedule-candidate","weeks":[]}'::jsonb,
    '{}'::jsonb,
    (select availability from local_week_payload),
    '2026-07-13',
    '2026-07-13 00:30:00+00',
    null,
    1,
    '2026-07-01 00:00:00+00',
    '2026-07-12'
  );

create temporary table local_schedule_result as
select *
  from public.schedule_change_schedule_proposal(
    '10000000-0000-0000-0000-000000000103',
    'local-schedule-proposal',
    'local-schedule-plan',
    'local-schedule-availability',
    '2026-07-13 00:31:00+00',
    '2026-07-12'
  );

select is(
  (select activation_status from local_schedule_result),
  'scheduled',
  'schedule permits exactly the supplied-local-date next Monday'
);

select throws_ok(
  $$
    select *
      from public.activate_due_change_schedule(
        '10000000-0000-0000-0000-000000000103',
        (select activation_id from local_schedule_result),
        '2026-07-13 00:32:00+00',
        '2026-07-12'
      )
  $$,
  'P0001',
  'change_schedule_activation_not_due',
  'activate-due is not eligible until the supplied-local-date current Monday'
);

create temporary table local_activation_result as
select *
  from public.activate_due_change_schedule(
    '10000000-0000-0000-0000-000000000103',
    (select activation_id from local_schedule_result),
    '2026-07-13 12:00:00+00',
    '2026-07-13'
  );

select is(
  (select activation_status from local_activation_result),
  'activated',
  'activate-due accepts the scheduled plan once the local Monday arrives'
);

select * from finish();

rollback;
