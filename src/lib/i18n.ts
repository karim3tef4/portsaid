import type { Locale } from "@/lib/types";
export const DEFAULT_LOCALE: Locale = "ar";
export const dirOf = (l: Locale) => (l === "ar" ? "rtl" : "ltr");
/** Pick the localized field, falling back to the other language so nothing renders blank. */
export function pick<T extends Record<string, unknown>>(row: T, field: string, locale: Locale): string {
  const primary = row[`${field}_${locale}`];
  const fallback = row[`${field}_${locale === "ar" ? "en" : "ar"}`];
  return typeof primary === "string" && primary ? primary : typeof fallback === "string" ? fallback : "";
}
