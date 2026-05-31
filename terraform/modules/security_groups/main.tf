# ZT SG 체인 — 인바운드는 SG 참조 only (IP 변경 무관, 신원 기반).
# 흐름: Internet → alb → nginx → app → db
#       관제: nginx/app → elk, uba → elk

# ── ALB ──────────────────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_prefix}-sg-alb"
  description = "ALB - allow HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-sg-alb" }
}

# ── Nginx PEP ────────────────────────────────────────────────────────────
resource "aws_security_group" "nginx" {
  name        = "${var.project_prefix}-sg-nginx"
  description = "Nginx PEP - allow 80 from sg-alb only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow 80 from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-sg-nginx" }
}

# ── App (Auth + API) ─────────────────────────────────────────────────────
resource "aws_security_group" "app" {
  name        = "${var.project_prefix}-sg-app"
  description = "Auth/API servers - allow 8080/8081 from sg-nginx only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow 8080 from Nginx (Auth server)"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx.id]
  }

  ingress {
    description     = "Allow 8081 from Nginx (API server)"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-sg-app" }
}

# ── RDS ──────────────────────────────────────────────────────────────────
resource "aws_security_group" "db" {
  name        = "${var.project_prefix}-sg-db"
  description = "RDS - allow 3306 from sg-app only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow MySQL from App"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-sg-db" }
}

# ── UBA (관제) ────────────────────────────────────────────────────────────
# 인바운드 없음. ELK 쿼리 + Slack/Anthropic API 호출만 (outbound).
resource "aws_security_group" "uba" {
  name        = "${var.project_prefix}-sg-uba"
  description = "UBA server - outbound only for ELK queries and external APIs"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-sg-uba" }
}

# ── ELK (관제) ────────────────────────────────────────────────────────────
resource "aws_security_group" "elk" {
  name        = "${var.project_prefix}-sg-elk"
  description = "ELK - 5044 Filebeat from nginx, 9200 ES from nginx+uba"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Beats input from Nginx"
    from_port       = 5044
    to_port         = 5044
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx.id]
  }

  ingress {
    description     = "Elasticsearch from Nginx"
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx.id]
  }

  ingress {
    description     = "Elasticsearch from UBA"
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [aws_security_group.uba.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_prefix}-sg-elk" }
}
