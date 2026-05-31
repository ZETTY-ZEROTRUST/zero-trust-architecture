variable "project_prefix" {
  type    = string
  default = "ZETI"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_a" {
  type = string
}

variable "az_b" {
  type = string
}

# tier 별 CIDR. ground truth: zeti-infra-backup/subnets.json
variable "subnet_cidrs" {
  description = "5 tier × 2 AZ subnet CIDR. ground truth 그대로."
  type        = map(string)
  default = {
    public_a       = "10.0.1.0/24"
    public_b       = "10.0.2.0/24"
    priv_web_a     = "10.0.11.0/24"
    priv_web_b     = "10.0.12.0/24"
    priv_app_a     = "10.0.21.0/24"
    priv_app_b     = "10.0.22.0/24"
    priv_db_a      = "10.0.31.0/24"
    priv_db_b      = "10.0.32.0/24"
    priv_monitor_a = "10.0.41.0/24"
    priv_monitor_b = "10.0.42.0/24"
  }
}
