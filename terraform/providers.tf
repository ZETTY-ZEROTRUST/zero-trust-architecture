provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "ZETI"
      ManagedBy = "Terraform"
      Env       = var.env
    }
  }
}
