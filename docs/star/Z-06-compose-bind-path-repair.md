# Z-06 worktree 이동 후 ZETTY 서비스 복구

- 상태: 완료 (중지 서비스 6개 복구; 기존 core 환경 파일 복구는 별도)
- 작성: 2026-10-03

## S — 문제

이전 zetty-wt에서 생성한 컨테이너가 현재 사라진 설정·TLS·secret 파일을 bind mount한다. nginx, Redis events, relay, indexer, Prometheus, mysqld-exporter가 중지 상태다. kms-init은 정상 종료(exit 0)한 초기화 작업이다.

## T — 목표

현재 zetty/zero-trust-architecture/compose를 기준으로 6개 중지 서비스를 복구하고 HTTPS, Redis health, exporter의 실제 DB 수집, 기존 core 컨테이너 및 데이터 볼륨 보존을 검증한다.

## A — 계획

- 설정/초기화 bind 6개를 long syntax / read_only / create_host_path=false로 변경한다.
- 현재 경로에 로컬 TLS를 생성한다. 키와 secret 파일은 gitignore 경로에만 보관한다.
- 사라진 분석·관측 접속 정보는 전용 역할(relay/indexer/exporter)만 새로 생성해 DB에 일치시킨다. Redis ACL도 전용 파일로 생성한다. 기존 Auth/API/BFF 계정 비밀번호·JWT 키·vault 키는 변경하지 않는다.
- root DB 인증은 기존 MySQL 컨테이너 안에서 처리한다. 원문 credential·SQL·키를 도구 출력이나 문서에 남기지 않는다.
- 복구용 recovery.env는 exporter 접속 정보만 포함한다. 원본 core .secrets/env를 복구한 것으로 주장하지 않는다.
- 선택한 6개 서비스만 --no-deps --no-build로 재생성한다. 이전 컨테이너의 core 환경을 추출하거나 복사하지 않는다.
- 컨테이너 ID·볼륨·마운트 source·HTTPS 응답·Prometheus readiness·mysql_up 지표로 검증한다.
- 사용자 요청이 없어 staging/commit/push는 하지 않는다.

## R — 결과

- nginx·Redis events·outbox relay·event indexer·Prometheus·MySQL exporter 6개 재생성 및 실행 확인.
- Redis events·relay·indexer의 Docker health가 healthy이고 nginx -t 성공. Prometheus readiness 성공, exporter의 mysql_up=1 확인.
- 로컬 CA를 명시한 curl에서 /users/me=401, /.well-known/jwks.json=200. TLS 검증을 비활성화하지 않고 HTTPS 연결을 확인했다.
- 8개 기존 core 컨테이너의 ID가 동일하고 계속 실행 중이다. 해당 컨테이너의 볼륨과 환경을 재생성하지 않았다.
- 복구한 6개 서비스의 실제 mount source에 zetty-wt 참조가 없음. 전체 14개 장기 실행 컨테이너 실행 중, kms-init만 정상 종료(exit 0).
- 전용 relay/indexer/exporter 계정의 credential은 새 runtime 파일과 일치시켰다. 기존 Auth/API/BFF 계정·JWT signing key·vault key는 변경하지 않았다.
- compose/.secrets/recovery.env는 관측 exporter 설정이며 원본 core .secrets/env를 대체하지 않는다. 원본 core env가 없어 현재 복구 helper는 선택 서비스만 --no-deps로 실행한다. core를 전체 재생성하려면 기존 DB·vault·HMAC 설정을 별도로 맞춰야 한다.
- 변경/생성된 TLS·credential 내용은 출력하지 않았고 gitignore 범위에만 저장했다. git diff --check 통과. Git 기록은 사용자 요청에 따라 fix/compose-bind-recovery 브랜치에서 분리한다.
- 증거: docs/star/results/Z-06-runtime-recovery.json. 실행: python3 compose/scripts/recover-services.py (exit 0).
