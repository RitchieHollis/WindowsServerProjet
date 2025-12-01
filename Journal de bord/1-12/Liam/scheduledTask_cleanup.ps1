<#
.SYNOPSIS
    Crée une tâche planifiée qui exécute cleanup_backups.ps1 quotidiennement à 23h30.

.DESCRIPTION
    Ce script crée une tâche planifiée appelée "Cleanup-Backups"
    qui lance le script cleanup_backups.ps1 via PowerShell.
    La tâche tourne sous l’utilisateur SYSTEM pour éviter les problèmes d’authentification.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath
)

# --- Vérification du fichier ---
if (-not (Test-Path $ScriptPath)) {
    Write-Host "ERREUR : Le script $ScriptPath n'existe pas." -ForegroundColor Red
    exit
}

# --- Déclencheur à 23h30 ---
$trigger = New-ScheduledTaskTrigger -Daily -At "23:30"

# --- Action ---
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

# --- Exécution sous SYSTEM ---
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

# --- Nom de la tâche ---
$taskName = "Cleanup-Backups"

# --- Création ---
Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Principal $principal -Description "Nettoyage automatique des anciennes sauvegardes"

Write-Host "Tâche planifiée '$taskName' créée avec succès." -ForegroundColor Green
Write-Host "Elle s'exécutera tous les jours à 23:30." -ForegroundColor Cyan
