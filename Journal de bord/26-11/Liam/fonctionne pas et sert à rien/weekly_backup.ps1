<#
.SYNOPSIS
    Script de planification de la sauvegarde Full Server hebdomadaire.

.DESCRIPTION
    Ce script installe Windows Server Backup si nécessaire.
    Il crée une tâche planifiée exécutant une sauvegarde Full Server
    tous les dimanches à 02h00. La sauvegarde est stockée sur le volume spécifié.

.PARAMETER BackupVolume
    Lettre du volume où les sauvegardes seront stockées (ex: "B:").

.EXAMPLE
    .\WeeklyFullBackup.ps1 -BackupVolume "B:"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$BackupVolume
)

# --- Vérification du volume ---
if (-not (Test-Path $BackupVolume)) {
    Write-Host "Volume $BackupVolume introuvable..." -ForegroundColor Red
    exit
}

Import-Module ServerManager -ErrorAction SilentlyContinue

# --- Vérification et installation de Windows Server Backup ---
if (-not (Get-WindowsFeature -Name Windows-Server-Backup).Installed) {
    Write-Host "Installation de la fonctionnalité Windows Server Backup..." -ForegroundColor Cyan
    Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools
    Write-Host "Installation terminée." -ForegroundColor Green
} else {
    Write-Host "Windows Server Backup déjà installé." -ForegroundColor Green
}

if (-not (Get-Module -Name WindowsServerBackup)) {
    Import-Module WindowsServerBackup
}


# --- Création du script Full Server dans %TEMP% ---
$FullBackupScriptPath = "$env:TEMP\FullServerBackup.ps1"

$fullBackupScript = @"
Import-Module WindowsServerBackup

\$fullServerPolicy = New-WBPolicy
\$systemVolume = Get-WBVolume | Where-Object { \$_.IsSystemVolume -eq \$true }
\$otherVolumes = Get-WBVolume | Where-Object { \$_.IsSystemVolume -eq \$false }

foreach (\$vol in \$systemVolume + \$otherVolumes) {
    Add-WBVolume -Policy \$fullServerPolicy -Volume \$vol
}

Add-WBBackupTarget -Policy \$fullServerPolicy -Target (New-WBBackupTarget -VolumePath '$BackupVolume')

# Full VSS Backup = marque les fichiers comme sauvegardés
Set-WBVssBackupOptions -Policy \$fullServerPolicy -VssFullBackup

Set-WBPolicy -Policy \$fullServerPolicy
"@

$fullBackupScript | Out-File -FilePath $FullBackupScriptPath -Encoding UTF8
Write-Host "Script Full Server généré : $FullBackupScriptPath" -ForegroundColor Green

# --- Tâche planifiée Weekly Full Backup ---
Write-Host "`nCréation de la tâche planifiée Full Server hebdomadaire..." -ForegroundColor Cyan

$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$FullBackupScriptPath`""
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 02:00AM

Register-ScheduledTask `
    -Action $Action `
    -Trigger $Trigger `
    -TaskName "FullServerBackupWeekly" `
    -Description "Sauvegarde Full Server hebdomadaire (dimanche 2h00)" `
    -User "SYSTEM" `
    -RunLevel Highest `
    -Force

Write-Host "Tâche planifiée Weekly Full Backup créée avec succès !" -ForegroundColor Green

Write-Host "`n=== Script Weekly Full Backup terminé ===" -ForegroundColor Cyan
