create table if not exists public.adaptation_reviews (
  id                      text primary key,
  user_id                 uuid references auth.users(id) on delete cascade not null,
  status                  text not null,
  classification          text not null,
  severity                text not null,
  week_start              date not null,
  week_end                date not null,
  source_plan_version_id  text,
  proposed_plan_version_id text,
  created_at              timestamptz not null,
  updated_at              timestamptz not null,
  load_before             double precision,
  load_after              double precision,
  data                    jsonb not null
);

create index if not exists adaptation_reviews_user_created
  on public.adaptation_reviews (user_id, created_at desc);

create index if not exists adaptation_reviews_user_status
  on public.adaptation_reviews (user_id, status);

create index if not exists adaptation_reviews_user_week
  on public.adaptation_reviews (user_id, week_start, week_end);

create unique index if not exists adaptation_reviews_one_pending_per_plan_week
  on public.adaptation_reviews (
    user_id,
    source_plan_version_id,
    week_start,
    week_end
  )
  where status = 'pending';

alter table public.adaptation_reviews enable row level security;

drop policy if exists "Users manage own adaptation reviews"
  on public.adaptation_reviews;

drop policy if exists "Users view own adaptation reviews"
  on public.adaptation_reviews;

create policy "Users view own adaptation reviews"
  on public.adaptation_reviews for select
  using ((select auth.uid()) = user_id);

create or replace function public.accept_adaptation_plan_version(
  p_user_id uuid,
  p_review_id text,
  p_source_plan_version_id text,
  p_new_plan_version_id text,
  p_generated_at timestamptz,
  p_plan_data jsonb,
  p_review_data jsonb
) returns void
language plpgsql
as $$
declare
  v_active_plan_id text;
  v_pending_review_id text;
begin
  select id
    into v_active_plan_id
    from public.plan_versions
   where user_id = p_user_id
     and id = p_source_plan_version_id
     and is_active = true
   for update;

  if v_active_plan_id is null then
    raise exception 'source_plan_version_not_active';
  end if;

  select id
    into v_pending_review_id
    from public.adaptation_reviews
   where user_id = p_user_id
     and id = p_review_id
     and source_plan_version_id = p_source_plan_version_id
     and status = 'pending'
   for update;

  if v_pending_review_id is null then
    raise exception 'adaptation_review_not_pending';
  end if;

  update public.plan_versions
     set is_active = false
   where user_id = p_user_id
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
    p_new_plan_version_id,
    p_user_id,
    p_generated_at,
    'adaptation',
    true,
    1,
    p_plan_data
  );

  update public.adaptation_reviews
     set status = 'accepted',
         proposed_plan_version_id = p_new_plan_version_id,
         updated_at = p_generated_at,
         data = p_review_data
   where user_id = p_user_id
     and id = p_review_id;
end;
$$;

revoke all on function public.accept_adaptation_plan_version(
  uuid,
  text,
  text,
  text,
  timestamptz,
  jsonb,
  jsonb
) from public, anon, authenticated;

grant execute on function public.accept_adaptation_plan_version(
  uuid,
  text,
  text,
  text,
  timestamptz,
  jsonb,
  jsonb
) to service_role;
