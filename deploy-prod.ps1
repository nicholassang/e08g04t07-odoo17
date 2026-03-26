param(
    [string]$targetImage = "theejr/odoo17:v1",
    [switch]$rolloutOnly
)

$NAMESPACE = "odoo-prod"
$DEPLOYMENT = "odoo-prod"
$FILESTORE_LOCAL = ".\filestore\odoo"
$FILESTORE_REMOTE = "/var/lib/odoo/filestore/odoo"
$RG = "esm-aks-rg"
$AKS = "esm-aks-sea-aks"

az aks get-credentials --resource-group $RG --name $AKS --admin --overwrite-existing

if ($rolloutOnly) {
    kubectl -n $NAMESPACE set image deployment/$DEPLOYMENT odoo-prod=$targetImage
    kubectl -n $NAMESPACE rollout status deployment/$DEPLOYMENT --timeout=300s
    $PGPOD = kubectl -n $NAMESPACE get pods -l app=postgres -o jsonpath="{.items[0].metadata.name}"
    kubectl -n $NAMESPACE exec -it $PGPOD -- psql -U odoo -d odoo -c "DELETE FROM ir_attachment WHERE url LIKE '/web/assets/%' OR name LIKE '%.min.css' OR name LIKE '%.min.js';"
    kubectl -n $NAMESPACE get pods
    kubectl -n $NAMESPACE rollout history deployment/$DEPLOYMENT
    exit 0
}

kubectl apply -f k8s/namespace.yaml
kubectl -n $NAMESPACE apply -f k8s/postgres-secret.yaml
kubectl -n $NAMESPACE apply -f k8s/odoo-secret.yaml
kubectl -n $NAMESPACE apply -f k8s/odoo-configmap.yaml
kubectl -n $NAMESPACE apply -f k8s/postgres-pvc.yaml
kubectl -n $NAMESPACE apply -f k8s/odoo-pvc.yaml
kubectl -n $NAMESPACE apply -f k8s/postgres-deployment.yaml
kubectl -n $NAMESPACE apply -f k8s/postgres-service.yaml
kubectl -n $NAMESPACE apply -f k8s/odoo-deployment.yaml
kubectl -n $NAMESPACE apply -f k8s/odoo-service.yaml
kubectl -n $NAMESPACE set image deployment/$DEPLOYMENT odoo-prod=$targetImage
kubectl -n $NAMESPACE rollout status deployment/postgres --timeout=120s
kubectl -n $NAMESPACE rollout status deployment/$DEPLOYMENT --timeout=300s

$POD = kubectl -n $NAMESPACE get pods -l app=$DEPLOYMENT -o jsonpath="{.items[0].metadata.name}"
kubectl -n $NAMESPACE exec -it $POD -- mkdir -p $FILESTORE_REMOTE
kubectl -n $NAMESPACE cp $FILESTORE_LOCAL\. ${POD}:${FILESTORE_REMOTE}/

$PGPOD = kubectl -n $NAMESPACE get pods -l app=postgres -o jsonpath="{.items[0].metadata.name}"
kubectl -n $NAMESPACE exec -it $PGPOD -- psql -U odoo -d odoo -c "DELETE FROM ir_attachment WHERE url LIKE '/web/assets/%' OR name LIKE '%.min.css' OR name LIKE '%.min.js';"
kubectl -n $NAMESPACE delete pod -l app=$DEPLOYMENT
kubectl -n $NAMESPACE rollout status deployment/$DEPLOYMENT --timeout=300s
kubectl -n $NAMESPACE get pods
kubectl -n $NAMESPACE get svc