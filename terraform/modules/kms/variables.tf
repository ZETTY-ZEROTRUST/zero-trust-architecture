variable "project_prefix" {
  type    = string
  default = "ZETI"
}

variable "auth_server_role_arn" {
  description = "auth-server IAM role ARN — kms:Sign 권한 부여."
  type        = string
}

variable "api_server_role_arn" {
  description = "api-server IAM role ARN — kms:Verify / kms:GetPublicKey 권한 부여."
  type        = string
}
