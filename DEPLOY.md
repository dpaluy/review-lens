# Deployment Guide

ReviewLens deploys to DigitalOcean with Kamal 2: a single Droplet runs the web
server (Puma behind kamal-proxy) and a dedicated Solid Queue worker, plus a
PostgreSQL accessory for the four Rails databases (primary + Cache/Queue/Cable).

## Prerequisites

- DigitalOcean account with API token (read/write). Create one at
  https://cloud.digitalocean.com/account/api/tokens.
- `doctl` CLI authenticated (`doctl auth init`).
- `kamal` 2.x installed locally (`gem install kamal`).
- A domain name you control, with DNS access.

## 1. Provision a DigitalOcean Droplet

Kamal 2 installs Docker and kamal-proxy itself over SSH, so a plain Ubuntu image
is enough. Create a 2 GB / 1 vCPU Droplet (minimum; 4 GB recommended for builds):

```bash
doctl compute droplet create reviewlens \
  --region nyc1 \
  --image ubuntu-24-04-x64 \
  --size s-2vcpu-4gb \
  --ssh-keys <your-ssh-key-fingerprint> \
  --enable-monitoring \
  --tag-name reviewlens
```

Record the public IP:

```bash
doctl compute droplet get reviewlens --template "{{.PublicIPv4}}"
```

Add an **A record** pointing your domain (e.g. `reviewlens.example.com`) at this
IP. Configure a DigitalOcean Cloud Firewall (or UFW) to allow inbound
`22`, `80`, `443` only.

## 2. Create the container registry

Kamal pushes the image to the DO Container Registry. The registry subscription
name must match the `image:` value in `config/deploy.yml` (`reviewlens`):

```bash
doctl registry create reviewlens
doctl registry login   # configures docker auth using your API token
```

## 3. Configure DNS + secrets

Export the deployment values (do this in every shell or CI runner that deploys):

```bash
export DEPLOY_HOST=203.0.113.10            # Droplet public IP
export DEPLOY_DOMAIN=reviewlens.example.com # your domain
export DIGITALOCEAN_API_TOKEN=dop_xxxxxxxx  # DO API token (also the registry password)
export POSTGRES_PASSWORD=$(openssl rand -hex 24)  # database password
export OPENAI_API_KEY=sk-xxxxxxxx
export OPENAI_MODEL=gpt-4o-mini            # optional, defaults to gpt-4o-mini
```

`config/master.key` already exists locally; Kamal reads it via `.kamal/secrets`.
Keep a backup of both `config/master.key` and `POSTGRES_PASSWORD` somewhere safe
(password manager). They are not in version control.

## 4. First deployment

```bash
bin/kamal setup    # installs Docker, boots accessories, deploys, enables SSL
```

`kamal setup` will:
1. Install Docker on the Droplet (if missing).
2. Start the `postgres:16` accessory and run `config/postgres/init.sql` to create
   the Cache/Queue/Cable databases.
3. Build and push the image to `registry.digitalocean.com/reviewlens`.
4. Launch the `web` and `job` roles.
5. Provision a Let's Encrypt certificate via kamal-proxy.

Verify: `curl -I https://reviewlens.example.com/up` should return `200 OK`.

## 5. Subsequent deploys and operations

```bash
bin/kamal deploy                 # build + push + rolling restart
bin/kamal redeploy               # redeploy last image without rebuilding
bin/kamal app containers         # list deployed versions
bin/kamal rollback <version>     # roll back to a prior version

bin/kamal console                # Rails console on the server
bin/kamal logs                   # tail web logs
bin/kamal job-logs               # tail Solid Queue worker logs
bin/kamal accessory logs db      # tail Postgres logs
bin/kamal dbc                    # Rails dbconsole
```

## Database topology

A single Postgres instance hosts four databases:

| Connection | Database                        | Used by           |
|------------|---------------------------------|-------------------|
| primary    | `review_lens_production`        | ApplicationRecord |
| cache      | `review_lens_production_cache`  | Solid Cache       |
| queue      | `review_lens_production_queue`  | Solid Queue       |
| cable      | `review_lens_production_cable`  | Solid Cable       |

Connection URLs are built in `.kamal/secrets` from `POSTGRES_PASSWORD` +
`DB_HOST` (the on-droplet accessory `review_lens-db`). Postgres is bound to
`127.0.0.1:5432` so it is never reachable from the public internet.

### Upgrading to a managed database (recommended for production)

For higher durability and automated backups, replace the accessory with a
DigitalOcean Managed PostgreSQL cluster:

1. Create the cluster and a `review_lens` database/user via `doctl` or the
   control panel.
2. Create the three extra databases (`_cache`, `_queue`, `_cable`) on it.
3. Set `DB_HOST` to the managed cluster host and `POSTGRES_PASSWORD` to the
   managed user password.
4. Remove the `accessories: db` block from `config/deploy.yml`.
5. Redeploy.

## Secrets handling

- `config/master.key`, `.kamal/secrets`, and any `*_DATABASE_URL` are
  **git-ignored** and excluded from the Docker image via `.dockerignore`.
- All deployment secrets are read from the operator's environment, never
  committed. In CI, inject them as masked variables.

## Apple Silicon build note

Building an `amd64` image on an arm64 Mac goes through QEMU and is slow. For
faster native builds, add a remote builder (a small amd64 Droplet with Docker):

```yaml
builder:
  arch: amd64
  remote: ssh://root@<builder-ip>
```
