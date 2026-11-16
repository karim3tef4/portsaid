import "server-only";
import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { ADMIN_GATE_HEADER, verifyGate } from "@/lib/admin-gate";
import { adminGateSecret } from "@/lib/env";

export type StaffRole = "admin" | "editor";
export interface AuthedStaff { userId: string; email: string | null; role: StaffRole }

/** Validated user from Supabase Auth (getUser() verifies the JWT server-side; getSession() would not). */
export async function getCurrentUser() {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getUser();
  return error || !data.user ? null : data.user;
}

/** Role is read from the database under RLS — never from the browser or JWT claims we don't control. */
export async function getStaffRole(userId: string): Promise<StaffRole | null> {
  const supabase = await createClient();
  const { data } = await supabase.from("user_roles").select("role").eq("user_id", userId).maybeSingle();
  return data?.role === "admin" || data?.role === "editor" ? data.role : null;
}

async function assertGate() {
  const secret = adminGateSecret();
  const ok = secret ? await verifyGate(secret, (await headers()).get(ADMIN_GATE_HEADER)) : false;
  if (!ok) notFound(); // indistinguishable from a non-existent page
}

/** Deny-by-default guard for admin pages: gate header + valid session + DB-verified role. */
export async function requireStaff(minimum: StaffRole = "editor"): Promise<AuthedStaff> {
  await assertGate();
  const user = await getCurrentUser();
  if (!user) redirect("/login");
  const role = await getStaffRole(user.id);
  if (!role || (minimum === "admin" && role !== "admin")) notFound();
  return { userId: user.id, email: user.email ?? null, role };
}

/** For Server Actions / route handlers: throws instead of redirecting. Call at the top of EVERY mutation. */
export class AuthzError extends Error {
  constructor(readonly status: 401 | 403) { super(status === 401 ? "Unauthenticated" : "Forbidden"); }
}
export async function assertStaff(minimum: StaffRole = "editor"): Promise<AuthedStaff> {
  const user = await getCurrentUser();
  if (!user) throw new AuthzError(401);
  const role = await getStaffRole(user.id);
  if (!role || (minimum === "admin" && role !== "admin")) throw new AuthzError(403);
  return { userId: user.id, email: user.email ?? null, role };
}
