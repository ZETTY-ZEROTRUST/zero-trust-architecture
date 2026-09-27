# Z-05 보안 이벤트 파이프라인 통합 — 실제 요청에서 ES까지

- 상태: 완료(기능 검증) · 부하 측정은 L-6
- 연결: backend `docs/star/B-06-outbox-events.md` · log-pipeline `docs/star/P-01`(C-02 계약), `P-02`(relay·indexer)
- 작성/갱신: 2026-09-27

## S — 문제

- 구성 요소는 따로 검증됐다: 이벤트 발행(Java, C-02 fixture 판정 일치), relay·indexer(일회용 컨테이너 복구 시나리오 10종).
- 하지만 **실제 producer → Outbox → relay → Redis Streams → indexer → ES**를 한 스택에서 돌린 적은 없었다. 그 연결에서만 드러나는 문제(요청 ID, 권한, 인덱스 이름, 비밀 전달)가 남아 있었다.

## T — 목표

- 실제 요청으로 만든 이벤트가 **유실·중복 없이** ES에 들어간다(outbox = receipt = ES 문서 수).
- 한 요청의 edge·BFF·API·Auth 기록을 같은 request_id로 잇는다.
- ES에 토큰·비밀번호·이메일 원문이 없다.

## A — 어떻게

- Compose `analysis` profile: `redis-events`(AOF, `noeviction`, ACL 사용자별 최소 권한, default 사용자 끔), `elasticsearch`(로컬 전용), `outbox-relay`, `event-indexer`(비밀은 `*_FILE` + compose secrets).
- DB 권한: producer(auth·api)는 outbox INSERT만. relay는 outbox SELECT + 상태 컬럼 UPDATE만, indexer는 receipt SELECT·INSERT만.
- nginx가 `$request_id`를 UUID v4 모양으로 바꿔 `X-Request-Id`를 **덮어쓰고**(클라이언트 값 무시) 응답 헤더에도 노출.
- BFF가 API·Auth 호출 모두에 UUID 형식 요청 ID만 전달.

### 통합 중 발견·수정
| 발견 | 원인 | 조치 |
|---|---|---|
| 요청 ID가 스키마 위반이 될 수 있음 | nginx `$request_id`는 16진수 32자, C-02는 RFC 9562 UUID(버전·variant 비트) 요구 | nginx `map`으로 버전 4·variant 8 UUID로 변환 |
| BFF 경유 요청의 추적이 끊김 | BFF가 헤더를 새로 만들며 `X-Request-Id`를 버림 | API·Auth 호출에 UUID 형식 값만 전달 |
| ES 인덱스 이름 불일치 | 공유 계약 `security-events-v2-` vs owner 문서·검증기 `zetty-security-events-v2-` | owner 문서 기준으로 통일(템플릿 패턴 포함) |
| 운영 DB에 Outbox 테이블 없음 | `schema.sql`은 새 볼륨 초기화 때만 실행되고, 앞부분 `DROP TABLE` 때문에 재실행 불가 | Outbox DDL만 추출해 적용(업무 데이터 보존) |

## R — 결과 (실제 스택, 2026-09-27)

요청 9회(BFF 로그인·마이페이지·프로필 수정, 토큰 없는 호출, 로그인 실패, 직접 로그인, 남의 주문 조회, refresh, 같은 RT 재사용):

| 확인 | 결과 |
|---|---|
| 발행 이벤트 | 12건(AUTHENTICATION 3, TOKEN_ISSUED 2, ACCESS_DECISION 4, BUSINESS_RESULT 1, TOKEN_REFRESHED 1, TOKEN_REUSE 1) |
| Outbox 상태 | 12건 모두 PUBLISHED |
| 수신확인(receipt) / ES 문서 | 12 / 12 (`zetty-security-events-v2-2026.09.27`) → 유실·중복 0 |
| request_id 연결 | BFF 로그인 요청 ID → auth AUTHENTICATION·TOKEN_ISSUED 2건, BFF 마이페이지 요청 ID → api ACCESS_DECISION 1건 |
| 민감정보 | JWT(`eyJ`)·비밀번호·이메일·`Bearer` 검색 0건, 원문 문자열도 없음 |
| 거부 이벤트 형태 | 토큰 없음 → `TOKEN_MISSING`·actor null / 비밀번호 틀림 → `INVALID_CREDENTIALS`·actor null / 남의 주문 → `OBJECT_NOT_FOUND_OR_NOT_OWNED`, actor는 HMAC 가명 키, 경로는 `/orders/{orderId}/detail` 템플릿 |

### 남은 과제
- 부하에서 이벤트 기록이 API 지연·처리량에 주는 영향과 전달 지연(backlog) 측정 → L-6.
- 스키마 위반 이벤트(poison)의 사유가 Redis DLQ에만 남음(유실 가능) → 격리 테이블 등 계약 변경 필요.
- 스트림 자동 trim·오래된 consumer 정리 없음(수동 절차는 pipeline README).
- ES 보안 기능 꺼짐(로컬 전용). 운영에서는 켜고 indexer에 최소 권한 키.
