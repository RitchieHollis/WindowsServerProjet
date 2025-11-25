########################################
# DHCP CONFIG POUR VLAN 10 - LONDON
########################################

$ServerIP     = "10.0.0.2"              # IP du DHCP/DC
$ScopeName    = "London-VLAN10"
$ScopeNetwork = "10.0.0.0"              # ID réseau du /22
$StartIP      = "10.0.0.30"             # Début de la plage
$EndIP        = "10.0.3.250"            # Fin de la plage (10.0.0.0/22 = .0 à .3)
$SubnetMask   = "255.255.252.0"
$Gateway      = "10.0.0.1"
$DnsServer    = "10.0.0.2"
$DnsDomain    = "anglettere.lan"
########################################


Write-Host "🔹 Installation du rôle DHCP..." -ForegroundColor Cyan
Install-WindowsFeature DHCP -IncludeManagementTools

Write-Host "🔹 Autorisation du serveur DHCP dans Active Directory..." -ForegroundColor Cyan
Add-DhcpServerInDC -DnsName "London.$DnsDomain" -IpAddress $ServerIP

Write-Host "🔹 Création de l'étendue DHCP pour VLAN 10 (London)..." -ForegroundColor Cyan
Add-DhcpServerv4Scope `
    -Name $ScopeName `
    -StartRange $StartIP `
    -EndRange $EndIP `
    -SubnetMask $SubnetMask `
    -State Active

Write-Host "🔹 Configuration des options DHCP..." -ForegroundColor Cyan
Set-DhcpServerv4OptionValue -ScopeId $ScopeNetwork -Router $Gateway
Set-DhcpServerv4OptionValue -ScopeId $ScopeNetwork -DnsServer $DnsServer
Set-DhcpServerv4OptionValue -ScopeId $ScopeNetwork -DnsDomain $DnsDomain

Write-Host "🔹 Vérification de l'étendue..." -ForegroundColor Cyan
Get-DhcpServerv4Scope

Write-Host "✅ DHCP configuré pour le VLAN 10 (London) !" -ForegroundColor Green
