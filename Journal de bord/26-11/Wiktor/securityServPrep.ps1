<#
securityServPrep.ps1

Script pour le setup basique du serveur SRVSEC
#>

$TargetName = "SRVSEC"
$DomainName = "angleterre.lan"

$IPv4Address = "10.0.0.5"
$PrefixLen = 22            
$Gateway = "10.0.0.1"
$DnsServers = @("10.0.0.2")  

$adapter = Get-NetAdapter |
Where-Object { $_.Status -eq 'Up' -and -not $_.Virtual } |
Sort-Object ifIndex |
Select-Object -First 1

if (-not $adapter) {
    Write-Error "You need to set un a NAT card, fella"
    exit 1
}

Write-Host "Using adapter: $($adapter.Name)"

$needReboot = $false

Write-Host "Configuring static IP..." -ForegroundColor Cyan

Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress -InterfaceIndex $adapter.ifIndex `
    -IPAddress $IPv4Address `
    -PrefixLength $PrefixLen `
    -DefaultGateway $Gateway

Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex `
    -ServerAddresses $DnsServers

if ($env:COMPUTERNAME -ne $TargetName) {
    Write-Host "Renaming computer to $TargetName..." -ForegroundColor Cyan
    Rename-Computer -NewName $TargetName -Force
    $needReboot = $true
}

$cs = Get-WmiObject Win32_ComputerSystem
if (-not $cs.PartOfDomain) {
    Write-Host "Joining domain '$DomainName'..." -ForegroundColor Cyan
    $cred = Get-Credential -Message "Enter credentials with rights to join $DomainName"
    Add-Computer -DomainName $DomainName -Credential $cred
    $needReboot = $true
}

Write-Host "Configuring Windows Firewall..." -ForegroundColor Cyan

Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True

# Disable built-in stuff
Disable-NetFirewallRule -DisplayGroup "Remote Desktop"        -ErrorAction SilentlyContinue
Disable-NetFirewallRule -DisplayGroup "File and Printer Sharing" -ErrorAction SilentlyContinue
Disable-NetFirewallRule -DisplayGroup "Remote Assistance"     -ErrorAction SilentlyContinue

#Allow ICMP (ping) from LAN only
New-NetFirewallRule -DisplayName "Allow ICMPv4 In from LAN" `
    -Direction Inbound -Protocol ICMPv4 -IcmpType 8 `
    -Profile Domain `
    -RemoteAddress "10.0.0.0/24" `
    -Action Allow `
    -ErrorAction SilentlyContinue | Out-Null

#PowerShell remoting for remote admin, restricted to DCROOT/admin IP
Enable-PSRemoting -Force

#Restrict WinRM HTTP inbound rule
$winrmRule = Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -ErrorAction SilentlyContinue
if ($winrmRule) {
    Set-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" `
        -RemoteAddress $MgmtHostIP
}

if ($needReboot) {
    Write-Host "Rebooting to apply changes..." -ForegroundColor Yellow
    Restart-Computer
}
else {
    Write-Host "Baseline configuration complete. No reboot required." -ForegroundColor Green
}
