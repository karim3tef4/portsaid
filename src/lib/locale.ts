import { cookies } from "next/headers";
import { DEFAULT_LOCALE } from "@/lib/i18n";
import type { Locale } from "@/lib/types";

export const LOCALE_COOKIE = "psh_locale";
export async function getLocale(): Promise<Locale> {
  const v = (await cookies()).get(LOCALE_COOKIE)?.value;
  return v === "en" || v === "ar" ? v : DEFAULT_LOCALE;
}
