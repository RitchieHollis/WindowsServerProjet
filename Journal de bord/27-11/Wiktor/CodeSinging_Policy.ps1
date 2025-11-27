<#
.SYNOPSIS
    Met en place une politique de signature de scripts PowerShell appuyée sur la PKI interne.

.DESCRIPTION
    Ce script renforce l’usage de PowerShell dans le domaine en imposant la signature
    des scripts et en isolant la capacité de signer dans un compte dédié :

    - Création (si nécessaire) d’une GPO "PKI-CodeSigning-Policy" :
        * ExecutionPolicy = AllSigned sur les machines ciblées
          (les scripts locaux ou distants doivent être signés par un certificat de
           confiance pour pouvoir s’exécuter).
        * Activation de la clé de registre "EnableScripts" dans les stratégies,
          afin que PowerShell prenne bien en compte la politique de signature.

    - Lien optionnel de la GPO sur des UO spécifiques (par exemple UO des serveurs
      et des postes d’administration). Les DN des UO sont paramétrables pour
      s’adapter à la structure réelle du domaine.

    - Création d’un compte de service "ScriptSigner" dédié à la signature de code :
        * Le compte est placé dans le groupe "ScriptSigners" (créé par le script
          ADCS_Templates.ps1).
        * Ce compte sera utilisé pour s’authentifier sur un poste d’administration,
          demander un certificat "Code Signing" auprès de la CA, puis signer les scripts.

    - Mise en place optionnelle d’un partage de scripts officiel :
        * Création d’un dossier de référence (par défaut C:\SecureScripts) et d’un
          partage SMB (par défaut \\<serveur>\SecureScripts).
        * Droits NTFS/share configurés de façon à ce que :
            - Domain Admins : contrôle total.
            - ScriptSigners : modification / écriture.
            - Utilisateurs standards : lecture seule.
        * Objectif : garantir que les scripts exécutés en production proviennent
          d’un emplacement central contrôlé et sont signés par un certificat
          "Code Signing" émis par la PKI interne.

    Ce script est idempotent : si la GPO, le compte ou le partage existent déjà,
    ils sont réutilisés et simplement ajustés à l’état souhaité.

    Si error : installer group policy managment avec Install-WindowsFeature GPMC
#>

param(
    [string]$DomainName = "angleterre.lan",
    [string]$GpoName = "PKI-CodeSigning-Policy",

    [string]$ServersOuDn = "OU=Servers,DC=angleterre,DC=lan",
    [string]$AdminWorkstationsOuDn = "OU=AdminWorkstations,DC=angleterre,DC=lan",

    [bool]  $CreateScriptShare = $true,
    [string]$ScriptSharePath = "C:\SecureScripts",
    [string]$ScriptShareName = "SecureScripts"
)

Write-Host "`n[CodeSigning] Starting code signing policy configuration" -ForegroundColor Cyan

if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found. Run this on the domain controller or install RSAT-AD-PowerShell."
    return
}
if (-not (Get-Module -ListAvailable -Name GroupPolicy)) {
    Write-Error "GroupPolicy module not found. Install GPMC/RSAT-GroupPolicy on this server."
    return
}

Import-Module ActiveDirectory
Import-Module GroupPolicy

$domain = Get-ADDomain -Identity $DomainName
$netbios = $domain.NetBIOSName

Write-Host "[CodeSigning] Ensuring GPO '$GpoName' exists" -ForegroundColor Cyan
$gpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue
if (-not $gpo) {
    $gpo = New-GPO -Name $GpoName -Comment "PKI-backed PowerShell code signing policy (ExecutionPolicy = AllSigned)."
    Write-Host "[CodeSigning] GPO '$GpoName' created." -ForegroundColor Gray
}
else {
    Write-Host "[CodeSigning] GPO '$GpoName' already exists." -ForegroundColor Yellow
}

# Registry path used by the "Turn on Script Execution" policy:
# HKLM\Software\Policies\Microsoft\Windows\PowerShell
#   EnableScripts (DWORD) = 1
#   ExecutionPolicy (REG_SZ) = "AllSigned"

Write-Host "[CodeSigning] Configuring ExecutionPolicy = AllSigned in GPO..." -ForegroundColor Cyan

$policyKey = "HKLM\Software\Policies\Microsoft\Windows\PowerShell"
Set-GPRegistryValue -Name $GpoName -Key $policyKey -ValueName "EnableScripts"  -Type DWord -Value 1
Set-GPRegistryValue -Name $GpoName -Key $policyKey -ValueName "ExecutionPolicy" -Type String -Value "AllSigned"

Write-Host "[CodeSigning] ExecutionPolicy configured in GPO." -ForegroundColor Gray

