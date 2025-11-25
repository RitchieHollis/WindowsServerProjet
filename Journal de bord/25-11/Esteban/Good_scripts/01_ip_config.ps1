# --- VARIABLES ---
$ServerName = "Londres-SRV"
$Interface  = "Ethernet"
$IPAddress  = "10.0.0.2"
$PrefixLength = 22
$Gateway   = "10.0.0.1"
$DNSServer = "10.0.0.2"

# --- RENOMMAGE DU SERVEUR ---
Write-Host "`n--- RENOMMAGE DU SERVEUR ---`n" -ForegroundColor Cyan
Rename-Computer -NewName $ServerName -Force

# --- CONFIGURATION IP STATIQUE ---
Write-Host "`n--- CONFIGURATION IP STATIQUE ---`n" -ForegroundColor Cyan
Get-NetIPAddress -InterfaceAlias $Interface -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false
Set-DnsClientServerAddress -InterfaceAlias $Interface -ServerAddresses $null
New-NetIPAddress -InterfaceAlias $Interface -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway
Set-DnsClientServerAddress -InterfaceAlias $Interface -ServerAddresses $DNSServer

# --- REDÉMARRAGE ---
Write-Host "Redémarrage requis après renommage et IP..." -ForegroundColor Yellow
Restart-Computer -Force
