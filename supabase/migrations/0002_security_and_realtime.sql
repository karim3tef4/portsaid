-- Port Said Hub — 0002: triggers, least-privilege grants, RLS policies, RPCs, realtime.

-- ───────────── Triggers ─────────────
do $$
declare t text;
begin
  foreach t in array array['governorates','cities','districts','profiles','categories','places','place_images',
    'place_services','opening_hours','announcements','homepage_sections','homepage_section_items','offers']
  loop
    execute format('create trigger a_set_updated_at before update on public.%I for each row execute function public.set_updated_at()', t);
  end loop;
end $$;

create function public.touch_actor() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_by := coalesce((select auth.uid()), new.updated_by); return new; end $$;

create function public.apply_publish_rules() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.status = 'published' and new.published_at is null then new.published_at := now(); end if;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['places','announcements','homepage_sections','offers'] loop
    execute format('create trigger b_touch_actor before insert or update on public.%I for each row execute function public.touch_actor()', t);
  end loop;
  foreach t in array array['places','announcements','homepage_sections'] loop
    execute format('create trigger c_publish_rules before insert or update on public.%I for each row execute function public.apply_publish_rules()', t);
  end loop;
end $$;

-- Audit trail: every change to managed content / settings / roles is recorded.
create function public.log_admin_change() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  rec jsonb; old_rec jsonb; changed jsonb := '{}'::jsonb; snapshot jsonb;
  noisy text[] := array['description_ar','description_en','body_ar','body_en','content','updated_at'];
begin
  if tg_op = 'DELETE' then rec := to_jsonb(old); else rec := to_jsonb(new); end if;
  if tg_op = 'UPDATE' then
    old_rec := to_jsonb(old);
    select coalesce(jsonb_object_agg(n.key, jsonb_build_object('old', old_rec -> n.key, 'new', n.value)), '{}'::jsonb)
      into changed
      from jsonb_each(rec) as n
     where (old_rec -> n.key) is distinct from n.value and n.key <> all (noisy);
    if changed = '{}'::jsonb then return new; end if;   -- nothing meaningful changed
  end if;
  snapshot := rec - noisy;
  insert into public.admin_audit_logs (admin_id, action, target_table, target_id, metadata)
  values ((select auth.uid()), lower(tg_op), tg_table_name,
          coalesce(rec ->> 'id', rec ->> 'key', rec ->> 'user_id'),
          jsonb_build_object('source', case when (select auth.uid()) is null then 'service' else 'user' end,
                             'changes', changed, 'row', case when tg_op = 'UPDATE' then null else snapshot end));
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['places','categories','place_images','homepage_sections','homepage_section_items',
    'announcements','offers','platform_settings','feature_flags','user_roles','governorates','cities','districts'] loop
    execute format('create trigger z_audit after insert or update or delete on public.%I for each row execute function public.log_admin_change()', t);
  end loop;
end $$;
create trigger z_audit_status after update on public.profiles
  for each row when (old.status is distinct from new.status) execute function public.log_admin_change();

-- Append-only guarantees for the audit log and the points ledger.
create function public.forbid_mutation() returns trigger
language plpgsql set search_path = '' as $$
begin raise exception '% is append-only', tg_table_name using errcode = '42501'; end $$;
create trigger no_update_delete before update or delete on public.admin_audit_logs
  for each row execute function public.forbid_mutation();
create trigger no_truncate before truncate on public.admin_audit_logs
  for each statement execute function public.forbid_mutation();
create trigger no_update_delete before update or delete on public.points_transactions
  for each row execute function public.forbid_mutation();

-- ───────────── Least-privilege grants (RLS still applies on top) ─────────────
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

grant select on public.governorates, public.cities, public.districts, public.categories, public.places,
  public.place_images, public.place_services, public.opening_hours, public.announcements,
  public.homepage_sections, public.homepage_section_items, public.offers,
  public.platform_settings, public.feature_flags to anon, authenticated;

grant insert, update, delete on public.governorates, public.cities, public.districts, public.categories,
  public.places, public.place_images, public.place_services, public.opening_hours, public.announcements,
  public.homepage_sections, public.homepage_section_items, public.offers,
  public.platform_settings, public.feature_flags to authenticated;

grant select on public.profiles, public.user_roles, public.offer_redemptions,
  public.points_transactions, public.admin_audit_logs to authenticated;
