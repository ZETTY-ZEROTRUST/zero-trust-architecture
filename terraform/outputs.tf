output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "route53_name_servers" {
  description = "도메인 등록기관 (가비아 등) 에서 NS 위임할 값."
  value       = module.route53.name_servers
}

output "acm_certificate_arn" {
  value = module.route53.acm_certificate_arn
}

output "waf_web_acl_arn" {
  value = module.waf.web_acl_arn
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "kms_jwt_signing_key_arn" {
  value = module.kms.jwt_signing_key_arn
}

output "kms_jwt_signing_alias" {
  value = module.kms.jwt_signing_alias
}
