import type { Metadata } from "next";
import Link from "next/link";
import { getCategoriesList, getPlaceCountsByCategory } from "@/lib/data/places";
import { getLocale } from "@/lib/locale";
import { t } from "@/lib/messages";
import { pick } from "@/lib/i18n";

export async function generateMetadata(): Promise<Metadata> {
  return { title: t(await getLocale()).categories.title, alternates: { canonical: "/categories" } };
}

export default async function CategoriesPage() {
  const locale = await getLocale();
  const m = t(locale);
  const [categories, counts] = await Promise.all([getCategoriesList(), getPlaceCountsByCategory()]);
  return (
    <div className="mx-auto max-w-6xl px-4 py-10">
      <h1 className="text-3xl font-bold text-secondary">{m.categories.title}</h1>
      <ul className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {categories.map((c) => (
          <li key={c.id}>
            <Link href={`/explore?category=${c.slug}`} className="flex items-center justify-between rounded-card border border-line bg-surface p-5 shadow-card hover:border-primary">
              <span className="font-semibold text-secondary">{pick(c as unknown as Record<string, unknown>, "name", locale)}</span>
              <span className="rounded-full bg-surface-muted px-3 py-1 text-sm text-ink-muted">{counts[c.id] ?? 0}</span>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
