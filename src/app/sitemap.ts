import type { MetadataRoute } from "next";
import { getPublishedSlugs } from "@/lib/data/places";

export const dynamic = "force-dynamic";
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = (process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000").replace(/\/$/, "");
  const staticPaths = ["", "/explore", "/categories", "/offers", "/about", "/contact"];
  const places = await getPublishedSlugs(); // RLS: published only. The admin path is never listed.
  return [
    ...staticPaths.map((p) => ({ url: `${base}${p}` })),
    ...places.map((p) => ({ url: `${base}/places/${p.slug}`, lastModified: new Date(p.updated_at) })),
  ];
}
