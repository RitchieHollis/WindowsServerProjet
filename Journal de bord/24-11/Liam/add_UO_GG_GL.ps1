Param(
    [string]$DomainDN = (Get-ADDomain).DistinguishedName
)

Import-Module ActiveDirectory

$RootOU = "Direction"
$RootOUPath = "OU=$RootOU,$DomainDN"

if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$RootOU)" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name $RootOU -Path $DomainDN
    Write-Host "OU créée : $RootOU"
} else {
    Write-Host "OU déjà existante : $RootOU"
}

$RootGroup = "GG_"+$RootOU.ToUpper()
if (-not (Get-ADGroup -Filter "SamAccountName -eq '$RootGroup'" -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name $RootGroup `
                -SamAccountName $RootGroup `
                -GroupScope Global `
                -GroupCategory Security `
                -Path $RootOUPath
    Write-Host "Groupe créé : $RootGroup"
} else {
    Write-Host "Groupe déjà existant : $RootGroup"
}

$GLTypes = @("R", "W", "RW")

foreach ($type in $GLTypes) {
    $GLName = "GL_DIRECTION_$type"

    if (-not (Get-ADGroup -Filter "SamAccountName -eq '$GLName'" -ErrorAction SilentlyContinue)) {

        New-ADGroup -Name $GLName `
                    -SamAccountName $GLName `
                    -GroupScope DomainLocal `
                    -GroupCategory Security `
                    -Path $RootOUPath

        Write-Host "GL créé : $GLName"
    }
    else {
        Write-Host "GL déjà existant : $GLName"
    }
}

$Structure = @{
    "Informatique"        = @("Developpement", "Hotline", "Systemes")
    "Ressources humaines" = @("Recrutement", "Gestion du personnel")
    "Finances"            = @("Investissements", "Comptabilite")
    "R&D"                 = @("Testing", "Recherche")
    "Technique"           = @("Techniciens", "Achat")
    "Commerciaux"         = @("Sedentaires", "Technico")
    "Marketting"          = @("Site1", "Site2", "Site3", "Site4")
}

Write-Host "=== DÉBUT DE CRÉATION DES OU, GG ET GL ===" -ForegroundColor Cyan

foreach ($OUParent in $Structure.Keys) {

    $ParentOUPath = "OU=$OUParent,$RootOUPath"

    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OUParent)" -SearchBase $RootOUPath -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $OUParent -Path $RootOUPath
        Write-Host "OU créée : $OUParent"
    } else {
        Write-Host "OU déjà existante : $OUParent"
    }

    foreach ($OUSub in $Structure[$OUParent]) {

        $SubOUPath = "OU=$OUSub,$ParentOUPath"

        if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OUSub)" -SearchBase $ParentOUPath -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $OUSub -Path $ParentOUPath
            Write-Host "  Sous-OU créée : $OUSub"
        } else {
            Write-Host "  Sous-OU déjà existante : $OUSub"
        }

        $Prefix = $OUParent.ToUpper().Replace(" ", "")
        $GroupName = "GG_${Prefix}_$($OUSub.ToUpper().Replace(' ', ''))"

        if (-not (Get-ADGroup -Filter "SamAccountName -eq '$GroupName'" -ErrorAction SilentlyContinue)) {

            New-ADGroup -Name $GroupName `
                        -SamAccountName $GroupName `
                        -GroupScope Global `
                        -GroupCategory Security `
                        -Path $SubOUPath

            Write-Host "    Groupe créé : $GroupName"
        } else {
            Write-Host "    Groupe déjà existant : $GroupName"
        }

        $GLs = @("R", "W", "RW")
        foreach ($type in $GLs) {

            $BaseName = $GroupName.Substring(3)
            $GLName = "GL_${BaseName}_${type}"

            if (-not (Get-ADGroup -Filter "SamAccountName -eq '$GLName'" -ErrorAction SilentlyContinue)) {

                New-ADGroup -Name $GLName `
                            -SamAccountName $GLName `
                            -GroupScope DomainLocal `
                            -GroupCategory Security `
                            -Path $SubOUPath

                Write-Host "        GL créé : $GLName"
            } else {
                Write-Host "        GL déjà existant : $GLName"
            }
        }
    }
}

Write-Host "=== SCRIPT TERMINÉ ===" -ForegroundColor Green
