variable "do_token" {
  description = "DigitalOcean API token (read/write)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for Droplet access"
  type        = string
}

variable "admin_ip" {
  description = "Admin IP/CIDR allowed SSH access. Do NOT use 0.0.0.0/0 in production."
  type        = string
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

variable "spaces_access_key_id" {
  description = "DO Spaces access key (for backup bucket)"
  type        = string
  sensitive   = true
}

variable "spaces_secret_access_key" {
  description = "DO Spaces secret key (for backup bucket)"
  type        = string
  sensitive   = true
}
