# outputs.tf
output "jenkins_public_ip" {
  description = "Public IP of the Jenkins server"
  value       = aws_instance.jenkins_server.public_ip
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "prometheus_private_ip" {
  description = "Private IP of the Prometheus server"
  value       = aws_instance.prometheus_server.private_ip
}

output "grafana_private_ip" {
  description = "Private IP of the Grafana server"
  value       = aws_instance.grafana_server.private_ip
}

output "ecr_repository_url" {
  description = "ECR Repository URL for the application"
  value       = aws_ecr_repository.app_repo.repository_url
}
