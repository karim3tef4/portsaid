import type { ReactNode } from "react";
import { requireStaff } from "@/lib/auth/authorize";

export const metadata = { robots: { index: false, follow: false } };

// Every admin page is wrapped by this guard: gate header + valid session + DB-verified role. Deny by default.
export default async function AdminLayout({ children }: { children: ReactNode }) {
  const staff = await requireStaff("editor");
  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      <p className="text-sm text-ink-muted">{staff.email} · {staff.role}</p>
      {children}
    </div>
  );
}
