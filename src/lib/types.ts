// Hand-written row types for the columns the UI reads.
// TODO: replace with `supabase gen types typescript` output once the project is linked.
export type Locale = "ar" | "en";
export interface Category { id: string; slug: string; name_ar: string; name_en: string | null; icon: string | null; sort_order: number }
export interface PlaceSummary {
  id: string; slug: string; name_ar: string; name_en: string | null;
  description_ar: string | null; description_en: string | null;
  cover_image_path: string | null; category_id: string; is_featured: boolean; is_sample: boolean;
}
export interface HomepageSection {
  id: string; key: string; type: "hero" | "featured_places" | "categories" | "offers" | "announcements" | "banner" | "rich_text";
  title_ar: string | null; title_en: string | null; subtitle_ar: string | null; subtitle_en: string | null;
  content: Record<string, unknown>; sort_order: number;
}

export interface PlaceDetail extends PlaceSummary {
  address_ar: string | null; address_en: string | null;
  latitude: number | null; longitude: number | null;
  phone: string | null; whatsapp: string | null; email: string | null; website: string | null;
  social_links: Record<string, unknown>;
  category: { slug: string; name_ar: string; name_en: string | null } | null;
  city: { name_ar: string; name_en: string | null } | null;
  district: { name_ar: string; name_en: string | null } | null;
  place_images: { id: string; storage_path: string; alt_ar: string | null; alt_en: string | null; sort_order: number }[];
  place_services: { id: string; name_ar: string; name_en: string | null; sort_order: number }[];
  opening_hours: { id: string; day_of_week: number; opens_at: string | null; closes_at: string | null; is_closed: boolean }[];
  offers: OfferRow[];
}
export interface OfferRow {
  id: string; title_ar: string; title_en: string | null; description_ar: string | null; description_en: string | null;
  conditions_ar: string | null; conditions_en: string | null;
  discount_type: "percentage" | "fixed_amount" | "other"; discount_value: number | null; ends_at: string | null;
  place?: { slug: string; name_ar: string; name_en: string | null } | null;
}
