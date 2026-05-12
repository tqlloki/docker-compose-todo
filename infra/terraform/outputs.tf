output "droplet_ip" {
  description = "Public IPv4 address of the Droplet."
  value       = digitalocean_droplet.todo_api.ipv4_address
}

output "ssh_command" {
  description = "SSH command for the Droplet."
  value       = "ssh root@${digitalocean_droplet.todo_api.ipv4_address}"
}
