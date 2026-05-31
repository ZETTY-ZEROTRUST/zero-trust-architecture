output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "nginx_sg_id" {
  value = aws_security_group.nginx.id
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "db_sg_id" {
  value = aws_security_group.db.id
}

output "elk_sg_id" {
  value = aws_security_group.elk.id
}

output "uba_sg_id" {
  value = aws_security_group.uba.id
}
