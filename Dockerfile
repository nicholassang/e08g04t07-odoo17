FROM odoo:17

USER root

# Install PostgreSQL
RUN apt-get update && apt-get install -y postgresql

# Create PostgreSQL user + DB
RUN service postgresql start && \
    su postgres -c "psql -c \"CREATE USER odoo WITH PASSWORD 'odoo';\"" && \
    su postgres -c "createdb -O odoo odoo"

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]