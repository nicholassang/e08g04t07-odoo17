#!/usr/bin/env bash
set -euo pipefail

OD_SERVICE="odoo17"
LIVE_DIR="/opt/odoo17/odoo17"
TEMP_DIR="/home/is214/deploy-temp"
VENV_DIR="/opt/odoo17/odoo17-venv"
ODOO_USER="odoo17"

echo "[1] Stop Odoo"
sudo systemctl stop ${OD_SERVICE}

echo "[2] Copy updated code (no delete, safe merge)"
sudo cp -rT --no-preserve=ownership "${TEMP_DIR}/" "${LIVE_DIR}/"

echo "[3] Install updated requirements (if exists)"
if [ -f "${LIVE_DIR}/requirements.txt" ]; then
    sudo -u ${ODOO_USER} bash -lc "
        source ${VENV_DIR}/bin/activate &&
        pip install --upgrade pip -q --disable-pip-version-check &&
        pip install -r ${LIVE_DIR}/requirements.txt \
            --upgrade --upgrade-strategy only-if-needed \
            --disable-pip-version-check -q
    "
fi

echo "[4] Fix file ownership"
sudo chown -R ${ODOO_USER}:${ODOO_USER} ${LIVE_DIR}

echo "[5] Start Odoo"
sudo systemctl start ${OD_SERVICE}

echo "Deployment complete."
