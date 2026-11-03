output "ip" {
  value = var.running ? hcloud_server.worker[0].ipv4_address : null
}

output "running" {
  value = var.running
}
