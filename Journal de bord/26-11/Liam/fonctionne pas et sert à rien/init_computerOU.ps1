# Ce script crée une OU spécifique pour les comptes ordinateurs dans Active Directory.
# Il remplace l'OU par défaut "Computers" et configure la redirection automatique
# des nouveaux comptes ordinateurs vers cette OU.
# Le script détecte le domaine actif pour s'assurer que la redirection s'applique correctement.

Param(
    [string]$OUName = "Ordinateurs"
)

Import-Module ActiveDirectory

$DomainDN = (Get-ADDomain).DistinguishedName

$OUPath = "OU=$OUName,$DomainDN"

if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OUName)")) {
    Write-Host "Création de l'OU '$OUName'..."
    New-ADOrganizationalUnit -Name $OUName -Path $DomainDN
} else {
    Write-Host "OU '$OUName' existe déjà."
}

Write-Host "Redirection des nouveaux ordinateurs vers : $OUPath"
redircmp "$OUPath"

Write-Host "Configuration terminée."
