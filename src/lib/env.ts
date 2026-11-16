import { z } from "zod";

const publicSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(20),
  NEXT_PUBLIC_SITE_URL: z.url().default("http://localhost:3000"),
});

// Min 16 URL-safe chars so the hidden path can't be guessed. Unset => admin disabled (deny by default).
const adminPathSchema = z.string().regex(/^[A-Za-z0-9_-]{16,64}$/);

export function publicEnv() {
  // Literal property access is required so Next can inline NEXT_PUBLIC_* in the browser bundle.
  return publicSchema.parse({
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    NEXT_PUBLIC_SITE_URL: process.env.NEXT_PUBLIC_SITE_URL,
  });
}

/** Server-only secrets. Never import from client components. */
export function serverEnv() {
  return {
    serviceRoleKey: z.string().min(20).parse(process.env.SUPABASE_SERVICE_ROLE_KEY),
    contactSalt: z.string().min(16).parse(process.env.CONTACT_HASH_SALT),
  };
}

export function adminPanelPath(): string | null {
  const parsed = adminPathSchema.safeParse(process.env.ADMIN_PANEL_PATH);
  return parsed.success ? parsed.data : null;
}

export function adminGateSecret(): string | null {
  const s = process.env.ADMIN_GATE_SECRET;
  return s && s.length >= 32 ? s : null;
}
