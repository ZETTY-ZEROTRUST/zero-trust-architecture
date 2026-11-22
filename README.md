# ZETTY 로컬 인프라

현재 실행 환경은 [Docker Compose](compose/README.md)다. AWS 연결 없이 Java 21의 Auth/API/BFF, nginx, MySQL, Redis, 로컬 KMS, 보안 이벤트 전달 및 관측 서비스를 기동한다. 과거 AWS Terraform 코드는 현행 BFF·RS256·Redis 구조와 다르고 Compose에서 참조하지 않아 제거했다.

## 요청과 이벤트 경로

```text
브라우저 → nginx HTTPS 8443 → BFF → Auth / API
                                    Auth → 로컬 KMS
                                    Auth/API → MySQL Outbox
MySQL Outbox → outbox-relay → redis-events → event-indexer → Elasticsearch
```

| 프로파일 | 서비스 | 역할 |
|---|---|---|
| core | nginx, auth, api, bff, mysql, redis-session, kms | TLS·세션·인증·인가·원본 저장·서명 |
| analysis | outbox-relay, redis-events, event-indexer, elasticsearch | 보안 이벤트 전달·색인 |
| observability | prometheus, cadvisor, mysqld-exporter | 앱·컨테이너·DB 지표 |
| 초기화 | kms-init | 서명키 alias 준비 후 exit 0 |

상시 서비스는 14개다. nginx만 호스트의 HTTPS 8443을 공개한다. [Compose 파일](compose/compose.yaml)은 `application`, `data`, `kms`, `analysis` 네트워크로 통신을 나누며 Auth만 KMS 서명 네트워크에 접근한다. nginx는 신뢰 헤더와 request ID를 재설정하고 `access_log off`로 동작한다. Filebeat는 없다.

## 실행과 검증

기동·복구 명령, 비밀값·TLS 파일, health, 프로파일 선택은 [Compose README](compose/README.md)를 따른다. 현재 컨테이너가 떠 있어도 인증·인가·Outbox 종단 결과와 새 AI 성능은 별도로 검증한다. 실제 측정은 [STAR 기록](docs/star/)에 조건·시각과 함께 기록한다.
