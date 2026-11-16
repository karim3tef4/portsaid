-- 0004: abuse protection for the contact form + editable "About" page content.
-- ip_hash is a salted SHA-256 (salt is a server secret); raw IPs are never stored.
alter table public.contact_messages add column ip_hash text check (ip_hash is null or char_length(ip_hash) = 64);
create index contact_messages_ip_recent on public.contact_messages (ip_hash, created_at desc);

insert into public.platform_settings (key, value, is_public) values
 ('page.about', $json${
   "ar": {"title":"عن بورسعيد هاب",
          "vision":"أن تكون بورسعيد هاب البوابة الأولى لاكتشاف المدينة: أماكنها وخدماتها وتجاربها وعروضها في مكان واحد.",
          "mission":"مساعدة الطلاب والمقيمين والزائرين على الوصول إلى ما يحتاجونه في بورسعيد بسهولة، ومساعدة الأعمال المحلية على الوصول إلى عملاء جدد.",
          "why":"كثير من الأماكن الجيدة يصعب العثور عليها، خاصة على الطلاب الجدد والزائرين. نجمع المعلومات الموثوقة في تجربة واحدة بسيطة.",
          "future":"نبدأ ببورسعيد، وصُمّمت المنصة لتتوسع إلى باقي المحافظات المصرية."},
   "en": {"title":"About Port Said Hub",
          "vision":"To be the first gateway for discovering Port Said: its places, services, experiences and offers in one place.",
          "mission":"Help students, residents and visitors find what they need in Port Said, and help local businesses reach new customers.",
          "why":"Many great places are hard to find, especially for new students and visitors. We bring reliable information together in one simple experience.",
          "future":"We start with Port Said and the platform is built to expand to other Egyptian governorates."}
 }$json$::jsonb, true)
on conflict (key) do nothing;
