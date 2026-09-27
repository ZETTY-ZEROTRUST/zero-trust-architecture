# Z-04 수평 확장과 로드 밸런싱(nginx) · 로그인 과부하 제한

- 상태: 진행(동적 LB·관측 완료, 요청 제한 재측정 대기)
- 연결: 부하 L-05(로그인 병목) · attack-simulation `docs/star/L-05-login-bottleneck.md`
- 작성/갱신: 2026-09-27 — **작업 도중 작성**(사용자 질문 "서버 두 대면 LB가 있어야 하지 않나"를 계기로 바로 착수해 착수 전 문서 규칙을 지키지 못했다)

## S — 문제

- L-05에서 로그인 한계가 auth 1대당 약 24 TPS(BCrypt CPU)로 확인돼 auth를 2대로 늘렸다(→ 약 47 TPS).
- 그런데 분산 구성이 암묵적이었다.
  - nginx `upstream auth_up { server auth:8080; }`는 **시작·reload 때만** DNS를 조회 → 인스턴스를 늘려도 수동 reload 전에는 반영되지 않고, 죽은 인스턴스도 빠지지 않는다.
  - 헬스 체크 설정이 없다.
  - `keepalive 32`를 써 놨지만 `proxy_http_version 1.1`이 없어 **upstream에 요청마다 새 TCP 연결**을 맺고 있었다(지금까지의 모든 부하 측정이 이 조건).
  - BFF → auth 호출은 nginx를 거치지 않는다(내부망 직접 호출).
  - Prometheus는 `auth:9090` 하나만 수집 → 늘린 인스턴스 지표 누락.
- 한계를 넘는 로그인 요청은 줄을 서서 p95가 30초까지 늘었다.

## T — 목표

- 인스턴스 증감이 reload 없이 반영되는 로드 밸런싱, 연속 실패 인스턴스 자동 제외.
- 모든 인스턴스를 관측.
- 로그인 과부하 때 받아들인 요청의 지연을 지키고 넘치는 요청은 즉시 거절.

## A — 어떻게

- nginx `resolver 127.0.0.11 valid=5s` + upstream `zone` + `server auth:8080 resolve max_fails=2 fail_timeout=10s`(nginx 1.27.3+ 오픈소스 지원). 라운드 로빈, sticky 없음(상태는 DB·Redis).
- 비멱등 요청(POST 로그인)은 다른 인스턴스로 자동 재시도하지 않는다(기본값 유지 — 중복 발급 방지).
- `proxy_http_version 1.1` + `Connection ""`로 upstream keepalive를 실제로 동작시킴.
- Prometheus `dns_sd_configs`(A 레코드)로 auth·api·bff 모든 인스턴스 수집.
- 로그인 요청 제한: `limit_req_zone`(전역) 22 r/s, burst 10, 초과 429. `/auth/login`과 `/bff/login`을 같은 구역으로 묶음(브라우저 경로가 nginx `/auth/login` 제한을 우회하지 않게).

### 대안 비교
| 방식 | 판단 |
|---|---|
| nginx upstream + DNS 동적 재조회 | 로컬 Compose에 이미 있는 구성 요소. **채택** |
| 별도 LB 컨테이너(HAProxy·Traefik) | 능동 헬스 체크·서비스 발견이 더 풍부. 로컬 범위에선 과함 |
| 운영(AWS) ALB | 능동 헬스 체크·오토스케일 연동. 배포 단계에서 대체 |
| 전역 고정 요청 제한(nginx) | 단순. 대신 인스턴스 수가 바뀌면 값을 다시 맞춰야 함 |
| 앱 단 인스턴스별 동시성 제한 / 계정별 실패 제한(Redis) | 인스턴스 수에 자동으로 비례, 무차별 대입까지 방어. **후속** |

## R — 결과 (진행 중)

| 확인 | 결과 |
|---|---|
| auth 2대, nginx reload 없이 로그인 40 TPS | 두 인스턴스 CPU 0.75 / 0.82코어로 분산 → **동적 재조회 동작** |
| auth 2대 수동 reload 시 로그인 40 TPS | p95 98ms, 성공 100%, 한계 약 47 TPS(1대 24의 약 2배) |
| Prometheus 수집 대상 | auth 2개·api·bff 인스턴스 모두 up |
| 요청 제한 22 r/s + auth 2대, 40 TPS | 받아들인 요청 p95 **87ms**, 그러나 **44.6% 불필요 거절**(한계 48인데 22로 고정) → 고정 제한은 확장과 맞지 않음 |
| 요청 제한 22 r/s + auth 1대, 40 TPS | **재측정 필요**: 측정 중 다른 작업의 통합 테스트 컨테이너가 돌아 오염(받아들인 요청 p95 8.6초로 기록됨) |

주의: 이 변경부터 upstream keepalive가 실제로 동작하므로, 이전 부하 측정 수치와 직접 비교하지 않는다.
