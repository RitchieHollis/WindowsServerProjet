# Ce script crée automatiquement la structure Active Directory des départements et sous-départements.
# Pour chaque département sans sous-OU, il crée des sous-dossiers "GG", "GL" et "Users" et les groupes correspondants.
# Pour les départements avec sous-OU, il ne crée pas de sous-dossiers au niveau parent, mais les crée pour chaque sous-département.
# Les groupes "GG" (Global) et "GL" (Domain Local) sont générés selon la nomenclature de chaque département et sous-département.
# Le script vérifie également si les OU et les groupes existent déjà pour éviter les doublons.

Param(
    [string]$DomainDN = (Get-ADDomain).DistinguishedName
)

Import-Module ActiveDirectory

$Structure = @{
    "Direction"           = @()
    "Informatique"        = @("Developpement", "Hotline", "Systemes")
    "Ressources humaines" = @("Recrutement", "Gestion du personnel")
    "Finances"            = @("Investissements", "Comptabilite")
    "R&D"                 = @("Testing", "Recherche")
    "Technique"           = @("Techniciens", "Achat")
    "Commerciaux"         = @("Sedentaires", "Technico")
    "Marketting"          = @("Site1", "Site2", "Site3", "Site4")
}

$SubFolders = @("GG", "GL", "Users")
$GLTypes = @("R", "W", "RW")

Write-Host "=== DÉBUT DE CRÉATION DES OU, GG, GL ET USERS ===" -ForegroundColor Cyan

foreach ($OUParent in $Structure.Keys) {

    $ParentOUPath = "OU=$OUParent,$DomainDN"

    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OUParent)" -SearchBase $DomainDN -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $OUParent -Path $DomainDN
        Write-Host "OU créée : $OUParent"
    } else {
        Write-Host "OU déjà existante : $OUParent"
    }

    if ($Structure[$OUParent].Count -eq 0) {

        Write-Host "   Département sans sous-OU : création de GG / GL / Users"

        foreach ($folder in $SubFolders) {
            $FolderPath = "OU=$folder,OU=$OUParent,$DomainDN"

            if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$folder)" -SearchBase $ParentOUPath -ErrorAction SilentlyContinue)) {
                New-ADOrganizationalUnit -Name $folder -Path $ParentOUPath
                Write-Host "    Sous-OU créée : $folder"
            } else {
                Write-Host "    Sous-OU déjà existante : $folder"
            }
        }

        $Prefix = $OUParent.ToUpper().Replace(" ", "")

        $GroupGG = "GG_${Prefix}"
        $GGPath = "OU=GG,OU=$OUParent,$DomainDN"

        if (-not (Get-ADGroup -Filter "SamAccountName -eq '$GroupGG'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $GroupGG `
                        -SamAccountName $GroupGG `
                        -GroupScope Global `
                        -GroupCategory Security `
                        -Path $GGPath
            Write-Host "    Groupe créé : $GroupGG"
        } else {
            Write-Host "    Groupe déjà existant : $GroupGG"
        }

        foreach ($type in $GLTypes) {
            $GLName = "GL_${Prefix}_${type}"
            $GLPath = "OU=GL,OU=$OUParent,$DomainDN"

            if (-not (Get-ADGroup -Filter "SamAccountName -eq '$GLName'" -ErrorAction SilentlyContinue)) {
                New-ADGroup -Name $GLName `
                            -SamAccountName $GLName `
                            -GroupScope DomainLocal `
                            -GroupCategory Security `
                            -Path $GLPath
                Write-Host "    GL créé : $GLName"
            } else {
                Write-Host "    GL déjà existant : $GLName"
            }
        }

        continue
    }

    Write-Host "   Département avec sous-OU : pas de GG/GL/Users dans $OUParent"

    foreach ($OUSub in $Structure[$OUParent]) {

        $SubOUPath = "OU=$OUSub,$ParentOUPath"

        if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OUSub)" -SearchBase $ParentOUPath -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $OUSub -Path $ParentOUPath
            Write-Host "    Sous-OU créée : $OUSub"
        } else {
            Write-Host "    Sous-OU déjà existante : $OUSub"
        }

        foreach ($folder in $SubFolders) {
            $SubFolderPath = "OU=$folder,OU=$OUSub,OU=$OUParent,$DomainDN"

            if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$folder)" -SearchBase $SubOUPath -ErrorAction SilentlyContinue)) {
                New-ADOrganizationalUnit -Name $folder -Path $SubOUPath
                Write-Host "      Sous-OU créée : $folder"
            } else {
                Write-Host "      Sous-OU déjà existante : $folder"
            }
        }

        $PrefixParent = $OUParent.ToUpper().Replace(" ", "")
        $PrefixSub = $OUSub.ToUpper().Replace(" ", "")

        $GroupGGSub = "GG_${PrefixParent}_${PrefixSub}"
        $GGSubPath = "OU=GG,OU=$OUSub,OU=$OUParent,$DomainDN"

        if (-not (Get-ADGroup -Filter "SamAccountName -eq '$GroupGGSub'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $GroupGGSub `
                        -SamAccountName $GroupGGSub `
                        -GroupScope Global `
                        -GroupCategory Security `
                        -Path $GGSubPath
            Write-Host "      Groupe créé : $GroupGGSub"
        } else {
            Write-Host "      Groupe déjà existant : $GroupGGSub"
        }

        foreach ($type in $GLTypes) {
            $GLNameSub = "GL_${PrefixParent}_${PrefixSub}_${type}"
            $GLSubPath = "OU=GL,OU=$OUSub,OU=$OUParent,$DomainDN"

            if (-not (Get-ADGroup -Filter "SamAccountName -eq '$GLNameSub'" -ErrorAction SilentlyContinue)) {
                New-ADGroup -Name $GLNameSub `
                            -SamAccountName $GLNameSub `
                            -GroupScope DomainLocal `
                            -GroupCategory Security `
                            -Path $GLSubPath
                Write-Host "      GL créé : $GLNameSub"
            } else {
                Write-Host "      GL déjà existant : $GLNameSub"
            }
        }
    }
}

Write-Host "=== SCRIPT TERMINÉ ===" -ForegroundColor Green
