variable "project_prefix" {
  type    = string
  default = "ZETI"
}

variable "priv_db_subnet_ids" {
  type = list(string)
}

variable "db_sg_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "db_name" {
  type    = string
  default = "zeti_db"
}

variable "master_username" {
  type    = string
  default = "admin"
}

variable "master_password" {
  description = "RDS master password. Secrets Manager 로 운영 시 random_password + aws_secretsmanager_secret 로 교체."
  type        = string
  sensitive   = true
}
