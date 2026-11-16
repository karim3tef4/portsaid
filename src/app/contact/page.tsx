import type { Metadata } from "next";
import { getLocale } from "@/lib/locale";
import { getSetting } from "@/lib/data/places";
import { t } from "@/lib/messages";
import { safeSocialLinks } from "@/lib/safe";
import { ContactForm } from "./contact-form";

export async function generateMetadata(): Promise<Metadata> {
  return { title: t(await getLocale()).contact.title, alternates: { canonical: "/contact" } };
}

export default async function ContactPage() {
  const locale = await getLocale();
  const m = t(locale);
  const social = safeSocialLinks((await getSetting<Record<string, unknown>>("contact.social")) ?? {});
  return (
    <div className="mx-auto max-w-2xl px-4 py-10">
      <h1 className="text-3xl font-bold text-secondary">{m.contact.title}</h1>
      <p className="mt-2 text-ink-muted">{m.contact.intro}</p>
      <ContactForm labels={m.contact} />
      {social.length > 0 && (
        <ul className="mt-8 flex flex-wrap gap-2">{social.map((s) => <li key={s.key}><a href={s.url} rel="noopener noreferrer nofollow" target="_blank" className="rounded-full border border-line px-3 py-1 text-sm capitalize">{s.key}</a></li>)}</ul>
      )}
    </div>
  );
}
