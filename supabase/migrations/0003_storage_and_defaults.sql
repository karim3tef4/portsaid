-- Port Said Hub — 0003: storage buckets/policies and production defaults (settings, flags, homepage).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('place-images', 'place-images', true, 5242880, array['image/jpeg','image/png','image/webp','image/avif']),
  ('branding',     'branding',     true, 2097152, array['image/jpeg','image/png','image/webp','image/svg+xml'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy "public read site media" on storage.objects for select to anon, authenticated
  using (bucket_id in ('place-images', 'branding'));
create policy "staff write place images" on storage.objects for insert to authenticated
  with check (bucket_id = 'place-images' and (select public.is_staff()));
create policy "staff update place images" on storage.objects for update to authenticated
  using (bucket_id = 'place-images' and (select public.is_staff()))
  with check (bucket_id = 'place-images' and (select public.is_staff()));
create policy "staff delete place images" on storage.objects for delete to authenticated
  using (bucket_id = 'place-images' and (select public.is_staff()));
create policy "admin write branding" on storage.objects for insert to authenticated
  with check (bucket_id = 'branding' and (select public.is_admin()));
create policy "admin update branding" on storage.objects for update to authenticated
  using (bucket_id = 'branding' and (select public.is_admin()))
  with check (bucket_id = 'branding' and (select public.is_admin()));
create policy "admin delete branding" on storage.objects for delete to authenticated
  using (bucket_id = 'branding' and (select public.is_admin()));

-- Platform defaults (centralised branding: swap the logo here / in the dashboard, no code change).
insert into public.platform_settings (key, value, is_public) values
  ('site.name',        '{"ar":"بورسعيد هاب","en":"Port Said Hub"}', true),
  ('site.tagline',     '{"ar":"اكتشف بورسعيد في مكان واحد","en":"Discover Port Said in one place"}', true),
  ('branding.logo',    '{"light_path":null,"dark_path":null}', true),
  ('branding.tokens',  '{"primary":"#0E6E8C","secondary":"#0B2F3F","accent":"#F2A541"}', true),
  ('contact.social',   '{}', true),
  ('site.default_locale', '"ar"', true)
on conflict (key) do nothing;

-- Unfinished features stay OFF until validated.
insert into public.feature_flags (key, enabled, description) values
  ('offers_page',    true,  'Show the offers listing page (no redemption)'),
  ('qr_redemption',  false, 'QR-based discount redemption'),
  ('points_rewards', false, 'Points and rewards'),
  ('user_photos',    false, 'User-generated photos and comments'),
  ('ai_assistant',   false, 'AI discovery assistant'),
  ('transportation', false, 'Transportation information')
on conflict (key) do nothing;

insert into public.homepage_sections (key, type, title_ar, title_en, content, sort_order) values
  ('hero', 'hero', 'اكتشف بورسعيد', 'Discover Port Said', '{"cta_label_ar":"استكشف الآن","cta_label_en":"Explore now","cta_href":"/explore"}', 10),
  ('categories', 'categories', 'التصنيفات', 'Categories', '{}', 20),
  ('featured_places', 'featured_places', 'أماكن مميزة', 'Featured places', '{}', 30),
  ('offers', 'offers', 'أحدث العروض', 'Latest offers', '{}', 40),
  ('announcements', 'announcements', 'إعلانات', 'Announcements', '{}', 50)
on conflict (key) do nothing;
