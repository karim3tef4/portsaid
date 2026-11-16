# Port Said Hub
Local discovery platform for Port Said (multi-governorate ready). See `docs/ARCHITECTURE.md`.

## Database
```
supabase/migrations/   0001 schema · 0002 triggers, RLS, RPCs, realtime · 0003 storage + defaults
supabase/seed.sql      DEV ONLY sample content (flagged is_sample)
tests/db/              RLS/privilege/integrity suite
scripts/test-db.sh     applies everything to a throwaway Postgres and runs the suite
```
Run: `./scripts/test-db.sh` (needs a local PostgreSQL; creates database `psh_test`).

## Granting the first admin (owner-controlled; no public admin sign-up)
Sign in once with Google, then in the Supabase SQL editor:
```sql
insert into public.user_roles (user_id, role)
select id, 'admin' from auth.users where email = 'YOU@example.com';
```

## Local verification
```
npm run typecheck && npm run lint && npm test      # types, lint, unit tests
npm run test:db                                      # 81 RLS/privilege/integrity assertions
PGRST_BIN=/path/to/postgrest npm run test:integration  # app + schema via PostgREST (65 checks)
```
Admin path: set `ADMIN_PANEL_PATH` (16+ URL-safe chars) and `ADMIN_GATE_SECRET` (32+ chars). Unset = admin disabled.
