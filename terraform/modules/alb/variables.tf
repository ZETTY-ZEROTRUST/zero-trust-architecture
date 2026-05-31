variable "project_prefix" {
  type    = string
  default = "ZETI"
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "acm_certificate_arn" {
  description = "ACM cert ARN for HTTPS 443 listener. route53 모듈에서 생성."
  type        = string
}
