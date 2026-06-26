# The deploy SSH key already exists in DigitalOcean (uploaded as "m5").
# Look it up by fingerprint instead of recreating it.
data "digitalocean_ssh_key" "deploy" {
  name = var.ssh_key_name
}

resource "digitalocean_droplet" "web" {
  name     = "${var.project_name}-web"
  image    = "ubuntu-24-04-x64"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [data.digitalocean_ssh_key.deploy.id]
  tags     = [var.project_name, "environment:production", "managed_by:opentofu"]

  # Cloud-config hardens SSH at first boot. Kamal installs Docker later via
  # the Ansible playbook (infra/ansible/playbook.yml).
  user_data = <<-EOF
    #cloud-config
    ssh_pwauth: false
    package_update: true
    package_upgrade: true
    packages:
      - curl
      - ca-certificates
    runcmd:
      - sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
      - sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
      - systemctl restart sshd
  EOF
}
