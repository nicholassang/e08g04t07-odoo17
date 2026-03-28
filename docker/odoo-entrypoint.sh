#!/usr/bin/env bash
set -euo pipefail

is_true() {
    local value="${1:-}"
    value="$(echo "$value" | tr '[:upper:]' '[:lower:]')"
    [[ "$value" == "1" || "$value" == "true" || "$value" == "yes" || "$value" == "on" ]]
}

if [[ -z "${ODOO_DB_HOST:-}" ]]; then
    echo "ODOO_DB_HOST must be set."
    exit 1
fi

ODOO_DB_PORT="${ODOO_DB_PORT:-5432}"
ODOO_DB_USER="${ODOO_DB_USER:-odoo}"
ODOO_DB_PASSWORD="${ODOO_DB_PASSWORD:-odoo}"
ODOO_DB_NAME="${ODOO_DB_NAME:-odoo}"
ODOO_ADMIN_PASSWORD="${ODOO_ADMIN_PASSWORD:-admin}"
ODOO_DATA_DIR="${ODOO_DATA_DIR:-/var/lib/odoo}"
ODOO_HTTP_PORT="${ODOO_HTTP_PORT:-8069}"
ODOO_ADDONS_PATH="${ODOO_ADDONS_PATH:-/opt/odoo/custom/addons,/usr/lib/python3/dist-packages/odoo/addons}"
ODOO_REQUIRED_MODULES="${ODOO_REQUIRED_MODULES:-helpdesk_mgmt,helpdesk_mgmt_merge,helpdesk_mgmt_project,helpdesk_mgmt_sale,helpdesk_ticket_related,helpdesk_type}"
ODOO_CONFIG_FILE="${ODOO_CONFIG_FILE:-${ODOO_DATA_DIR}/odoo.conf}"

mkdir -p "$ODOO_DATA_DIR"

cat > "$ODOO_CONFIG_FILE" <<EOF
[options]
admin_passwd = ${ODOO_ADMIN_PASSWORD}
EOF

check_db_initialized() {
    local preflight_status

    if python3 - <<'PY'
import os
import sys

try:
    import psycopg2
except Exception:
    sys.exit(12)

conn_args = {
    "host": os.environ["ODOO_DB_HOST"],
    "port": int(os.environ["ODOO_DB_PORT"]),
    "user": os.environ["ODOO_DB_USER"],
    "password": os.environ["ODOO_DB_PASSWORD"],
    "dbname": os.environ["ODOO_DB_NAME"],
}

try:
    with psycopg2.connect(**conn_args) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT to_regclass('public.ir_module_module')")
            relation = cur.fetchone()[0]
            if relation is None:
                sys.exit(10)

            cur.execute("SELECT 1 FROM ir_module_module WHERE name='base' LIMIT 1")
            if cur.fetchone() is None:
                sys.exit(11)
except psycopg2.Error:
    sys.exit(13)
PY
    then
        return 0
    else
        preflight_status=$?
    fi

    case "$preflight_status" in
        10|11)
            echo "Odoo database preflight failed: database '${ODOO_DB_NAME}' exists but is not initialized."
            echo "This usually happens when an existing PostgreSQL volume skipped one-time init scripts in /docker-entrypoint-initdb.d."
            echo "To reseed local data, run:"
            echo "  docker compose down -v"
            echo "  docker compose up --build"
            ;;
        12)
            echo "Odoo database preflight failed: Python PostgreSQL driver is unavailable in the container."
            ;;
        13)
            echo "Odoo database preflight failed: unable to connect/query database '${ODOO_DB_NAME}' at ${ODOO_DB_HOST}:${ODOO_DB_PORT} with user '${ODOO_DB_USER}'."
            ;;
        *)
            echo "Odoo database preflight failed with unexpected status code: ${preflight_status}."
            ;;
    esac

    return 1
}

check_db_initialized

check_required_modules_available() {
    local preflight_status

    if python3 - <<'PY'
import os
import sys

try:
    import psycopg2
except Exception:
    sys.exit(31)

required_modules = [
    module.strip()
    for module in os.environ.get("ODOO_REQUIRED_MODULES", "").split(",")
    if module.strip()
]
if not required_modules:
    sys.exit(0)

addons_paths = [
    addon_path.strip()
    for addon_path in os.environ.get("ODOO_ADDONS_PATH", "").split(",")
    if addon_path.strip()
]

available_modules = {
    module
    for module in required_modules
    if any(os.path.isdir(os.path.join(addon_path, module)) for addon_path in addons_paths)
}

conn_args = {
    "host": os.environ["ODOO_DB_HOST"],
    "port": int(os.environ["ODOO_DB_PORT"]),
    "user": os.environ["ODOO_DB_USER"],
    "password": os.environ["ODOO_DB_PASSWORD"],
    "dbname": os.environ["ODOO_DB_NAME"],
}

try:
    with psycopg2.connect(**conn_args) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT name FROM ir_module_module WHERE state='installed' AND name = ANY(%s)",
                (required_modules,),
            )
            installed_required_modules = {row[0] for row in cur.fetchall()}
except psycopg2.Error:
    sys.exit(32)

missing_modules = sorted(installed_required_modules - available_modules)
if missing_modules:
    sys.stderr.write(
        "Missing installed modules in ODOO_ADDONS_PATH: "
        + ", ".join(missing_modules)
        + "\n"
    )
    sys.stderr.write("ODOO_ADDONS_PATH=" + ",".join(addons_paths) + "\n")
    sys.exit(33)
PY
    then
        return 0
    else
        preflight_status=$?
    fi

    case "$preflight_status" in
        31)
            echo "Odoo module preflight failed: Python PostgreSQL driver is unavailable in the container."
            ;;
        32)
            echo "Odoo module preflight failed: unable to query installed modules from database '${ODOO_DB_NAME}'."
            ;;
        33)
            echo "Odoo module preflight failed: one or more installed modules are missing from ODOO_ADDONS_PATH."
            echo "Add the missing module sources or update ODOO_REQUIRED_MODULES."
            ;;
        *)
            echo "Odoo module preflight failed with unexpected status code: ${preflight_status}."
            ;;
    esac

    return 1
}

check_required_modules_available

odoo_args=(
    "--config=${ODOO_CONFIG_FILE}"
    "--db_host=${ODOO_DB_HOST}"
    "--db_port=${ODOO_DB_PORT}"
    "--db_user=${ODOO_DB_USER}"
    "--db_password=${ODOO_DB_PASSWORD}"
    "--database=${ODOO_DB_NAME}"
    "--data-dir=${ODOO_DATA_DIR}"
    "--http-port=${ODOO_HTTP_PORT}"
    "--addons-path=${ODOO_ADDONS_PATH}"
)

if is_true "${ODOO_PROXY_MODE:-true}"; then
    odoo_args+=("--proxy-mode")
fi

if ! is_true "${ODOO_LIST_DB:-false}"; then
    odoo_args+=("--no-database-list")
fi

if [[ -n "${ODOO_EXTRA_ARGS:-}" ]]; then
    # Intentional word splitting to support passing multiple CLI flags via ODOO_EXTRA_ARGS.
    # shellcheck disable=SC2206
    extra_args=( ${ODOO_EXTRA_ARGS} )
    odoo_args+=("${extra_args[@]}")
fi

exec odoo server "${odoo_args[@]}" "$@"
