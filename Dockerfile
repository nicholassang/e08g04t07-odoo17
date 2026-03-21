FROM odoo:17.0

# Switch to root user to perform administrative tasks
USER root

# Install additional Python packages
RUN pip3 install num2words xlwt

# Create necessary directories for Odoo
RUN mkdir -p /etc/odoo /mnt/extra-addons /var/lib/odoo/filestore

# Add the Odoo configuration file directly into the container
RUN touch /etc/odoo/odoo.conf
RUN echo "[options]" > /etc/odoo/odoo.conf && \
    echo "addons_path = /mnt/extra-addons" >> /etc/odoo/odoo.conf && \
    echo "data_dir = /var/lib/odoo" >> /etc/odoo/odoo.conf && \
    echo "db_host = db" >> /etc/odoo/odoo.conf && \
    echo "db_port = 5432" >> /etc/odoo/odoo.conf && \
    echo "db_user = odoo" >> /etc/odoo/odoo.conf && \
    echo "db_password = odoo" >> /etc/odoo/odoo.conf && \
    echo "limit_time_cpu = 600" >> /etc/odoo/odoo.conf && \
    echo "limit_time_real = 1200" >> /etc/odoo/odoo.conf && \
    echo "db_maxconn = 64" >> /etc/odoo/odoo.conf && \
    echo "workers = 2" >> /etc/odoo/odoo.conf && \
    echo "max_cron_threads = 1" >> /etc/odoo/odoo.conf && \
    echo "admin_passwd = 214Odoo"

# Set permissions for the created directories
RUN chown -R odoo:odoo /etc/odoo /mnt/extra-addons /var/lib/odoo/filestore

RUN chmod 755 /etc/odoo /mnt/extra-addons /var/lib/odoo/filestore

# Switch back to odoo user
USER odoo
