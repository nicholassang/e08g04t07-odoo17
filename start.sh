#!/bin/bash

# Start PostgreSQL
service postgresql start

# Wait for DB
sleep 5

# Start Odoo
odoo --db_host=localhost --db_user=odoo --db_password=odoo