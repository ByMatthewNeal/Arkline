-- Admin-only reader list for a broadcast. broadcast_reads RLS restricts each
-- user to their own rows, so this SECURITY DEFINER function is the sanctioned
-- path for the founder/admin to see who read an insight. Non-admins get an error.
create or replace function public.get_broadcast_readers(p_broadcast_id uuid)
returns table (
  user_id uuid,
  display_name text,
  email text,
  read_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from profiles where id = auth.uid() and role = 'admin'
  ) then
    raise exception 'not authorized';
  end if;

  return query
  select
    r.user_id,
    coalesce(nullif(btrim(p.full_name), ''), p.username, split_part(p.email, '@', 1)) as display_name,
    p.email,
    r.read_at
  from broadcast_reads r
  left join profiles p on p.id = r.user_id
  where r.broadcast_id = p_broadcast_id
  order by r.read_at desc;
end;
$$;

revoke all on function public.get_broadcast_readers(uuid) from public;
grant execute on function public.get_broadcast_readers(uuid) to authenticated;
