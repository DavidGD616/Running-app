create table if not exists public.apple_tokens (
  user_id uuid references auth.users(id) on delete cascade primary key,
  refresh_token text not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.apple_tokens enable row level security;
-- No user-facing policies; only service role writes/reads
