import Link from "next/link";
import { Logo } from "@/components/logo";
import { setLocale } from "@/app/actions/locale";
import { t } from "@/lib/messages";
import type { Branding } from "@/lib/data/site";
import type { Locale } from "@/lib/types";

const links = (m: ReturnType<typeof t>) => [
  { href: "/explore", label: m.nav.explore }, { href: "/categories", label: m.nav.categories },
  { href: "/offers", label: m.nav.offers }, { href: "/about", label: m.nav.about }, { href: "/contact", label: m.nav.contact },
];

export function SiteHeader({ branding, locale }: { branding: Branding; locale: Locale }) {
  const m = t(locale);
  const other: Locale = locale === "ar" ? "en" : "ar";
  const linkCls = "rounded-md px-3 py-2 text-sm font-medium text-ink-muted hover:bg-surface-muted hover:text-secondary";
  return (
    <header className="sticky top-0 z-30 border-b border-line bg-surface/95 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-3 px-4">
        <Logo branding={branding} locale={locale} />
        <nav aria-label="Main" className="hidden items-center gap-1 md:flex">
          {links(m).map((l) => <Link key={l.href} href={l.href} className={linkCls}>{l.label}</Link>)}
        </nav>
        <div className="flex items-center gap-2">
          <form action={setLocale}>
            <input type="hidden" name="locale" value={other} />
            <button type="submit" lang={other} className="rounded-md border border-line px-3 py-1.5 text-sm font-medium text-secondary hover:bg-surface-muted">{m.nav.switchLang}</button>
          </form>
          <details className="relative md:hidden">
            <summary className="cursor-pointer list-none rounded-md border border-line px-3 py-1.5 text-sm font-medium text-secondary">{m.nav.menu}</summary>
            <nav aria-label="Mobile" className="absolute end-0 mt-2 w-56 rounded-card border border-line bg-surface p-2 shadow-card">
              {links(m).map((l) => <Link key={l.href} href={l.href} className={`block ${linkCls}`}>{l.label}</Link>)}
            </nav>
          </details>
        </div>
      </div>
    </header>
  );
}

export function SiteFooter({ branding, locale }: { branding: Branding; locale: Locale }) {
  const m = t(locale);
  const name = locale === "ar" ? branding.nameAr : branding.nameEn;
  const tagline = locale === "ar" ? branding.taglineAr : branding.taglineEn;
  return (
    <footer className="mt-16 border-t border-line bg-surface-muted">
      <div className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-10 text-sm text-ink-muted sm:flex-row sm:justify-between">
        <div>
          <p className="font-semibold text-secondary">{name}</p>
          {tagline && <p className="mt-1">{tagline}</p>}
          <p className="mt-6">© {new Date().getFullYear()} {name}. {m.footer.rights}.</p>
        </div>
        <nav aria-label="Footer" className="flex flex-wrap gap-x-5 gap-y-2">
          {links(m).map((l) => <Link key={l.href} href={l.href} className="hover:text-secondary">{l.label}</Link>)}
        </nav>
      </div>
    </footer>
  );
}
