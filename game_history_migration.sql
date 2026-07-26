-- Supabase Database Migration for Game History Storage

create table if not exists public.game_history (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    game_data jsonb not null,
    created_at timestamptz not null default now()
);

-- Index for fetching a user's match history efficiently ordered by date
create index if not exists idx_game_history_user_id_created_at 
    on public.game_history(user_id, created_at desc);

-- Enable Row Level Security (RLS)
alter table public.game_history enable row level security;

-- RLS Policies: Users can only interact with their own history records
create policy "Users can read game history" on public.game_history
    for select to authenticated
    using (true);

create policy "Users can insert their own game history" on public.game_history
    for insert to authenticated
    with check (auth.uid() = user_id);

create policy "Users can update their own game history" on public.game_history
    for update to authenticated
    using (auth.uid() = user_id);

create policy "Users can delete their own game history" on public.game_history
    for delete to authenticated
    using (auth.uid() = user_id);
