import { z } from "zod";
import { createPublicClient } from "@/lib/supabase/public";
import type { Category, OfferRow, PlaceDetail, PlaceSummary } from "@/lib/types";

export const PAGE_SIZE = 12;
const SUMMARY = "id,slug,name_ar,name_en,description_ar,description_en,cover_image_path,category_id,is_featured,is_sample";

const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v);
const schema = z.object({
  q: z.string().trim().max(100).optional().catch(undefined),
  category: z.string().regex(/^[a-z0-9-]{1,60}$/).optional().catch(undefined),
  sort: z.enum(["relevance", "popular"]).catch("relevance"),
  view: z.enum(["grid", "list"]).catch("grid"),
  page: z.coerce.number().int().min(1).max(500).catch(1),
});
export type ExploreParams = z.infer<typeof schema>;

/** Untrusted URL params -> validated values. Bad input degrades to defaults instead of erroring. */
export function parseExploreParams(raw: Record<string, string | string[] | undefined>): ExploreParams {
  return schema.parse({ q: first(raw.q) || undefined, category: first(raw.category) || undefined, sort: first(raw.sort), view: first(raw.view), page: first(raw.page) });
}

export async function getCategoriesList(): Promise<Category[]> {
  const { data, error } = await createPublicClient().from("categories").select("id,slug,name_ar,name_en,icon,sort_order").order("sort_order");
  if (error) throw new Error(`categories: ${error.message}`);
  return data as Category[];
}

export async function searchPlaces(p: ExploreParams, categories: Category[]) {
  const db = createPublicClient();
  const categoryId = p.category ? categories.find((c) => c.slug === p.category)?.id : undefined;
  if (p.category && !categoryId) return { items: [] as PlaceSummary[], total: 0 };
  const args = { q: p.q ?? null, p_category: categoryId ?? null };
  const [rows, count] = await Promise.all([
    db.rpc("search_places", { ...args, p_sort: p.sort, p_limit: PAGE_SIZE, p_offset: (p.page - 1) * PAGE_SIZE }),
    db.rpc("search_places_count", args),
  ]);
  if (rows.error || count.error) throw new Error(`search: ${(rows.error ?? count.error)?.message}`);
  return { items: rows.data as PlaceSummary[], total: Number(count.data) };
}

export async function getPlaceBySlug(slug: string): Promise<PlaceDetail | null> {
  if (!/^[a-z0-9-]{1,120}$/.test(slug)) return null;
  const { data, error } = await createPublicClient().from("places").select(
    `${SUMMARY},address_ar,address_en,latitude,longitude,phone,whatsapp,email,website,social_links,
     category:categories(slug,name_ar,name_en),city:cities(name_ar,name_en),district:districts(name_ar,name_en),
     place_images(id,storage_path,alt_ar,alt_en,sort_order),place_services(id,name_ar,name_en,sort_order),
     opening_hours(id,day_of_week,opens_at,closes_at,is_closed),
     offers(id,title_ar,title_en,description_ar,description_en,conditions_ar,conditions_en,discount_type,discount_value,ends_at)`,
  ).eq("slug", slug).is("deleted_at", null).maybeSingle();
  if (error) throw new Error(`place: ${error.message}`);
  return (data as PlaceDetail | null) ?? null;
}

export async function getRelatedPlaces(categoryId: string, excludeId: string): Promise<PlaceSummary[]> {
  const { data } = await createPublicClient().from("places").select(SUMMARY)
    .eq("category_id", categoryId).neq("id", excludeId).is("deleted_at", null).order("popularity_score", { ascending: false }).limit(4);
  return (data as PlaceSummary[] | null) ?? [];
}

export async function getActiveOffers(): Promise<OfferRow[]> {
  const { data, error } = await createPublicClient().from("offers").select(
    "id,title_ar,title_en,description_ar,description_en,conditions_ar,conditions_en,discount_type,discount_value,ends_at,place:places(slug,name_ar,name_en)",
  ).order("ends_at", { ascending: true, nullsFirst: false });
  if (error) throw new Error(`offers: ${error.message}`);
  return data as unknown as OfferRow[];
}

export async function getPlaceCountsByCategory(): Promise<Record<string, number>> {
  const { data } = await createPublicClient().from("places").select("category_id").is("deleted_at", null);
  const counts: Record<string, number> = {};
  for (const r of (data ?? []) as { category_id: string }[]) counts[r.category_id] = (counts[r.category_id] ?? 0) + 1;
  return counts;
}

export async function getSetting<T>(key: string): Promise<T | null> {
  const { data } = await createPublicClient().from("platform_settings").select("value").eq("key", key).maybeSingle();
  return (data?.value as T | undefined) ?? null;
}

export async function getFlag(key: string): Promise<boolean> {
  const { data } = await createPublicClient().from("feature_flags").select("enabled").eq("key", key).maybeSingle();
  return data?.enabled === true;
}

export async function getPublishedSlugs(): Promise<{ slug: string; updated_at: string }[]> {
  const { data } = await createPublicClient().from("places").select("slug,updated_at").is("deleted_at", null).limit(5000);
  return (data as { slug: string; updated_at: string }[] | null) ?? [];
}
