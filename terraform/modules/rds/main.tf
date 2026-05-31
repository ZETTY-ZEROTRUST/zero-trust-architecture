resource "aws_db_subnet_group" "main" {
  name        = "zeti-db-subnet-group"
  description = "ZETI RDS subnet group across priv-db-2a and priv-db-2b"
  subnet_ids  = var.priv_db_subnet_ids

  tags = { Name = "${var.project_prefix}-db-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier     = "zeti-rds"
  engine         = "mysql"
  engine_version = "8.4.8"
  instance_class = "db.t3.micro"

  db_name  = var.db_name
  username = var.master_username
  password = var.master_password
  port     = 3306

  allocated_storage     = 5
  max_allocated_storage = 1000
  storage_type          = "gp2"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_sg_id]
  publicly_accessible    = false

  parameter_group_name = "default.mysql8.4"

  backup_retention_period = 7
  backup_window           = "16:32-17:02"
  maintenance_window      = "tue:15:04-tue:15:34"
  copy_tags_to_snapshot   = true

  deletion_protection       = true
  delete_automated_backups  = false
  skip_final_snapshot       = false
  final_snapshot_identifier = "zeti-rds-final-snapshot"

  auto_minor_version_upgrade = true

  tags = { Name = "${var.project_prefix}-rds" }
}
