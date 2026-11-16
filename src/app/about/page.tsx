import type { Metadata } from "next";
import { getSetting } from "@/lib/data/places";
import { getLocale } from "@/lib/locale";
import { t } from "@/lib/messages";
import type { Locale } from "@/lib/types";

type AboutContent = Record<Locale, { title: string; vision: string; mission: string; why: string; future: string }>;
const headings = {
  ar: { vision: "رؤيتنا", mission: "رسالتنا", why: "لماذا بورسعيد هاب؟", future: "نحو المستقبل" },
  en: { vision: "Our vision", mission: "Our mission", why: "Why Port Said Hub?", future: "Looking ahead" },
} as const;

export async function generateMetadata(): Promise<Metadata> {
  const c = await getSetting<AboutContent>("page.about");
  return { title: c?.[await getLocale()]?.title ?? t(await getLocale()).nav.about, alternates: { canonical: "/about" } };
}

export default async function AboutPage() {
  const locale = await getLocale();
  const content = (await getSetting<AboutContent>("page.about"))?.[locale]; // editable from the dashboard
  if (!content) return <div className="mx-auto max-w-3xl px-4 py-10"><h1 className="text-3xl font-bold text-secondary">{t(locale).nav.about}</h1></div>;
  return (
    <div className="mx-auto max-w-3xl px-4 py-10">
      <h1 className="text-3xl font-bold text-secondary">{content.title}</h1>
      {(["vision", "mission", "why", "future"] as const).map((k) => content[k] && (
        <section key={k} className="mt-8"><h2 className="text-xl font-bold text-primary">{headings[locale][k]}</h2><p className="mt-2 leading-8">{content[k]}</p></section>
      ))}
    </div>
  );
}
