import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { ADMIN_GATE_HEADER, INTERNAL_ADMIN_PREFIX, signGate } from "@/lib/admin-gate";
import { adminGateSecret, adminPanelPath } from "@/lib/env";

function buildCsp(nonce: string): string {
  const dev = process.env.NODE_ENV !== "production";
  const supabase = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const wss = supabase.replace(/^https:/, "wss:");
  return [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${dev ? " 'unsafe-eval'" : ""}`,
    "style-src 'self' 'unsafe-inline'",
    `img-src 'self' blob: data: ${supabase}`,
    "font-src 'self'",
    `connect-src 'self' ${supabase} ${wss}`,
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
    ...(dev ? [] : ["upgrade-insecure-requests"]),
  ].join("; ");
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const nonce = btoa(crypto.randomUUID());
  const csp = buildCsp(nonce);

  const requestHeaders = new Headers(request.headers);
  requestHeaders.delete(ADMIN_GATE_HEADER); // never trust a client-supplied gate header
  requestHeaders.set("x-nonce", nonce);
  requestHeaders.set("content-security-policy", csp);

  // ── Hidden admin entry ──
  const secretPath = adminPanelPath();
  const secret = adminGateSecret();
  let rewriteTo: URL | null = null;
  if (pathname === INTERNAL_ADMIN_PREFIX || pathname.startsWith(`${INTERNAL_ADMIN_PREFIX}/`)) {
    rewriteTo = new URL("/_not-found", request.url); // internal prefix is not reachable directly
  } else if (secretPath && (pathname === `/${secretPath}` || pathname.startsWith(`/${secretPath}/`))) {
    if (secret) {
      requestHeaders.set(ADMIN_GATE_HEADER, await signGate(secret));
      rewriteTo = new URL(INTERNAL_ADMIN_PREFIX + pathname.slice(secretPath.length + 1), request.url);
      rewriteTo.search = request.nextUrl.search;
    } else {
      rewriteTo = new URL("/_not-found", request.url); // misconfigured => admin disabled
    }
  }

  let response = rewriteTo
    ? NextResponse.rewrite(rewriteTo, { request: { headers: requestHeaders } })
    : NextResponse.next({ request: { headers: requestHeaders } });

  // ── Session refresh (keeps auth cookies fresh for Server Components) ──
  if (process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
    const supabase = createServerClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY, {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll(list) {
          for (const { name, value } of list) request.cookies.set(name, value);
          response = rewriteTo
            ? NextResponse.rewrite(rewriteTo, { request: { headers: requestHeaders } })
            : NextResponse.next({ request: { headers: requestHeaders } });
          for (const { name, value, options } of list) response.cookies.set(name, value, options);
        },
      },
    });
    await supabase.auth.getUser();
  }

  response.headers.set("content-security-policy", csp);
  if (rewriteTo || pathname.startsWith("/login")) response.headers.set("cache-control", "private, no-store");
  return response;
}

export const config = {
  matcher: [{ source: "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)" }],
};
