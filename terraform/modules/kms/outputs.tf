output "jwt_signing_key_id" {
  value = aws_kms_key.jwt_signing.key_id
}

output "jwt_signing_key_arn" {
  value = aws_kms_key.jwt_signing.arn
}

output "jwt_signing_alias" {
  value = aws_kms_alias.jwt_signing.name
}

output "rds_key_arn" {
  value = aws_kms_key.rds.arn
}
