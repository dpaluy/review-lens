terraform {
  required_version = ">= 1.8"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token

  # Spaces operations (digitalocean_spaces_bucket) require a Spaces access key,
  # even though the DO API token can create the key itself. This creates a
  # bootstrapping cycle, so the Spaces key is created once via the DO API
  # (digitalocean_spaces_key), stored to 1Password, and supplied here on
  # subsequent runs. On the very first run, set SPACES_ACCESS_ID/SPACES_SECRET_KEY
  # to empty strings; the key resource will create them and the script stores
  # them to 1Password before the bucket is created.
  spaces_access_id  = var.spaces_access_id
  spaces_secret_key = var.spaces_secret_key
  spaces_endpoint   = "https://${var.spaces_region}.digitaloceanspaces.com"
}
