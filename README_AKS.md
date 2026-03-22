# AKS + ACR + Azure DevOps deployment for Odoo

This branch adds Kubernetes manifests and Azure DevOps pipeline to run Odoo on AKS with ACR.

## 1. Prerequisites
- Azure subscription
- Azure CLI installed and logged in
- AKS cluster created
- ACR registry created
- Helm and kubectl installed (if using ingress or extra resources)
- Azure DevOps service connections (Azure Resource Manager) set up

## 2. Branch and pipeline
- Branch: `aks-acr-azuredevops`
- Pipeline file: `azure-pipelines-aks.yml`

### 2.1 Set pipeline variables in Azure DevOps
- `azureSubscription`: service connection name
- `azureResourceGroup`
- `aksClusterName`
- `acrName`

## 3. Kubernetes manifests
- `k8s/odoo-configmap.yaml` (odoo.conf)
- `k8s/odoo-secret.yaml` (odoo secrets)
- `k8s/odoo-pvc.yaml` (filestore/addons PVCs)
- `k8s/odoo-deployment.yaml` (odoo app)
- `k8s/odoo-service.yaml` (ClusterIP)
- `k8s/postgres-secret.yaml` (postgres credentials)
- `k8s/postgres-deployment.yaml` (postgres deployment + pvc)
- `k8s/postgres-service.yaml` (postgres ClusterIP)
- `k8s/ingress.yaml` (ingress rule for `odoo.example.com`)

## 4. Post-deploy
- Validate Pod status: `kubectl -n odoo get pods`
- Validate service: `kubectl -n odoo get svc`
- Validate ingress: `kubectl -n odoo get ingress`
- Update DNS for host

## 5. Notes
- In production use managed PostgreSQL (Azure Database for PostgreSQL) instead of in-cluster Postgres.
- Replace hardcoded secrets with Azure Key Vault or secure variable groups.
- Secure TLS certs via cert-manager where possible.
