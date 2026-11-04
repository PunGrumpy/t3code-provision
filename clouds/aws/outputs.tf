output "ip" {
  value = var.running ? aws_instance.worker[0].public_ip : null
}

output "running" {
  value = var.running
}
