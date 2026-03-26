param(
    [switch]$hardReset,
    [switch]$fixAssets
)

$NAMESPACE = "odoo-prod"
$DEPLOYMENT = "odoo-prod"

Write-Host "`n[1] Connecting to AKS..." -ForegroundColor Cyan
az aks get-credentials --resource-group e08g04t07production-RG --name e08g04t07production --admin --overwrite-existing

# ── Fix Assets Only (no rollback) ─────────────────────────────
if ($fixAssets) {
    Write-Host "`n[FIX ASSETS] Clearing stale asset bundles..." -ForegroundColor Yellow
    $PGPOD = kubectl -n $NAMESPACE get pods -l app=postgres -o jsonpath="{.items[0].metadata.name}"
    kubectl -n $NAMESPACE exec -it $PGPOD -- psql -U odoo -d odoo -c "DELETE FROM ir_attachment WHERE url LIKE '/web/assets/%' OR name LIKE '%.min.css' OR name LIKE '%.min.js';"

    Write-Host "  Restarting Odoo to regenerate assets..." -ForegroundColor Yellow
    kubectl -n $NAMESPACE delete pod -l app=$DEPLOYMENT
    kubectl -n $NAMESPACE rollout status deployment/$DEPLOYMENT --timeout=300s

    Write-Host "`nAsset fix complete. Test in incognito: http://esmos-odoo-prod.eastasia.cloudapp.azure.com:8069" -ForegroundColor Green
    exit 0
}

# ── Hard Reset ─────────────────────────────────────────────────
if ($hardReset) {
    Write-Host "`n[HARD RESET] This will destroy ALL data including PVCs!" -ForegroundColor Red
    $confirm = Read-Host "  Type YES to confirm"
    if ($confirm -ne "YES") {
        Write-Host "  Cancelled." -ForegroundColor Green
        exit 0
    }
    kubectl -n $NAMESPACE delete deployment $DEPLOYMENT
    kubectl -n $NAMESPACE delete deployment postgres
    kubectl -n $NAMESPACE delete service $DEPLOYMENT
    kubectl -n $NAMESPACE delete service postgres
    kubectl -n $NAMESPACE delete ingress --all
    kubectl -n $NAMESPACE delete pvc --all
    kubectl -n $NAMESPACE delete configmap --all
    kubectl -n $NAMESPACE delete secret --all
    Write-Host "`nHard reset complete. Run .\deploy-staging.ps1 to redeploy." -ForegroundColor Red
    exit 0
}

# ── Soft Rollback (default) ────────────────────────────────────
Write-Host "`n[2] Rollout history:" -ForegroundColor Cyan
kubectl -n $NAMESPACE rollout history deployment/$DEPLOYMENT

Write-Host "`n[3] Rolling back to previous version..." -ForegroundColor Yellow
kubectl -n $NAMESPACE rollout undo deployment/$DEPLOYMENT
kubectl -n $NAMESPACE rollout status deployment/$DEPLOYMENT --timeout=300s

Write-Host "`n[4] Clearing asset cache after rollback..." -ForegroundColor Cyan
$PGPOD = kubectl -n $NAMESPACE get pods -l app=postgres -o jsonpath="{.items[0].metadata.name}"
kubectl -n $NAMESPACE exec -it $PGPOD -- psql -U odoo -d odoo -c "DELETE FROM ir_attachment WHERE url LIKE '/web/assets/%' OR name LIKE '%.min.css' OR name LIKE '%.min.js';"

kubectl -n $NAMESPACE delete pod -l app=$DEPLOYMENT
kubectl -n $NAMESPACE rollout status deployment/$DEPLOYMENT --timeout=300s
kubectl -n $NAMESPACE get pods

Write-Host "`nRollback complete!" -ForegroundColor Green
Write-Host "  To rollback to a specific revision:" -ForegroundColor Yellow
Write-Host "  kubectl -n $NAMESPACE rollout undo deployment/$DEPLOYMENT --to-revision=<NUMBER>"