grant update (display_name, avatar_url, preferred_locale) on public.profiles to authenticated; -- NOT status/email
grant select, insert, delete on public.favorites to authenticated;
grant select, update, delete on public.contact_messages to authenticated;   -- inserts: server (service role) only

-- ───────────── Row Level Security ─────────────
alter table public.governorates enable row level security;
alter table public.cities enable row level security;
alter table public.districts enable row level security;
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.categories enable row level security;
alter table public.places enable row level security;
alter table public.place_images enable row level security;
alter table public.place_services enable row level security;
alter table public.opening_hours enable row level security;
alter table public.favorites enable row level security;
alter table public.announcements enable row level security;
alter table public.homepage_sections enable row level security;
alter table public.homepage_section_items enable row level security;
alter table public.platform_settings enable row level security;
alter table public.feature_flags enable row level security;
alter table public.contact_messages enable row level security;
alter table public.offers enable row level security;
alter table public.offer_redemptions enable row level security;
alter table public.points_transactions enable row level security;
alter table public.admin_audit_logs enable row level security;

-- Geography: public reads active rows; admins manage.
do $$
declare t text;
begin
  foreach t in array array['governorates','cities','districts'] loop
    execute format('create policy "public read active" on public.%I for select to anon, authenticated using (is_active)', t);
    execute format('create policy "staff read all" on public.%I for select to authenticated using ((select public.is_staff()))', t);
    execute format('create policy "admin insert" on public.%I for insert to authenticated with check ((select public.is_admin()))', t);
    execute format('create policy "admin update" on public.%I for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()))', t);
    execute format('create policy "admin delete" on public.%I for delete to authenticated using ((select public.is_admin()))', t);
  end loop;
end $$;

-- Staff-managed content: staff write, public sees only published/active.
create policy "public read active" on public.categories for select to anon, authenticated using (is_active);
create policy "public read published" on public.places for select to anon, authenticated
  using (deleted_at is null and public.is_published(status, publish_at));
create policy "public read via place" on public.place_images for select to anon, authenticated
  using (exists (select 1 from public.places p where p.id = place_id and p.deleted_at is null and public.is_published(p.status, p.publish_at)));
create policy "public read via place" on public.place_services for select to anon, authenticated
  using (exists (select 1 from public.places p where p.id = place_id and p.deleted_at is null and public.is_published(p.status, p.publish_at)));
create policy "public read via place" on public.opening_hours for select to anon, authenticated
  using (exists (select 1 from public.places p where p.id = place_id and p.deleted_at is null and public.is_published(p.status, p.publish_at)));
create policy "public read published" on public.announcements for select to anon, authenticated
  using (public.is_published(status, publish_at) and (expires_at is null or expires_at > now()));
create policy "public read published" on public.homepage_sections for select to anon, authenticated
  using (is_active and public.is_published(status, publish_at));
create policy "public read via section" on public.homepage_section_items for select to anon, authenticated
  using (exists (select 1 from public.homepage_sections s where s.id = section_id and s.is_active and public.is_published(s.status, s.publish_at)));
create policy "public read active offers" on public.offers for select to anon, authenticated
  using (status = 'active' and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at > now())
         and exists (select 1 from public.places p where p.id = place_id and p.deleted_at is null and public.is_published(p.status, p.publish_at)));

do $$
declare t text; del text;
begin
  for t, del in select * from (values
    ('categories','is_admin'), ('places','is_admin'), ('announcements','is_admin'), ('offers','is_admin'),
    ('place_images','is_staff'), ('place_services','is_staff'), ('opening_hours','is_staff'),
    ('homepage_sections','is_admin'), ('homepage_section_items','is_staff')) as v(t, d)
  loop
    execute format('create policy "staff read all" on public.%I for select to authenticated using ((select public.is_staff()))', t);
    execute format('create policy "staff insert" on public.%I for insert to authenticated with check ((select public.is_staff()))', t);
    execute format('create policy "staff update" on public.%I for update to authenticated using ((select public.is_staff())) with check ((select public.is_staff()))', t);
    execute format('create policy "restricted delete" on public.%I for delete to authenticated using ((select public.%I()))', t, del);
  end loop;
end $$;

