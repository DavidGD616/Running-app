create table if not exists public.strava_oauth_states (
  nonce text primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists strava_oauth_states_expires_at_idx
  on public.strava_oauth_states (expires_at);

alter table public.strava_oauth_states enable row level security;
-- Single-use OAuth state nonces are managed exclusively by service-role edge
-- functions; they are never exposed through client RLS.
