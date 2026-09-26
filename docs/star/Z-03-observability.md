# Z-03 부하 측정을 위한 관측 스택

- 상태: 계획
- 연결: Jira O-02 · 부하 실험 L-1~L-7 공통 기반
- 작성/갱신: 2026-09-26

## S — 문제 발생

- 앱에 Actuator/Micrometer가 없다. 커넥션 풀 대기, 스레드 사용량, GC 같은 **병목의 원인을 볼 지표가 없다.**
- 부하 도구의 응답 시간만으로는 "왜 느려졌는가"(DB 풀 고갈인지, CPU 포화인지, 쿼리인지)를 구분할 수 없다. 그러면 개선 효과도 설명할 수 없다.

## T — 왜 / 목표

- 부하 실험마다 **클라이언트 지표**(k6: RPS, p95/p99, 에러율)와 **서버 지표**를 같은 시간축에 기록한다.
  - 서버 지표: Hikari active/pending/timeout, Tomcat busy threads, JVM heap/GC, 컨테이너 CPU·메모리, MySQL QPS·slow query
- 성공 기준: Prometheus에서 위 지표를 조회할 수 있고, 실험 종료 후 결과를 파일로 내보낼 수 있다.

## A — 어떻게

### 계획

- **앱:** `spring-boot-starter-actuator` + `micrometer-registry-prometheus`. management port(9090)를 application 포트와 분리한다. Nginx로 프록시하지 않고 host에도 공개하지 않는다.
- `observability` profile: `prometheus`(scrape 5s), `cadvisor`, `mysqld-exporter`. Prometheus UI만 `127.0.0.1:9091`에 bind한다.
- 결과 export: 실험 스크립트가 Prometheus HTTP API로 구간 query 결과를 JSON으로 저장한다.

### 검토한 대안과 선택 이유

- **Grafana 추가:** 시각화에는 좋지만 수치 보고에는 필수가 아니다. 사용자 결정이 대기 중이라 이번 단계에서는 제외하고, 필요하면 `ui` profile로 추가한다.
- **APM(Pinpoint 등):** 설치 비용이 크다. 1차 목표는 풀·스레드·쿼리 수준의 병목 구분이다.

### 시행착오

(진행 중 추가)

## R — 개선 결과

미측정.

## 자소서 한 줄 (R 확정 후)
