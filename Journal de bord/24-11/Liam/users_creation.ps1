# Ce script crée des utilisateurs Active Directory à partir d’un fichier CSV.
# Chaque utilisateur est placé dans le bon OU "Users" correspondant à son département ou sous-département.
# Un mot de passe aléatoire est généré pour chaque utilisateur et stocké dans un fichier CSV.
# Les utilisateurs sont ajoutés au groupe global (GG) correspondant à leur département/sous-département.
# Les erreurs de création sont enregistrées dans un fichier séparé pour suivi.

Param(
    [Parameter(Mandatory=$true)]
    [string]$InputCsv
)

Import-Module ActiveDirectory

$DomainDN = (Get-ADDomain).DistinguishedName
$ErrorLog = ".\Users_Error.csv"
$PasswordLog = ".\Users_Passwords.csv"

# --- Fonction pour générer mot de passe aléatoire ---
function Generate-RandomPassword {

    $length = 7
    $upper = 65..90 | ForEach-Object {[char]$_}
    $lower = 97..122 | ForEach-Object {[char]$_}
    $digits = 48..57 | ForEach-Object {[char]$_}
    $special = "!@#$%^&*()_+-=".ToCharArray()

    $pw = @()
    $pw += $upper | Get-Random -Count 1
    $pw += $lower | Get-Random -Count 1
    $pw += $digits | Get-Random -Count 1
    $pw += $special | Get-Random -Count 1

    $allChars = $upper + $lower + $digits + $special
    $remainingLength = $Length - $pw.Count
    $pw += ($allChars | Get-Random -Count $remainingLength)
    $pw = $pw | Sort-Object {Get-Random}

    return -join $pw
}

$users = Import-Csv -Path $InputCsv
$ErrorUsers = @()
$PasswordList = @()

Write-Host "=== DÉBUT DE CRÉATION DES UTILISATEURS ===" -ForegroundColor Cyan

foreach ($user in $users) {
    try {

        $Nom = $user.Nom
        $Prenom = $user.Prenom
        $Description = $user.Description
        $Departement = $user.Departement
        $NInterne = $user.NInterne
        $Bureau = $user.Bureau

        $parts = $Departement -split "/"

        if ($parts.Count -eq 2) {
            $Dept = $parts[1]
            $SubDept = $parts[0]

            $OUPath = "OU=Users,OU=$SubDept,OU=$Dept,$DomainDN"

            $GGName = "GG_"+($Dept.Replace(" ","")).ToUpper()+"_"+$($SubDept.Replace(" ","")).ToUpper()

        } else {

            $Dept = $parts[0]

            $OUPath = "OU=Users,OU=$Dept,$DomainDN"

            $GGName = "GG"+"_"+$($Dept.Replace(" ","")).ToUpper()
        }

        $SAM = "$Prenom.$Nom"
        if ($SAM.Length -gt 20) {
            $SAM = "$($Prenom.Substring(0,1)).$Nom"
        }

        if (Get-ADUser -Filter "SamAccountName -eq '$SAM'" -ErrorAction SilentlyContinue) {
            $SAM += (Get-Random -Minimum 10 -Maximum 99)
        }

        $Password = Generate-RandomPassword
        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

        New-ADUser -Name "$Prenom $Nom" `
                   -GivenName $Prenom `
                   -Surname $Nom `
                   -Description $Description `
                   -Office $Bureau `
                   -OfficePhone $NInterne `
                   -SamAccountName $SAM `
                   -UserPrincipalName "$SAM@$(Get-ADDomain).DNSRoot" `
                   -AccountPassword $SecurePassword `
                   -Enabled $true `
                   -Path $OUPath

        Write-Host "[OK] Utilisateur créé : $SAM"

        if (Get-ADGroup -Identity $GGName -ErrorAction SilentlyContinue) {
            Add-ADGroupMember -Identity $GGName -Members $SAM
            Write-Host "     Ajouté au groupe : $GGName"
        } else {
            Write-Warning "     Groupe manquant : $GGName"
        }

        $PasswordList += [PSCustomObject]@{
            SAMAccountName = $SAM
            Password       = $Password
        }

    } catch {
        $errMsg = $_.Exception.Message
        Write-Warning "[ERREUR] Utilisateur non créé : $Nom $Prenom"
        Write-Warning "         Détail : $errMsg"

        $user | Add-Member -NotePropertyName "Erreur" -NotePropertyValue $errMsg -Force
        $ErrorUsers += $user
    }
}

if ($PasswordList.Count -gt 0) {
    $PasswordList | Export-Csv -Path $PasswordLog -NoTypeInformation -Encoding UTF8
    Write-Host "`nMot de passe des utilisateurs créés exporté dans : $PasswordLog" -ForegroundColor Green
}

if ($ErrorUsers.Count -gt 0) {
    $ErrorUsers | Export-Csv -Path $ErrorLog -NoTypeInformation -Encoding UTF8
    Write-Host "`nCertains utilisateurs n'ont pas pu être créés. Voir le fichier : $ErrorLog" -ForegroundColor Yellow
}

Write-Host "`n=== SCRIPT TERMINÉ ===" -ForegroundColor Green
