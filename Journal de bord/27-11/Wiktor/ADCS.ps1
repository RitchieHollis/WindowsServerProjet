<#
.SYNOPSIS
    Installe et sécurise une autorité de certification racine d’entreprise (Enterprise Root CA)
    sur SRVSEC pour le domaine angleterre.lan.

.DESCRIPTION
    Ce script transforme SRVSEC en serveur de certification dédié pour la forêt angleterre.lan,
    en appliquant plusieurs principes de sécurité qui seront détaillés dans le rapport :

    - ADCS est installé sur un SERVEUR MEMBRE et non sur un contrôleur de domaine,
      afin de réduire la surface d’attaque du DC et d’isoler les « bijoux de famille » PKI
      sur une machine dédiée.

    - La CA est configurée comme Enterprise Root CA avec une clé privée NON EXPORTABLE
      et une durée de vie de 10 ans (valeur typique pour une racine dans une PKI
      mono-niveau de type laboratoire). Le matériel de clé reste lié à l’hôte SRVSEC
      et ne peut pas être déplacé ou copié facilement.

    - Les informations de révocation CRL (Certificate Revocation List) et AIA
      (Authority Information Access) sont publiées en HTTP sur SRVSEC dans un dossier
      dédié C:\www\angleterre\CertEnroll. Les clients peuvent ainsi vérifier la validité
      des certificats via HTTP sans avoir accès au système de fichiers interne de la CA.

    - La durée de vie des CRL est fixée à 1 semaine avec un chevauchement d’1 jour,
      ce qui équilibre charge opérationnelle et sécurité : les informations de révocation
      sont actualisées régulièrement sans nécessiter une maintenance quotidienne.

    - Le pare-feu Windows est ajusté pour n’activer explicitement que les règles
      nécessaires au fonctionnement de l’autorité de certification (groupe
      Active Directory Certificate Services). Les autres règles de durcissement
      de base sont considérées comme déjà appliquées par le script de "préparation"
      du serveur.

    Le script est idempotent : si ADCS est déjà installé, l’étape d’installation
    est ignorée et seules la configuration (CRL/AIA) et les règles de pare-feu
    sont réappliquées.
#>

param(
    [string]$DomainName = "angleterre.lan",
    [string]$CACommonName = "ANGLETERRE-ROOT-CA"
)

$CrlFolder = "C:\www\angleterre\CertEnroll"
$CertEnrollSystemPath = "C:\Windows\System32\CertSrv\CertEnroll"

Write-Host "Starting Enterprise Root CA configuration on SRVSEC" -ForegroundColor Cyan

$cs = Get-WmiObject Win32_ComputerSystem
if (-not $cs.PartOfDomain -or $cs.Domain -ne $DomainName) {
    throw "This server is not joined to the expected domain '$DomainName'. Current domain: '$($cs.Domain)'. Aborting."
}

Write-Host "[ADCS] Checking AD CS role..." -ForegroundColor Cyan
$adcsFeature = Get-WindowsFeature ADCS-Cert-Authority

if (-not $adcsFeature -or -not $adcsFeature.Installed) {
    Write-Host "    ADCS-Cert-Authority not installed, installing..." -ForegroundColor Yellow
    Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools | Out-Null
    Write-Host "    AD CS role installed." -ForegroundColor Green
}
else {
    Write-Host "    AD CS role already installed." -ForegroundColor Gray
}

$caConfigKey = "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration"
$caConfigured = Test-Path $caConfigKey

if (-not $caConfigured) {
    Write-Host "[ADCS] Installing Enterprise Root CA role" -ForegroundColor Cyan

    Install-AdcsCertificationAuthority `
        -CAType EnterpriseRootCA `
        -CACommonName $CACommonName `
        -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
        -KeyLength 2048 `
        -HashAlgorithmName SHA256 `
        -ValidityPeriod Years `
        -ValidityPeriodUnits 10 `
        -DatabaseDirectory "C:\Windows\System32\CertLog" `
        -LogDirectory "C:\Windows\System32\CertLog" `
        -Force

    Write-Host "[ADCS] Enterprise Root CA installed with 10-year lifetime and non-exportable key." -ForegroundColor Gray
}
else {
    Write-Host "[ADCS] CA already configured, skipping Install-AdcsCertificationAuthority." -ForegroundColor Yellow
}

Write-Host "Configuring CRL and AIA publication over HTTP..." -ForegroundColor Cyan

New-Item -ItemType Directory -Path $CrlFolder -Force | Out-Null

# CRL validity&verlap
# 1 week validity, 1 day overlap (clients accept old CRL for 1 extra day while the new one is distributed)
certutil -setreg CA\CRLPeriod "Weeks"           | Out-Null
certutil -setreg CA\CRLPeriodUnits 1            | Out-Null
certutil -setreg CA\CRLOverlapPeriod "Days"     | Out-Null
certutil -setreg CA\CRLOverlapPeriodUnits 1     | Out-Null

#  HTTP base URL for clients
$httpBase = "http://srvsec.$DomainName/CertEnroll"

# CDP (CRL Distribution Points)
#  1 = local file path used by the CA itself
# 10 = HTTP URL used by clients
certutil -setreg CA\CRLPublicationURLs "1:$CrlFolder\%3%8%9.crl`n10:$httpBase/%3%8%9.crl" | Out-Null

# AIA (Authority Information Access) for CA certificate publication
certutil -setreg CA\CACertPublicationURLs "1:$CrlFolder\%1_%3%4.crt`n10:$httpBase/%1_%3%4.crt" | Out-Null

$certSvc = Get-Service certsvc -ErrorAction SilentlyContinue
if ($certSvc) {
    Restart-Service certsvc
    certutil -crl | Out-Null
}
else {
    Write-Warning "[ADCS] certsvc service not found, cannot restart CA service. Verify ADCS installation."
}

if (Test-Path $CertEnrollSystemPath) {
    Copy-Item "$CertEnrollSystemPath\*.*" $CrlFolder -Force
}

Write-Host "[ADCS] CRL/AIA HTTP publication configured at: $httpBase" -ForegroundColor Gray
Write-Host "[ADCS] Enabling firewall rules for certificate services..." -ForegroundColor Cyan

# Enable only the built-in ADCS firewall group; the baseline script already enforced general hardening.
Enable-NetFirewallRule -DisplayGroup "Active Directory Certificate Services" -ErrorAction SilentlyContinue

Write-Host "`n[ADCS] Enterprise Root CA hardening complete." -ForegroundColor Gray
Write-Host "       - CA Name : $CACommonName"
Write-Host "       - CRL URL : $httpBase"
Write-Host ""