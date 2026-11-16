import { createPublicClient } from "@/lib/supabase/public";
import type { Category, HomepageSection, PlaceSummary } from "@/lib/types";

const HEX = /^#[0-9a-fA-F]{6}$/;

export interface Branding {
  nameAr: string; nameEn: string; taglineAr: string; taglineEn: string;
  logoLightPath: string | null; logoDarkPath: string | null;
  colors: { primary?: string; secondary?: string; accent?: string };
}

/** Single source of truth for brand name/logo/colors. Change in platform_settings, not in components. */
export async function getBranding(): Promise<Branding> {
  const { data } = await createPublicClient().from("platform_settings").select("key, value").like("key", "%.%");
  const map = new Map((data ?? []).map((r) => [r.key as string, r.value as Record<string, string | null>]));
  const name = map.get("site.name") ?? {};
  const tagline = map.get("site.tagline") ?? {};
  const logo = map.get("branding.logo") ?? {};
  const t = map.get("branding.tokens") ?? {};
  const color = (v: unknown) => (typeof v === "string" && HEX.test(v) ? v : undefined); // validated: prevents CSS injection
  return {
    nameAr: name.ar ?? "بورسعيد هاب", nameEn: name.en ?? "Port Said Hub",
    taglineAr: tagline.ar ?? "", taglineEn: tagline.en ?? "",
    logoLightPath: logo.light_path ?? null, logoDarkPath: logo.dark_path ?? null,
    colors: { primary: color(t.primary), secondary: color(t.secondary), accent: color(t.accent) },
  };
}

export async function getHomepage() {
  const db = createPublicClient();
  const [sections, categories, featured] = await Promise.all([
    db.from("homepage_sections").select("id,key,type,title_ar,title_en,subtitle_ar,subtitle_en,content,sort_order").order("sort_order"),
    db.from("categories").select("id,slug,name_ar,name_en,icon,sort_order").order("sort_order"),
    db.from("places").select("id,slug,name_ar,name_en,description_ar,description_en,cover_image_path,category_id,is_featured,is_sample")
      .eq("is_featured", true).is("deleted_at", null).order("popularity_score", { ascending: false }).limit(8),
  ]);
  const error = sections.error ?? categories.error ?? featured.error;
  if (error) throw new Error(`Failed to load homepage: ${error.message}`); // surfaced by error.tsx — never swallowed
  return {
    sections: sections.data as HomepageSection[],
    categories: categories.data as Category[],
    featured: featured.data as PlaceSummary[],
  };
}
