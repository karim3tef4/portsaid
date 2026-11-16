/** Helpers for rendering untrusted-ish values (DB content entered by staff) safely. */
const SOCIAL_KEYS = ["facebook", "instagram", "x", "tiktok", "youtube", "tripadvisor"] as const;
export function safeSocialLinks(raw: Record<string, unknown>): { key: string; url: string }[] {
  const out: { key: string; url: string }[] = [];
  for (const key of SOCIAL_KEYS) {
    const v = raw[key];
    if (typeof v !== "string") continue;
    try { const u = new URL(v); if (u.protocol === "https:") out.push({ key, url: u.toString() }); } catch { /* ignore invalid */ }
  }
  return out;
}
export const telHref = (p: string) => `tel:${p.replace(/[^\d+]/g, "")}`;
export const whatsappHref = (p: string) => `https://wa.me/${p.replace(/\D/g, "")}`;
export const directionsHref = (lat: number, lng: number) => `https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}`;
/** JSON-LD must not be able to close the <script> tag. */
export const jsonLd = (obj: unknown) => JSON.stringify(obj).replace(/</g, "\\u003c");
export const hhmm = (t: string | null) => (t ? t.slice(0, 5) : "");
