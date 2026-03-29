param(
    [string]$Namespace = "odoo-prod",
    [string]$ManifestPath = ".\k8s\hpa.yaml",
    [switch]$Rollback
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}

kubectl apply -f $ManifestPath


$pgPod = kubectl get pods -n $Namespace -l $PostgresPodLabel -o jsonpath="{.items[0].metadata.name}"

if (-not $pgPod) {
    throw "No PostgreSQL pod found in namespace '$Namespace' with label '$PostgresPodLabel'"
}


$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = "$BackupDir/backup-$timestamp.sql"


kubectl exec -n $Namespace $pgPod -- sh -c "mkdir -p $BackupDir && pg_dump -U $DbUser -d $DbName > $backupFile"


kubectl exec -n $Namespace $pgPod -- sh -c "ls -lh $backupFile"
