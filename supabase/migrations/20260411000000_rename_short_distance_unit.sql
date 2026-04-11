do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_preferences'
      and column_name = 'short_distance_unit'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_preferences'
      and column_name = 'elevation_unit'
  ) then
    alter table public.user_preferences
      rename column short_distance_unit to elevation_unit;
  end if;
end $$;
