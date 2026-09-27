# ZETTY 로컬 Compose (core)

AWS 없이 인증 기반을 기동한다. backend 저장소를 형제 디렉터리로 checkout한 상태를 전제한다.

## 기동

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
B=https://127.0.0.1:8443
curl -sk -X POST $B/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"...","password":"..."}'   # accessToken(RS256)
curl -sk $B/users/me -H "Authorization: Bearer <token>"
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
- `SWAGGER_ENABLED`(Compose 기본 true). 운영 배포에서는 false로 둔다.