-- Settings & flags: public reads public settings / all flags; admins write.
create policy "public read public settings" on public.platform_settings for select to anon, authenticated using (is_public);
create policy "admin read all settings" on public.platform_settings for select to authenticated using ((select public.is_admin()));
create policy "admin insert" on public.platform_settings for insert to authenticated with check ((select public.is_admin()));
create policy "admin update" on public.platform_settings for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "admin delete" on public.platform_settings for delete to authenticated using ((select public.is_admin()));
create policy "public read flags" on public.feature_flags for select to anon, authenticated using (true);
create policy "admin insert" on public.feature_flags for insert to authenticated with check ((select public.is_admin()));
create policy "admin update" on public.feature_flags for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "admin delete" on public.feature_flags for delete to authenticated using ((select public.is_admin()));

-- Identity. No client write path to roles at all; profile status changes go through an RPC.
create policy "own or admin read" on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));
create policy "own update" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "own or admin read" on public.user_roles for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

-- Favorites: own rows only; active accounts; place must be visible to the caller.
create policy "own read" on public.favorites for select to authenticated using (user_id = (select auth.uid()));
create policy "own insert" on public.favorites for insert to authenticated
  with check (user_id = (select auth.uid()) and (select public.is_active_user())
              and exists (select 1 from public.places p where p.id = place_id));
create policy "own delete" on public.favorites for delete to authenticated using (user_id = (select auth.uid()));

-- Inbox, audit, ledgers.
create policy "admin read" on public.contact_messages for select to authenticated using ((select public.is_admin()));
create policy "admin update" on public.contact_messages for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "admin delete" on public.contact_messages for delete to authenticated using ((select public.is_admin()));
create policy "own or admin read" on public.offer_redemptions for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));
create policy "own or admin read" on public.points_transactions for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));
create policy "admin read" on public.admin_audit_logs for select to authenticated using ((select public.is_admin()));

-- ───────────── RPCs ─────────────
create function public.admin_set_account_status(target uuid, new_status public.account_status)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if target = (select auth.uid()) then raise exception 'cannot change your own status' using errcode = '22023'; end if;
  update public.profiles set status = new_status where id = target;
end $$;
revoke all on function public.admin_set_account_status(uuid, public.account_status) from public, anon;
grant execute on function public.admin_set_account_status(uuid, public.account_status) to authenticated;

-- Shared filter for search and count (SECURITY INVOKER: RLS applies; explicit public filter keeps staff previews honest).
create function public.places_matching(q text default null, p_category uuid default null,
  p_governorate uuid default null, p_city uuid default null, p_district uuid default null)
returns setof public.places language sql stable set search_path = public, extensions as $$
  select p.* from public.places p
   where p.deleted_at is null and public.is_published(p.status, p.publish_at)
     and (p_category is null or p.category_id = p_category)
     and (p_governorate is null or p.governorate_id = p_governorate)
     and (p_city is null or p.city_id = p_city)
     and (p_district is null or p.district_id = p_district)
     and (nullif(btrim(q), '') is null
          or p.name_ar ilike '%' || public.escape_like(btrim(q)) || '%'
          or p.name_en ilike '%' || public.escape_like(btrim(q)) || '%'
          or p.description_ar ilike '%' || public.escape_like(btrim(q)) || '%'
          or p.description_en ilike '%' || public.escape_like(btrim(q)) || '%')
$$;

create function public.search_places(q text default null, p_category uuid default null,
  p_governorate uuid default null, p_city uuid default null, p_district uuid default null,
  p_sort text default 'relevance', p_limit int default 24, p_offset int default 0)
returns setof public.places language sql stable set search_path = public, extensions as $$
  select * from public.places_matching(q, p_category, p_governorate, p_city, p_district) m
   order by case when p_sort = 'popular' then m.popularity_score end desc nulls last,
         case when nullif(btrim(q), '') is not null
              then greatest(similarity(m.name_ar, btrim(q)), similarity(coalesce(m.name_en, ''), btrim(q))) end desc nulls last,
         m.is_featured desc, m.created_at desc, m.id
   limit least(greatest(p_limit, 1), 100) offset greatest(p_offset, 0)
$$;
create function public.search_places_count(q text default null, p_category uuid default null,
  p_governorate uuid default null, p_city uuid default null, p_district uuid default null)
returns bigint language sql stable set search_path = public as $$
  select count(*) from public.places_matching(q, p_category, p_governorate, p_city, p_district)
$$;

-- ───────────── Realtime (RLS-aware postgres_changes) ─────────────
do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['places','place_images','place_services','opening_hours','categories','offers',
      'announcements','homepage_sections','homepage_section_items','platform_settings','feature_flags'] loop
      execute format('alter publication supabase_realtime add table public.%I', t);
    end loop;
  end if;
end $$;
