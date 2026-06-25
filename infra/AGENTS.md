# infra/

DigitalOcean infrastructure-as-code for ReviewLens.

## Stack

- **OpenTofu** (`digitalocean` provider): Droplet, firewall, DO Spaces bucket.
- **Ansible**: Docker install, OS hardening, Postgres backup cron.
- **Kamal** is driven from the repo root (`config/deploy.yml`); this directory
  only prepares the host and prints the IP that Kamal deploys to.

## Conventions

- All secrets are read from the environment or `terraform.tfvars` (git-ignored).
  Never hardcode tokens, passwords, or Spaces keys in tracked files.
- `admin_ip` must be a real operator CIDR. `0.0.0.0/0` for SSH is rejected in
  review, do not weaken it.
- Postgres runs as a Kamal accessory on `127.0.0.1`; the firewall does NOT open
  5432. Backups go to DO Spaces via `pg_dump`, never Litestream (SQLite-only).

## Adding a resource

1. Add the `.tf` resource in the smallest applicable file (server/network/storage).
2. Add outputs to `outputs.tf` only if the deploy or provision script needs them.
3. If the host needs new software or config, add it to `ansible/playbook.yml`,
   not to `config/deploy.yml`.
