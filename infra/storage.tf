# DO Spaces bucket for pg_dump backups. PostgreSQL cannot use Litestream
# (SQLite-only), so we ship compressed pg_dump archives to Spaces instead
# (see infra/ansible/files/pg_backup.sh, run via cron on the Droplet).
resource "aws_s3_bucket" "backups" {
  provider = aws.spaces
  bucket   = "${var.project_name}-backups"
}

resource "aws_s3_bucket_versioning" "backups" {
  provider = aws.spaces
  bucket   = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Expire daily backups after 30 days; keep weekly snapshots longer via versions.
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  provider = aws.spaces
  bucket   = aws_s3_bucket.backups.id

  rule {
    id     = "expire-dumps"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
