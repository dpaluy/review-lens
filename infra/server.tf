# SSH key uploaded to DigitalOcean so the Droplet can be reached.
resource "digitalocean_ssh_key" "deploy" {
  name       = "${var.project_name}-deploy"
  public_key = var.ssh_public_key
}

resource "digitalocean_droplet" "web" {
  name     = "${var.project_name}-web"
  image    = "ubuntu-24-04-x64"
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [digitalocean_ssh_key.deploy.id]
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
