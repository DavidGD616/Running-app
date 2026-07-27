alter table public.change_schedule_drafts
  add column if not exists effective_week text;

update public.change_schedule_drafts
  set effective_week = 'current'
  where effective_week is null;

alter table public.change_schedule_drafts
  alter column effective_week set default 'current';

alter table public.change_schedule_drafts
  alter column effective_week set not null;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_constraint
     WHERE conrelid = 'public.change_schedule_drafts'::regclass
       AND conname = 'change_schedule_drafts_effective_week_check'
       AND contype = 'c'
  ) THEN
    ALTER TABLE public.change_schedule_drafts
      ADD CONSTRAINT change_schedule_drafts_effective_week_check
        CHECK (effective_week in ('current', 'next'));
  END IF;
END $$;
