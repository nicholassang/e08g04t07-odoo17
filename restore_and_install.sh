#!/bin/bash
set -e

# --- Arguments ---
DB_USER="$1"     # e.g., odoo
DB_NAME="$2"     # e.g., odoo
SQL_FILE="$3"    # e.g., /path/to/your/backup.sql

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo "Error: SQL file not found at $SQL_FILE"
    exit 1
fi

echo "Restoring PostgreSQL database..."
echo "DB_USER=$DB_USER, DB_NAME=$DB_NAME, SQL_FILE=$SQL_FILE"

# Start the database container if not running
docker-compose up -d db

# Wait for DB to be ready
sleep 5

# Call the existing restore script
./restore_db.sh $DB_USER $DB_NAME $SQL_FILE

echo "Database restored successfully."

# Start all services
docker-compose up -d

# Wait for Odoo to be ready (adjust time as needed)
echo "Waiting for Odoo to start..."
sleep 30

# Stop the web service for module installation
docker-compose stop web

# Install the helpdesk module
echo "Installing helpdesk_mgmt module..."
docker-compose run --rm web odoo -d $DB_NAME -i helpdesk_mgmt --stop-after-init

# Start the web service again
docker-compose start web

echo "Database restored and helpdesk module installed. Odoo should be accessible at http://localhost:8069"