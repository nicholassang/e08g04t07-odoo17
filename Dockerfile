# --- Odoo 17 Custom Image ---------------------------------------------------
# Base: Official Odoo 17.0 (Debian Bookworm, Python 3.11, all system deps)
FROM odoo:17.0

USER root

# Install extra Python packages not present in official base
# num2words and xlwt are referenced in requirements.txt for report generation
RUN pip3 install --no-cache-dir num2words xlwt

# Create directories for addons and filestore
RUN mkdir -p /mnt/extra-addons /mnt/odoo-addons \
    && chown -R odoo:odoo /mnt/extra-addons /mnt/odoo-addons \
    && chmod 755 /mnt/extra-addons /mnt/odoo-addons

# Copy custom addons into the image (lightweight; no secrets)
# The main Odoo source is already in the base image at /usr/lib/python3/dist-packages/odoo
# We only copy addons that are custom to this project
COPY --chown=odoo:odoo addons/ /mnt/odoo-addons/

# NOTE: odoo.conf is NOT baked in - it will be mounted as a ConfigMap in AKS.
# NOTE: Database credentials are NOT embedded - injected via K8s Secrets at runtime.

USER odoo

# Odoo web port
EXPOSE 8069
# Odoo long-polling port (needed for live chat / bus)
EXPOSE 8072

# Entrypoint and CMD are inherited from the official odoo:17.0 image
# Default: /entrypoint.sh -> odoo --config /etc/odoo/odoo.conf