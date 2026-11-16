import Image from "next/image";
import Link from "next/link";
import { mediaUrl } from "@/lib/media";
import type { Branding } from "@/lib/data/site";
import type { Locale } from "@/lib/types";

/** The ONLY place the logo is rendered. Upload a logo to the `branding` bucket and set `branding.logo` to swap it everywhere. */
export function Logo({ branding, locale }: { branding: Branding; locale: Locale }) {
  const name = locale === "ar" ? branding.nameAr : branding.nameEn;
  const src = mediaUrl("branding", branding.logoLightPath);
  return (
    <Link href="/" className="inline-flex items-center gap-2 font-bold text-secondary" aria-label={name}>
      {src ? (
        <Image src={src} alt={name} width={160} height={40} priority className="h-10 w-auto" />
      ) : (
        <span className="text-xl tracking-tight">
          <span className="text-primary">●</span> {name}
        </span>
      )}
    </Link>
  );
}
