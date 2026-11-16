import Image from "next/image";
import Link from "next/link";
import { mediaUrl } from "@/lib/media";
import { pick } from "@/lib/i18n";
import type { Locale, PlaceSummary } from "@/lib/types";

export function PlaceCard({ place, locale, layout = "grid" }: { place: PlaceSummary; locale: Locale; layout?: "grid" | "list" }) {
  const cover = mediaUrl("place-images", place.cover_image_path);
  const rec = place as unknown as Record<string, unknown>;
  const name = pick(rec, "name", locale);
  const desc = pick(rec, "description", locale);
  const list = layout === "list";
  return (
    <article className={`group relative overflow-hidden rounded-card border border-line bg-surface shadow-card transition-shadow hover:shadow-lg ${list ? "sm:flex" : ""}`}>
      <div className={`relative bg-surface-muted ${list ? "aspect-[16/9] sm:aspect-auto sm:w-56 sm:shrink-0" : "aspect-[4/3]"}`}>
        {cover && <Image src={cover} alt="" fill sizes={list ? "224px" : "(min-width:1024px) 25vw, (min-width:640px) 50vw, 100vw"} className="object-cover" />}
      </div>
      <div className="p-4">
        <h3 className="font-semibold text-secondary">
          <Link href={`/places/${place.slug}`} className="after:absolute after:inset-0 focus-visible:underline">
            {name}
          </Link>
        </h3>
        {desc && <p className="mt-1 line-clamp-2 text-sm text-ink-muted">{desc}</p>}
      </div>
    </article>
  );
}
