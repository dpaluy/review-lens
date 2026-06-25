output "server_ip" {
  description = "Public IPv4 of the web Droplet"
  value       = digitalocean_droplet.web.ipv4_address
}

output "server_ipv6" {
  description = "Public IPv6 of the web Droplet"
  value       = digitalocean_droplet.web.ipv6_address
}

output "backups_bucket" {
  description = "DO Spaces bucket for Postgres backups"
  value       = aws_s3_bucket.backups.bucket
}

output "next_steps" {
  description = "Next steps after provisioning"
  value       = <<-EOT
    1. Point DNS: ${var.project_name} domain -> ${digitalocean_droplet.web.ipv4_address}
    2. Run: infra/bin/provision --config   (Ansible: harden + Docker + backup cron)
    3. Set env then run: infra/bin/provision --deploy   (kamal setup)
       export DEPLOY_HOST=${digitalocean_droplet.web.ipv4_address}
       export DEPLOY_DOMAIN=<your-domain>
  EOT
}
