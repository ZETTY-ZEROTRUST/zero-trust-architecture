output "nginx_instance_ids" {
  value = [aws_instance.nginx_pep_a.id, aws_instance.nginx_pep_b.id]
}

output "auth_instance_ids" {
  value = [aws_instance.auth_server_a.id, aws_instance.auth_server_b.id]
}

output "api_instance_ids" {
  value = [aws_instance.api_server_a.id, aws_instance.api_server_b.id]
}

output "elk_instance_id" {
  value = aws_instance.elk_server.id
}

output "uba_instance_id" {
  value = aws_instance.uba_server.id
}

output "auth_server_role_arn" {
  value = aws_iam_role.auth_server.arn
}

output "api_server_role_arn" {
  value = aws_iam_role.api_server.arn
}
