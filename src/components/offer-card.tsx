import Link from "next/link";
import { fmt, t } from "@/lib/messages";
import { pick } from "@/lib/i18n";
import type { Locale, OfferRow } from "@/lib/types";

export function OfferCard({ offer, locale, showPlace = false }: { offer: OfferRow; locale: Locale; showPlace?: boolean }) {
  const m = t(locale);
  const r = offer as unknown as Record<string, unknown>;
  const badge = offer.discount_value == null ? null
    : offer.discount_type === "percentage" ? fmt(m.offers.off, { v: offer.discount_value })
    : offer.discount_type === "fixed_amount" ? fmt(m.offers.fixed, { v: offer.discount_value }) : null;
  const until = offer.ends_at ? new Intl.DateTimeFormat(locale === "ar" ? "ar-EG" : "en-GB", { dateStyle: "medium", timeZone: "Africa/Cairo" }).format(new Date(offer.ends_at)) : null;
  const desc = pick(r, "description", locale);
  const cond = pick(r, "conditions", locale);
  return (
    <article className="rounded-card border border-line bg-surface p-5 shadow-card">
      {badge && <span className="inline-block rounded-full bg-accent px-3 py-1 text-sm font-bold text-secondary">{badge}</span>}
      <h3 className="mt-2 font-semibold text-secondary">{pick(r, "title", locale)}</h3>
      {showPlace && offer.place && (
        <p className="text-sm text-ink-muted">{m.offers.at} <Link className="text-primary underline" href={`/places/${offer.place.slug}`}>{pick(offer.place as unknown as Record<string, unknown>, "name", locale)}</Link></p>
      )}
      {desc && <p className="mt-2 text-sm text-ink">{desc}</p>}
      {cond && <p className="mt-2 text-xs text-ink-muted"><strong>{m.offers.conditions}:</strong> {cond}</p>}
      {until && <p className="mt-2 text-xs text-ink-muted">{fmt(m.offers.validUntil, { d: until })}</p>}
    </article>
  );
}
