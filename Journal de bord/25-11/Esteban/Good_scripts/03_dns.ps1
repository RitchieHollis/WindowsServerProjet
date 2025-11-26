$DNSServer = "10.0.0.2"
$Interface = "Ethernet"

$DomainName = "angleterre.lan"   # adapt if needed
$HostName = "London"
$DCIP = "10.0.0.2"

$ReverseZones = @(
    "0.0.10.in-addr.arpa",
    "1.0.10.in-addr.arpa",
    "2.0.10.in-addr.arpa",
    "3.0.10.in-addr.arpa"
)

Write-Host ""
Write-Host "--- DNS CLIENT CONFIG ---"
Set-DnsClientServerAddress -InterfaceAlias $Interface -ServerAddresses $DNSServer

Write-Host ""
Write-Host "--- DNS ROLE INSTALL ---"
Install-WindowsFeature DNS -IncludeManagementTools

Write-Host ""
Write-Host "--- REVERSE ZONES CREATION ---"
foreach ($zone in $ReverseZones) {
    if (-not (Get-DnsServerZone -Name $zone -ErrorAction SilentlyContinue)) {
        Add-DnsServerPrimaryZone -Name $zone -DynamicUpdate Secure
        Write-Host "Created zone: $zone"
    }
    else {
        Write-Host "Zone already exists: $zone"
    }
}

# A record for dcroot
if (-not (Get-DnsServerResourceRecord -ZoneName $DomainName -Name $HostName -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordA -ZoneName $DomainName -Name $HostName -IPv4Address $DCIP
}

# PTR record for 10.0.0.2
if (-not (Get-DnsServerResourceRecord -ZoneName "0.0.10.in-addr.arpa" -Name "2" -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordPtr -ZoneName "0.0.10.in-addr.arpa" -Name "2" -PtrDomainName "$HostName.$DomainName"
}

Write-Host ""
Write-Host "DNS configuration finished."

