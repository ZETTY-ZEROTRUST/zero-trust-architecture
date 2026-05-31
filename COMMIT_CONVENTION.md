# Commit Message Convention

ZETTY 프로젝트 커밋 메시지 규칙. Conventional Commits 기반.

---

## 1. 기본 포맷

```
<type>(<scope>): <subject>

<body>

<footer>
```

- **type, scope, subject는 필수**
- body, footer는 선택
- 제목과 본문 사이 한 줄 공백
- 본문과 푸터 사이 한 줄 공백

---

## 2. Type

| 타입 | 용도 |
| --- | --- |
| `feat` | 새 기능 추가 |
| `fix` | 버그 수정 |
| `refactor` | 기능 변화 없는 코드 구조 개선 |
| `docs` | 문서/README/주석 수정 |
| `style` | 포맷팅, 세미콜론 등 (코드 동작 변화 없음) |
| `test` | 테스트 추가/수정 |
| `chore` | 빌드, 의존성, 설정 등 잡일 |
| `perf` | 성능 개선 |
| `ci` | CI/CD 설정 변경 (GitHub Actions 등) |
| `revert` | 이전 커밋 되돌리기 |

---

## 3. Scope

ZETTY는 모노레포 + 멀티 컴포넌트 구조라 **scope를 거의 항상 명시**한다.

| 스코프 | 영역 |
| --- | --- |
| `auth` | Auth Server (JWT 발급) |
| `api` | API Server (주문/주소 등) |
| `infra` | Terraform, AWS 인프라 설정 |
| `nginx` | Nginx PEP 설정/커스텀 로깅 |
| `uba` | UBA 분석 로직, 리스크 스코어링 |
| `pipeline` | 로그 파이프라인 |
| `llm` | LLM 추론 모듈 |
| `dashboard` | 시각화 대시보드 |
| `kms` | KMS 키 관리 |
| `db` | DB 스키마/마이그레이션 |
| `ci` | GitHub Actions, 빌드 스크립트 |
| `docs` | 문서, 컨벤션 |

여러 스코프에 걸치면 가장 중심 스코프 하나만 적는다. 정말 광범위하면 생략 가능.

---

## 4. Subject (제목)

- **한글로 작성** (팀 커뮤니케이션 일관성)
- 50자 이내
- 마침표 없이
- 명령형/현재형 (`추가`, `수정` — `추가했음`, `수정함` 지양)
- "무엇을" 변경했는지 명확히

### 좋은 예

```
feat(api): IDOR 취약 엔드포인트 GET /addresses/{userId} 추가
fix(api): KMS 공개키 캐싱 시 kid 매칭 오류 수정
refactor(uba): 리스크 스코어링 팩터 분리
chore(api): Spring Boot 3.4.0 프로젝트 골격 생성
docs(infra): README에 EC2 접속 방법 추가
test(api): 주문 조회 IDOR 시나리오 테스트 추가
```

### 나쁜 예

```
update                       # 무엇을 했는지 모름
fix bug                      # 어떤 버그인지 모름
[API] 추가함                 # 타입 규격 안 맞음
feat: 여러 기능 한꺼번에     # 한 커밋이 너무 큼
WIP                          # 의미 없음
```

---

## 5. Body (본문, 선택)

제목만으로 부족할 때 작성. **왜** 변경했는지를 중심으로.

- 한 줄 72자 이내
- 한국어/영어 혼용 가능
- 코드 변경 내역 나열보다 의도 설명 우선

```
feat(api): KMS 공개키 기반 JWT 검증 필터 추가

쿠팡 사고 재현을 위해 ES256 서명 검증 로직을 도입.
부팅 시 KMS GetPublicKey로 공개키 가져와 메모리 캐싱하며,
키 회전 대비 kid 기반 Map<String, ECPublicKey> 구조로 관리.
인가(authorization)는 의도적으로 생략하여 IDOR 시연 가능 상태로 둠.
```

---

## 6. Footer (푸터, 선택)

이슈 트래킹, Breaking Change 명시.

```
Closes #12
Refs #34, #56
BREAKING CHANGE: JWT 알고리즘이 HS256 → ES256으로 변경됨
```

- `Closes #N` — 머지 시 이슈 자동 종료
- `Refs #N` — 관련 이슈 참조만
- `BREAKING CHANGE:` — API 호환성 깨질 때

---

## 7. 한 커밋의 단위

**원칙: 한 커밋에 한 가지 변경.**

- 기능 추가 + 버그 수정 → 두 커밋으로 분리
- 리팩터링 + 새 기능 → 두 커밋으로 분리
- 포맷팅만 변경 → 별도 `style` 커밋

PR 리뷰어 입장에서 커밋 단위로 이해할 수 있어야 한다.

---

## 8. 자주 쓰는 패턴 (ZETTY 프로젝트 기준)

```
chore(api): Spring Boot 프로젝트 골격 생성
chore(api): KMS, Nimbus JWT 의존성 추가
feat(api): User/Address/Order 엔티티 정의
feat(db): 더미 사용자/주소 데이터 schema.sql, data.sql 추가
feat(api): KMS 공개키 캐싱 컴포넌트 구현
feat(api): JWT 검증 필터 구현
feat(api): IDOR 취약 엔드포인트 추가
test(api): IDOR 시연 통합 테스트 추가
docs(api): README에 실행/시연 방법 작성
ci(api): GitHub Actions 빌드 워크플로우 추가
```

---

## 9. 템플릿 사용

저장소 루트에 `.gitmessage` 파일이 있으면 아래 명령으로 템플릿 등록:

```bash
git config --local commit.template .gitmessage
```

이후 `git commit`만 치면 에디터에 가이드가 자동으로 뜬다.

---

## 10. Git 관리 약속

### .gitmessage 템플릿

```
# <type>(<scope>): <subject>
#
# ─────────────────────────────────────────────
# Type:    feat | fix | refactor | docs | style | test | chore | perf | ci | revert
# Scope:   auth | api | infra | nginx | uba | pipeline | llm | dashboard | kms | db | ci | docs
# Subject: 50자 이내, 마침표 없이, 명령형 (예: "JWT 검증 필터 추가")
# ─────────────────────────────────────────────
#
# Body (선택, 한 줄 72자 이내):
# - "왜" 변경했는지 중심으로 작성
# - 코드 변경 나열보다 의도/배경 설명
#
#
# ─────────────────────────────────────────────
# Footer (선택):
# - Closes #N           : 머지 시 이슈 자동 종료
# - Refs #N             : 관련 이슈 참조
# - BREAKING CHANGE:    : 호환성 깨지는 변경 명시
# ─────────────────────────────────────────────
```

### 등록 (레포별 1회)

```bash
cd zero-trust-architecture
git config --local commit.template .gitmessage
```

이후 `git commit` 만 치면 에디터에 가이드가 자동으로 뜬다. Claude Code 도 이 템플릿을 읽고 `git commit` / `git push` 안내를 그에 맞춰 제안한다.

### 운영 약속

- 사용자가 `git` 명령어를 직접 친다. Claude Code 는 명령어 제안만, 실행은 사용자.
- 예외: 사용자가 명시적으로 "직접 쳐줘" 라 위임한 경우만 Claude 가 실행.
- `--no-verify` 절대 사용 금지 (pre-commit hook 우회).
- `--amend` 는 푸시 전 마지막 commit 한정. 푸시 후 amend → force push 필요 → 금지.
- **Co-Authored-By 라인 절대 추가 금지** (본인 단독 진행).
