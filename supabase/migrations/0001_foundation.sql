-- Port Said Hub — 0001 foundation: types, geography, identity, content tables.
-- Security model: RLS on every table + explicit least-privilege GRANTs (defense in depth).

create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;

-- ───────────── Enums ─────────────
create type public.content_status as enum ('draft', 'published', 'scheduled', 'archived');
create type public.offer_status   as enum ('draft', 'scheduled', 'active', 'expired', 'disabled');
create type public.app_role       as enum ('admin', 'editor');
create type public.account_status as enum ('active', 'suspended');
create type public.discount_type  as enum ('percentage', 'fixed_amount', 'other');

-- ───────────── Generic helpers ─────────────
create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end $$;

create function public.escape_like(t text) returns text
language sql immutable set search_path = '' as $$
  select replace(replace(replace(t, '\', '\\'), '%', '\%'), '_', '\_')
$$;

-- Visible to the public? (published, or scheduled and its time has arrived)
create function public.is_published(s public.content_status, publish_at timestamptz)
returns boolean language sql stable set search_path = '' as $$
  select s = 'published' or (s = 'scheduled' and publish_at is not null and publish_at <= now())
$$;

-- ───────────── Geography (multi-governorate from day one) ─────────────
create table public.governorates (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_ar text not null, name_en text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.cities (
  id uuid primary key default gen_random_uuid(),
  governorate_id uuid not null references public.governorates(id) on delete restrict,
  slug text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_ar text not null, name_en text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (governorate_id, slug)
);
create table public.districts (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities(id) on delete restrict,
  slug text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_ar text not null, name_en text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (city_id, slug)
);
create index on public.cities (governorate_id);
create index on public.districts (city_id);

-- ───────────── Identity ─────────────
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text check (char_length(display_name) <= 80),
  avatar_url text check (avatar_url is null or avatar_url ~ '^https://'),
  preferred_locale text not null default 'ar' check (preferred_locale in ('ar', 'en')),
  status public.account_status not null default 'active',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index on public.profiles (status);

create table public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null,
  granted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Role helpers. SECURITY DEFINER so they are not subject to the caller's RLS.
create function public.has_role(required public.app_role) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_roles ur
                 where ur.user_id = (select auth.uid()) and ur.role = required)
$$;
create function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$ select public.has_role('admin') $$;
create function public.is_staff() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_roles ur where ur.user_id = (select auth.uid()))
$$;
create function public.is_active_user() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p
                 where p.id = (select auth.uid()) and p.status = 'active')
$$;

-- Auto-create profile on signup (Google OAuth). Avatar sanitised: https only.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare avatar text := new.raw_user_meta_data->>'avatar_url';
begin
  insert into public.profiles (id, email, display_name, avatar_url)
  values (new.id, new.email,
          left(coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'), 80),
          case when avatar ~ '^https://' then avatar end)
  on conflict (id) do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────────── Content ─────────────
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_ar text not null, name_en text,
  description_ar text, description_en text,
  icon text,                         -- lucide icon name
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.places (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  category_id uuid not null references public.categories(id) on delete restrict,
  governorate_id uuid not null references public.governorates(id) on delete restrict,
  city_id uuid references public.cities(id) on delete restrict,
  district_id uuid references public.districts(id) on delete restrict,
  name_ar text not null check (char_length(name_ar) between 1 and 200),
  name_en text check (char_length(name_en) <= 200),
  description_ar text check (char_length(description_ar) <= 10000),
  description_en text check (char_length(description_en) <= 10000),
  address_ar text, address_en text,
  latitude  numeric(9,6) check (latitude  between -90  and 90),
  longitude numeric(9,6) check (longitude between -180 and 180),
  phone text check (char_length(phone) <= 30),
  whatsapp text check (char_length(whatsapp) <= 30),
  email text check (char_length(email) <= 254),
  website text check (website is null or website ~* '^https?://'),
  social_links jsonb not null default '{}'::jsonb check (jsonb_typeof(social_links) = 'object'),
  cover_image_path text,
  is_featured boolean not null default false,
  is_sample boolean not null default false,       -- marks seed/demo content
  popularity_score int not null default 0,
  status public.content_status not null default 'draft',
  publish_at timestamptz,
  published_at timestamptz,
  deleted_at timestamptz,                          -- soft delete
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check ((latitude is null) = (longitude is null)),
  check (status <> 'scheduled' or publish_at is not null)
);
create index on public.places (status, publish_at) where deleted_at is null;
create index on public.places (category_id);
create index on public.places (governorate_id, city_id, district_id);
create index on public.places (is_featured) where is_featured;
create index places_name_ar_trgm on public.places using gin (name_ar extensions.gin_trgm_ops);
create index places_name_en_trgm on public.places using gin (name_en extensions.gin_trgm_ops);

create table public.place_images (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  storage_path text not null,
  alt_ar text, alt_en text,
  sort_order int not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index on public.place_images (place_id, sort_order);

create table public.place_services (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  name_ar text not null, name_en text,
  sort_order int not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index on public.place_services (place_id, sort_order);

create table public.opening_hours (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),   -- 0 = Sunday
  opens_at time, closes_at time,
  is_closed boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (is_closed or (opens_at is not null and closes_at is not null)),
  unique (place_id, day_of_week, opens_at)
);

create table public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  place_id uuid not null references public.places(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, place_id)
);
create index on public.favorites (place_id);

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title_ar text not null, title_en text,
  body_ar text, body_en text,
  severity text not null default 'info' check (severity in ('info', 'success', 'warning')),
  status public.content_status not null default 'draft',
  publish_at timestamptz, published_at timestamptz, expires_at timestamptz,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (status <> 'scheduled' or publish_at is not null)
);

create table public.homepage_sections (
  id uuid primary key default gen_random_uuid(),
  key text not null unique check (key ~ '^[a-z0-9_]+$'),
  type text not null check (type in ('hero', 'featured_places', 'categories', 'offers', 'announcements', 'banner', 'rich_text')),
  title_ar text, title_en text, subtitle_ar text, subtitle_en text,
  content jsonb not null default '{}'::jsonb check (jsonb_typeof(content) = 'object'),
  sort_order int not null default 0,
  is_active boolean not null default true,
  status public.content_status not null default 'published',
  publish_at timestamptz, published_at timestamptz,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (status <> 'scheduled' or publish_at is not null)
);
create table public.homepage_section_items (
  id uuid primary key default gen_random_uuid(),
  section_id uuid not null references public.homepage_sections(id) on delete cascade,
  place_id uuid references public.places(id) on delete cascade,
  category_id uuid references public.categories(id) on delete cascade,
  image_path text,
  link_url text check (link_url is null or link_url ~* '^(https?://|/)'),
  title_ar text, title_en text, body_ar text, body_en text,
  sort_order int not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index on public.homepage_section_items (section_id, sort_order);

create table public.platform_settings (
  key text primary key check (key ~ '^[a-z0-9_.]+$'),
  value jsonb not null,
  is_public boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
create table public.feature_flags (
  key text primary key check (key ~ '^[a-z0-9_]+$'),
  enabled boolean not null default false,
  description text,
  updated_at timestamptz not null default now()
);

create table public.contact_messages (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  email text not null check (char_length(email) between 3 and 254),
  subject text check (char_length(subject) <= 200),
  message text not null check (char_length(message) between 5 and 5000),
  status text not null default 'new' check (status in ('new', 'read', 'archived')),
  created_at timestamptz not null default now()
);

-- ───────────── Offers & future-ready ledgers (inactive in MVP, behind flags) ─────────────
create table public.offers (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  title_ar text not null, title_en text,
  description_ar text, description_en text,
  conditions_ar text, conditions_en text,
  discount_type public.discount_type not null default 'percentage',
  discount_value numeric(10,2) check (discount_value is null or discount_value >= 0),
  starts_at timestamptz, ends_at timestamptz,
  status public.offer_status not null default 'draft',
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (ends_at is null or starts_at is null or ends_at > starts_at),
  check (discount_type <> 'percentage' or discount_value is null or discount_value <= 100)
);
create index on public.offers (place_id);
create index on public.offers (status, starts_at, ends_at);

create table public.offer_redemptions (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references public.offers(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  redeemed_at timestamptz not null default now(),
  unique (offer_id, user_id)               -- no repeat redemption (relax per-offer later)
);

create table public.points_transactions (  -- immutable ledger
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete restrict,
  delta int not null check (delta <> 0),
  reason text not null,
  ref_type text, ref_id text,
  idempotency_key text not null unique,     -- prevents duplicate awards
  created_at timestamptz not null default now()
);
create index on public.points_transactions (user_id, created_at desc);

-- ───────────── Audit log ─────────────
create table public.admin_audit_logs (
  id bigint generated always as identity primary key,
  admin_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_table text not null,
  target_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index on public.admin_audit_logs (created_at desc);
create index on public.admin_audit_logs (admin_id);
create index on public.admin_audit_logs (target_table, target_id);
