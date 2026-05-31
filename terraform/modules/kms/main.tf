data "aws_caller_identity" "current" {}

# JWT ES256 서명용 비대칭 키. 쿠팡 사고 대응 — 하드코딩 키 → KMS 전환.
resource "aws_kms_key" "jwt_signing" {
  description              = "ZETI JWT ES256 signing key (ECC_NIST_P256)"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "ECC_NIST_P256"
  deletion_window_in_days  = 30
  enable_key_rotation      = false # 비대칭 SIGN_VERIFY 는 자동 rotation 미지원

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccount"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AuthServerSign"
        Effect    = "Allow"
        Principal = { AWS = var.auth_server_role_arn }
        Action = [
          "kms:Sign",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid       = "ApiServerVerify"
        Effect    = "Allow"
        Principal = { AWS = var.api_server_role_arn }
        Action = [
          "kms:Verify",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = { Name = "${var.project_prefix}-kms-jwt-signing" }
}

resource "aws_kms_alias" "jwt_signing" {
  name          = "alias/zeti-jwt-signing"
  target_key_id = aws_kms_key.jwt_signing.key_id
}

# RDS storage encryption key
resource "aws_kms_key" "rds" {
  description             = "ZETI RDS storage encryption"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = { Name = "${var.project_prefix}-kms-rds" }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/zeti-rds"
  target_key_id = aws_kms_key.rds.key_id
}
