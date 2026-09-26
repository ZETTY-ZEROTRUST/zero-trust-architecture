# Z-01 로컬 KMS 에뮬레이터로 AWS 의존 제거

- 상태: 계획
- 연결: Jira A-01 · 부하 실험 L-5 · backend `docs/star/B-01`
- 작성/갱신: 2026-09-26

## S — 문제 발생

- API 서버는 기동 시 `@PostConstruct`에서 **실제 AWS KMS**의 공개키를 조회한다(backend `api-server/.../KmsPublicKeyProvider.java:31-38`). AWS 자격증명과 네트워크가 없으면 서버가 뜨지 않는다.
- Auth 서버는 로그인마다 `kmsClient.sign()`으로 AWS에 서명을 요청한다(backend `auth-server/.../KmsJwtSigner.java:38`). 리전(`ap-northeast-2`)도 코드에 고정돼 있다(`JwtConfig`).
- 리스크
  - 팀원과 다른 에이전트가 AWS 계정 없이는 통합 시험을 할 수 없다.
  - 부하 시험이 실제 클라우드 할당량과 과금에 묶여 수치를 재현할 수 없다.
  - 공격 시나리오를 실제 클라우드 키로 돌리게 될 위험이 있다.

## T — 왜 / 목표

- **AWS 접속 없이** `docker compose up`만으로 Auth가 RS256 서명을 하고 API가 검증하는 상태를 만든다.
- KMS 구조(키는 앱 밖에 있고 서명 API만 노출)는 유지한다. 운영과 같은 보안 모델을 로컬에서 시험하기 위해서다.
- 성공 기준
  - AWS 자격증명 mount와 환경변수 없이 core profile의 `up --wait`가 성공한다.
  - KMS 컨테이너 네트워크에 붙은 앱은 Auth 하나뿐이다.
  - RS256 토큰 발급 → API 검증 smoke가 통과한다.

## A — 어떻게

### 계획

1. **gate:** `local-kms`에서 RSA_2048 키를 만들고 `Sign`(RSASSA_PKCS1_V1_5_SHA_256) 결과를 독립 도구로 검증한다. 통과해야 다음으로 진행한다.
2. `kms` 서비스: image digest 고정, `/data` volume으로 키를 영속화한다. 키는 Git에 두지 않고 일회성 `kms-init`이 없을 때만 생성한다(멱등).
3. 전용 `kms` 네트워크에는 `auth`와 `kms-init`만 연결한다. host port는 공개하지 않는다.
4. Auth에는 endpoint override와 에뮬레이터 전용 더미 자격증명만 주입한다. `~/.aws`는 mount하지 않는다.
5. API는 KMS가 아니라 Auth의 JWKS에서 공개키를 받는다.

### 검토한 대안과 선택 이유

| 대안 | 판단 |
|---|---|
| 파일 RSA 키를 Auth에 mount | 가장 단순하다. 하지만 개인키가 앱 파일·메모리에 존재해 KMS 운영 모델과 달라진다. lab·부하 비교용으로만 남긴다 |
| `local-kms` | 경량이고 JSON API가 AWS와 같다. **선택** |
| LocalStack KMS | 범위가 넓지만 무겁다. gate 실패 시 대안 |
| 실제 AWS KMS | 재현성·비용·공격 시험 안전성 문제로 제외 |

에뮬레이터는 IAM/key policy를 실제로 강제하지 않는다. 그래서 **서명 권한 경계는 네트워크 분리로 구현**하고, 이 한계를 README에 명시한다.

### 시행착오

- 2026-09-26 gate 결과
  - `nsmithuk/local-kms:3` (arm64, digest `sha256:360d7377…`)에서 `CreateKey`(RSA_2048, SIGN_VERIFY)가 성공했다.
  - `Sign` 결과 서명(RSASSA_PKCS1_V1_5_SHA_256)을 `GetPublicKey`의 DER 공개키로 `openssl dgst -sha256 -verify` 검증했다 → `Verified OK`.
  - 컨테이너를 재시작한 뒤에도 키 목록이 유지됐다.
  - 결론: LocalStack 대안은 불필요하다.

## R — 개선 결과

미측정. 측정 예정 항목:

| 지표 | 전 | 후 | 조건 |
|---|---|---|---|
| AWS 없이 core 기동 | 불가 | ? | 새 volume, `up --wait` |
| 기동~ready 시간 | — | ? | 3회 중앙값 |
| KMS 네트워크 접근 가능 앱 수 | — | 1 목표 | `docker network inspect` |

## 자소서 한 줄 (R 확정 후)
