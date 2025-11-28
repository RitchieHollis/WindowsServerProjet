<#
.SYNOPSIS
    Déploie un site intranet IIS sécurisé avec certificat de l’AC SRVSEC.

.DESCRIPTION
    Ce script installe IIS sur SRVSEC et publie un site "Intranet" accessible
    en HTTPS uniquement, avec certificat émis par l’autorité de certification
    interne (modèle "Web Server").

    Principes de sécurité mis en œuvre :

    - Le rôle Web-Server et les outils d’administration IIS sont installés
      uniquement si nécessaire (script idempotent).

    - Un nouveau site IIS "Intranet" est créé dans C:\www\Intranet avec un
      en-tête d’hôte dédié (intranet.angleterre.lan). Le site par défaut
      peut ensuite être désactivé dans la stratégie globale.

    - Le serveur SRVSEC demande automatiquement un certificat serveur
      au modèle "WebServer" via ADCS. L’empreinte de ce certificat est
      liée au binding HTTPS (443) avec SNI activé.

    - Le site écoute en HTTP (80) uniquement pour rediriger vers HTTPS
      (redirection 301 permanente) grâce au module Web-Http-Redirect.

    - Le pare-feu Windows est configuré pour n’ouvrir que les ports 80/443
      en entrée sur le profil Domaine, ce qui limite l’exposition aux
      seules machines du domaine angleterre.lan.

    - Le script est ré-exécutable sans effet de bord : si IIS, le site,
      le certificat ou les règles de pare-feu existent déjà, ils sont
      vérifiés et réutilisés.
#>

[CmdletBinding()]
param(
    [string]$SiteName = "Intranet",
    [string]$DnsName = "intranet.angleterre.lan",
    [string]$PhysicalPath = "C:\www\Intranet",
    [string]$CertTemplate = "WebServer"  #Nom court du modèle ADCS
)

Write-Host "`n[IIS] Starting secure intranet deployment" -ForegroundColor Cyan

Write-Host "[IIS] Checking IIS role on $($env:COMPUTERNAME)" -ForegroundColor Cyan
$features = @(
    "Web-Server",        # IIS core
    "Web-Http-Redirect"  # For HTTP -> HTTPS redirect
)

$changed = $false
foreach ($f in $features) {
    $feat = Get-WindowsFeature $f -ErrorAction SilentlyContinue
    if (-not $feat) {
        Write-Error "[IIS] Feature '$f' not found on this OS."
        return
    }
    if (-not $feat.Installed) {
        Write-Host "[IIS] Installing feature $f..." -ForegroundColor Cyan
        Install-WindowsFeature $f -IncludeManagementTools | Out-Null
        $changed = $true
    }
}

if (-not $changed) {
    Write-Host "[IIS] IIS role and required features already installed" -ForegroundColor Yellow
}
else {
    Write-Host "[IIS] IIS role installed/updated." -ForegroundColor Green
}

Import-Module WebAdministration

if (-not (Test-Path $PhysicalPath)) {
    Write-Host "[IIS] Creating site directory '$PhysicalPath'..." -ForegroundColor Cyan
    New-Item -Path $PhysicalPath -ItemType Directory -Force | Out-Null
}

$indexFile = Join-Path $PhysicalPath "index.html"
if (-not (Test-Path $indexFile)) {
    Write-Host "[IIS] Creating simple index.html as landing page" -ForegroundColor Cyan
    @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8" />
    <title>Intranet sécurisé</title>
</head>
<body>
    <h1>Intranet sécurisé - angleterre.lan</h1>
    <p>Ce site est publié depuis SRVSEC et protégé par un certificat émis par notre AC interne.</p>
    <p>You have been warned, silly boy</p>
</body>
</html>
"@ | Set-Content -Path $indexFile -Encoding UTF8
}

Write-Host "[IIS] Ensuring IIS site '$SiteName' exists..." -ForegroundColor Cyan

$existingSite = Get-Website -Name $SiteName -ErrorAction SilentlyContinue

