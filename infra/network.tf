# Firewall: SSH (optionally restricted to admin IP), HTTP/HTTPS open to the world.
# Postgres is intentionally NOT opened; it binds to 127.0.0.1 in deploy.yml.
# DigitalOcean Cloud Firewalls are stateful and allow all outbound traffic by
# default, so no outbound_rule blocks are needed.
resource "digitalocean_firewall" "web" {
  name = "${var.project_name}-web"

  droplet_ids = [digitalocean_droplet.web.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [var.admin_ip]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound. DO Cloud Firewalls are stateful, and without explicit
  # outbound rules ALL egress is denied (apt update, docker pull, Let's Encrypt,
  # Kamal registry pushes all break). This is the standard config.
  outbound_rule {
    protocol              = "tcp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
