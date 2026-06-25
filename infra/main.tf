terraform {
  required_version = ">= 1.8"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# DO Spaces is S3-compatible. The AWS provider lets us manage the bucket as
# infrastructure. Use the region-specific endpoint (e.g. nyc3).
provider "aws" {
  alias  = "spaces"

  region = var.spaces_region

  access_key = var.spaces_access_key_id
  secret_key = var.spaces_secret_access_key

  endpoints {
    s3 = "https://${var.spaces_region}.digitaloceanspaces.com"
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
}
