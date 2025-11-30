<#
.SYNOPSIS
    Script de création de la tâche planifiée pour la sauvegarde Full Server hebdomadaire.

.DESCRIPTION
    Ce script crée une tâche planifiée exécutant le script de backup
    Run_WeeklyFullBackup.ps1 tous les dimanches à 02h00.

.PARAMETER BackupVolume
    Lettre du volume où les sauvegardes seront stockées (ex: "B:").

.PARAMETER BackupScriptPath
    Chemin complet du script Run_WeeklyFullBackup.ps1.

.EXAMPLE
    .\Setup_WeeklyFullBackup.ps1 -BackupVolume "B:" -BackupScriptPath "C:\Scripts\Run_WeeklyFullBackup.ps1"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$BackupVolume,

    [Parameter(Mandatory = $true)]
    [string]$BackupScriptPath
)

# --- Vérification du chemin du script ---
if (-not (Test-Path $BackupScriptPath)) {
    Write-Host "Le script spécifié n'existe pas : $BackupScriptPath" -ForegroundColor Red
    exit 1
}

# --- Vérification du volume ---
if (-not (Test-Path $BackupVolume)) {
    Write-Host "Volume $BackupVolume introuvable..." -ForegroundColor Red
    exit 1
}

Import-Module ServerManager -ErrorAction SilentlyContinue

# --- Installation de Windows Server Backup si nécessaire ---
if (-not (Get-WindowsFeature -Name Windows-Server-Backup).Installed) {
    Write-Host "Installation de la fonctionnalité Windows Server Backup..." -ForegroundColor Cyan
    Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools
    Write-Host "Installation terminée." -ForegroundColor Green
} else {
    Write-Host "Windows Server Backup déjà installé." -ForegroundColor Green
}

# --- Création de la tâche planifiée ---
Write-Host "`nCréation de la tâche planifiée Weekly Full Backup..." -ForegroundColor Cyan

$Action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$BackupScriptPath`" -BackupVolume $BackupVolume"

$Trigger = New-ScheduledTaskTrigger `
    -Weekly -DaysOfWeek Sunday -At 02:00AM

Register-ScheduledTask `
    -Action $Action `
    -Trigger $Trigger `
    -TaskName "FullServerBackupWeekly" `
    -Description "Sauvegarde Full Server hebdomadaire (dimanche 2h00)" `
    -User "SYSTEM" `
    -RunLevel Highest `
    -Force

Write-Host "Tâche planifiée Weekly Full Backup créée avec succès !" -ForegroundColor Green
