import { getHomepage } from "@/lib/data/site";
import Link from "next/link";
import { pick } from "@/lib/i18n";
import { getLocale } from "@/lib/locale";
import { SearchBox } from "@/components/search-box";
import { PlaceCard } from "@/components/place-card";
import type { HomepageSection } from "@/lib/types";


export default async function HomePage() {
  const L = await getLocale();
  const text = (s: HomepageSection, f: "title" | "subtitle") => pick(s as unknown as Record<string, unknown>, f, L);
  const { sections, categories, featured } = await getHomepage();
  return (
    <div>
      {sections.map((s) => {
        switch (s.type) {
          case "hero":
            return (
              <section key={s.id} className="bg-secondary text-white">
                <div className="mx-auto max-w-6xl px-4 py-20 sm:py-28">
                  <h1 className="max-w-2xl text-4xl font-bold leading-tight sm:text-5xl">{text(s, "title")}</h1>
                  {text(s, "subtitle") && <p className="mt-4 max-w-xl text-lg text-white/80">{text(s, "subtitle")}</p>}
                  <div className="mt-8"><SearchBox locale={L} /></div>
                </div>
              </section>
            );
          case "categories":
            return (
              <section key={s.id} className="mx-auto max-w-6xl px-4 pt-12" aria-labelledby={`h-${s.key}`}>
                <h2 id={`h-${s.key}`} className="text-2xl font-bold text-secondary">{text(s, "title")}</h2>
                <ul className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
                  {categories.map((c) => (
                    <li key={c.id}>
                      <Link href={`/explore?category=${c.slug}`} className="block rounded-card border border-line bg-surface-muted px-4 py-5 text-center font-medium text-secondary hover:border-primary">
                        {pick(c as unknown as Record<string, unknown>, "name", L)}
                      </Link>
                    </li>
                  ))}
                </ul>
              </section>
            );
          case "featured_places":
            return featured.length === 0 ? null : (
              <section key={s.id} className="mx-auto max-w-6xl px-4 pt-12" aria-labelledby={`h-${s.key}`}>
                <h2 id={`h-${s.key}`} className="text-2xl font-bold text-secondary">{text(s, "title")}</h2>
                <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                  {featured.map((p) => <PlaceCard key={p.id} place={p} locale={L} />)}
                </div>
              </section>
            );
          default:
            return null; // offers / announcements / banner / rich_text sections land in later stages
        }
      })}
    </div>
  );
}
