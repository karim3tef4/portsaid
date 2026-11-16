import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { getActiveOffers, getFlag } from "@/lib/data/places";
import { getLocale } from "@/lib/locale";
import { t } from "@/lib/messages";
import { OfferCard } from "@/components/offer-card";

export async function generateMetadata(): Promise<Metadata> {
  return { title: t(await getLocale()).offers.title, alternates: { canonical: "/offers" } };
}

export default async function OffersPage() {
  if (!(await getFlag("offers_page"))) notFound(); // feature-flagged
  const locale = await getLocale();
  const m = t(locale);
  const offers = await getActiveOffers(); // RLS returns only active, in-date offers on published places
  return (
    <div className="mx-auto max-w-6xl px-4 py-10">
      <h1 className="text-3xl font-bold text-secondary">{m.offers.title}</h1>
      {offers.length === 0 ? (
        <p className="mt-8 rounded-card bg-surface-muted p-8 text-center text-ink-muted">{m.offers.empty}</p>
      ) : (
        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">{offers.map((o) => <OfferCard key={o.id} offer={o} locale={locale} showPlace />)}</div>
      )}
    </div>
  );
}
