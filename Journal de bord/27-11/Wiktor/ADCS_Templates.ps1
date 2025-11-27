<#
.SYNOPSIS
    Renforce la sécurité des modèles de certificats ADCS pour un environnement critique.

.DESCRIPTION
    Ce script met en place une séparation stricte des rôles autour de la PKI :

    - Création (si nécessaire) de groupes de sécurité dédiés :
        * PKI-Admins      : administration de la PKI / CA.
        * WebServerCerts  : serveurs autorisés à obtenir des certificats Web.
        * ScriptSigners   : comptes autorisés à obtenir des certificats de signature de code.

    - Application du principe du moindre privilège sur les modèles de certificats :
        * Modèle "Web Server" :
            - Accorde à WebServerCerts les droits Read + Enroll + Autoenroll.
            - Permet d’automatiser l’émission de certificats serveur uniquement
              pour les machines explicitement placées dans ce groupe.
        * Modèle "Code Signing" :
            - Accorde à ScriptSigners les droits Read + Enroll.
            - Pas d’Autoenroll pour éviter la distribution non contrôlée
              de certificats de signature de code.

    Les droits sont ajoutés directement sur les objets de modèles de certificats
    dans la partition Configuration d’Active Directory, via des ACE
    (Access Control Entries) spécifiques :

        - Read        : droit GenericRead sur le modèle.
        - Enroll      : droit étendu "Certificate-Enrollment"
                        (GUID 0e10c968-78fb-11d2-90d4-00c04f79dc55).
        - Autoenroll  : droit étendu "Certificate-AutoEnrollment"
                        (GUID a05b8cc2-17bc-4802-a710-e7c15ab866a2).

    Le script est idempotent : avant d’ajouter un droit, il vérifie si
    une ACE équivalente existe déjà pour le groupe cible. Les ACL existantes
    ne sont pas supprimées, ce qui évite de casser des droits hérités ou
    des délégations déjà en place.

    Objectif pédagogique / documentation :
        - Montrer comment la PKI est intégrée au contrôle d’accès (qui peut
          demander quel type de certificat).
        - Illustrer un modèle “standard d'entreprise” : peu de groupes,
          peu de comptes privilégiés, et des modèles de certificats
          verrouillés pour minimiser les scénarios d’abus (ESC1, ESC4, etc.).
#>

param(
    [string]$DomainName = "angleterre.lan"
)

Install-WindowsFeature RSAT-AD-PowerShell

Write-Host "`n[PKI] Starting certificate template hardening..." -ForegroundColor Cyan

if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory PowerShell module not found. Install RSAT-AD-PowerShell or run this script on the domain controller."
    return
}
Import-Module ActiveDirectory

$domain = Get-ADDomain -Identity $DomainName
$usersContainer = $domain.UsersContainer   # e.g. CN=Users,DC=...

