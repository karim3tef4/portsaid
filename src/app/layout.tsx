import type { Metadata } from "next";
import type { CSSProperties, ReactNode } from "react";
import { getBranding } from "@/lib/data/site";
import { dirOf } from "@/lib/i18n";
import { getLocale } from "@/lib/locale";
import { SiteFooter, SiteHeader } from "@/components/site-header";
import "./globals.css";

export const dynamic = "force-dynamic"; // TODO(stage 6): move to tag-based caching + realtime invalidation

export async function generateMetadata(): Promise<Metadata> {
  const b = await getBranding();
  return {
    title: { default: `${b.nameAr} | ${b.nameEn}`, template: `%s | ${b.nameAr}` },
    description: b.taglineAr || b.taglineEn,
    metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"),
  };
}

export default async function RootLayout({ children }: { children: ReactNode }) {
  const locale = await getLocale();
  const branding = await getBranding();
  const vars: Record<string, string> = {};
  if (branding.colors.primary) vars["--color-primary"] = branding.colors.primary;
  if (branding.colors.secondary) vars["--color-secondary"] = branding.colors.secondary;
  if (branding.colors.accent) vars["--color-accent"] = branding.colors.accent;
  return (
    <html lang={locale} dir={dirOf(locale)} style={vars as CSSProperties}>
      <body className="min-h-dvh antialiased">
        <SiteHeader branding={branding} locale={locale} />
        <main>{children}</main>
        <SiteFooter branding={branding} locale={locale} />
      </body>
    </html>
  );
}
