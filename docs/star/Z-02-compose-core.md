# Z-02 Compose core: 네트워크 분리·자원 상한·기동 순서

- 상태: 계획
- 연결: Jira A-01 · 부하 실험 L-1~L-3의 실행 기반
- 작성/갱신: 2026-09-26

## S — 문제 발생

- 통합 실행 파일이 없다. 현재 Compose는 `backend/api-server/compose.yaml`의 MySQL 하나뿐이다.
  - root 비밀번호가 평문(`root`)이다.
  - 3306 포트를 모든 인터페이스에 공개한다.
- 앱·DB·키 저장소가 네트워크로 분리되지 않는다. API가 서명키 저장소에 접근할 수 있는 구조도 막을 수단이 없다.
- 컨테이너 자원 상한이 없다. 부하 시험 수치가 호스트 상태에 따라 달라져 재현할 수 없다.
- 기동 순서를 컨테이너 생성 순서에만 맡긴다. DB 준비 전에 앱이 기동해 실패할 수 있다.

## T — 왜 / 목표

- 한 명령으로 `nginx(HTTPS) → auth/api → mysql/redis/kms`가 기동하는 core profile을 만든다.
- **최소 노출:** 외부 진입은 Nginx HTTPS 하나(127.0.0.1)로 제한한다. DB·Redis·KMS·API 포트는 host에 열지 않는다.
- **네트워크 분리:** `edge` / `application` / `data` / `kms`. 서비스는 필요한 네트워크만 공유한다.
- **재현 가능한 부하 조건:** 모든 서비스에 cpus/memory 상한을 둔다. image는 버전 또는 digest로 고정한다.
- 성공 기준
  - `compose config --quiet`가 통과한다.
  - `up --wait`로 모든 healthcheck가 healthy가 된다.
  - host에서 열린 포트는 127.0.0.1의 Nginx뿐이다.
  - HTTPS 로그인 → API 호출 smoke가 통과한다.

## A — 어떻게

### 계획

- `compose/compose.yaml`
  - core: `nginx`, `auth`, `api`, `mysql`, `redis-session`, `kms`, `kms-init`
  - `observability` profile(Z-03)
- **secret:** MySQL 계정 비밀번호와 TLS 키는 `compose/.secrets/`(gitignore)에 생성 스크립트로 만든다. Compose `secrets`/파일로 주입한다.
- **MySQL 계정 분리:** `auth_app`(users 읽기/쓰기), `api_app`(업무 테이블). root는 초기화에만 쓴다.
- **TLS:** 로컬 CA와 `zetty.localhost` SAN 인증서를 스크립트로 생성한다. Nginx가 443을 종료하고 `127.0.0.1:8443`에만 bind한다.
- **health:** mysql(`mysqladmin ping`), redis(`PING`), kms(ListKeys), 앱(actuator readiness). `depends_on: condition: service_healthy`를 쓴다.
- **backend image:** backend 저장소의 Dockerfile을 build context(`../../backend/...`)로 참조한다. 두 저장소를 형제 디렉터리로 checkout하는 것을 전제한다.

### 검토한 대안과 선택 이유

- **단일 네트워크:** 설정은 쉽다. 하지만 "API는 서명 권한이 없다"는 경계를 인프라로 증명할 수 없어 제외했다.
- **Kubernetes(kind):** 로컬 재현 비용이 크다. 합의 범위가 Compose라서 제외했다.

### 시행착오

(진행 중 추가)

## R — 개선 결과

미측정.

## 자소서 한 줄 (R 확정 후)