function Ensure-AdGroup {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Description
    )

    $existing = Get-ADGroup -Filter "Name -eq '$Name'" -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
        Write-Host "[PKI] Creating group '$Name'..." -ForegroundColor Cyan
        $existing = New-ADGroup -Name $Name `
            -SamAccountName $Name `
            -GroupScope Global `
            -GroupCategory Security `
            -Path $usersContainer `
            -Description $Description
        Write-Host "[PKI] Group '$Name' created." -ForegroundColor Green
    }
    else {
        Write-Host "[PKI] Group '$Name' already exists." -ForegroundColor Yellow
    }

    return $existing
}

Ensure-AdGroup -Name "PKI-Admins"     -Description "Administrators of the PKI / certificate authority."
Ensure-AdGroup -Name "WebServerCerts" -Description "Servers allowed to enroll for Web Server certificates."
Ensure-AdGroup -Name "ScriptSigners"  -Description "Accounts allowed to enroll for Code Signing certificates."

function Ensure-TemplatePermissions {
    param(
        [Parameter(Mandatory)] [string]$TemplateDisplayName,
        [Parameter(Mandatory)] [string]$GroupSamAccountName,
        [switch]$AllowRead,
        [switch]$AllowEnroll,
        [switch]$AllowAutoEnroll
    )

    $configNC = ([ADSI]"LDAP://RootDSE").configurationNamingContext
    $templatesDN = "LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"

    $filter = "(&(objectClass=pKICertificateTemplate)(displayName=$TemplateDisplayName))"
    $searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]$templatesDN, $filter)
    $result = $searcher.FindOne()

    if ($null -eq $result) {
        throw "Certificate template with displayName '$TemplateDisplayName' not found."
    }

    $template = $result.GetDirectoryEntry()
    $domainNetbios = $domain.NetBIOSName
    $ntAccount = New-Object System.Security.Principal.NTAccount("$domainNetbios\$GroupSamAccountName")
    $identityValue = $ntAccount.Value

    $objectSecurity = $template.ObjectSecurity
    $needsCommit = $false

    #GUIDs for extended rights Enroll / AutoEnroll (from Microsoft schema docs)
    $enrollGuid = New-Object Guid "0e10c968-78fb-11d2-90d4-00c04f79dc55"
    $autoEnrollGuid = New-Object Guid "a05b8cc2-17bc-4802-a710-e7c15ab866a2"

    if ($AllowRead) {
        $hasRead = $false
        foreach ($ar in $objectSecurity.Access) {
            if ($ar.IdentityReference -like "*$identityValue" -and
                $ar.ActiveDirectoryRights.HasFlag([System.DirectoryServices.ActiveDirectoryRights]::GenericRead)) {
                $hasRead = $true
                break
            }
        }

        if (-not $hasRead) {
            Write-Host "[PKI] Adding READ permission on template '$TemplateDisplayName' for '$identityValue'..." -ForegroundColor Cyan
            $aceRead = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                $ntAccount,
                [System.DirectoryServices.ActiveDirectoryRights]::GenericRead,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            $objectSecurity.AddAccessRule($aceRead)
            $needsCommit = $true
        }
        else {
            Write-Host "[PKI] READ permission already present on '$TemplateDisplayName' for '$identityValue'." -ForegroundColor Yellow
        }
    }

    if ($AllowEnroll) {
        $hasEnroll = $false
        foreach ($ar in $objectSecurity.Access) {
            if ($ar.IdentityReference -like "*$identityValue" -and
                $ar.ActiveDirectoryRights.HasFlag([System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
                $ar.ObjectType -eq $enrollGuid) {
                $hasEnroll = $true
                break
            }
        }

        if (-not $hasEnroll) {
            Write-Host "[PKI] Adding ENROLL permission on template '$TemplateDisplayName' for '$identityValue'..." -ForegroundColor Cyan
            $aceEnroll = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                $ntAccount,
                [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
                [System.Security.AccessControl.AccessControlType]::Allow,
                $enrollGuid
            )
            $objectSecurity.AddAccessRule($aceEnroll)
            $needsCommit = $true
        }
        else {
            Write-Host "[PKI] ENROLL permission already present on '$TemplateDisplayName' for '$identityValue'." -ForegroundColor Yellow
        }
    }

    if ($AllowAutoEnroll) {
        $hasAuto = $false
        foreach ($ar in $objectSecurity.Access) {
            if ($ar.IdentityReference -like "*$identityValue" -and
                $ar.ActiveDirectoryRights.HasFlag([System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
                $ar.ObjectType -eq $autoEnrollGuid) {
                $hasAuto = $true
                break
            }
        }

        if (-not $hasAuto) {
            Write-Host "[PKI] Adding AUTOENROLL permission on template '$TemplateDisplayName' for '$identityValue'..." -ForegroundColor Cyan
            $aceAuto = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                $ntAccount,
                [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
                [System.Security.AccessControl.AccessControlType]::Allow,
                $autoEnrollGuid
            )
            $objectSecurity.AddAccessRule($aceAuto)
            $needsCommit = $true
        }
        else {
            Write-Host "[PKI] AUTOENROLL permission already present on '$TemplateDisplayName' for '$identityValue'." -ForegroundColor Yellow
        }
    }

    if ($needsCommit) {
        $template.ObjectSecurity = $objectSecurity
        $template.CommitChanges()
        Write-Host "[PKI] Permissions updated on template '$TemplateDisplayName'." -ForegroundColor Gray
    }
    else {
        Write-Host "[PKI] No changes required for template '$TemplateDisplayName'." -ForegroundColor Gray
    }
}


# Web Server: Read + Enroll + AutoEnroll for WebServerCerts
Ensure-TemplatePermissions -TemplateDisplayName "Web Server" `
    -GroupSamAccountName "WebServerCerts" `
    -AllowRead -AllowEnroll -AllowAutoEnroll

# Code Signing: Read + Enroll only (no AutoEnroll) for ScriptSigners
Ensure-TemplatePermissions -TemplateDisplayName "Code Signing" `
    -GroupSamAccountName "ScriptSigners" `
    -AllowRead -AllowEnroll

Write-Host "`n[PKI] Certificate template hardening completed." -ForegroundColor Gray
