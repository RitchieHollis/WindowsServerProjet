<#
.SYNOPSIS
    Script de planification des sauvegardes Windows Server.

.DESCRIPTION
    Ce script installe Windows Server Backup si nécessaire.
    Il crée :
      - Une sauvegarde Full Server hebdomadaire (dimanche 2h00) via le Planificateur de tâches.
      - Une sauvegarde System State quotidienne à 23h00.
    Les sauvegardes sont effectuées directement sur le volume spécifié.
    Permet de standardiser le plan de sauvegarde sur plusieurs serveurs.

.PARAMETER BackupVolume
    Lettre du volume où les sauvegardes seront stockées (ex: "B:").

.EXAMPLE
    .\PlanificationSauvegarde.ps1 -BackupVolume "B:"
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

# --- Vérification et installation de la fonctionnalité Windows Server Backup ---
if (-not (Get-WindowsFeature -Name Windows-Server-Backup).Installed) {
    Write-Host "Installation de la fonctionnalité Windows Server Backup..." -ForegroundColor Cyan
    Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools
    Write-Host "Installation terminée." -ForegroundColor Green
} else {
    Write-Host "Windows Server Backup déjà installé." -ForegroundColor Green
}

Import-Module WindowsServerBackup

# --- Création du script Full Server pour le Planificateur de tâches ---
$FullBackupScriptPath = "$env:TEMP\FullServerBackup.ps1"

$fullBackupScript = @"
Import-Module WindowsServerBackup

\$fullServerPolicy = New-WBPolicy
\$systemVolume = Get-WBVolume | Where-Object {\$_.IsSystemVolume -eq \$true}
\$otherVolumes = Get-WBVolume | Where-Object {\$_.IsSystemVolume -eq \$false}

foreach (\$vol in \$systemVolume + \$otherVolumes) {
    Add-WBVolume -Policy \$fullServerPolicy -Volume \$vol
}

# Cible uniquement le volume pour WSB
Add-WBBackupTarget -Policy \$fullServerPolicy -Target (New-WBBackupTarget -VolumePath '$BackupVolume')
Set-WBVssBackupOptions -Policy \$fullServerPolicy -VssFullBackup
Set-WBPolicy -Policy \$fullServerPolicy
"@

$fullBackupScript | Out-File -FilePath $FullBackupScriptPath -Encoding UTF8
Write-Host "Script Full Server créé : $FullBackupScriptPath" -ForegroundColor Green

# --- Création de la tâche planifiée hebdomadaire pour Full Server ---
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$FullBackupScriptPath`""
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 02:00AM
Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName "FullServerBackupWeekly" -Description "Sauvegarde Full Server hebdomadaire" -User "SYSTEM" -RunLevel Highest -Force
Write-Host "Tâche planifiée Full Server hebdomadaire créée (dimanche 2h00)." -ForegroundColor Green

# --- Création de la planification System State quotidienne ---
Write-Host "`nCréation de la planification System State quotidienne..." -ForegroundColor Cyan
$ssPolicy = New-WBPolicy
Add-WBSystemState -Policy $ssPolicy
Add-WBBackupTarget -Policy $ssPolicy -Target (New-WBBackupTarget -VolumePath $BackupVolume)
Set-WBSchedule -Policy $ssPolicy -Schedule (Get-Date "23:00")
Set-WBVssBackupOptions -Policy $ssPolicy -VssCopyBackup
Set-WBPolicy -Policy $ssPolicy
Write-Host "Planification System State quotidienne créée à 23h00." -ForegroundColor Green

Write-Host "`n=== Script de planification des sauvegardes terminé ===" -ForegroundColor Cyan
