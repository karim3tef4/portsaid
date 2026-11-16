import type { MetadataRoute } from "next";
export default function robots(): MetadataRoute.Robots {
  const base = (process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000").replace(/\/$/, "");
  // Deliberately no admin path here: listing it would reveal it.
  return { rules: [{ userAgent: "*", allow: "/", disallow: ["/login", "/account"] }], sitemap: `${base}/sitemap.xml` };
}
