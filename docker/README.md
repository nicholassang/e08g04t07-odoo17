Docker quickstart for this repository

Prerequisites
- Docker and Docker Compose v2 installed
- The repository root contains `odoo.sql.gz` (export of your current DB) or an uncompressed `odoo.sql`.

Prepare initial database

From the repository root run:

```bash
./docker/prepare-initdb.sh
```

This creates `docker/initdb/odoo.sql` by decompressing `odoo.sql.gz`. The Postgres official image will automatically run any `*.sql` files in `/docker-entrypoint-initdb.d/` on first container initialization.

Start services

```bash
docker compose -f docker/docker-compose.yml up -d
```

Verify helpdesk module installation

To install the required `helpdesk_mgmt` module on the restored DB, run:

```bash
docker compose run --rm odoo -d odoo -i helpdesk_mgmt --stop-after-init
```

Notes
- Uses `postgres:16` as required.
- Uses official `odoo:17` image to keep the compose file minimal. If you want a custom image that bakes in private addons, add a `Dockerfile` under `docker/` and update the `odoo` service to `build: ./docker`.
- Do not commit `odoo.sql` or `odoo.sql.gz` into the final image or Docker Hub; decompress in CI pipeline then publish images without the dump.
