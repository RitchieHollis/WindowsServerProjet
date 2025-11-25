<#
NTPconf.ps1

Configuration de NTP sur DCroot :
    - Enabled: 1 pour TimeProviders pour utiliser NTP
    - AnnounceFlags 5 pour mettre London DCroot comme le server source pour l'horloge de réseau
    - Check la connection internet. Si la connection est présente, NTP utilisera les pools
    - Synchronization avec internet pour récuperer l'horloge via range des pools
    - Acceptation du port 123 en UDP dans le firewall
#>
$NtpPeers = "0.be.pool.ntp.org 1.be.pool.ntp.org" # I guess two are enough

Write-Host "Configuring NTP on DCroot..." -ForegroundColor Cyan

Set-ItemProperty `
  -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpServer" `
  -Name "Enabled" `
  -Value 1

#5 = 0x05 = Always time server + reliable
Set-ItemProperty `
  -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" `
  -Name "AnnounceFlags" `
  -Value 5

#w32time using NTP
Write-Host "Testing Internet reachability to NTP pool..." -ForegroundColor Yellow

$HasInternet = $false
try {
  $HasInternet = Test-Connection -ComputerName "0.be.pool.ntp.org" `
    -Count 1 -Quiet -ErrorAction SilentlyContinue
}
catch {
  $HasInternet = $false
}

if ($HasInternet) {
  Write-Host "Internet reachable. Using external NTP pools as time source." -ForegroundColor Cyan

  w32tm /config /manualpeerlist:$NtpPeers /syncfromflags:manual /reliable:yes /update
}
else {
  Write-Host "No Internet detected. Configuring DCroot as standalone time source." -ForegroundColor Yellow

  w32tm /config /syncfromflags:NO /reliable:yes /update
}

Set-Service -Name w32time -StartupType Automatic
netsh advfirewall firewall add rule name="NTP Inbound" dir=in action=allow protocol=UDP localport=123 > $null
Restart-Service w32time

#check
w32tm /resync
w32tm /query /configuration
w32tm /query /status
w32tm /query /peers
