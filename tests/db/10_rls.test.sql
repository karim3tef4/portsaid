-- RLS / privilege / integrity test suite. Any failed assertion aborts the run (ON_ERROR_STOP).
create schema t;
grant usage on schema t to public;
create table t.results (label text);
grant all on t.results to public;

create function t.pass(label text) returns void language plpgsql as $$ begin insert into t.results values (label); end $$;
create function t.ok(cond boolean, label text) returns void language plpgsql as $$
begin if cond is not true then raise exception 'FAIL: %', label; end if; perform t.pass(label); end $$;
create function t.as_user(uid uuid, r text default 'authenticated') returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', coalesce(uid::text, ''), true);
  execute format('set local role %I', r);
end $$;
create function t.reset() returns void language plpgsql as $$ begin execute 'reset role'; end $$;
create function t.count(q text) returns bigint language plpgsql as $$
declare n bigint; begin execute 'select count(*) from (' || q || ') s' into n; return n; end $$;
create function t.affected(q text) returns bigint language plpgsql as $$
declare n bigint; begin execute q; get diagnostics n = row_count; return n; end $$;
create function t.denied(q text, label text, code text default '42501') returns void language plpgsql as $$
begin
  begin execute q;
  exception when others then
    if sqlstate = code then perform t.pass(label); return; end if;
    raise exception 'FAIL (wrong error % : %): %', sqlstate, sqlerrm, label;
  end;
  raise exception 'FAIL (statement was allowed): %', label;
end $$;

