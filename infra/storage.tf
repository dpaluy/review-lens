# DO Spaces bucket for pg_dump backups. The bucket is created in the DO Console
# (DigitalOcean Spaces API cannot bootstrap: a key cannot create a bucket it
# does not yet have access to). The Spaces key is also created in the Console
# and stored in 1Password; this resource imports/adopt it for lifecycle tracking.
#
# PostgreSQL cannot use Litestream (SQLite-only), so we ship compressed
# pg_dump archives to Spaces instead (infra/ansible/files/pg_backup.sh, run via
# cron on the Droplet).

resource "digitalocean_spaces_bucket" "backups" {
  name   = var.spaces_bucket
  region = var.spaces_region
  acl    = "private"
}