if (-not $existingSite) {
    Write-Host "[IIS] Creating site '$SiteName' on port 80 with host header $DnsName..." -ForegroundColor Cyan
    New-Website -Name $SiteName `
        -Port 80 `
        -IPAddress "*" `
        -HostHeader $DnsName `
        -PhysicalPath $PhysicalPath `
        -ApplicationPool "DefaultAppPool" | Out-Null
}
else {
    Write-Host "[IIS] Site '$SiteName' already exists, updating basic settings" -ForegroundColor Yellow
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $PhysicalPath
}

Write-Host "[IIS] Looking for existing WebServer certificate for '$DnsName'" -ForegroundColor Cyan

$webServerOid = "1.3.6.1.5.5.7.3.1" #Server Authentication EKU

$cert = Get-ChildItem Cert:\LocalMachine\My |
Where-Object {
    $_.EnhancedKeyUsageList.ObjectId -contains $webServerOid -and
    ($_.Subject -like "*CN=$DnsName*" -or $_.DnsNameList.Unicode -contains $DnsName)
} |
Sort-Object NotAfter -Descending |
Select-Object -First 1

if (-not $cert) {
    Write-Host "[IIS] No suitable certificate found, requesting new one from template '$CertTemplate'" -ForegroundColor Cyan
    try {
        $req = Get-Certificate -Template $CertTemplate `
            -DnsName  $DnsName `
            -CertStoreLocation "cert:\LocalMachine\My" `
            -ErrorAction Stop
        $cert = $req.Certificate
        Write-Host "[IIS] Certificate issued with thumbprint $($cert.Thumbprint)." -ForegroundColor Green
    }
    catch {
        Write-Error "[IIS] Failed to enroll certificate from template '$CertTemplate' : $($_.Exception.Message)"
        return
    }
}
else {
    Write-Host "[IIS] Reusing existing certificate with thumbprint $($cert.Thumbprint)." -ForegroundColor Yellow
}

Write-Host "[IIS] Ensuring HTTPS binding for '$SiteName' on 443 with host '$DnsName'" -ForegroundColor Cyan

$bindingInfo = "*:443:$DnsName"

$httpsBinding = Get-WebBinding -Name $SiteName -Protocol https -ErrorAction SilentlyContinue |
Where-Object { $_.bindingInformation -eq $bindingInfo }

if (-not $httpsBinding) {
    Write-Host "[IIS] Creating HTTPS binding" -ForegroundColor Cyan
    New-WebBinding -Name $SiteName -Protocol https -Port 443 -HostHeader $DnsName -SslFlags 1 | Out-Null
}

# Bind certificate via IIS:\SslBindings (SNI aware)
Push-Location IIS:\SslBindings
$sslPath = "0.0.0.0!443!$DnsName"
$existingSsl = Get-Item $sslPath -ErrorAction SilentlyContinue
if (-not $existingSsl) {
    Write-Host "[IIS] Binding certificate thumbprint $($cert.Thumbprint) to HTTPS (SNI)" -ForegroundColor Cyan
    New-Item $sslPath -Thumbprint $cert.Thumbprint -SSLFlags 1 | Out-Null
}
else {
    Write-Host "[IIS] HTTPS SNI binding already present for $DnsName." -ForegroundColor Yellow
}
Pop-Location

Write-Host "[IIS] Configuring HTTP -> HTTPS redirect" -ForegroundColor Cyan

$redirectPath = "IIS:\Sites\$SiteName"
Set-WebConfigurationProperty -PSPath $redirectPath `
    -Filter "system.webServer/httpRedirect" `
    -Name "enabled" `
    -Value "True"

Set-WebConfigurationProperty -PSPath $redirectPath `
    -Filter "system.webServer/httpRedirect" `
    -Name "destination" `
    -Value ("https://{0}/" -f $DnsName)

Set-WebConfigurationProperty -PSPath $redirectPath `
    -Filter "system.webServer/httpRedirect" `
    -Name "httpResponseStatus" `
    -Value "Permanent"

Write-Host "[IIS] HTTP requests to http://$DnsName will be redirected permanently to https://$DnsName/." -ForegroundColor Green

Write-Host "[IIS] Ensuring firewall rules for HTTP/HTTPS (Domain profile)" -ForegroundColor Cyan

function Ensure-FirewallRule {
    param(
        [string]$Name,
        [int]$Port
    )
    $rule = Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue
    if (-not $rule) {
        New-NetFirewallRule -DisplayName $Name `
            -Direction Inbound `
            -Profile Domain `
            -Action Allow `
            -Protocol TCP `
            -LocalPort $Port | Out-Null
        Write-Host "[IIS] Firewall rule '$Name' created for port $Port (Domain profile)." -ForegroundColor Green
    }
    else {
        Write-Host "[IIS] Firewall rule '$Name' already exists." -ForegroundColor Yellow
    }
}

Ensure-FirewallRule -Name "IIS Intranet HTTP (80)"  -Port 80
Ensure-FirewallRule -Name "IIS Intranet HTTPS (443)" -Port 443

Write-Host "`n[IIS] Secure intranet deployment completed successfully." -ForegroundColor Cyan
