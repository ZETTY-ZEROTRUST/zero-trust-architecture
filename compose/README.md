# ZETTY 로컬 Compose (core)

AWS 없이 인증 기반을 기동한다. backend 저장소를 형제 디렉터리로 checkout한 상태를 전제한다.

## 최초 새 환경 기동

```sh
cd compose
./scripts/gen-secrets.sh     # .secrets/env, mysql-init(계정+스키마+시드) 생성
./scripts/gen-tls.sh         # tls/ 로컬 인증서 생성
docker compose --env-file .secrets/env up -d --build --wait
```

- 외부 진입은 `https://127.0.0.1:8443` 하나. DB/Redis/KMS/API 포트는 host에 열지 않는다.
- 서명키는 `kms` 컨테이너에만 있고 `auth`만 kms 네트워크에 연결된다. `kms-init`이 alias를 멱등 생성한다.
- `.secrets/`, `tls/`는 Git에 올리지 않는다(자격증명·키).

## smoke

```sh
curl --cacert tls/ca.crt --output /dev/null --write-out '%{http_code}\n' \
  https://127.0.0.1:8443/.well-known/jwks.json
curl --cacert tls/ca.crt --output /dev/null --write-out '%{http_code}\n' \
  https://127.0.0.1:8443/users/me
# Expected: JWKS 200, protected API without authentication 401
```

측정·부하·시나리오 절차는 `../docs/star/`의 사이클 기록을 따른다.

## observability (부하 측정용)

```sh
docker compose --env-file .secrets/env --profile observability up -d --wait
# Prometheus UI: http://127.0.0.1:9091 (auth·api·cadvisor·mysqld scrape)
```

## API 문서 (Swagger, 로컬 전용)

- api: https://127.0.0.1:8443/swagger-ui.html
- auth: https://127.0.0.1:8443/auth/swagger-ui.html
- bff(브라우저 진입점): https://127.0.0.1:8443/bff/swagger-ui.html
- `SWAGGER_ENABLED`(Compose 기본 true). 운영 배포에서는 false로 둔다.
- 사용법·도입 이유: backend `docs/swagger-guide.md`

## worktree 이동 후 선택 서비스 복구

기존 컨테이너는 생성 당시의 절대 bind 경로를 유지한다. 파일 경로 이동은 현재 Compose로 재생성해야 반영된다.

```sh
python3 scripts/recover-services.py
```

이 helper는 현재 compose 경로의 로컬 TLS와 분석/관측 전용 runtime 파일을 준비하고 nginx·Redis events·relay·indexer·Prometheus·exporter만 재생성한다. 전용 relay/indexer/exporter DB 접속 정보만 일치시키며 기존 core 컨테이너와 데이터 볼륨은 유지한다.

`.secrets/recovery.env`는 exporter 설정만 포함하며 원본 `.secrets/env`의 대체물이 아니다. 원본 환경 파일이 유실된 기존 DB에서는 `gen-secrets.sh`로 새 값을 만들어 core 전체를 재생성하면 DB 비밀번호·vault·HMAC 설정이 어긋날 수 있다. core 전체 재생성 전에 해당 설정을 별도로 맞춰야 한다.

실측 기록: [Z-06](../docs/star/Z-06-compose-bind-path-repair.md).

## Containers and TLS

- [Service roles and flow](../../docs/CURRENT_ARCHITECTURE.md)
- [Certificate, private key and bind path](../../docs/LOCAL_TLS.md)
