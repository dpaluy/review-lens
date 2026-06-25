# ReviewLens Infrastructure

OpenTofu + Ansible infrastructure for deploying ReviewLens on DigitalOcean
with Kamal. PostgreSQL (not SQLite), so backups use `pg_dump` to DO Spaces
rather than Litestream.

```
┌──────────────────────────────────────────────────────────────┐
│                     DigitalOcean                             │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Droplet (Ubuntu 24.04, s-2vcpu-4gb)                   │  │
│  │  Firewall: 22 (admin IP) / 80 / 443                    │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌────────────────┐  │  │
│  │  │ web (Puma)   │ │ job (SQ)     │ │ postgres:16    │  │  │
│  │  │ kamal-proxy  │ │ bin/jobs     │ │ 127.0.0.1:5432 │  │  │
│  │  └──────┬───────┘ └──────┬───────┘ └────────┬───────┘  │  │
│  │         └──── volumes ────┴──────────────────┘          │  │
│  │  cron 02:00 UTC: pg_dump -> DO Spaces                   │  │
│  └────────────────────────────────────────────────────────┘  │
│                          │                                    │
│  ┌───────────────────────▼────────────────────────────────┐  │
│  │  DO Spaces: reviewlens-backups                          │  │
│  │  postgres/<stamp>.tar.gz (4 DBs, 30-day expiry)         │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## Prerequisites

```bash
brew install opentofu ansible   # kamal already installed via Gemfile
```

Create a DigitalOcean API token (read/write), a Spaces bucket key pair, and an
SSH key. Put the values in `terraform.tfvars` (git-ignored) or export them:

```bash
cat > infra/terraform.tfvars <<EOF
do_token               = "dop_xxxxxxxx"
ssh_public_key         = "$(cat ~/.ssh/id_ed25519.pub)"
admin_ip               = "203.0.113.5/32"   # YOUR IP, not 0.0.0.0/0
spaces_region          = "nyc3"
spaces_access_key_id   = "..."
spaces_secret_access_key = "..."
EOF
```

Also export for the deploy/config steps:

```bash
export OP_ACCOUNT=my.1password.com
export DEPLOY_DOMAIN=app.cairnfoundry.com
export ADMIN_IP=203.0.113.5/32   # your IP in CIDR
```

Secrets (DO token, Postgres password, OpenAI key, Spaces keys, Rails master
key) are pulled from 1Password by `.kamal/secrets` and `infra/bin/provision`.
Create the items listed in `DEPLOY.md` step 3.

## Provisioning

```bash
infra/bin/provision            # infra + config + deploy (all)
infra/bin/provision --infra    # OpenTofu only
infra/bin/provision --config   # Ansible hardening + backup cron
infra/bin/provision --deploy   # kamal setup
```

`--infra` prints the Droplet IP. Point DNS at it before `--deploy` (kamal-proxy
needs the domain for the Let's Encrypt certificate).

## Files

| File | Purpose |
|------|---------|
| `main.tf` | Providers (digitalocean, aws for Spaces) |
| `server.tf` | Droplet + SSH key + cloud-config |
| `network.tf` | Firewall (22 admin-only, 80/443 open) |
| `storage.tf` | DO Spaces backup bucket + lifecycle |
| `variables.tf` | Input variables |
| `outputs.tf` | Server IPs, bucket, next steps |
| `ansible/playbook.yml` | Docker + hardening + backup cron |
| `ansible/files/pg_backup.sh` | pg_dump -> Spaces script |
| `bin/provision` | Orchestration |

## Backup and restore

Backups run nightly at 02:00 UTC (Ansible cron). Each archive contains all four
Postgres databases (primary + cache/queue/cable) as `pg_dump -Fc` custom format.

### Restore

```bash
# Download the archive
aws s3 cp s3://reviewlens-backups/postgres/<stamp>.tar.gz . \
  --endpoint-url https://nyc3.digitaloceanspaces.com

# Stop the app, then restore each DB into the accessory container
tar xzf <stamp>.tar.gz
for db in review_lens_production review_lens_production_cache \
          review_lens_production_queue review_lens_production_cable; do
  docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" review_lens-db \
    pg_restore -U review_lens -d "$db" --clean --if-exists < "${db}-<stamp>.dump"
done

kamal deploy   # restart
```

## Security notes

- SSH is restricted to `admin_ip` at the firewall. Do not set `0.0.0.0/0`.
- Password auth disabled; key-only; root login is `prohibit-password`.
- fail2ban bans after 3 failed attempts.
- Postgres binds to `127.0.0.1` only, never exposed publicly.
- `unattended-upgrades` applies security patches automatically.
- Secrets (tfvars, state, `.kamal/secrets`, `master.key`) are git-ignored.
