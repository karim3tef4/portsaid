#!/usr/bin/env bash
# Local integration test: real schema (Postgres) + PostgREST as the Supabase REST layer + the real Next.js server.
# Needs: root (for `su postgres`), PostgreSQL, PGRST_BIN (PostgREST binary), built or buildable app.
set -uo pipefail
cd "$(dirname "$0")/.."
PGRST_BIN=${PGRST_BIN:-/tmp/postgrest}
SECRET="integration-test-secret-0123456789abcdef"
ADMIN_PATH="k9Zq-Tn4_vWx8Lp2Rb7d"
GATE_SECRET="0123456789abcdef0123456789abcdef"
pg() { su postgres -c "psql -v ON_ERROR_STOP=1 -q -X $*"; }
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1 (expected '$3', got '$2')"; fail=$((fail+1)); fi; }

su postgres -c "pg_isready -q" || { service postgresql start >/dev/null 2>&1; sleep 4; }
pg "-c 'drop database if exists psh_dev' -c 'create database psh_dev'" 2>/dev/null
for f in tests/db/00_supabase_stub.sql supabase/migrations/*.sql supabase/seed.sql; do pg "-d psh_dev -f $PWD/$f" 2>&1 | grep -E "ERROR" ; done
pg "-d psh_dev -c \"do \\\$\\\$ begin if not exists (select 1 from pg_roles where rolname='authenticator') then create role authenticator login password 'pw' noinherit; end if; end \\\$\\\$; grant anon, authenticated, service_role to authenticator;\""

b64() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
H=$(printf '{"alg":"HS256","typ":"JWT"}' | b64)
P=$(printf '{"role":"anon","iss":"supabase","exp":4102444800}' | b64)
S=$(printf '%s.%s' "$H" "$P" | openssl dgst -sha256 -hmac "$SECRET" -binary | b64)
ANON="$H.$P.$S"
PS=$(printf '{"role":"service_role","iss":"supabase","exp":4102444800}' | b64)
SS=$(printf '%s.%s' "$H" "$PS" | openssl dgst -sha256 -hmac "$SECRET" -binary | b64)
SERVICE="$H.$PS.$SS"
cat > /tmp/fixtures.sql <<'SQL'
insert into public.places (slug, category_id, governorate_id, name_ar, name_en, description_ar, address_ar, latitude, longitude, phone, website, social_links, status, is_sample)
select 'test-cafe', c.id, g.id, 'مقهى الاختبار', 'Test Cafe', 'وصف </script><b>x</b>', 'شارع الاختبار', 31.265000, 32.301900, '+20 100 000 0000', 'https://example.com',
       '{"facebook":"https://facebook.com/x","instagram":"javascript:alert(1)"}', 'published', true
  from public.categories c, public.governorates g where c.slug = 'cafes' and g.slug = 'port-said';
insert into public.opening_hours (place_id, day_of_week, opens_at, closes_at) select id, 0, '09:00', '23:00' from public.places where slug = 'test-cafe';
insert into public.opening_hours (place_id, day_of_week, is_closed) select id, 5, true from public.places where slug = 'test-cafe';
insert into public.place_services (place_id, name_ar, name_en) select id, 'واي فاي', 'Wi-Fi' from public.places where slug = 'test-cafe';
insert into public.offers (place_id, title_ar, title_en, discount_type, discount_value, status, ends_at)
  select id, 'خصم الاختبار', 'Test offer', 'percentage', 20, 'active', now() + interval '10 days' from public.places where slug = 'test-cafe';
insert into public.offers (place_id, title_ar, discount_type, discount_value, status) select id, 'عرض مسودة', 'percentage', 5, 'draft' from public.places where slug = 'test-cafe';
SQL
pg "-d psh_dev -f /tmp/fixtures.sql"

cat > /tmp/pgrst.conf <<CONF
db-uri = "postgres://authenticator:pw@localhost:5432/psh_dev"
db-schemas = "public"
db-anon-role = "anon"
jwt-secret = "$SECRET"
server-port = 3001
CONF
su postgres -c "psql -q -X -d psh_dev -c \"alter role authenticator password 'pw'\"" >/dev/null
# allow password login over TCP for authenticator
su postgres -c "psql -q -X -tAc \"show hba_file\"" > /tmp/hba_path
HBA=$(cat /tmp/hba_path); grep -q "authenticator" "$HBA" || { sed -i '1i host all authenticator 127.0.0.1/32 md5\nhost all authenticator ::1/128 md5' "$HBA"; su postgres -c "psql -q -X -c 'select pg_reload_conf()'" >/dev/null; }
nohup "$PGRST_BIN" /tmp/pgrst.conf > /tmp/pgrst.log 2>&1 &
PGRST_PID=$!

# Supabase-style /rest/v1 prefix shim -> PostgREST
cat > /tmp/shim.mjs <<'JS'
import http from "node:http";
http.createServer((req, res) => {
  if (!req.url.startsWith("/rest/v1/")) { res.writeHead(404).end(); return; }
  const up = http.request({ host: "127.0.0.1", port: 3001, path: req.url.slice(8), method: req.method, headers: req.headers },
    (r) => { res.writeHead(r.statusCode, r.headers); r.pipe(res); });
  up.on("error", () => res.writeHead(502).end()); req.pipe(up);
}).listen(54321);
JS
nohup node /tmp/shim.mjs > /tmp/shim.log 2>&1 &
SHIM_PID=$!
sleep 3

export NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321 NEXT_PUBLIC_SUPABASE_ANON_KEY="$ANON" NEXT_PUBLIC_SITE_URL=http://localhost:3100
export ADMIN_PANEL_PATH=$ADMIN_PATH ADMIN_GATE_SECRET=$GATE_SECRET SUPABASE_SERVICE_ROLE_KEY="$SERVICE" CONTACT_HASH_SALT=integration-salt-0123456789
npx next build >/tmp/build.log 2>&1 || { echo "BUILD FAILED"; tail -20 /tmp/build.log; }
nohup npx next start -p 3100 > /tmp/next.log 2>&1 &
NEXT_PID=$!
for i in $(seq 1 30); do curl -s -o /dev/null http://localhost:3100/ && break; sleep 1; done

echo "REST layer (anon, through RLS):"
check "anon sees 3 published places" "$(curl -s "http://127.0.0.1:54321/rest/v1/places?select=slug" -H "apikey: $ANON" -H "Authorization: Bearer $ANON" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')" "3"
check "anon cannot read profiles (permission denied)" "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:54321/rest/v1/profiles?select=id" -H "Authorization: Bearer $ANON")" "401"
check "anon cannot insert places" "$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:54321/rest/v1/places" -H "Authorization: Bearer $ANON" -H 'Content-Type: application/json' -d '{"slug":"x"}')" "401"
check "search RPC works" "$(curl -s -X POST "http://127.0.0.1:54321/rest/v1/rpc/search_places" -H "Authorization: Bearer $ANON" -H 'Content-Type: application/json' -d '{"q":"Lighthouse"}' | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')" "1"

echo "Next.js app:"
HOME_HTML=$(curl -s -D /tmp/home.hdr http://localhost:3100/)
check "home page 200" "$(head -1 /tmp/home.hdr | awk '{print $2}')" "200"
check "home has RTL + ar" "$(echo "$HOME_HTML" | grep -c 'lang="ar" dir="rtl"')" "1"
check "home renders seeded featured place" "$(echo "$HOME_HTML" | grep -c 'فنار بورسعيد')" "1"
check "home renders categories from DB" "$(echo "$HOME_HTML" | grep -c 'مطاعم')" "1"
check "draft place NOT on public page" "$(echo "$HOME_HTML" | grep -c 'مسودة')" "0"
check "CSP header present with nonce" "$(grep -i '^content-security-policy' /tmp/home.hdr | grep -c "nonce-")" "1"
check "frame-ancestors none" "$(grep -i '^content-security-policy' /tmp/home.hdr | grep -c "frame-ancestors 'none'")" "1"
check "HSTS header" "$(grep -ic '^strict-transport-security' /tmp/home.hdr)" "1"
check "no x-powered-by" "$(grep -ic '^x-powered-by' /tmp/home.hdr)" "0"
check "admin path NOT in page HTML" "$(echo "$HOME_HTML" | grep -c "$ADMIN_PATH")" "0"


echo "Public pages:"
get() { curl -s -o /tmp/body.html -w '%{http_code}' "$1"; }
code=$(get "http://localhost:3100/explore"); check "/explore 200" "$code" "200"
check "explore lists published places" "$(grep -c 'فنار بورسعيد' /tmp/body.html)" "1"
check "explore hides draft" "$(grep -c 'مسودة' /tmp/body.html)" "0"
get "http://localhost:3100/explore?q=Lighthouse" >/dev/null; check "search finds by name" "$(grep -c 'فنار بورسعيد' /tmp/body.html)" "1"
check "search excludes non-matches" "$(grep -c 'مقهى الاختبار' /tmp/body.html)" "0"
get "http://localhost:3100/explore?q=%25" >/dev/null; check "wildcard search returns nothing" "$(grep -c 'لا توجد نتائج' /tmp/body.html)" "1"
get "http://localhost:3100/explore?category=cafes" >/dev/null; check "category filter works" "$(grep -c 'مقهى الاختبار' /tmp/body.html)" "1"
check "garbage params degrade (200)" "$(get 'http://localhost:3100/explore?page=-5&sort=evil&view=x&category=../../etc')" "200"
check "huge page number is safe (200)" "$(get 'http://localhost:3100/explore?page=999999999')" "200"
check "XSS in q is escaped" "$(curl -s 'http://localhost:3100/explore?q=%22%3E%3Cscript%3Ealert(1)%3C/script%3E' | grep -c '<script>alert(1)')" "0"

code=$(get "http://localhost:3100/places/test-cafe"); check "place page 200" "$code" "200"
check "place shows Google Maps directions" "$(grep -c 'google.com/maps/dir/?api=1&amp;destination=31.265,32.3019' /tmp/body.html)" "1"
check "place shows opening hours" "$(grep -c '09:00' /tmp/body.html)" "1"
check "place shows closed day" "$(grep -c 'مغلق' /tmp/body.html)" "1"
check "place shows service" "$(grep -c 'واي فاي' /tmp/body.html)" "1"
check "place shows active offer" "$(grep -c 'خصم الاختبار' /tmp/body.html)" "1"
check "place hides draft offer" "$(grep -c 'عرض مسودة' /tmp/body.html)" "0"
check "https social link rendered" "$(grep -c 'facebook.com/x' /tmp/body.html)" "1"
check "javascript: social link dropped" "$(grep -c 'javascript:' /tmp/body.html)" "0"
check "JSON-LD present" "$(grep -c 'application/ld+json' /tmp/body.html)" "1"
check "JSON-LD cannot break out of script tag" "$(grep -o '</script><b>' /tmp/body.html | wc -l | tr -d ' ')" "0"
check "Open Graph tags" "$(grep -c 'og:title' /tmp/body.html)" "1"
check "draft place is 404" "$(get http://localhost:3100/places/sample-draft-place)" "404"
check "unknown place is 404" "$(get http://localhost:3100/places/nope)" "404"
check "malformed slug is 404" "$(get 'http://localhost:3100/places/%27%3Bdrop')" "404"
code=$(get "http://localhost:3100/categories"); check "/categories 200" "$code" "200"
get "http://localhost:3100/offers" >/dev/null; check "/offers shows active offer" "$(grep -c 'خصم الاختبار' /tmp/body.html)" "1"
check "/offers hides draft offer" "$(grep -c 'عرض مسودة' /tmp/body.html)" "0"
pg "-d psh_dev -c \"update feature_flags set enabled=false where key='offers_page'\"" ; check "/offers is 404 when flag off" "$(get http://localhost:3100/offers)" "404"
pg "-d psh_dev -c \"update feature_flags set enabled=true where key='offers_page'\""
get "http://localhost:3100/about" >/dev/null; check "/about renders DB content" "$(grep -c 'رؤيتنا' /tmp/body.html)" "1"
check "English via cookie" "$(curl -s -b 'psh_locale=en' http://localhost:3100/ | grep -c 'lang="en" dir="ltr"')" "1"
check "invalid locale cookie falls back to ar" "$(curl -s -b 'psh_locale=zz' http://localhost:3100/ | grep -c 'lang="ar" dir="rtl"')" "1"
check "nav links present" "$(curl -s http://localhost:3100/ | grep -c 'href="/explore"')" "1"
SM=$(curl -s http://localhost:3100/sitemap.xml)
check "sitemap lists published place" "$(echo "$SM" | grep -c 'places/test-cafe')" "1"
check "sitemap excludes draft" "$(echo "$SM" | grep -c 'sample-draft-place')" "0"
check "sitemap hides admin path" "$(echo "$SM" | grep -c "$ADMIN_PATH")" "0"
check "robots hides admin path" "$(curl -s http://localhost:3100/robots.txt | grep -c "$ADMIN_PATH")" "0"

echo "Contact form (server action):"
cat > /tmp/extract.py <<'PYEOF'
import re,html
h=open('/tmp/contact.html').read()
for m in re.finditer(r'<input[^>]*type="hidden"[^>]*>',h):
    tag=m.group(0); n=re.search(r'name="([^"]+)"',tag); v=re.search(r'value="([^"]*)"',tag)
    if n and n.group(1).startswith('$ACTION'): print(html.unescape(n.group(1))+'\t'+html.unescape(v.group(1) if v else ''))
PYEOF
submit() { # name email message company ip
  curl -s -c /tmp/cj -b /tmp/cj http://localhost:3100/contact > /tmp/contact.html
  python3 /tmp/extract.py > /tmp/fields
  args=(); while IFS=$'\t' read -r n v; do args+=(-F "$n=$v"); done < /tmp/fields
  curl -s -X POST http://localhost:3100/contact -H "Origin: http://localhost:3100" -H "X-Forwarded-For: ${5:-9.9.9.9}" "${args[@]}" -F "name=$1" -F "email=$2" -F "message=$3" -F "company=${4:-}"
}
dbq() { su postgres -c "psql -d psh_dev -tAc \"$1\""; }
check "valid message accepted" "$(submit 'Tester' 'a@b.co' 'hello there friend' | grep -c 'تم استلام رسالتك')" "1"
check "message stored in DB" "$(dbq "select count(*) from contact_messages where email='a@b.co'")" "1"
check "IP stored only as 64-char hash" "$(dbq "select char_length(ip_hash) from contact_messages where email='a@b.co'")" "64"
check "invalid email rejected" "$(submit 'T' 'not-an-email' 'hello there friend' | grep -c 'تحقق من الحقول')" "1"
submit 'Bot' 'bot@b.co' 'spam spam spam' 'ACME' >/dev/null
check "honeypot silently dropped" "$(dbq "select count(*) from contact_messages where email='bot@b.co'")" "0"
for i in 1 2 3 4; do submit 'Flood' "f$i@b.co" 'flooding the form' '' 8.8.8.8 >/dev/null; done
check "5th message from same IP accepted" "$(submit 'Flood' 'f5@b.co' 'flooding the form' '' 8.8.8.8 | grep -c 'تم استلام رسالتك')" "1"
check "6th message from same IP rate-limited" "$(submit 'Flood' 'f6@b.co' 'flooding the form' '' 8.8.8.8 | grep -c 'عددًا كبيرًا')" "1"
check "other IP still accepted" "$(submit 'Other' 'o@b.co' 'hello from elsewhere' '' 7.7.7.7 | grep -c 'تم استلام رسالتك')" "1"

echo "Hidden admin gate:"
check "/admin is 404" "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3100/admin)" "404"
check "/studio-internal direct is 404" "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3100/studio-internal)" "404"
check "forged gate header on /studio-internal is 404" "$(curl -s -o /dev/null -w '%{http_code}' -H 'x-psh-admin-gate: 1700000000000.deadbeef' http://localhost:3100/studio-internal)" "404"
check "forged gate header via secret path doesn't bypass login" "$(curl -s -o /dev/null -w '%{http_code}' -H 'x-psh-admin-gate: 1.2' http://localhost:3100/$ADMIN_PATH)" "307"
check "secret path without session redirects to /login" "$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' http://localhost:3100/$ADMIN_PATH)" "307 http://localhost:3100/login"
check "wrong secret path is 404" "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3100/$ADMIN_PATH-nope)" "404"

kill $NEXT_PID $SHIM_PID $PGRST_PID 2>/dev/null; pkill -f "next start" 2>/dev/null; pkill -f "next-server" 2>/dev/null
echo; echo "passed=$pass failed=$fail"; [ "$fail" = 0 ]
