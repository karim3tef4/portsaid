"use server";
import { headers } from "next/headers";
import { z } from "zod";
import { createServiceClient } from "@/lib/supabase/admin";
import { serverEnv } from "@/lib/env";

export type ContactState = { status: "idle" | "success" | "error" | "rate" | "invalid"; fieldErrors?: Partial<Record<"name" | "email" | "subject" | "message", true>> };

const schema = z.object({
  name: z.string().trim().min(1).max(120),
  email: z.email().max(254),
  subject: z.string().trim().max(200).optional(),
  message: z.string().trim().min(5).max(5000),
});
const MAX_PER_HOUR = 5;

async function hashIp(ip: string, salt: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${salt}:${ip}`));
  return Array.from(new Uint8Array(buf), (b) => b.toString(16).padStart(2, "0")).join("");
}

export async function submitContact(_prev: ContactState, formData: FormData): Promise<ContactState> {
  // Honeypot: bots fill hidden fields. Pretend success so they don't adapt.
  if (formData.get("company")) return { status: "success" };

  const parsed = schema.safeParse({
    name: formData.get("name"), email: formData.get("email"),
    subject: formData.get("subject") || undefined, message: formData.get("message"),
  });
  if (!parsed.success) {
    const fieldErrors: NonNullable<ContactState["fieldErrors"]> = {};
    for (const i of parsed.error.issues) { const k = i.path[0]; if (k === "name" || k === "email" || k === "subject" || k === "message") fieldErrors[k] = true; }
    return { status: "invalid", fieldErrors };
  }

  try {
    const { contactSalt } = serverEnv();
    const h = await headers();
    const ip = (h.get("x-forwarded-for")?.split(",")[0] ?? h.get("x-real-ip") ?? "unknown").trim();
    const ipHash = await hashIp(ip, contactSalt);
    const db = createServiceClient();

    const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const { count, error: countErr } = await db.from("contact_messages").select("id", { count: "exact", head: true }).eq("ip_hash", ipHash).gte("created_at", since);
    if (countErr) throw countErr;
    if ((count ?? 0) >= MAX_PER_HOUR) return { status: "rate" };

    const { error } = await db.from("contact_messages").insert({ ...parsed.data, ip_hash: ipHash });
    if (error) throw error;
    return { status: "success" };
  } catch (e) {
    console.error("contact form failed", e instanceof Error ? e.message : e); // details stay server-side
    return { status: "error" };
  }
}
