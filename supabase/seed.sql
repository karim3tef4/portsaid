-- DEVELOPMENT SEED — sample content only. Never run against production.
-- Geography/categories are structural; places are flagged is_sample = true and carry no invented coordinates.
insert into public.governorates (slug, name_ar, name_en, sort_order) values
  ('port-said', 'بورسعيد', 'Port Said', 1) on conflict do nothing;
insert into public.cities (governorate_id, slug, name_ar, name_en, sort_order)
  select id, c.slug, c.ar, c.en, c.o from public.governorates g,
  (values ('port-said','بورسعيد','Port Said',1), ('port-fouad','بورفؤاد','Port Fouad',2)) as c(slug, ar, en, o)
  where g.slug = 'port-said' on conflict do nothing;

insert into public.categories (slug, name_ar, name_en, icon, sort_order) values
  ('tourist-attractions','معالم سياحية','Tourist Attractions','landmark',1),
  ('restaurants','مطاعم','Restaurants','utensils',2),
  ('cafes','كافيهات','Cafes','coffee',3),
  ('hotels','فنادق','Hotels','bed',4),
  ('beaches','شواطئ','Beaches','waves',5),
  ('entertainment','ترفيه','Entertainment','ticket',6),
  ('shopping','تسوق','Shopping','shopping-bag',7),
  ('public-services','خدمات عامة','Public Services','building-2',8),
  ('transportation','مواصلات','Transportation','bus',9),
  ('other','تجارب محلية أخرى','Other Local Experiences','sparkles',10)
on conflict do nothing;

insert into public.places (slug, category_id, governorate_id, city_id, name_ar, name_en, description_ar, description_en, status, is_sample, is_featured)
select s.slug, c.id, g.id, ci.id, s.ar, s.en, 'محتوى تجريبي — يُستبدل من لوحة التحكم.', 'Sample content — replace from the admin dashboard.', s.status::public.content_status, true, s.feat
from (values
  ('port-said-lighthouse','tourist-attractions','فنار بورسعيد','Port Said Lighthouse','published',true),
  ('port-said-national-museum','tourist-attractions','المتحف القومي ببورسعيد','Port Said National Museum','published',false),
  ('sample-draft-place','cafes','مكان تجريبي (مسودة)','Sample draft place','draft',false)
) as s(slug, cat, ar, en, status, feat)
join public.categories c on c.slug = s.cat
join public.governorates g on g.slug = 'port-said'
join public.cities ci on ci.governorate_id = g.id and ci.slug = 'port-said'
on conflict do nothing;
