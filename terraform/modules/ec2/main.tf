# IMDSv2 강제 옵션 — ground truth instances.json 의 HttpTokens=required 와 일치
locals {
  metadata = {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
  }
}

# ── Nginx PEP × 2 AZ ─────────────────────────────────────────────────────
resource "aws_instance" "nginx_pep_a" {
  ami                    = var.ami_ubuntu
  instance_type          = "t3.small"
  subnet_id              = var.priv_web_subnet_ids[0]
  vpc_security_group_ids = [var.nginx_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  ebs_optimized          = true

  metadata_options {
    http_tokens                 = local.metadata.http_tokens
    http_put_response_hop_limit = local.metadata.http_put_response_hop_limit
    http_endpoint               = local.metadata.http_endpoint
  }

  tags = { Name = "${var.project_prefix}-nginx-pep-2a" }
}

resource "aws_instance" "nginx_pep_b" {
  ami                    = var.ami_ubuntu
  instance_type          = "t3.small"
  subnet_id              = var.priv_web_subnet_ids[1]
  vpc_security_group_ids = [var.nginx_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  ebs_optimized          = true

  metadata_options {
    http_tokens                 = local.metadata.http_tokens
    http_put_response_hop_limit = local.metadata.http_put_response_hop_limit
    http_endpoint               = local.metadata.http_endpoint
  }

  tags = { Name = "${var.project_prefix}-nginx-pep-2b" }
}

# Target group attachment — ALB → Nginx
resource "aws_lb_target_group_attachment" "nginx_a" {
  target_group_arn = var.tg_nginx_arn
  target_id        = aws_instance.nginx_pep_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "nginx_b" {
  target_group_arn = var.tg_nginx_arn
  target_id        = aws_instance.nginx_pep_b.id
  port             = 80
}

# ── Auth × 2 AZ ───────────────────────────────────────────────────────────
resource "aws_instance" "auth_server_a" {
  ami                    = var.ami_amazon_linux
  instance_type          = "t3.small"
  subnet_id              = var.priv_app_subnet_ids[0]
  vpc_security_group_ids = [var.app_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.auth_server.name
  ebs_optimized          = true

  metadata_options {
    http_tokens                 = local.metadata.http_tokens
    http_put_response_hop_limit = local.metadata.http_put_response_hop_limit
    http_endpoint               = local.metadata.http_endpoint
  }

  tags = { Name = "${var.project_prefix}-auth-server-2a" }
}

resource "aws_instance" "auth_server_b" {
  ami                    = var.ami_amazon_linux
  instance_type          = "t3.small"
  subnet_id              = var.priv_app_subnet_ids[1]
  vpc_security_group_ids = [var.app_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.auth_server.name
  ebs_optimized          = true

  metadata_options {
    http_tokens                 = local.metadata.http_tokens
    http_put_response_hop_limit = local.metadata.http_put_response_hop_limit
    http_endpoint               = local.metadata.http_endpoint
  }

  tags = { Name = "${var.project_prefix}-auth-server-2b" }
}

# ── API × 2 AZ ────────────────────────────────────────────────────────────
resource "aws_instance" "api_server_a" {
  ami                    = var.ami_amazon_linux
  instance_type          = "t3.small"
  subnet_id              = var.priv_app_subnet_ids[0]
  vpc_security_group_ids = [var.app_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.api_server.name
  ebs_optimized          = true

  metadata_options {
    http_tokens                 = local.metadata.http_tokens
    http_put_response_hop_limit = local.metadata.http_put_response_hop_limit
    http_endpoint               = local.metadata.http_endpoint
  }

  tags = { Name = "${var.project_prefix}-api-server-2a" }
}

resource "aws_instance" "api_server_b" {
  ami                    = var.ami_amazon_linux
  instance_type          = "t3.small"
  subnet_id              = var.priv_app_subnet_ids[1]
  vpc_security_group_ids = [var.app_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.api_server.name
  ebs_optimized          = true

  metadata_options {
    http_tokens                 = local.metadata.http_tokens
    http_put_response_hop_limit = local.metadata.http_put_response_hop_limit
    http_endpoint               = local.metadata.http_endpoint
  }

  tags = { Name = "${var.project_prefix}-api-server-2b" }
}

# ── ELK (priv-monitor-2a 만) ─────────────────────────────────────────────
resource "aws_instance" "elk_server" {
  ami                    = "ami-04cf9f87233911231"
  instance_type          = "t2.large"
  subnet_id              = var.priv_monitor_subnet_ids[0]
  vpc_security_group_ids = [var.elk_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  private_ip             = "10.0.41.10"

  metadata_options {
    http_tokens                 = local.metadata.http_tokens
    http_put_response_hop_limit = local.metadata.http_put_response_hop_limit
    http_endpoint               = local.metadata.http_endpoint
  }

  tags = { Name = "${var.project_prefix}-elk-server-2a" }
}

# ── UBA (priv-monitor-2a 만) ─────────────────────────────────────────────
resource "aws_instance" "uba_server" {
  ami                    = "ami-01b2055d178d0ce5c"
  instance_type          = "t3.large"
  subnet_id              = var.priv_monitor_subnet_ids[0]
  vpc_security_group_ids = [var.uba_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  private_ip             = "10.0.41.20"
  ebs_optimized          = true

  metadata_options {
    http_tokens                 = local.metadata.http_tokens
    http_put_response_hop_limit = local.metadata.http_put_response_hop_limit
    http_endpoint               = local.metadata.http_endpoint
  }

  tags = { Name = "${var.project_prefix}-uba-server-2a" }
}
