import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { getPlaceBySlug, getRelatedPlaces } from "@/lib/data/places";
import { getLocale } from "@/lib/locale";
import { fmt, t } from "@/lib/messages";
import { pick } from "@/lib/i18n";
import { mediaUrl } from "@/lib/media";
import { directionsHref, hhmm, jsonLd, safeSocialLinks, telHref, whatsappHref } from "@/lib/safe";
import { PlaceCard } from "@/components/place-card";
import { OfferCard } from "@/components/offer-card";

type Props = { params: Promise<{ slug: string }> };
const rec = (o: unknown) => o as Record<string, unknown>;

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const place = await getPlaceBySlug(slug);
  if (!place) return { title: "404" };
  const locale = await getLocale();
  const name = pick(rec(place), "name", locale);
  const desc = pick(rec(place), "description", locale).slice(0, 160);
  const cover = mediaUrl("place-images", place.cover_image_path);
  return {
    title: name, description: desc, alternates: { canonical: `/places/${place.slug}` },
    openGraph: { title: name, description: desc, type: "website", url: `/places/${place.slug}`, ...(cover ? { images: [cover] } : {}) },
  };
}

export default async function PlacePage({ params }: Props) {
  const { slug } = await params;
  const place = await getPlaceBySlug(slug);
  if (!place) notFound();
  const locale = await getLocale();
  const m = t(locale);
  const related = await getRelatedPlaces(place.category_id, place.id);
  const name = pick(rec(place), "name", locale);
  const address = pick(rec(place), "address", locale);
  const description = pick(rec(place), "description", locale);
  const cover = mediaUrl("place-images", place.cover_image_path);
  const gallery = [...place.place_images].sort((a, b) => a.sort_order - b.sort_order);
  const services = [...place.place_services].sort((a, b) => a.sort_order - b.sort_order);
  const hours = [...place.opening_hours].sort((a, b) => a.day_of_week - b.day_of_week || (a.opens_at ?? "").localeCompare(b.opens_at ?? ""));
  const social = safeSocialLinks(place.social_links);
  const area = [place.district, place.city].filter(Boolean).map((x) => pick(rec(x), "name", locale)).join("، ");
  const hasGeo = place.latitude != null && place.longitude != null;

  const structured = {
    "@context": "https://schema.org", "@type": "TouristAttraction", name, description: description || undefined,
    address: address ? { "@type": "PostalAddress", streetAddress: address, addressCountry: "EG" } : undefined,
    geo: hasGeo ? { "@type": "GeoCoordinates", latitude: place.latitude, longitude: place.longitude } : undefined,
    telephone: place.phone ?? undefined, image: cover ?? undefined,
  };

  return (
    <article className="mx-auto max-w-6xl px-4 py-8">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: jsonLd(structured) }} />
      <nav aria-label="Breadcrumb" className="text-sm text-ink-muted">
        <Link href="/explore" className="hover:underline">{m.nav.explore}</Link>
        {place.category && <> / <Link href={`/explore?category=${place.category.slug}`} className="hover:underline">{pick(rec(place.category), "name", locale)}</Link></>}
      </nav>
      <h1 className="mt-3 text-3xl font-bold text-secondary">{name}</h1>
      {area && <p className="mt-1 text-ink-muted">{area}</p>}

      <div className="relative mt-6 aspect-[16/7] overflow-hidden rounded-card bg-surface-muted">
        {cover && <Image src={cover} alt={name} fill priority sizes="(min-width:1152px) 1152px, 100vw" className="object-cover" />}
      </div>

      <div className="mt-8 grid gap-8 lg:grid-cols-3">
        <div className="space-y-8 lg:col-span-2">
          {description && <p className="whitespace-pre-line leading-8 text-ink">{description}</p>}

          {services.length > 0 && (
            <section aria-labelledby="svc"><h2 id="svc" className="text-xl font-bold text-secondary">{m.place.services}</h2>
              <ul className="mt-3 flex flex-wrap gap-2">{services.map((s) => <li key={s.id} className="rounded-full bg-surface-muted px-3 py-1 text-sm">{pick(rec(s), "name", locale)}</li>)}</ul>
            </section>
          )}

          {gallery.length > 0 && (
            <section aria-labelledby="gal"><h2 id="gal" className="text-xl font-bold text-secondary">{m.place.gallery}</h2>
              <ul className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-3">
                {gallery.map((img) => {
                  const src = mediaUrl("place-images", img.storage_path);
                  return src ? (
                    <li key={img.id} className="relative aspect-[4/3] overflow-hidden rounded-card bg-surface-muted">
                      <Image src={src} alt={pick(rec(img), "alt", locale) || name} fill sizes="(min-width:1024px) 22vw, 50vw" className="object-cover" loading="lazy" />
                    </li>
                  ) : null;
                })}
              </ul>
            </section>
          )}

          {place.offers.length > 0 && (
            <section aria-labelledby="off"><h2 id="off" className="text-xl font-bold text-secondary">{m.place.offers}</h2>
              <div className="mt-3 grid gap-3">{place.offers.map((o) => <OfferCard key={o.id} offer={o} locale={locale} />)}</div>
            </section>
          )}
        </div>

        <aside className="space-y-6">
          <section className="rounded-card border border-line p-5" aria-labelledby="contact">
            <h2 id="contact" className="text-lg font-bold text-secondary">{m.place.contact}</h2>
            <dl className="mt-3 space-y-3 text-sm">
              {address && <div><dt className="text-ink-muted">{m.place.address}</dt><dd>{address}</dd></div>}
              {place.phone && <div><dt className="text-ink-muted">{m.place.phone}</dt><dd><a className="text-primary underline" href={telHref(place.phone)} dir="ltr">{place.phone}</a></dd></div>}
              {place.whatsapp && <div><dt className="text-ink-muted">{m.place.whatsapp}</dt><dd><a className="text-primary underline" href={whatsappHref(place.whatsapp)} rel="noopener noreferrer" target="_blank" dir="ltr">{place.whatsapp}</a></dd></div>}
              {place.email && <div><dt className="text-ink-muted">{m.place.email}</dt><dd><a className="text-primary underline" href={`mailto:${place.email}`} dir="ltr">{place.email}</a></dd></div>}
              {place.website && <div><dt className="text-ink-muted">{m.place.website}</dt><dd><a className="break-all text-primary underline" href={place.website} rel="noopener noreferrer nofollow" target="_blank" dir="ltr">{place.website}</a></dd></div>}
            </dl>
            {hasGeo && (
              <a href={directionsHref(place.latitude!, place.longitude!)} target="_blank" rel="noopener noreferrer"
                className="mt-4 block rounded-card bg-primary px-4 py-2.5 text-center font-medium text-white">{m.place.directions}</a>
            )}
            {social.length > 0 && (
              <ul className="mt-4 flex flex-wrap gap-2" aria-label={m.place.social}>
                {social.map((s) => <li key={s.key}><a href={s.url} rel="noopener noreferrer nofollow" target="_blank" className="rounded-full border border-line px-3 py-1 text-sm capitalize text-secondary">{s.key}</a></li>)}
              </ul>
            )}
          </section>

          {hours.length > 0 && (
            <section className="rounded-card border border-line p-5" aria-labelledby="hrs">
              <h2 id="hrs" className="text-lg font-bold text-secondary">{m.place.hours}</h2>
              <ul className="mt-3 space-y-1.5 text-sm">
                {hours.map((h) => (
                  <li key={h.id} className="flex justify-between gap-4">
                    <span>{m.days[h.day_of_week]}</span>
                    <span dir="ltr" className="text-ink-muted">{h.is_closed ? m.place.closed : `${hhmm(h.opens_at)} – ${hhmm(h.closes_at)}`}</span>
                  </li>
                ))}
              </ul>
            </section>
          )}
        </aside>
      </div>

      {related.length > 0 && (
        <section className="mt-12" aria-labelledby="rel"><h2 id="rel" className="text-xl font-bold text-secondary">{m.place.related}</h2>
          <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">{related.map((p) => <PlaceCard key={p.id} place={p} locale={locale} />)}</div>
        </section>
      )}
    </article>
  );
}
