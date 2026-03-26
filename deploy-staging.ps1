$NAMESPACE = "odoo-staging"
$DEPLOYMENT = "odoo-staging"
$FILESTORE_LOCAL = ".\filestore\odoo"
$FILESTORE_REMOTE = "/var/lib/odoo/filestore/odoo"

Write-Host "`n[1/9] Connecting to AKS..." -ForegroundColor Cyan
az aks get-credentials --resource-group e08g04t07production-RG --name e08g04t07production --admin --overwrite-existing

Write-Host "`n[2/9] Applying all K8s manifests..." -ForegroundColor Cyan
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
kubectl -n $NAMESPACE apply -f k8s/ingress.yaml

Write-Host "`n[3/9] Waiting for PostgreSQL to be ready..." -ForegroundColor Cyan
kubectl -n $NAMESPACE rollout status deployment/postgres --timeout=120s

Write-Host "`n[4/9] Waiting for Odoo pods to be ready..." -ForegroundColor Cyan
kubectl -n $NAMESPACE rollout status deployment/$DEPLOYMENT --timeout=300s

Write-Host "`n[5/9] Verifying filestore local file count..." -ForegroundColor Cyan
$localCount = (Get-ChildItem -Recurse -File $FILESTORE_LOCAL).Count
Write-Host "  Local filestore file count: $localCount"
if ($localCount -lt 100) {
    Write-Host "  WARNING: Filestore looks incomplete (< 100 files). Check your filestore.tar.gz!" -ForegroundColor Red
    $continue = Read-Host "  Continue anyway? (YES/NO)"
    if ($continue -ne "YES") { exit 1 }
}

Write-Host "`n[6/9] Copying filestore into pod..." -ForegroundColor Cyan
$POD = kubectl -n $NAMESPACE get pods -l app=$DEPLOYMENT -o jsonpath="{.items[0].metadata.name}"
Write-Host "  Target pod: $POD"
kubectl -n $NAMESPACE exec -it $POD -- mkdir -p $FILESTORE_REMOTE
kubectl -n $NAMESPACE exec -it $POD -- chown -R odoo:odoo /var/lib/odoo/
kubectl -n $NAMESPACE cp $FILESTORE_LOCAL\. ${POD}:${FILESTORE_REMOTE}/

Write-Host "`n[7/9] Verifying filestore in pod..." -ForegroundColor Cyan
$podCount = kubectl -n $NAMESPACE exec -it $POD -- bash -c "find $FILESTORE_REMOTE -type f | wc -l"
Write-Host "  Pod filestore file count: $podCount"
if ([int]($podCount -replace '\D','') -lt $localCount) {
    Write-Host "  WARNING: Pod has fewer files than local. Copy may be incomplete!" -ForegroundColor Yellow
}

Write-Host "`n[8/9] Clearing stale asset bundles from DB..." -ForegroundColor Cyan
$PGPOD = kubectl -n $NAMESPACE get pods -l app=postgres -o jsonpath="{.items[0].metadata.name}"
kubectl -n $NAMESPACE exec -it $PGPOD -- psql -U odoo -d odoo -c "DELETE FROM ir_attachment WHERE url LIKE '/web/assets/%' OR name LIKE '%.min.css' OR name LIKE '%.min.js';"

Write-Host "  Restarting Odoo to regenerate assets..." -ForegroundColor Cyan
kubectl -n $NAMESPACE delete pod -l app=$DEPLOYMENT
kubectl -n $NAMESPACE rollout status deployment/$DEPLOYMENT --timeout=300s

Write-Host "`n[9/9] Enabling session affinity and verifying..." -ForegroundColor Cyan
kubectl -n $NAMESPACE patch service $DEPLOYMENT -p '{"spec":{"sessionAffinity":"ClientIP"}}'
kubectl -n $NAMESPACE get pods
kubectl -n $NAMESPACE get pvc
kubectl -n $NAMESPACE get ingress

Write-Host "`nDeployment complete!" -ForegroundColor Green
Write-Host "  URL: http://esmos-odoo-staging.eastasia.cloudapp.azure.com:8069" -ForegroundColor Green
Write-Host "  NOTE: First load will be slow (~30s) while Odoo regenerates CSS/JS assets." -ForegroundColor Yellow
Write-Host "  TIP: Test in incognito window to verify styling loads correctly." -ForegroundColor Yellow