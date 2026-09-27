#!/usr/bin/env bash
# 로컬 전용 비밀값을 생성한다. compose/.secrets/(gitignore)에만 저장한다.
# 이미 있는 값은 유지하고 빠진 키만 추가한다(새 서비스가 생겨도 전체 초기화가 필요 없음).
# MySQL init SQL은 매번 현재 env·backend 스키마로 다시 만든다(새 볼륨 초기화 때만 적용됨).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .secrets/mysql-init
touch .secrets/env
chmod 600 .secrets/env
rnd(){ LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24; }
ensure(){ grep -q "^$1=" .secrets/env || echo "$1=$2" >> .secrets/env; }

ensure MYSQL_ROOT_PASSWORD "$(rnd)"
ensure EXPORTER_PASSWORD "$(rnd)"
ensure AUTH_DB_PASSWORD "$(rnd)"
ensure API_DB_PASSWORD "$(rnd)"
ensure BFF_DB_PASSWORD "$(rnd)"
# BFF 토큰 vault 암호화 키(AES-256, base64 32바이트). BFF만 받는다.
ensure BFF_VAULT_KEY "$(openssl rand -base64 32)"
# 보안 이벤트 가명화(HMAC) 키. auth·api producer에만 준다(같은 값). ML·파이프라인에는 주지 않는다.
ensure EVENT_HMAC_KEY "$(openssl rand -base64 32)"
# 이벤트 파이프라인 전용 계정(DB·Redis). 서비스별 최소 권한.
ensure RELAY_DB_PASSWORD "$(rnd)"
ensure INDEXER_DB_PASSWORD "$(rnd)"
ensure OPS_DB_PASSWORD "$(rnd)"
ensure REDIS_EVENTS_ADMIN_PASSWORD "$(rnd)"
ensure REDIS_RELAY_PASSWORD "$(rnd)"
ensure REDIS_INDEXER_PASSWORD "$(rnd)"

. .secrets/env
cat > .secrets/mysql-init/05-accounts.sql <<INNER
CREATE USER IF NOT EXISTS 'auth_app'@'%' IDENTIFIED BY '${AUTH_DB_PASSWORD}';
CREATE USER IF NOT EXISTS 'api_app'@'%'  IDENTIFIED BY '${API_DB_PASSWORD}';
CREATE USER IF NOT EXISTS 'bff_app'@'%'  IDENTIFIED BY '${BFF_DB_PASSWORD}';
CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY '${EXPORTER_PASSWORD}' WITH MAX_USER_CONNECTIONS 3;
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
-- 직무 분리: auth는 인증 테이블(users), api는 업무 테이블만 DML. 서로의 원본을 쓰지 않는다.
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.users TO 'auth_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.refresh_tokens TO 'auth_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.token_ledger TO 'auth_app'@'%';
GRANT SELECT ON zeti_db.token_ledger TO 'api_app'@'%';
GRANT SELECT ON zeti_db.users TO 'api_app'@'%';
-- 프로필 수정(PUT /users/me)용 컬럼 단위 권한. 비밀번호 해시·auth_version·email은 쓰지 못한다.
GRANT UPDATE (name, phone) ON zeti_db.users TO 'api_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.addresses TO 'api_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.orders TO 'api_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.order_items TO 'api_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.payments TO 'api_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.payment_history TO 'api_app'@'%';
-- 보안 이벤트 Outbox: producer는 INSERT만.
GRANT INSERT ON zeti_db.security_event_outbox TO 'auth_app'@'%';
GRANT INSERT ON zeti_db.security_event_outbox TO 'api_app'@'%';
-- 이벤트 파이프라인(log-pipeline pipeline/sql/least-privilege-grants.sql과 동일).
CREATE USER IF NOT EXISTS 'zetty_relay'@'%' IDENTIFIED BY '${RELAY_DB_PASSWORD}';
CREATE USER IF NOT EXISTS 'zetty_indexer'@'%' IDENTIFIED BY '${INDEXER_DB_PASSWORD}';
CREATE USER IF NOT EXISTS 'zetty_pipeline_ops'@'%' IDENTIFIED BY '${OPS_DB_PASSWORD}';
GRANT SELECT ON zeti_db.security_event_outbox TO 'zetty_relay'@'%';
GRANT UPDATE (status, lease_owner, lease_until, attempts, published_at) ON zeti_db.security_event_outbox TO 'zetty_relay'@'%';
GRANT SELECT, INSERT ON zeti_db.security_event_receipt TO 'zetty_indexer'@'%';
GRANT SELECT ON zeti_db.security_event_outbox TO 'zetty_pipeline_ops'@'%';
GRANT UPDATE (status, lease_owner, lease_until) ON zeti_db.security_event_outbox TO 'zetty_pipeline_ops'@'%';
GRANT SELECT ON zeti_db.security_event_receipt TO 'zetty_pipeline_ops'@'%';
-- BFF는 자기 vault 테이블만 읽고 쓴다(업무·인증 테이블 권한 없음).
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.bff_token_vault TO 'bff_app'@'%';
FLUSH PRIVILEGES;
INNER
BACKEND="${BACKEND_PATH:-../../backend}"
{ echo "USE zeti_db;"; cat "$BACKEND/api-server/src/main/resources/schema.sql"; } > .secrets/mysql-init/02-schema.sql
{ echo "USE zeti_db;"; cat "$BACKEND/api-server/src/main/resources/data.sql"; } > .secrets/mysql-init/03-data.sql
if [ -f "$BACKEND/bff-server/src/main/resources/bff-schema.sql" ]; then
  { echo "USE zeti_db;"; cat "$BACKEND/bff-server/src/main/resources/bff-schema.sql"; } > .secrets/mysql-init/04-bff-schema.sql
fi
# 파이프라인 컨테이너는 *_FILE로 비밀번호를 읽는다(환경변수·inspect에 값이 남지 않게).
mkdir -p .secrets/files .secrets/redis-events
for pair in relay_db:RELAY_DB_PASSWORD indexer_db:INDEXER_DB_PASSWORD ops_db:OPS_DB_PASSWORD redis_relay:REDIS_RELAY_PASSWORD redis_indexer:REDIS_INDEXER_PASSWORD; do
  f=${pair%%:*}; v=${pair#*:}; printf '%s' "${!v}" > ".secrets/files/$f"
done
# 컨테이너(uid 10001)가 읽을 수 있어야 한다. .secrets 자체는 gitignore·로컬 전용.
chmod 644 .secrets/files/*
sha(){ printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1; }
# redis-events ACL: 평문 대신 SHA-256만 둔다. default 사용자는 끈다.
cat > .secrets/redis-events/users.acl <<INNER
user default off
user admin on #$(sha "$REDIS_EVENTS_ADMIN_PASSWORD") ~* &* +@all
user healthcheck on nopass -@all +ping
user zetty-relay on #$(sha "$REDIS_RELAY_PASSWORD") resetkeys resetchannels -@all +ping +client|setinfo +xadd ~zetty:security-events
user zetty-indexer on #$(sha "$REDIS_INDEXER_PASSWORD") resetkeys resetchannels -@all +ping +client|setinfo +xreadgroup +xack +xautoclaim +xgroup|create +xpending ~zetty:security-events (+xadd ~zetty:security-events:dlq)
INNER
chmod 644 .secrets/redis-events/users.acl
echo ".secrets/env(빠진 키만 추가), mysql-init, 파이프라인 비밀 파일, redis-events ACL 갱신 완료"
