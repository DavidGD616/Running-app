create table if not exists public.strava_tokens (
  user_id uuid references auth.users(id) on delete cascade primary key,
  access_token text not null,
  refresh_token text not null,
  expires_at timestamptz not null,
  athlete_id bigint not null,
  scope text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.strava_tokens enable row level security;
-- Sensitive third-party OAuth tokens are never exposed through client RLS.
-- Access is restricted to service-role edge functions only.
