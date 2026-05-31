output "zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "도메인 등록기관에서 NS 위임 시 이 값들로 설정."
  value       = aws_route53_zone.main.name_servers
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.main.arn
}

output "acm_validation_complete" {
  value = aws_acm_certificate_validation.main.id
}