# Optionally link the GPO to OUs (if they exist)
function Link-GpoIfOuExists {
    param(
        [string]$OuDn
    )
    if ([string]::IsNullOrWhiteSpace($OuDn)) {
        return
    }

    try {
        Get-ADOrganizationalUnit -Identity $OuDn -ErrorAction Stop
        $existingLinks = (Get-GPInheritance -Target $OuDn).GpoLinks | Select-Object -ExpandProperty DisplayName
        if ($existingLinks -notcontains $GpoName) {
            Write-Host "[CodeSigning] Linking GPO '$GpoName' to OU '$OuDn'..." -ForegroundColor Cyan
            New-GPLink -Name $GpoName -Target $OuDn -Enforced:$false | Out-Null
            Write-Host "[CodeSigning] GPO linked to OU '$OuDn'." -ForegroundColor Gray
        }
        else {
            Write-Host "[CodeSigning] GPO '$GpoName' already linked to OU '$OuDn'." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "[CodeSigning] OU '$OuDn' not found. Adjust the DN in the script parameters if needed."
    }
}

Link-GpoIfOuExists -OuDn $ServersOuDn
Link-GpoIfOuExists -OuDn $AdminWorkstationsOuDn

Write-Host "[CodeSigning] Ensuring 'ScriptSigner' account exists..." -ForegroundColor Cyan

$scriptSignerUser = Get-ADUser -Filter "SamAccountName -eq 'ScriptSigner'" -ErrorAction SilentlyContinue
$usersContainer = $domain.UsersContainer

if (-not $scriptSignerUser) {
    # Ask for an initial password so we don't hardcode secrets in the script
    $securePwd = Read-Host "Enter initial password for ScriptSigner (will not be echoed)" -AsSecureString

    $scriptSignerUser = New-ADUser -Name "ScriptSigner" `
        -SamAccountName "ScriptSigner" `
        -UserPrincipalName "ScriptSigner@$DomainName" `
        -Path $usersContainer `
        -AccountPassword $securePwd `
        -Enabled $true `
        -Description "Dedicated account for PowerShell code signing."

    #rotation is mandatory - for this project I won't expire passwords
    Set-ADUser -Identity $scriptSignerUser -PasswordNeverExpires $true

    Write-Host "[CodeSigning] User 'ScriptSigner' created." -ForegroundColor Gray
}
else {
    Write-Host "[CodeSigning] User 'ScriptSigner' already exists." -ForegroundColor Yellow
}

# Ensure ScriptSigner is member of ScriptSigners group
$scriptSignersGroup = Get-ADGroup -Filter "SamAccountName -eq 'ScriptSigners'" -ErrorAction SilentlyContinue
if ($null -eq $scriptSignersGroup) {
    Write-Warning "[CodeSigning] Group 'ScriptSigners' not found. Run ADCS_Templates.ps1 first."
}
else {
    $isMember = Get-ADGroupMember -Identity $scriptSignersGroup -Recursive |
    Where-Object { $_.SamAccountName -eq "ScriptSigner" }

    if (-not $isMember) {
        Write-Host "[CodeSigning] Adding 'ScriptSigner' to group 'ScriptSigners'..." -ForegroundColor Cyan
        Add-ADGroupMember -Identity $scriptSignersGroup -Members $scriptSignerUser
        Write-Host "[CodeSigning] Membership updated." -ForegroundColor Green
    }
    else {
        Write-Host "[CodeSigning] 'ScriptSigner' is already member of 'ScriptSigners'." -ForegroundColor Yellow
    }
}

if ($CreateScriptShare) {
    Write-Host "[CodeSigning] Ensuring central script share '$ScriptShareName' exists..." -ForegroundColor Cyan

    # Create folder if needed
    if (-not (Test-Path $ScriptSharePath)) {
        New-Item -ItemType Directory -Path $ScriptSharePath -Force | Out-Null
        Write-Host "[CodeSigning] Folder '$ScriptSharePath' created." -ForegroundColor Gray
    }

    # Configure NTFS ACL (Domain Admins = Full, ScriptSigners = Modify, Authenticated Users = Read & Execute)
    $acl = Get-Acl $ScriptSharePath
    $acl.SetAccessRuleProtection($true, $false)   # disable inheritance, remove inherited ACEs

    # Remove existing explicit ACEs to start from a clean baseline
    foreach ($rule in $acl.Access) {
        $acl.RemoveAccessRule($rule) | Out-Null
    }

    $adminsAccount = New-Object System.Security.Principal.NTAccount("$netbios\Domain Admins")
    $signersAccount = New-Object System.Security.Principal.NTAccount("$netbios\ScriptSigners")
    $usersAccount = New-Object System.Security.Principal.NTAccount("NT AUTHORITY\Authenticated Users")


    $inheritFlags = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $propFlags = [System.Security.AccessControl.PropagationFlags]::None

    $ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $adminsAccount, "FullControl", $inheritFlags, $propFlags, "Allow"
    )
    $ruleSigners = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $signersAccount, "Modify", $inheritFlags, $propFlags, "Allow"
    )
    $ruleUsers = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $usersAccount, "ReadAndExecute", $inheritFlags, $propFlags, "Allow"
    )

    $acl.AddAccessRule($ruleAdmins)
    $acl.AddAccessRule($ruleSigners)
    $acl.AddAccessRule($ruleUsers)

    Set-Acl -Path $ScriptSharePath -AclObject $acl
    Write-Host "[CodeSigning] NTFS permissions configured on '$ScriptSharePath'." -ForegroundColor Gray

    # Create SMB share if not already present
    $existingShare = Get-SmbShare -Name $ScriptShareName -ErrorAction SilentlyContinue
    if (-not $existingShare) {
        New-SmbShare -Name $ScriptShareName -Path $ScriptSharePath `
            -FullAccess "$netbios\Domain Admins" `
            -ChangeAccess "$netbios\ScriptSigners" `
            -ReadAccess "Nt AUTHORITY\Authenticated Users" | Out-Null

        Write-Host "[CodeSigning] SMB share '$ScriptShareName' created for path '$ScriptSharePath'." -ForegroundColor Gray
    }
    else {
        Write-Host "[CodeSigning] SMB share '$ScriptShareName' already exists." -ForegroundColor Yellow
    }

    Write-Host "[CodeSigning] Central script repository available at: \\$($env:COMPUTERNAME)\$ScriptShareName" -ForegroundColor Gray
}

Write-Host "`n[CodeSigning] Code signing policy configuration completed." -ForegroundColor Gray
Write-Host "    - GPO : $GpoName"
Write-Host "    - Signer account : $($scriptSignerUser.SamAccountName)"
if ($CreateScriptShare) {
    Write-Host "    - Script share : \\$($env:COMPUTERNAME)\$ScriptShareName"
}
Write-Host ""