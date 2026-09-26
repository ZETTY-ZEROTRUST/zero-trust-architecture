#!/usr/bin/env bash
# 로컬 전용 임의 비밀번호를 생성한다. compose/.secrets/(gitignore)에만 저장한다.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .secrets
if [ -f .secrets/env ]; then echo ".secrets/env 이미 존재"; exit 0; fi
rnd(){ LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24; }
cat > .secrets/env <<INNER
MYSQL_ROOT_PASSWORD=$(rnd)
EXPORTER_PASSWORD=$(rnd)
AUTH_DB_PASSWORD=$(rnd)
API_DB_PASSWORD=$(rnd)
INNER
mkdir -p .secrets/mysql-init
. .secrets/env
cat > .secrets/mysql-init/05-accounts.sql <<INNER
CREATE USER IF NOT EXISTS 'auth_app'@'%' IDENTIFIED BY '${AUTH_DB_PASSWORD}';
CREATE USER IF NOT EXISTS 'api_app'@'%'  IDENTIFIED BY '${API_DB_PASSWORD}';
CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY '${EXPORTER_PASSWORD}' WITH MAX_USER_CONNECTIONS 3;
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
-- 직무 분리: auth는 인증 테이블(users), api는 업무 테이블만 DML. 서로의 원본을 쓰지 않는다.
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.users TO 'auth_app'@'%';
GRANT SELECT ON zeti_db.users TO 'api_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.addresses TO 'api_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.orders TO 'api_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.order_items TO 'api_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.payments TO 'api_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON zeti_db.payment_history TO 'api_app'@'%';
FLUSH PRIVILEGES;
INNER
BACKEND="${BACKEND_PATH:-../../backend}"
{ echo "USE zeti_db;"; cat "$BACKEND/api-server/src/main/resources/schema.sql"; } > .secrets/mysql-init/02-schema.sql
{ echo "USE zeti_db;"; cat "$BACKEND/api-server/src/main/resources/data.sql"; } > .secrets/mysql-init/03-data.sql
echo ".secrets/env 및 mysql-init(계정+스키마+시드) 생성 완료"
