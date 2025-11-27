<#
.SYNOPSIS
    Active la journalisation avancée et la surveillance de l’autorité de certification.

.DESCRIPTION
    Ce script renforce la traçabilité de l’AC (SRVSEC) en trois volets :

    1. Activation de l’audit avancé Windows pour les services de certification :
       - Sous-catégorie "Certification Services" activée en succès et en échec
         via auditpol /set.
       - Permet de générer des événements de sécurité lors de l’émission,
         de la révocation ou de l’échec d’enrôlement de certificats.

    2. Configuration du filtre d’audit ADCS (clé de registre CA\AuditFilter) :
       - Lecture de la valeur actuelle AuditFilter sous
         HKLM\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\<NomCA>.
       - Fixe un masque d’audit "complet" (0x7F) pour journaliser :
            * démarrage/arrêt de l’AC,
            * demandes et émissions de certificats,
            * refus, révocations,
            * modifications de configuration et de sécurité.
       - Redémarre le service certsvc si un changement est appliqué.

    3. Exemple de collecte d’événements depuis un serveur de supervision
       (par exemple DCRoot LONDRES) :
       - Utilisation de Get-WinEvent -ComputerName SRVSEC pour extraire les
         événements liés à ADCS dans le journal Sécurité (ID 4886–4893).
       - Ce mode « CollectOnly » illustre l’intégration possible avec une
         solution de type SIEM, sans modifier la configuration de l’AC.

    Le script est idempotent :
       - Si l’audit avancé et le filtre d’audit sont déjà configurés comme
         souhaité, aucune modification n’est effectuée.
       - En mode CollectOnly, aucun changement n’est apporté à la configuration,
         seules des lectures de journaux sont effectuées.
#>

[CmdletBinding()]
param(

    [switch]$ConfigureCA = $true,
    [switch]$CollectOnly,
    [string]$CaComputerName = "SRVSEC",
    [int]$SampleHours = 4
)

Write-Host "`n[PKI] Starting PKI auditing script..." -ForegroundColor Cyan

#Safety: do not configure and collect at the same time if user explicitly asks CollectOnly
if ($CollectOnly) {
    $ConfigureCA = $false
}

if ($ConfigureCA) {
    Write-Host "[PKI] Configuring local CA auditing on $($env:COMPUTERNAME)..." -ForegroundColor Cyan

    $adcs = Get-WindowsFeature ADCS-Cert-Authority -ErrorAction SilentlyContinue
    if (-not $adcs -or -not $adcs.Installed) {
        Write-Error "ADCS-Cert-Authority role is not installed on this server. Run this on SRVSEC (the CA)."
        return
    }

    Write-Host "[PKI] Enabling advanced audit subcategory 'Certification Services' (success/failure)..." -ForegroundColor Cyan

    $currentAudit = & auditpol.exe /get /subcategory:"Certification Services" 2>$null

    $successEnabled = $currentAudit -match "Success.*Enabled"
    $failureEnabled = $currentAudit -match "Failure.*Enabled"

    if ($successEnabled -and $failureEnabled) {
        Write-Host "[PKI] Audit subcategory 'Certification Services' already enabled for success and failure." -ForegroundColor Yellow
    }
    else {
        & auditpol.exe /set /subcategory:"Certification Services" /success:enable /failure:enable | Out-Null
        Write-Host "[PKI] Audit subcategory 'Certification Services' configured (success+failure)." -ForegroundColor Green
    }

    Write-Host "[PKI] Ensuring CA AuditFilter is set to strong auditing mask..." -ForegroundColor Cyan

    $caConfigKey = "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration"
    $caInstance = Get-ChildItem -Path $caConfigKey | Select-Object -First 1

    if (-not $caInstance) {
        Write-Error "Could not locate CA configuration key under $caConfigKey."
        return
    }

    $caKeyPath = Join-Path $caConfigKey $caInstance.PSChildName
    $currentAuditFilter = (Get-ItemProperty -Path $caKeyPath -Name "AuditFilter" -ErrorAction SilentlyContinue).AuditFilter

    # 0x7F = log essentially all CA events (start/stop, issue, deny, revoke, config changes, security changes, backup/restore)
    [int]$desiredAuditFilter = 0x7F

    if ($currentAuditFilter -eq $desiredAuditFilter) {
        Write-Host "[PKI] AuditFilter already set to 0x{0:X} (no change needed)." -f $desiredAuditFilter -ForegroundColor Yellow
    }
    else {
        Write-Host ("[PKI] Changing AuditFilter from 0x{0:X} to 0x{1:X}..." -f $currentAuditFilter, $desiredAuditFilter) -ForegroundColor Cyan
        Set-ItemProperty -Path $caKeyPath -Name "AuditFilter" -Value $desiredAuditFilter

        Write-Host "[PKI] Restarting 'certsvc' service to apply new audit settings..." -ForegroundColor Cyan
        Restart-Service certsvc -Force
        Write-Host "[PKI] CA service restarted. AuditFilter now enforced." -ForegroundColor Green
    }

    Write-Host "[PKI] Local CA auditing configuration completed." -ForegroundColor Green
}

if ($CollectOnly) {
    Write-Host "[PKI] Collecting sample CA audit events from '$CaComputerName'..." -ForegroundColor Cyan

    # 4886 - Certificate Services received a certificate request
    # 4887 - Certificate Services approved a certificate request and issued a certificate
    # 4888 - Certificate Services denied a certificate request
    # 4889 - Certificate Services set the status of a certificate as revoked
    # 4890 - Certificate Services archived a key
    # 4891 - Certificate Services recovered a key
    # 4892 - Certificate Services published the CA certificate to Active Directory
    # 4893 - A certificate request extension changed
    $ids = 4886, 4887, 4888, 4889, 4890, 4891, 4892, 4893

    $startTime = (Get-Date).AddHours( - [math]::Abs($SampleHours))

    try {
        $events = Get-WinEvent -ComputerName $CaComputerName -FilterHashtable @{
            LogName   = 'Security'
            Id        = $ids
            StartTime = $startTime
        } -ErrorAction Stop

        if (-not $events) {
            Write-Host "[PKI] No CA-related security events found in the last $SampleHours hour(s)." -ForegroundColor Yellow
        }
        else {
            Write-Host "[PKI] Showing recent CA audit events (up to 20 entries)..." -ForegroundColor Green
            $events |
            Select-Object -First 20 TimeCreated, Id, LevelDisplayName, ProviderName, Message
        }
    }
    catch {
        Write-Warning "[PKI] Failed to read Security log on '$CaComputerName'. Check firewall, credentials and 'Manage auditing and security log' rights."
    }
}

Write-Host "`n[PKI] PKI auditing script finished." -ForegroundColor Cyan
