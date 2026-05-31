# 공통 SSM assume role policy
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ── 공통 EC2 SSM role (nginx / elk / uba) ─────────────────────────────────
resource "aws_iam_role" "ec2_ssm" {
  name               = "${var.project_prefix}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project_prefix}-ec2-ssm-role"
  role = aws_iam_role.ec2_ssm.name
}

# ── Auth server role (KMS sign + SSM + CW) ───────────────────────────────
resource "aws_iam_role" "auth_server" {
  name               = "${var.project_prefix}-auth-server-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "auth_ssm" {
  role       = aws_iam_role.auth_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "auth_cw" {
  role       = aws_iam_role.auth_server.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "auth_secrets" {
  name = "${var.project_prefix}-auth-secrets-rds"
  role = aws_iam_role.auth_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:*:*:secret:zeti/rds/*"
    }]
  })
}

resource "aws_iam_instance_profile" "auth_server" {
  name = "${var.project_prefix}-auth-server-role"
  role = aws_iam_role.auth_server.name
}

# ── API server role (KMS verify + SSM + CW) ──────────────────────────────
resource "aws_iam_role" "api_server" {
  name               = "${var.project_prefix}-api-server-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "api_ssm" {
  role       = aws_iam_role.api_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "api_cw" {
  role       = aws_iam_role.api_server.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "api_secrets" {
  name = "${var.project_prefix}-api-secrets-rds"
  role = aws_iam_role.api_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:*:*:secret:zeti/rds/*"
    }]
  })
}

resource "aws_iam_instance_profile" "api_server" {
  name = "${var.project_prefix}-api-server-role"
  role = aws_iam_role.api_server.name
}
