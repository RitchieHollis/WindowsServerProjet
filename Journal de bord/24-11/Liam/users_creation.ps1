Param(
    [Parameter(Mandatory=$true)]
    [string]$InputCsv
)

Import-Module ActiveDirectory

$DomainDN = (Get-ADDomain).DistinguishedName
$RootOU = "Direction"
$ErrorLog = ".\Users_Error.csv"
$PasswordLog = ".\Users_Passwords.csv"

# --- Fonction pour générer mot de passe aléatoire ---
function Generate-RandomPassword {
    param([int]$Length = 12)

    if ($Length -lt 7) { $Length = 7 } # minimum requis

    $upper = 65..90 | ForEach-Object {[char]$_}      # A-Z
    $lower = 97..122 | ForEach-Object {[char]$_}     # a-z
    $digits = 48..57 | ForEach-Object {[char]$_}     # 0-9
    $special = "!@#$%^&*()_+-=".ToCharArray()       # caractères spéciaux

    # Sélection d'au moins un caractère de chaque catégorie
    $pw = @()
    $pw += $upper | Get-Random -Count 1
    $pw += $lower | Get-Random -Count 1
    $pw += $digits | Get-Random -Count 1
    $pw += $special | Get-Random -Count 1

    # Remplissage du reste de la longueur
    $allChars = $upper + $lower + $digits + $special
    $remainingLength = $Length - $pw.Count
    $pw += ($allChars | Get-Random -Count $remainingLength)

    # Mélange aléatoire des caractères pour éviter un ordre prévisible
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
            $ParentOUName = $parts[1]
            $OUName = $parts[0]

            $OUPath = "OU=$OUName,OU=$ParentOUName,OU=$RootOU,$DomainDN"

            $OUClean = ($OUName.Replace(" ","")).ToUpper()
            $ParentOUClean = ($ParentOUName.Replace(" ","")).ToUpper()
            $GGName = "GG_${ParentOUClean}_${OUClean}"
        } else {
            $OUName = $Departement
            $OUPath = "OU=$OUName,$DomainDN"
            $GGName = "GG_$($OUName.ToUpper())"
        }

        # --- DEBUG : affichage OU et GG ---
        # Write-Host "[DEBUG] OUPath : $OUPath"
        # Write-Host "[DEBUG] Groupe GG : $GGName"

        $SAM = "$Prenom.$Nom"
        if ($SAM.Length -gt 20) {
            $SAM = "$($Prenom.Substring(0,1)).$Nom"
        }

        if (Get-ADUser -Filter "SamAccountName -eq '$SAM'" -ErrorAction SilentlyContinue) {
            $SAM += (Get-Random -Minimum 10 -Maximum 99)
        }

        $Password = Generate-RandomPassword 12
        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

        New-ADUser -Name "$Prenom $Nom" `
                   -GivenName $Prenom `
                   -Surname $Nom `
                   -Description $Description `
                   -Office $Bureau `
                   -EmployeeID $NInterne `
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
