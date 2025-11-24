########################################
# VARIABLES À ADAPTER
########################################
$DomainName   = "anglettere.lan"      # Nom de ton domaine
$ReverseNetId = "10.0.0.0/22"         # Plage réseau de ton domaine
$ZoneFileForward = "$DomainName.dns"  # Nom du fichier de zone forward
$ZoneFileReverse = "10.0.0.rev"       # Nom du fichier de zone reverse
########################################

Write-Host "🔹 Vérification et installation du rôle DNS..." -ForegroundColor Cyan
# Installer DNS si ce n'est pas déjà fait
Install-WindowsFeature DNS -IncludeManagementTools

Write-Host "🔹 Création de la zone forward pour le domaine $DomainName..." -ForegroundColor Cyan
# Créer une zone primaire intégrée à AD pour le domaine
Add-DnsServerPrimaryZone -Name $DomainName -ZoneFile $ZoneFileForward -DynamicUpdate Secure

Write-Host "🔹 Création de la zone reverse pour le réseau $ReverseNetId..." -ForegroundColor Cyan
# Créer une zone de recherche inversée intégrée à AD
Add-DnsServerPrimaryZone -NetworkId $ReverseNetId -ZoneFile $ZoneFileReverse -DynamicUpdate Secure

Write-Host "🔹 Vérification des zones DNS créées..." -ForegroundColor Cyan
Get-DnsServerZone

Write-Host "🔹 Test de résolution du domaine local..." -ForegroundColor Cyan
Resolve-DnsName $DomainName
nslookup $DomainName

Write-Host "✅ Configuration DNS terminée !" -ForegroundColor Green
