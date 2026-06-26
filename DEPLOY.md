# Deployment Guide

ReviewLens deploys to DigitalOcean with Kamal 2: a single Droplet runs the web
server (Puma behind kamal-proxy) and a dedicated Solid Queue worker, plus a
PostgreSQL accessory for the four Rails databases (primary + Cache/Queue/Cable).

## Prerequisites

- DigitalOcean account with API token (read/write). Create one at
  https://cloud.digitalocean.com/account/api/tokens.
- A 1Password vault with the deployment secrets (see `.kamal/secrets` for the
  exact `op://` references). The `op` CLI must be installed and signed in.
- `doctl` CLI authenticated (`doctl auth init`) for one-off manual operations.
- `kamal` 2.x (`gem install kamal`), `opentofu`, and `ansible` for the
  declarative provisioner (see `infra/`).
- A domain name with DNS access. This project targets `app.cairnfoundry.com`.

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

Add an **A record** pointing your domain (`app.cairnfoundry.com`) at this
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

Secrets are loaded lazily by `infra/bin/provision` depending on the step.
Only two items must exist up front; the rest are created during provisioning.

**Required up front (create in the `reviewlens` vault):**

| Item reference | Value |
|----------------|-------|
| `reviewlens/digitalocean/credential` | DO API token (read/write) |
| `reviewlens/production-rails/production_key` | contents of `config/credentials/production.key` |

**Created during provisioning (do not create manually):**

| Item reference | When | How |
|----------------|------|-----|
| `reviewlens/production-postgres/password` | first `--deploy` | `infra/bin/provision` generates it and stores it |
| `reviewlens/digitalocean-spaces/access_key_id` | after `--infra` | you generate Spaces keys in the DO console and store them |
| `reviewlens/digitalocean-spaces/secret_access_key` | after `--infra` | you generate Spaces keys in the DO console and store them |

OpenAI key is NOT a deploy secret. It lives in `config/credentials/production.yml.enc`
and is read at runtime by the app.

Then export the deployment values used by the provisioner:

```bash
export OP_ACCOUNT=HOPQBD5OXZDG7M6WBMJPF6RKRI   # david@paluy.org
export ADMIN_IP=203.0.113.5/32   # your IP in CIDR, for SSH firewall
```

The Kamal target host and proxy domain are fixed in `config/deploy.yml` as
`app.cairnfoundry.com`. Make sure its DNS A record points at the Droplet.

Kamal reads the rest from 1Password when it sources `.kamal/secrets`. Keep a
backup of `config/master.key` and the Postgres password somewhere safe; they
are not in version control.

## 4. First deployment

Use the provisioner so secrets are handled in the right order:

```bash
infra/bin/provision --infra    # 1. create droplet + firewall + Spaces bucket
# 2. MANUAL: generate Spaces keys in DO console, store to 1Password
infra/bin/provision --config   # 3. harden droplet, install Docker, backup cron
infra/bin/provision --deploy   # 4. generate PG password, kamal setup
```

Or, for Kamal-only deploys after the droplet exists, source the 1Password
account first. Kamal reads the remaining secrets from `.kamal/secrets`, including
`POSTGRES_PASSWORD` for the Postgres accessory and
`REVIEW_LENS_DATABASE_PASSWORD` for Rails:

```bash
export OP_ACCOUNT=HOPQBD5OXZDG7M6WBMJPF6RKRI
bin/kamal setup
```

`kamal setup` will:
1. Install Docker on the Droplet (if missing).
2. Start the `postgres:16` accessory and run `config/postgres/init.sql` to create
   the Cache/Queue/Cable databases.
3. Build and push the image to `registry.digitalocean.com/reviewlens`.
4. Launch the `web` and `job` roles.
5. Provision a Let's Encrypt certificate via kamal-proxy.

Verify: `curl -I https://app.cairnfoundry.com/up` should return `200 OK`.

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

### Registry quota recovery

If deploy fails while pushing the image with `denied: quota exceeded`, the
DigitalOcean Container Registry is full before Kamal can publish the new image.
Kamal runs `.kamal/hooks/pre-build`, which prunes old registry manifests and
waits for DigitalOcean garbage collection before every build.

To run the same recovery manually:

```bash
export OP_ACCOUNT=HOPQBD5OXZDG7M6WBMJPF6RKRI
export DIGITALOCEAN_API_TOKEN=$(op read "op://reviewlens/digitalocean/credential" --account "$OP_ACCOUNT")
bin/prune-docr-repository
bin/kamal deploy
```

The prune script uses the DigitalOcean API directly, keeps the newest tagged
manifest in `registry.digitalocean.com/reviewlens/review_lens`, deletes older
or untagged manifests, then starts DigitalOcean garbage collection with untagged
manifests included and waits for it to finish. Change the retention window with
`DOCR_KEEP_MANIFESTS=3`. If the registry tier is too small to hold the retained
image and the next pushed image at the same time, use `DOCR_KEEP_MANIFESTS=0`
for the next deploy. Preview without deleting with
`DRY_RUN=1 bin/prune-docr-repository`.

DigitalOcean requires garbage collection after deleting old manifests before
registry storage is actually reclaimed. The hook waits because pushing while
garbage collection is still active or unreclaimed can still fail with quota
errors.

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
