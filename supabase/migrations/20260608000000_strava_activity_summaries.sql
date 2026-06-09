create table if not exists public.strava_activity_summaries (
  user_id uuid references auth.users(id) on delete cascade not null,
  strava_activity_id text not null,
  recorded_at timestamptz not null,
  activity_type text,
  sport_type text,
  distance_meters double precision,
  moving_time_seconds integer,
  elapsed_time_seconds integer,
  average_speed_mps double precision,
  max_speed_mps double precision,
  average_heartrate_bpm double precision,
  max_heartrate_bpm double precision,
  elevation_gain_meters double precision,
  workout_type integer,
  suffer_score integer,
  normalized_data jsonb not null default '{}'::jsonb,
  synced_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, strava_activity_id)
);

create index if not exists strava_activity_summaries_user_recorded
  on public.strava_activity_summaries (user_id, recorded_at desc);

alter table public.strava_activity_summaries enable row level security;

drop policy if exists "Users read own Strava activity summaries"
  on public.strava_activity_summaries;

create policy "Users read own Strava activity summaries"
  on public.strava_activity_summaries
  for select
  to authenticated
  using (auth.uid() = user_id);

comment on table public.strava_activity_summaries is
  'Privacy-safe normalized Strava activity summaries written by service-role edge functions. Client roles may read their own rows only.';
