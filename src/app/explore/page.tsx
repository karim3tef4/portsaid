import type { Metadata } from "next";
import Link from "next/link";
import { getCategoriesList, parseExploreParams, searchPlaces, PAGE_SIZE, type ExploreParams } from "@/lib/data/places";
import { getLocale } from "@/lib/locale";
import { fmt, t } from "@/lib/messages";
import { pick } from "@/lib/i18n";
import { PlaceCard } from "@/components/place-card";
import { SearchBox } from "@/components/search-box";

export async function generateMetadata(): Promise<Metadata> {
  const m = t(await getLocale());
  return { title: m.explore.title, alternates: { canonical: "/explore" } };
}

function href(p: Partial<ExploreParams>) {
  const u = new URLSearchParams();
  if (p.q) u.set("q", p.q);
  if (p.category) u.set("category", p.category);
  if (p.sort && p.sort !== "relevance") u.set("sort", p.sort);
  if (p.view && p.view !== "grid") u.set("view", p.view);
  if (p.page && p.page > 1) u.set("page", String(p.page));
  const qs = u.toString();
  return qs ? `/explore?${qs}` : "/explore";
}

export default async function ExplorePage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const locale = await getLocale();
  const m = t(locale);
  const params = parseExploreParams(await searchParams);
  const categories = await getCategoriesList();
  const { items, total } = await searchPlaces(params, categories);
  const pages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const field = "rounded-card border border-line bg-white px-3 py-2.5";
  return (
    <div className="mx-auto max-w-6xl px-4 py-10">
      <h1 className="text-3xl font-bold text-secondary">{m.explore.title}</h1>
      <div className="mt-5"><SearchBox locale={locale} defaultValue={params.q ?? ""} category={params.category} /></div>

      <form method="get" action="/explore" className="mt-4 flex flex-wrap items-end gap-3">
        {params.q && <input type="hidden" name="q" value={params.q} />}
        <div className="flex flex-col gap-1">
          <label htmlFor="category" className="text-sm font-medium text-ink-muted">{m.filters.category}</label>
          <select id="category" name="category" defaultValue={params.category ?? ""} className={field}>
            <option value="">{m.filters.all}</option>
            {categories.map((c) => <option key={c.id} value={c.slug}>{pick(c as unknown as Record<string, unknown>, "name", locale)}</option>)}
          </select>
        </div>
        <div className="flex flex-col gap-1">
          <label htmlFor="sort" className="text-sm font-medium text-ink-muted">{m.filters.sort}</label>
          <select id="sort" name="sort" defaultValue={params.sort} className={field}>
            <option value="relevance">{m.sort.relevance}</option><option value="popular">{m.sort.popular}</option>
          </select>
        </div>
        <input type="hidden" name="view" value={params.view} />
        <button type="submit" className="rounded-card bg-primary px-5 py-2.5 font-medium text-white">{m.filters.apply}</button>
        {(params.q || params.category) && <Link href="/explore" className="py-2.5 text-sm text-primary underline">{m.explore.reset}</Link>}
      </form>

      <div className="mt-6 flex items-center justify-between">
        <p aria-live="polite" className="text-sm text-ink-muted">{fmt(m.explore.results, { n: total })}</p>
        <div className="flex gap-1" role="group" aria-label="View">
          {(["grid", "list"] as const).map((v) => (
            <Link key={v} href={href({ ...params, view: v, page: 1 })} aria-current={params.view === v ? "true" : undefined}
              className={`rounded-md border px-3 py-1.5 text-sm ${params.view === v ? "border-primary bg-primary text-white" : "border-line text-secondary"}`}>{m.view[v]}</Link>
          ))}
        </div>
      </div>

      {items.length === 0 ? (
        <p className="mt-10 rounded-card bg-surface-muted p-8 text-center text-ink-muted">{m.explore.empty}</p>
      ) : (
        <div className={params.view === "list" ? "mt-4 grid gap-4" : "mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4"}>
          {items.map((p) => <PlaceCard key={p.id} place={p} locale={locale} layout={params.view} />)}
        </div>
      )}

      {pages > 1 && (
        <nav aria-label="Pagination" className="mt-8 flex items-center justify-center gap-4 text-sm">
          {params.page > 1 ? <Link rel="prev" href={href({ ...params, page: params.page - 1 })} className="text-primary underline">{m.paging.prev}</Link> : <span />}
          <span className="text-ink-muted">{fmt(m.paging.page, { p: params.page, n: pages })}</span>
          {params.page < pages ? <Link rel="next" href={href({ ...params, page: params.page + 1 })} className="text-primary underline">{m.paging.next}</Link> : <span />}
        </nav>
      )}
    </div>
  );
}
