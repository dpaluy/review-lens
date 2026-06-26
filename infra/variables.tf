variable "do_token" {
  description = "DigitalOcean API token (read/write)"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of an existing SSH key already uploaded to DigitalOcean"
  type        = string
  default     = "m5" # matches ~/.ssh/id_ed25519 (dpaluy@users.noreply.github.com)
}

variable "admin_ip" {
  description = "CIDR allowed SSH access. Restrict to your IP in real production; 0.0.0.0/0 relies on fail2ban only."
  type        = string
  default     = "0.0.0.0/0"
}

variable "droplet_region" {
  description = "DigitalOcean region slug"
  type        = string
  default     = "nyc3"
}

variable "droplet_size" {
  description = "Droplet size slug"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "project_name" {
  description = "Used for resource naming and tags"
  type        = string
  default     = "reviewlens"
}

variable "spaces_region" {
  description = "DO Spaces region"
  type        = string
  default     = "nyc3"
}

variable "spaces_bucket" {
  description = "Name of the DO Spaces bucket (created in DO Console) for pg_dump backups"
  type        = string
  default     = "reviewlens-spaces"
}

# Spaces credentials for the bucket resource. Created in the DO Console and
# stored in 1Password (the Spaces API cannot issue bucket-creation rights,
# so the key must be created manually once). Loaded by infra/bin/provision.
variable "spaces_access_id" {
  description = "DO Spaces access key id (from 1Password)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "spaces_secret_key" {
  description = "DO Spaces secret key (from 1Password)"
  type        = string
  default     = ""
  sensitive   = true
}
