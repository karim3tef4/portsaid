import { publicEnv } from "@/lib/env";
/** Public URL for an object in a public storage bucket. Paths come from our DB, never from user input at render time. */
export function mediaUrl(bucket: "place-images" | "branding", path: string | null | undefined): string | null {
  if (!path || path.includes("..") || path.startsWith("/")) return null;
  return `${publicEnv().NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/public/${bucket}/${path.split("/").map(encodeURIComponent).join("/")}`;
}
