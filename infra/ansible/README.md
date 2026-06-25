# Ansible: Droplet configuration

Hardens the Droplet, installs Docker, and schedules nightly Postgres backups
to a DigitalOcean Spaces bucket.

## Roles

```bash
ansible-galaxy install -r requirements.yml
```

## Run (usually via infra/bin/provision --config)

```bash
ansible-playbook -i "<SERVER_IP>," --user root playbook.yml \
  -e backup_bucket=reviewlens-backups \
  -e spaces_region=nyc3 \
  -e spaces_access_key_id=... \
  -e spaces_secret_access_key=... \
  -e db_password=...
```

## What it does

- Installs Docker CE + buildx/compose plugins.
- fail2ban SSH jail (3 retries, 1h ban).
- SSH hardening: key-only, no passwords, no root login, reduced keepalive.
- chrony NTP time sync.
- Kernel sysctl tuning (somaxconn, port range, file-max, swappiness).
- unattended-upgrades for automatic security patches.
- 2 GB swap (geerlingguy.swap).
- `awscli` + `/opt/reviewlens/pg_backup.sh` cron at 02:00 UTC, uploading
  compressed `pg_dump -Fc` archives (all four Rails DBs) to DO Spaces.
