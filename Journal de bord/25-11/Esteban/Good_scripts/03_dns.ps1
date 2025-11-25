# --- VARIABLES ---
$DNSServer = "10.0.0.2"
$Interface = "Ethernet"
$ReverseZones = @(
    "0.0.10.in-addr.arpa",
    "1.0.10.in-addr.arpa",
    "2.0.10.in-addr.arpa",
    "3.0.10.in-addr.arpa"
)

# --- FIXER DNS DU SERVEUR ---
Write-Host "`n--- CONFIGURATION DNS CLIENT ---`n" -ForegroundColor Cyan
Set-DnsClientServerAddress -InterfaceAlias $Interface -ServerAddresses $DNSServer

# --- INSTALLATION DU RÔLE DNS ---
Write-Host "`n--- INSTALLATION DU RÔLE DNS ---`n" -ForegroundColor Cyan
Install-WindowsFeature DNS -IncludeManagementTools

# --- CRÉATION DES ZONES INVERSES ---
Write-Host "`n--- CRÉATION DES ZONES INVERSES ---`n" -ForegroundColor Cyan
foreach ($zone in $ReverseZones) {
    if (-not (Get-DnsServerZone -Name $zone -ErrorAction SilentlyContinue)) {
        Add-DnsServerPrimaryZone -Name $zone -DynamicUpdate Secure
        Write-Host "✅ Zone créée : $zone"
    } else {
        Write-Host "ℹ️ Zone déjà existante : $zone"
    }
}

Write-Host "✅ Configuration DNS terminée !" -ForegroundColor Green