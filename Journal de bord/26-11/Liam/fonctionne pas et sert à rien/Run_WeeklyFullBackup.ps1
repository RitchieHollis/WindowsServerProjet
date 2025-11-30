param (
    [Parameter(Mandatory = $true)]
    [string]$BackupVolume
)

Import-Module WindowsServerBackup

# Crée la politique
$policy = New-WBPolicy

# Récupère uniquement le volume système C:
$systemVolume = Get-WBVolume -VolumePath "C:\"

# Ajoute le volume C:
Add-WBVolume -Policy $policy -Volume $systemVolume

# Ajoute la cible de sauvegarde
Add-WBBackupTarget -Policy $policy -Target (New-WBBackupTarget -VolumePath "$BackupVolume\")

# Full VSS Backup
Set-WBVssBackupOptions -Policy $policy -VssFullBackup

# Lance le backup immédiatement
Start-WBBackup -Policy $policy -Async
