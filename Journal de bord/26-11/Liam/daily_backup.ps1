<#
.SYNOPSIS
    Script de configuration de la sauvegarde quotidienne System State sur Windows Server.

.DESCRIPTION
    Ce script installe Windows Server Backup si nécessaire.
    Il configure :
      - Une sauvegarde quotidienne du System State à 23h00.
    La sauvegarde est effectuée directement sur le volume spécifié.

.PARAMETER BackupVolume
    Lettre du volume où les sauvegardes seront stockées (ex: "B:").

.EXAMPLE
    .\PlanificationSauvegardeDaily.ps1 -BackupVolume "B:"
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

# --- Création de la planification System State quotidienne ---
Write-Host "`nCréation de la planification System State quotidienne..." -ForegroundColor Cyan

$ssPolicy = New-WBPolicy

Add-WBSystemState -Policy $ssPolicy

Add-WBBackupTarget -Policy $ssPolicy -Target (New-WBBackupTarget -VolumePath $BackupVolume)

Set-WBSchedule -Policy $ssPolicy -Schedule (Get-Date "23:00")

Set-WBVssBackupOptions -Policy $ssPolicy -VssCopyBackup

Set-WBPolicy -Policy $ssPolicy

Write-Host "Planification System State quotidienne créée à 23h00." -ForegroundColor Green

Write-Host "`n=== Script Daily Backup terminé ===" -ForegroundColor Cyan
