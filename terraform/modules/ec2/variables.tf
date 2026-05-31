variable "project_prefix" {
  type    = string
  default = "ZETI"
}

# Subnets
variable "priv_web_subnet_ids" {
  type = list(string)
}

variable "priv_app_subnet_ids" {
  type = list(string)
}

variable "priv_monitor_subnet_ids" {
  type = list(string)
}

# Security groups
variable "nginx_sg_id" {
  type = string
}

variable "app_sg_id" {
  type = string
}

variable "elk_sg_id" {
  type = string
}

variable "uba_sg_id" {
  type = string
}

# AMI — ground truth (zeti-infra-backup/instances.json)
variable "ami_ubuntu" {
  description = "Ubuntu AMI (nginx/elk). ground truth: ami-0c96608afa8967cdb (nginx), ami-04cf9f87233911231 (elk)."
  type        = string
  default     = "ami-0c96608afa8967cdb"
}

variable "ami_amazon_linux" {
  description = "Amazon Linux 2023 (auth/api/uba). ground truth: ami-0f42d1a90801a2712 (app), ami-01b2055d178d0ce5c (uba)."
  type        = string
  default     = "ami-0f42d1a90801a2712"
}

# ALB target group — Nginx 등록
variable "tg_nginx_arn" {
  type = string
}
