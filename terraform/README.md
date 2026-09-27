# ZETTY Infrastructure — Terraform (AWS 배포 설계 · 아카이브)

쿠팡 JWT 유출 사고 모티브 Zero Trust SOC 인프라. AWS ap-northeast-2 단일 VPC Multi-AZ.

> **위치**: 현재 활성 인프라는 상위 [`../compose`](../compose) 로컬 스택이다. 이 Terraform 은 콘솔로 수기 구성했던 초기 AWS 배포를 코드로 정리한 **설계 아카이브**다. 아래 모듈에는 폐기된 v1 관제(ELK/UBA EC2) 흔적이 남아 있으며, 현재 탐지는 `log-pipeline`의 이상 탐지(v2)로 이관됐다.

## 현재 상태

- **콘솔로 수기 구성된 상태를 Terraform 으로 codify** (apply 가 아닌 IaC 정리)
- ground truth: 당시 `aws cli describe-*` 백업(JSON). 리소스 ID 는 각 모듈 변수/주석에 기록.

## State backend: local

단일 사용자·시연 목적이라 원격 state 불필요. 운영 환경이라면 S3 + DynamoDB lock 백엔드로 전환.

`*.tfstate` 는 `.gitignore` 처리 — state 파일에는 리소스 속성이 평문으로 들어가고 시크릿이 박힐 수 있어서 절대 커밋 금지. `.terraform.lock.hcl` 은 provider 버전 고정용이라 커밋함.

## 디렉토리

```
terraform/
├── versions.tf / providers.tf / variables.tf / main.tf / outputs.tf
├── terraform.tfvars.example
└── modules/
    ├── vpc/               VPC + 10 subnets (5 tier × 2 AZ) + IGW + 2 NAT + 3 RT
    ├── security_groups/   ZT SG 체인 (alb→nginx→app→db, monitor 별도)
    ├── alb/               ALB + tg-nginx + listener (HTTP 80, HTTPS 443)
    ├── waf/               WAFv2 REGIONAL + AWS Managed Rules + ALB 연결
    ├── route53/           placeholder hosted zone + ACM DNS-validated cert
    ├── ec2/               nginx-pep / auth / api / elk / uba EC2 + IAM
    ├── rds/               MySQL 8.4 Multi-AZ + KMS encrypted
    └── kms/               JWT ES256 비대칭 키 (ECC_NIST_P256)
```

## 사용

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars  # 값 채우기

terraform init
terraform plan
# terraform apply  # 현재 콘솔 자원과 중복 — apply 하려면 import 먼저
```

## Import (콘솔 자원을 state 로 흡수할 때)

각 모듈에 import 블록 또는 `terraform import` 명령으로 ground truth ID 를 state 로 가져온다. ID 는 각 모듈의 변수/주석 참고.

예시 — VPC:
```bash
terraform import 'module.vpc.aws_vpc.main' vpc-08a66a667d5e5013a
```

## Legacy SG (Terraform 미반영)

마이그레이션 흔적으로 남은 SG (`ZETI-nginx-sg`, `ZETI-elk-sg`, `ZETI-uba-sg`, `launch-wizard-*`) 는 Terraform 에 포함하지 않음. ZT 깨끗한 SG (`ZETI-sg-*`) 만 codify.
