resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_prefix}-VPC" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_prefix}-IGW" }
}

# ── Subnets ──────────────────────────────────────────────────────────────
# public — ALB / NAT GW
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidrs["public_a"]
  availability_zone       = var.az_a
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_prefix}-public-subnet-2a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidrs["public_b"]
  availability_zone       = var.az_b
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_prefix}-public-subnet-2b" }
}

# priv-web — Nginx PEP
resource "aws_subnet" "priv_web_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs["priv_web_a"]
  availability_zone = var.az_a
  tags              = { Name = "${var.project_prefix}-priv-web-2a" }
}

resource "aws_subnet" "priv_web_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs["priv_web_b"]
  availability_zone = var.az_b
  tags              = { Name = "${var.project_prefix}-priv-web-2b" }
}

# priv-app — Auth, API
resource "aws_subnet" "priv_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs["priv_app_a"]
  availability_zone = var.az_a
  tags              = { Name = "${var.project_prefix}-priv-app-2a" }
}

resource "aws_subnet" "priv_app_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs["priv_app_b"]
  availability_zone = var.az_b
  tags              = { Name = "${var.project_prefix}-priv-app-2b" }
}

# priv-db — RDS Multi-AZ
resource "aws_subnet" "priv_db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs["priv_db_a"]
  availability_zone = var.az_a
  tags              = { Name = "${var.project_prefix}-priv-db-2a" }
}

resource "aws_subnet" "priv_db_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs["priv_db_b"]
  availability_zone = var.az_b
  tags              = { Name = "${var.project_prefix}-priv-db-2b" }
}

# priv-monitor — ELK, UBA (현재 2a 만 사용, 2b 는 확장 대비)
resource "aws_subnet" "priv_monitor_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs["priv_monitor_a"]
  availability_zone = var.az_a
  tags              = { Name = "${var.project_prefix}-priv-monitor-2a" }
}

resource "aws_subnet" "priv_monitor_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs["priv_monitor_b"]
  availability_zone = var.az_b
  tags              = { Name = "${var.project_prefix}-priv-monitor-2b" }
}

# ── NAT GW (AZ 별 1개, HA) ───────────────────────────────────────────────
resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags   = { Name = "${var.project_prefix}-NAT-EIP-2a" }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
  tags   = { Name = "${var.project_prefix}-NAT-EIP-2b" }
}

resource "aws_nat_gateway" "a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "${var.project_prefix}-NAT-GW-2a" }
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id
  tags          = { Name = "${var.project_prefix}-NAT-GW-2b" }
  depends_on    = [aws_internet_gateway.main]
}

# ── Route Tables ─────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_prefix}-public-rt" }
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.a.id
  }

  tags = { Name = "${var.project_prefix}-private-rt-2a" }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.b.id
  }

  tags = { Name = "${var.project_prefix}-private-rt-2b" }
}

# ── RT associations ──────────────────────────────────────────────────────
# public — both AZ 의 public subnet
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# private-rt-2a — 2a 의 priv-web, priv-app, priv-db, priv-monitor
resource "aws_route_table_association" "priv_web_a" {
  subnet_id      = aws_subnet.priv_web_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "priv_app_a" {
  subnet_id      = aws_subnet.priv_app_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "priv_db_a" {
  subnet_id      = aws_subnet.priv_db_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "priv_monitor_a" {
  subnet_id      = aws_subnet.priv_monitor_a.id
  route_table_id = aws_route_table.private_a.id
}

# private-rt-2b — 2b 의 priv-web, priv-app, priv-db, priv-monitor
resource "aws_route_table_association" "priv_web_b" {
  subnet_id      = aws_subnet.priv_web_b.id
  route_table_id = aws_route_table.private_b.id
}

resource "aws_route_table_association" "priv_app_b" {
  subnet_id      = aws_subnet.priv_app_b.id
  route_table_id = aws_route_table.private_b.id
}

resource "aws_route_table_association" "priv_db_b" {
  subnet_id      = aws_subnet.priv_db_b.id
  route_table_id = aws_route_table.private_b.id
}

resource "aws_route_table_association" "priv_monitor_b" {
  subnet_id      = aws_subnet.priv_monitor_b.id
  route_table_id = aws_route_table.private_b.id
}
