variable "project_prefix" {
  type    = string
  default = "ZETI"
}

variable "alb_arn" {
  type = string
}

variable "rate_limit_per_5min" {
  description = "IP 당 5분 윈도우 요청 수 임계치. 초과 시 BLOCK."
  type        = number
  default     = 2000
}
