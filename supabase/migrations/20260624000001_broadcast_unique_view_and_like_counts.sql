-- Make broadcast analytics count unique PEOPLE, not raw events.
--   views: was incremented on every open (inflated); now derived from the
--          deduped broadcast_reads table via a trigger, and the per-open RPC
--          recomputes the true unique count so it can never inflate again.
--   likes: reaction_count was COUNT(*) of reaction rows (multiple emojis per
--          person counted multiple times); now COUNT(DISTINCT user_id).
-- Already applied to the live DB; idempotent for fresh environments.

create or replace function public.sync_broadcast_view_count()
returns trigger language plpgsql security definer set search_path = public as $$
declare bid uuid;
begin
  bid := coalesce(new.broadcast_id, old.broadcast_id);
  update public.broadcasts
  set view_count = (select count(distinct user_id) from public.broadcast_reads where broadcast_id = bid)
  where id = bid;
  return null;
end $$;

drop trigger if exists trg_sync_broadcast_view_count on public.broadcast_reads;
create trigger trg_sync_broadcast_view_count
  after insert or delete on public.broadcast_reads
  for each row execute function public.sync_broadcast_view_count();

create or replace function public.increment_view_count(broadcast_uuid uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.broadcasts
  set view_count = (select count(distinct user_id) from public.broadcast_reads where broadcast_id = broadcast_uuid)
  where id = broadcast_uuid;
end $$;

create or replace function public.update_broadcast_reaction_count()
returns trigger language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' then
    update broadcasts set reaction_count = (
      select count(distinct user_id) from broadcast_reactions where broadcast_id = new.broadcast_id
    ) where id = new.broadcast_id;
    return new;
  elsif tg_op = 'DELETE' then
    update broadcasts set reaction_count = (
      select count(distinct user_id) from broadcast_reactions where broadcast_id = old.broadcast_id
    ) where id = old.broadcast_id;
    return old;
  end if;
  return null;
end $$;

update public.broadcasts b set view_count = (
  select count(distinct user_id) from public.broadcast_reads r where r.broadcast_id = b.id
);
update public.broadcasts b set reaction_count = (
  select count(distinct user_id) from public.broadcast_reactions x where x.broadcast_id = b.id
);
