output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "priv_web_subnet_ids" {
  value = [aws_subnet.priv_web_a.id, aws_subnet.priv_web_b.id]
}

output "priv_app_subnet_ids" {
  value = [aws_subnet.priv_app_a.id, aws_subnet.priv_app_b.id]
}

output "priv_db_subnet_ids" {
  value = [aws_subnet.priv_db_a.id, aws_subnet.priv_db_b.id]
}

output "priv_monitor_subnet_ids" {
  value = [aws_subnet.priv_monitor_a.id, aws_subnet.priv_monitor_b.id]
}

output "igw_id" {
  value = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  value = [aws_nat_gateway.a.id, aws_nat_gateway.b.id]
}
