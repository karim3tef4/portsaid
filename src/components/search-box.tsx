import type { Locale } from "@/lib/types";
import { t } from "@/lib/messages";

export function SearchBox({ locale, defaultValue = "", category }: { locale: Locale; defaultValue?: string; category?: string }) {
  const m = t(locale);
  return (
    <form action="/explore" method="get" role="search" className="flex w-full max-w-xl gap-2">
      <label htmlFor="q" className="sr-only">{m.search.label}</label>
      <input id="q" name="q" type="search" maxLength={100} defaultValue={defaultValue} placeholder={m.search.placeholder}
        className="min-w-0 flex-1 rounded-card border border-line bg-white px-4 py-3 text-ink placeholder:text-ink-muted" />
      {category && <input type="hidden" name="category" value={category} />}
      <button type="submit" className="rounded-card bg-accent px-5 py-3 font-semibold text-secondary hover:brightness-95">{m.search.button}</button>
    </form>
  );
}
