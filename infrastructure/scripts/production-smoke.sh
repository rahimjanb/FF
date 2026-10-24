#!/bin/zsh
# Isolated Production-mode check: throwaway Postgres container (no named volume), release build, random one-off secrets.
# Never prints secrets. Does not touch the developer database or any server.
set -u
S=${1:?usage: production-smoke.sh <work-dir> (API published to <work-dir>/publish)}; export PATH=/usr/local/share/dotnet:$PATH
PGPW=$(openssl rand -hex 24); JWT=$(openssl rand -base64 48); ADMINPW="Boot$(openssl rand -hex 6)9"
docker run -d --rm --name ff-acceptance-pg -e POSTGRES_PASSWORD=$PGPW -e POSTGRES_DB=ff -p 127.0.0.1:55432:5432 postgres:17-alpine >/dev/null
for i in {1..30}; do docker exec ff-acceptance-pg pg_isready -U postgres -d ff >/dev/null 2>&1 && break; sleep 1; done; sleep 2
CS="Host=127.0.0.1;Port=55432;Database=ff;Username=postgres;Password=$PGPW"
API=http://127.0.0.1:5091
run_api() { ASPNETCORE_ENVIRONMENT=Production ASPNETCORE_URLS=$API ConnectionStrings__Default=$CS Database__MigrateOnStartup=true \
  Bootstrap__AdminPhone=+998901110000 Bootstrap__AdminPassword=$ADMINPW "$@" dotnet $S/publish/FitnessFormulasi.Api.dll > $S/prod-api.log 2>&1 & }
code() { curl -s -o /dev/null -w "%{http_code}" "$@"; }
login() { curl -s -H 'Content-Type: application/json' -d "{\"phone\":\"$1\",\"password\":\"$2\"}" $API/api/auth/login; }

echo "== 1. Start without JWT signing key"
run_api; P=$!; sleep 6
if kill -0 $P 2>/dev/null; then echo "FAIL: API started without a key"; kill $P; else echo "OK: refused to start ($(grep -m1 -o 'SigningKey[^.]*' $S/prod-api.log))"; fi

echo "== 2. Start with key"
run_api env Jwt__SigningKey=$JWT; P=$!
for i in {1..40}; do [ "$(code $API/health)" = 200 ] && break; sleep 1; done
echo "health: $(code $API/health)"
echo "migrations applied: $(docker exec ff-acceptance-pg psql -U postgres -d ff -tAc "select string_agg(\"MigrationId\", ', ' order by 1) from \"__EFMigrationsHistory\"")"
echo "users after start: $(docker exec ff-acceptance-pg psql -U postgres -d ff -tAc "select count(*) from \"Users\"") (expected 1: bootstrap admin only)"
echo "dev accounts +9980000000xx in DB: $(docker exec ff-acceptance-pg psql -U postgres -d ff -tAc "select count(*) from \"Users\" where \"Phone\" like '+99800000000%'")"
echo "swagger: $(code $API/swagger/index.html) (expected 404)"
echo "login 1/1: $(login 1 1 | grep -o '"code":"[a-z_]*"') (expected validation_failed)"
echo "login dev phone/1: $(login +998000000001 1 | grep -o '"code":"[a-z_]*"') (expected invalid_credentials)"
echo "sms verification: $(code -X POST $API/api/auth/phone-verification/request) (expected 401 anonymous)"
B=$(login +998901110000 $ADMINPW); TOK=$(print -r -- $B | python3 -c 'import sys,json;print(json.load(sys.stdin)["accessToken"])')
echo "bootstrap admin mustChangePassword: $(print -r -- $B | python3 -c 'import sys,json;print(json.load(sys.stdin)["user"]["mustChangePassword"])')"
echo "admin API before password change: $(code -H "Authorization: Bearer $TOK" $API/api/admin/dashboard) (expected 403)"
echo "SMS request as signed-in user: $(code -X POST -H "Authorization: Bearer $TOK" $API/api/auth/phone-verification/request) (expected 403 gate or 503 no provider)"
echo "HSTS header: $(curl -s -D - -o /dev/null $API/health | grep -ci strict-transport) (0 over plain HTTP is expected; HSTS is sent over HTTPS)"
echo "secrets in log: $(grep -c -e "$PGPW" -e "$ADMINPW" $S/prod-api.log) (expected 0)"
kill $P; wait $P 2>/dev/null

echo "== 3. Backup and restore"
docker exec ff-acceptance-pg pg_dump -U postgres -d ff -Fc -f /tmp/ff.dump && echo "dump size: $(docker exec ff-acceptance-pg stat -c %s /tmp/ff.dump) bytes"
docker exec ff-acceptance-pg createdb -U postgres ff_restore
docker exec ff-acceptance-pg pg_restore -U postgres -d ff_restore --no-owner /tmp/ff.dump && echo "restore: ok"
for t in Users Roles __EFMigrationsHistory; do
  a=$(docker exec ff-acceptance-pg psql -U postgres -d ff -tAc "select count(*) from \"$t\""); b=$(docker exec ff-acceptance-pg psql -U postgres -d ff_restore -tAc "select count(*) from \"$t\"")
  echo "  $t: original=$a restored=$b"
done
docker stop ff-acceptance-pg >/dev/null && echo "temporary container removed"
