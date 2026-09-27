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
echo ".secrets/env(빠진 키만 추가) 및 mysql-init(스키마·시드·계정) 갱신 완료"