-- ───── Fixtures (as superuser) ─────
insert into auth.users (id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-0000000000a1', 'alice@example.com', '{"full_name":"Alice","avatar_url":"https://img.example/a.png"}'),
 ('00000000-0000-0000-0000-0000000000b2', 'bob@example.com',   '{"name":"Bob","avatar_url":"http://evil.example/x.png"}'),
 ('00000000-0000-0000-0000-0000000000c3', 'carol@example.com', '{}'),
 ('00000000-0000-0000-0000-0000000000d4', 'dana@example.com',  '{}'),
 ('00000000-0000-0000-0000-0000000000e5', 'eli@example.com',   '{}');
update public.profiles set status = 'suspended' where id = '00000000-0000-0000-0000-0000000000c3';
insert into public.user_roles (user_id, role) values
 ('00000000-0000-0000-0000-0000000000d4', 'admin'), ('00000000-0000-0000-0000-0000000000e5', 'editor');

insert into public.places (slug, category_id, governorate_id, name_ar, status, publish_at, deleted_at)
select s.slug, (select id from public.categories where slug='cafes'), (select id from public.governorates limit 1),
       s.slug, s.st::public.content_status, s.pa, s.da
from (values
  ('sched-future','scheduled', now() + interval '1 day', null::timestamptz),
  ('sched-past',  'scheduled', now() - interval '1 hour', null),
  ('archived-x',  'archived',  null, null),
  ('deleted-x',   'published', null, now())) as s(slug, st, pa, da);
insert into public.place_images (place_id, storage_path)
  select id, 'x/' || slug || '.jpg' from public.places where slug in ('port-said-lighthouse','sample-draft-place');
insert into public.platform_settings (key, value, is_public) values ('secret.thing', '"hidden"', false);

do $$
declare alice uuid := '00000000-0000-0000-0000-0000000000a1'; bob uuid := '00000000-0000-0000-0000-0000000000b2';
        carol uuid := '00000000-0000-0000-0000-0000000000c3'; dana uuid := '00000000-0000-0000-0000-0000000000d4';
        eli uuid := '00000000-0000-0000-0000-0000000000e5';
        lighthouse uuid := (select id from public.places where slug='port-said-lighthouse');
        draft uuid := (select id from public.places where slug='sample-draft-place');
begin
  -- Signup trigger
  perform t.ok((select avatar_url from public.profiles where id = alice) = 'https://img.example/a.png', 'profile created with https avatar');
  perform t.ok((select avatar_url from public.profiles where id = bob) is null, 'non-https avatar from OAuth metadata discarded');

  -- ───── ANON ─────
  perform t.as_user(null, 'anon');
  perform t.ok(t.count('select 1 from public.places') = 3, 'anon sees only published + due-scheduled places (not draft/archived/future/deleted)');
  perform t.ok(t.count($q$select 1 from public.places where slug in ('sample-draft-place','archived-x','sched-future','deleted-x')$q$) = 0, 'anon cannot see unpublished rows');
  perform t.ok(t.count('select 1 from public.place_images') = 1, 'anon sees images only of published places');
  perform t.ok(t.count('select 1 from public.categories') = 10, 'anon reads active categories');
  perform t.ok(t.count($q$select 1 from public.platform_settings where key = 'secret.thing'$q$) = 0, 'anon cannot read non-public settings');
  perform t.ok(t.count('select 1 from public.platform_settings') >= 5, 'anon reads public settings');
  perform t.ok(t.count('select 1 from public.feature_flags') > 0, 'anon reads feature flags');
  perform t.denied($q$insert into public.places (slug, category_id, governorate_id, name_ar) select 'hack', id, (select id from public.governorates limit 1), 'x' from public.categories limit 1$q$, 'anon cannot insert places');
  perform t.denied('select 1 from public.user_roles', 'anon cannot read user_roles');
  perform t.denied('select 1 from public.profiles', 'anon cannot read profiles');
  perform t.denied('select 1 from public.contact_messages', 'anon cannot read contact messages');
  perform t.denied('select 1 from public.admin_audit_logs', 'anon cannot read audit logs');
  perform t.denied($q$insert into storage.objects (bucket_id, name) values ('place-images','a.jpg')$q$, 'anon cannot upload files');
  perform t.ok(t.count($q$select 1 from public.search_places('Lighthouse')$q$) = 1, 'search finds published place by name');
  perform t.ok(t.count($q$select 1 from public.search_places('%')$q$) = 0, 'LIKE wildcards are escaped in search');
  perform t.ok(t.count($q$select 1 from public.search_places('_____')$q$) = 0, 'underscore wildcards are escaped in search');
  perform t.ok(public.search_places_count(null) = 3, 'search count matches visible places');
  perform t.ok(t.count($q$select 1 from public.search_places(null, null, null, null, null, 'popular', 100000, 0)$q$) = 3, 'limit capped / sorting works');

  -- ───── NORMAL USER (alice) ─────
  perform t.as_user(alice);
  perform t.ok(t.count('select 1 from public.places') = 3, 'authenticated non-staff sees only public places');
  perform t.denied($q$insert into public.places (slug, category_id, governorate_id, name_ar) select 'hack', id, (select id from public.governorates limit 1), 'x' from public.categories limit 1$q$, 'user cannot insert places');
  perform t.ok(t.affected($q$update public.places set name_ar = 'pwned'$q$) = 0, 'user update on places affects 0 rows');
  perform t.denied($q$insert into public.user_roles (user_id, role) values ('00000000-0000-0000-0000-0000000000a1', 'admin')$q$, 'PRIVILEGE ESCALATION: user cannot grant self admin');
  perform t.denied($q$update public.user_roles set role = 'admin'$q$, 'user cannot update roles');
  perform t.denied($q$delete from public.user_roles$q$, 'user cannot delete roles');
  perform t.ok(t.affected($q$update public.profiles set display_name = 'Alice B' where id = '00000000-0000-0000-0000-0000000000a1'$q$) = 1, 'user can edit own display name');
  perform t.denied($q$update public.profiles set status = 'active' where id = '00000000-0000-0000-0000-0000000000a1'$q$, 'user cannot change own account status');
  perform t.denied($q$update public.profiles set email = 'x@y.z' where id = '00000000-0000-0000-0000-0000000000a1'$q$, 'user cannot change stored email');
  perform t.ok(t.affected($q$update public.profiles set display_name = 'hijack' where id = '00000000-0000-0000-0000-0000000000b2'$q$) = 0, 'user cannot edit another profile');
  perform t.ok(t.count('select 1 from public.profiles') = 1, 'user sees only own profile');
  perform t.ok(t.count('select 1 from public.user_roles') = 0, 'normal user sees no roles');
  perform t.ok(t.count('select 1 from public.admin_audit_logs') = 0, 'user cannot read audit logs');
  perform t.denied($q$insert into public.contact_messages (name, email, message) values ('a','a@b.c','hello world')$q$, 'client cannot insert contact messages directly');
  perform t.denied($q$select public.admin_set_account_status('00000000-0000-0000-0000-0000000000b2', 'suspended')$q$, 'user cannot call admin RPC');
  perform t.denied($q$insert into public.points_transactions (user_id, delta, reason, idempotency_key) values ('00000000-0000-0000-0000-0000000000a1', 1000, 'cheat', 'k1')$q$, 'user cannot award themselves points');
  perform t.denied($q$insert into public.offer_redemptions (offer_id, user_id) values (gen_random_uuid(), '00000000-0000-0000-0000-0000000000a1')$q$, 'user cannot write redemptions directly');
  perform t.denied($q$insert into storage.objects (bucket_id, name) values ('place-images','a.jpg')$q$, 'normal user cannot upload to place-images', '42501');
  -- favorites
  perform t.ok(t.affected(format('insert into public.favorites (place_id) values (%L)', lighthouse)) = 1, 'user can favorite a published place (user_id defaults to auth.uid())');
  perform t.denied(format('insert into public.favorites (user_id, place_id) values (%L, %L)', bob, lighthouse), 'user cannot favorite on behalf of another user');
  perform t.denied(format('insert into public.favorites (place_id) values (%L)', draft), 'user cannot favorite an unpublished place');

  perform t.as_user(bob);
  perform t.ok(t.count('select 1 from public.favorites') = 0, 'user cannot see others favorites');
  perform t.ok(t.affected('delete from public.favorites') = 0, 'user cannot delete others favorites');

  -- ───── SUSPENDED USER ─────
  perform t.as_user(carol);
  perform t.denied(format('insert into public.favorites (place_id) values (%L)', lighthouse), 'suspended user cannot favorite');

  -- ───── EDITOR ─────
  perform t.as_user(eli);
  perform t.ok(t.count('select 1 from public.places') = 7, 'editor sees all places incl. drafts and deleted');
  perform t.ok(t.affected($q$insert into public.places (slug, category_id, governorate_id, name_ar) select 'editor-place', id, (select id from public.governorates limit 1), 'x' from public.categories limit 1$q$) = 1, 'editor can create places');
  perform t.ok(t.affected($q$update public.places set status = 'published' where slug = 'editor-place'$q$) = 1, 'editor can publish places');
  perform t.ok(t.affected($q$delete from public.places where slug = 'editor-place'$q$) = 0, 'editor cannot hard-delete places (admin only)');
  perform t.ok(t.count('select 1 from public.admin_audit_logs') = 0, 'editor cannot read audit logs');
  perform t.ok(t.affected($q$update public.platform_settings set value = '1' where key = 'site.default_locale'$q$) = 0, 'editor cannot change settings');
  perform t.denied($q$insert into public.platform_settings (key, value) values ('evil', '1')$q$, 'editor cannot create settings');
  perform t.denied($q$insert into public.user_roles (user_id, role) values ('00000000-0000-0000-0000-0000000000e5', 'admin')$q$, 'editor cannot escalate to admin');
  perform t.ok(t.affected($q$insert into storage.objects (bucket_id, name) values ('place-images','e.jpg')$q$) = 1, 'editor can upload place images');
  perform t.denied($q$insert into storage.objects (bucket_id, name) values ('branding','logo.png')$q$, 'editor cannot upload branding');

  -- SERVICE ROLE (server-side contact form)
  perform t.as_user(null, 'service_role');
  perform t.ok(t.affected($q$insert into public.contact_messages (name, email, message) values ('Visitor','v@example.com','Hello team')$q$) = 1, 'service role can store contact messages');

  -- ADMIN
  perform t.as_user(dana);
  perform t.ok(t.count('select 1 from public.admin_audit_logs') > 0, 'admin can read audit logs');
  perform t.ok(t.count('select 1 from public.profiles') = 5, 'admin can list all profiles');
  perform t.ok(t.count('select 1 from public.contact_messages') = 1, 'admin can read contact messages');
  perform t.ok(t.affected($q$update public.platform_settings set value = '"v2"' where key = 'site.default_locale'$q$) = 1, 'admin can update settings');
  perform public.admin_set_account_status(bob, 'suspended');
  perform t.denied(format('select public.admin_set_account_status(%L, %L)', dana, 'suspended'), 'admin cannot suspend self', '22023');
  perform t.ok(t.affected($q$delete from public.places where slug = 'editor-place'$q$) = 1, 'admin can delete places');
  perform t.denied($q$update public.admin_audit_logs set action = 'x'$q$, 'admin cannot edit audit logs');
  perform t.denied($q$delete from public.admin_audit_logs$q$, 'admin cannot delete audit logs');
  perform t.denied($q$insert into public.user_roles (user_id, role) values ('00000000-0000-0000-0000-0000000000a1', 'admin')$q$, 'admin cannot grant roles from the client (owner/service process only)');
  perform t.ok(t.affected($q$insert into storage.objects (bucket_id, name) values ('branding','logo.png')$q$) = 1, 'admin can upload branding');

  -- SUPERUSER: audit + integrity
  perform t.reset();
  perform t.ok((select status from public.profiles where id = bob) = 'suspended', 'suspension persisted');
  perform t.ok((select count(*) from public.admin_audit_logs where admin_id = eli and target_table = 'places' and action = 'insert') = 1, 'audit: editor place creation logged with actor');
  perform t.ok((select count(*) from public.admin_audit_logs where admin_id = eli and action = 'update' and metadata #>> '{changes,status,new}' = 'published') = 1, 'audit: publish change recorded with old/new');
  perform t.ok((select count(*) from public.admin_audit_logs where admin_id = dana and target_table = 'profiles') = 1, 'audit: account suspension logged');
  perform t.ok((select count(*) from public.admin_audit_logs where admin_id = dana and target_table = 'places' and action = 'delete') = 1, 'audit: deletion logged');
  perform t.ok((select count(*) from public.admin_audit_logs where target_table = 'user_roles') = 2, 'audit: role grants logged');
  perform t.denied($q$update public.admin_audit_logs set action = 'x'$q$, 'audit log is append-only even for owner');
  perform t.denied($q$truncate public.admin_audit_logs$q$, 'audit log cannot be truncated');
  insert into public.points_transactions (user_id, delta, reason, idempotency_key) values (alice, 5, 'r', 'k');
  perform t.denied($q$update public.points_transactions set delta = 99$q$, 'points ledger is immutable');
  perform t.denied($q$insert into public.points_transactions (user_id, delta, reason, idempotency_key) values ('00000000-0000-0000-0000-0000000000a1', 5, 'r', 'k')$q$, 'duplicate points award rejected by idempotency key', '23505');
  perform t.denied($q$update public.places set latitude = 31.2 where slug = 'port-said-lighthouse'$q$, 'latitude without longitude rejected', '23514');
  perform t.denied($q$update public.places set status = 'scheduled', publish_at = null where slug = 'port-said-lighthouse'$q$, 'scheduled requires publish_at', '23514');
  perform t.denied($q$insert into public.offers (place_id, title_ar, discount_type, discount_value) select id, 'x', 'percentage', 150 from public.places limit 1$q$, 'percentage over 100 rejected', '23514');
  perform t.denied($q$insert into public.categories (slug, name_ar) values ('Bad Slug', 'x')$q$, 'invalid slug rejected', '23514');
  perform t.denied($q$insert into public.categories (slug, name_ar) values ('cafes', 'x')$q$, 'duplicate slug rejected', '23505');
  perform t.denied($q$update public.places set website = 'javascript:alert(1)' where slug = 'port-said-lighthouse'$q$, 'non-http website URL rejected', '23514');
end $$;

select count(*) || ' assertions passed' as result from t.results;
