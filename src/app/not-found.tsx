import Link from "next/link";
import { getLocale } from "@/lib/locale";
import { t } from "@/lib/messages";

export default async function NotFound() {
  const m = t(await getLocale());
  return (
    <div className="mx-auto max-w-xl px-4 py-24 text-center">
      <h1 className="text-3xl font-bold text-secondary">404 — {m.errors.notFound}</h1>
      <p className="mt-3 text-ink-muted">{m.errors.notFoundBody}</p>
      <Link href="/" className="mt-6 inline-block rounded-card bg-primary px-5 py-2.5 font-medium text-white">{m.errors.back}</Link>
    </div>
  );
}
