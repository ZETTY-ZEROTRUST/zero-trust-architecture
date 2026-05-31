variable "region" {
  description = "AWS region. ZETI 는 단일 ap-northeast-2 고정."
  type        = string
  default     = "ap-northeast-2"
}

variable "env" {
  description = "환경 이름 — default_tags 에 들어감."
  type        = string
  default     = "dev"
}

variable "project_prefix" {
  description = "리소스 Name 태그 prefix. CLAUDE.md 컨벤션: ZETI-{tier}-{resource}-{az}"
  type        = string
  default     = "ZETI"
}

variable "az_a" {
  description = "Availability zone A."
  type        = string
  default     = "ap-northeast-2a"
}

variable "az_b" {
  description = "Availability zone B."
  type        = string
  default     = "ap-northeast-2b"
}

variable "vpc_cidr" {
  description = "ZETI-VPC CIDR. ground truth: 10.0.0.0/16."
  type        = string
  default     = "10.0.0.0/16"
}

variable "domain_name" {
  description = "Route53 hosted zone domain. placeholder (zeti.example.com) — 실제 도메인 확보 시 교체."
  type        = string
  default     = "zeti.example.com"
}

variable "admin_ip_cidr" {
  description = "운영자 IP /32. legacy nginx-sg/elk-sg 의 22 SSH 허용 IP (116.127.149.219/32). ZT 깨끗한 SG 에는 미사용."
  type        = string
  default     = "116.127.149.219/32"
}

variable "rds_master_password" {
  description = "RDS master password. terraform.tfvars 에 넣거나 TF_VAR_rds_master_password 환경변수."
  type        = string
  sensitive   = true
}
