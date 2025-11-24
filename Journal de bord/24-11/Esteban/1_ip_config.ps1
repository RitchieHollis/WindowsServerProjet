########################################
# VARIABLES À ADAPTER
########################################

# Nouveau nom du serveur
$NewServerName = "London"

# Configuration IP
$InterfaceAlias = "Ethernet"
$IPAddress      = "10.0.0.2"
$IPMask         = "22"
$Gateway        = "10.0.0.1"
$DNS            = "10.0.0.2"

########################################
# 1. Renommer le serveur
########################################
Write-Host "Renommage du serveur..." -ForegroundColor Cyan
Rename-Computer -NewName $NewServerName -Force

########################################
# 2. Configuration IP
########################################
Write-Host "Configuration IP..." -ForegroundColor Cyan

Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $null

New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $IPMask -DefaultGateway $Gateway
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNS

########################################
# 3. Redémarrage
########################################
Write-Host "Redémarrage en cours..." -ForegroundColor Yellow
Restart-Computer
