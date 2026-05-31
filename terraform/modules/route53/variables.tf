variable "project_prefix" {
  type    = string
  default = "ZETI"
}

variable "domain_name" {
  description = "Public hosted zone domain. placeholder zeti.example.com."
  type        = string
}

variable "alb_dns_name" {
  type = string
}

variable "alb_zone_id" {
  type = string
}

variable "subdomains" {
  description = "ALB 로 alias 할 서브도메인 리스트. CLAUDE.md JWT iss/aud 와 매핑."
  type        = list(string)
  default     = ["auth", "api", "kibana"]
}
