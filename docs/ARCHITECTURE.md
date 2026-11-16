# Port Said Hub — Architecture (v0.1)

## Decisions
| Area | Decision | Why |
|---|---|---|
| App | Next.js App Router + TS strict, server components by default | SEO, minimal client JS |
| Data | Supabase Postgres, RLS on every table + least-privilege GRANTs | Two independent layers; a missed policy alone cannot leak data |
| Auth | Supabase Auth (Google OAuth), cookie sessions via `@supabase/ssr` | No tokens in localStorage |
| i18n | Arabic-first (RTL), English second; paired `*_ar` / `*_en` columns | Target users are Arabic speakers; simple admin editing |
| Roles | `user_roles` (`admin`, `editor`); **no client write path** | Roles are granted only by the owner/service process, never via the API |
| Publishing | `draft / scheduled / published / archived` enforced in RLS | Unpublished data can't leak even if app code is wrong |
| Soft delete | `places.deleted_at` (hard delete admin-only) | Recoverable mistakes |
| Audit | Trigger-based, append-only, records actor + old/new values | Can't be skipped by app code |

## Authorization model
- **Public (anon):** reads published rows only (`is_published()` also honours scheduled rows whose time has arrived).
- **User:** own profile (display name / avatar / locale only — column-level grant), own favorites. Suspended users can't write.
- **Editor:** create/update content, upload place images; cannot hard-delete places, change settings, or read audit logs.
- **Admin:** everything above + settings, flags, users (via `admin_set_account_status` RPC), contact inbox, audit logs, branding.
- **Service role:** server-only; contact form inserts, owner-controlled admin provisioning.
- Every server action/route re-verifies the role on the server; RLS is the backstop.

## Hidden admin entry (defence in depth, not security)
1. `ADMIN_PANEL_PATH` (server env) is the only public-facing entry. Middleware rewrites `/<secret>` → an internal route group and signs a short-lived HMAC header.
2. Internal routes 404 without a valid gate header **and** require a valid session **and** a DB-verified admin/editor role.
3. The secret never appears in client bundles, sitemap, robots, metadata or API responses. Admin accounts are provisioned manually (SQL / service role) — no admin sign-up exists.

## Realtime & cache coherence
1. Admin mutation → Server Action validates (Zod) + authorizes → DB write → audit trigger fires.
2. Action calls `revalidateTag()` for affected content (server cache is the source of truth).
3. Clients subscribe (Supabase Realtime `postgres_changes`, RLS-aware) to the few public content tables; on event they debounce and `router.refresh()`.
4. Fallback: if the channel isn't `SUBSCRIBED`, poll on an interval and on tab focus; unsubscribe on unmount; resubscribe on reconnect.
5. Scheduled publishing: time passing emits no DB event, so ISR revalidation (≤60 s) reveals due items; an optional `pg_cron` job can flip status to emit an event.

## Roadmap (status)
1. ✅ Database: schema, RLS, grants, audit, search RPC, storage, defaults — **tested (81 assertions)**
2. ✅ Next.js foundation: strict TS, env validation, Supabase clients, nonce CSP + security headers, session-refresh proxy, signed hidden-admin gate, server authz layer, design tokens, branding from DB, home page — **typecheck, lint, 9 unit tests, build, 20 integration checks pass**
3. ✅ Public site: home, explore (search/filter/sort/grid-list/pagination), place details (gallery, hours, services, offers, directions, related, JSON-LD), categories, offers (feature-flagged), about (DB-editable), contact (validated, honeypot, DB-backed rate limit), AR/EN + RTL/LTR, sitemap, robots, OG/canonical — **65 integration checks pass**
4. ⏳ Auth + account (Google, profile, favorites)
5. ⏳ Admin (gate, dashboard, places, categories, homepage CMS, images, users, audit view)
6. ⏳ Realtime + cache invalidation
7. ⏳ Playwright E2E, CI (GitHub Actions), security review, deployment docs

## Known limitations of current verification
- DB tests run on vanilla PostgreSQL 16 with a **stub** of Supabase's `auth`/`storage` schemas. Re-run the suite against a real Supabase project (e.g. via `supabase start`) before launch.
- Auth (Google/GoTrue) is not covered by local tests: login, callback and role-gated admin pages need a real Supabase project.
- Dependencies: TypeScript pinned to 6.x because typescript-eslint doesn't yet support 7. `npm audit --omit=dev` = 0 vulnerabilities; remaining findings are dev-only lint tooling.
- Realtime publication membership isn't exercised locally (needs `wal_level=logical`).
