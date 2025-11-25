param(
    [string]$SharesRoot = "C:\Shares",
    [string]$DepartmentsBaseOU = "OU=Departments,DC=Angleterre,DC=lan",
    [string]$DirectionGroupSam = "Direction",
    [string]$AllUsersGroupSam = "Domain Users" 
)

Import-Module ActiveDirectory

Write-Host "Department permissions init" -ForegroundColor Yellow

$Structure = @{
    "Informatique"        = @("Developpement", "Hotline", "Systemes")
    "Ressources humaines" = @("Recrutement", "Gestion du personnel")
    "Finances"            = @("Investissements", "Comptabilite")
    "R&D"                 = @("Testing", "Recherche")
    "Technique"           = @("Techniciens", "Achat")
    "Commerciaux"         = @("Sedentaires", "Technico")
    "Marketing"           = @("Site1", "Site2", "Site3", "Site4")
}

function Get-SubDeptGroupName {
    param(
        [string]$Department,
        [string]$SubDepartment
    )

    #"Informatique" + "Developpement" -> "GG_Informatique_Developpement"
    $deptSafe = ($Department -replace '\s+', '')
    $subSafe = ($SubDepartment -replace '\s+', '')

    return "GG_${deptSafe}_${subSafe}"
}


# NTFS perms
function Grant-FolderPermission {
    param(
        [string]$Path,
        [string]$Identity,   #ANGLETERRE\GG_Informatique_Developpement
        [System.Security.AccessControl.FileSystemRights]$Rights
    )

    $acl = Get-Acl -Path $Path

    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $Identity,
        $Rights,
        'ContainerInherit, ObjectInherit',
        'None',
        'Allow'
    )

    $acl.SetAccessRule($rule)
    Set-Acl -Path $Path -AclObject $acl
}

$domainNetBIOS = (Get-ADDomain).NetBIOSName

$DirectionIdentity = "$domainNetBIOS\$DirectionGroupSam"
$AllUsersIdentity = "$domainNetBIOS\$AllUsersGroupSam"

$DeptInfo = @{}  # Dept -> SubDept -> [Group, Users, Manager]

foreach ($dept in $Structure.Keys) {
    $DeptInfo[$dept] = @{}

    foreach ($sub in $Structure[$dept]) {
        $groupName = Get-SubDeptGroupName -Department $dept -SubDepartment $sub

        Write-Host "Dept '$dept' / Sub '$sub' -> Group '$groupName'" -ForegroundColor Yellow

        try {
            $group = Get-ADGroup -Identity $groupName -ErrorAction Stop
        }
        catch {
            Write-Warning "Group '$groupName' not found, skipping this sub-department."
            continue
        }

        $users = Get-ADGroupMember -Identity $group |
        Where-Object { $_.objectClass -eq 'user' }

        if (-not $users) {
            Write-Warning "No users in group '$groupName', skipping responsable selection."
            continue
        }

        $manager = Get-Random -InputObject $users

        $DeptInfo[$dept][$sub] = [PSCustomObject]@{
            Group   = $group.SamAccountName
            Users   = $users
            Manager = $manager
        }

        Write-Host "  -> And our winner is... drum-roll please: $($manager.SamAccountName)" -ForegroundColor Green
    }
}

$AllManagersIdentities = @()

foreach ($dept in $DeptInfo.Keys) {
    foreach ($entry in $DeptInfo[$dept].GetEnumerator()) {
        $mgrSam = $entry.Value.Manager.SamAccountName
        $AllManagersIdentities += "$domainNetBIOS\$mgrSam"
    }
}
$AllManagersIdentities = $AllManagersIdentities | Select-Object -Unique

Write-Host ""
Write-Host "Applying NTFS permissions under $SharesRoot" -ForegroundColor Yellow

#not sure for this one, lads
function Cleanup-Inheritance {
    param([string]$Path)

    icacls $Path /inheritance:d | Out-Null

    #Try to remove some generic groups if present, ignore errors
    foreach ($g in @("BUILTIN\Users", "Users", "Authenticated Users", "Everyone")) {
        icacls $Path /remove:g $g 2>$null | Out-Null
    }
}

foreach ($dept in $DeptInfo.Keys) {

    $deptData = $DeptInfo[$dept]

    if ($deptData.Count -eq 0) {
        Write-Warning "No valid sub-departments for '$dept', skipping permissions."
        continue
    }

    $deptPath = Join-Path $SharesRoot $dept

    if (-not (Test-Path $deptPath)) {
        Write-Warning "Folder '$deptPath' not found, skipping."
        continue
    }

    Write-Host ""
    Write-Host "== Department: $dept ==" -ForegroundColor Magenta

    Cleanup-Inheritance -Path $deptPath

    # Compute group + manager identities
    $subEntries = $deptData.GetEnumerator()
    $subGroups = $subEntries | ForEach-Object { "$domainNetBIOS\$($_.Value.Group)" }
    $managers = $subEntries | ForEach-Object { "$domainNetBIOS\$($_.Value.Manager.SamAccountName)" }

    # Dept root: all workers R, responsables RW
    Write-Host "  [A] Setting ACL on '$deptPath'" -ForegroundColor Cyan
    foreach ($g in $subGroups) {
        Grant-FolderPermission -Path $deptPath -Identity $g -Rights 'ReadAndExecute'
    }
    foreach ($m in $managers) {
        Grant-FolderPermission -Path $deptPath -Identity $m -Rights 'Modify'
    }

    # Direction: RW on department root
    Grant-FolderPermission -Path $deptPath -Identity $DirectionIdentity -Rights 'Modify'

    # Commun folder: everyone in dept RW (common space)
    $communPath = Join-Path $deptPath "Commun"
    if (Test-Path $communPath) {
        Write-Host "  [B] Setting ACL on '$communPath'" -ForegroundColor Cyan
        Cleanup-Inheritance -Path $communPath

        foreach ($g in $subGroups) {
            Grant-FolderPermission -Path $communPath -Identity $g -Rights 'Modify'
        }
    }

    # Direction also RW on department Commun
    Grant-FolderPermission -Path $communPath -Identity $DirectionIdentity -Rights 'Modify'

    #Sub-department folders: own group RW, others R
    foreach ($entry in $deptData.GetEnumerator()) {
        $sub = $entry.Key
        $info = $entry.Value

        $subPath = Join-Path $deptPath $sub
        if (-not (Test-Path $subPath)) {
            Write-Warning "Sub-folder '$subPath' not found, skipping."
            continue
        }

        Write-Host "  [C] Setting ACL on '$subPath'" -ForegroundColor Cyan
        Cleanup-Inheritance -Path $subPath

        $ownGroup = "$domainNetBIOS\$($info.Group)"
        $ownManager = "$domainNetBIOS\$($info.Manager.SamAccountName)"

        # Own sub-dept: RW
        Grant-FolderPermission -Path $subPath -Identity $ownGroup   -Rights 'Modify'
        Grant-FolderPermission -Path $subPath -Identity $ownManager -Rights 'Modify'

        # Other sub-departments: R
        foreach ($other in $deptData.GetEnumerator() | Where-Object { $_.Key -ne $sub }) {
            $otherGroup = "$domainNetBIOS\$($other.Value.Group)"
            Grant-FolderPermission -Path $subPath -Identity $otherGroup -Rights 'ReadAndExecute'
        }

        # Direction RW on each sub-department folder
        Grant-FolderPermission -Path $subPath -Identity $DirectionIdentity -Rights 'Modify'
    }
}

Write-Host ""
Write-Host "Global Commun folder rules " -ForegroundColor Magenta

$globalCommunPath = Join-Path $SharesRoot "Commun"

if (Test-Path $globalCommunPath) {
    Cleanup-Inheritance -Path $globalCommunPath

    Write-Host "  Setting ACL on '$globalCommunPath'" -ForegroundColor Cyan

    Grant-FolderPermission -Path $globalCommunPath -Identity $AllUsersIdentity -Rights 'ReadAndExecute'
    foreach ($mgr in $AllManagersIdentities) {
        Grant-FolderPermission -Path $globalCommunPath -Identity $mgr -Rights 'Modify'
    }
    Grant-FolderPermission -Path $globalCommunPath -Identity $DirectionIdentity -Rights 'Modify'
}
else {
    Write-Warning "Global Commun folder '$globalCommunPath' not found, skipping."
}

Write-Host ""
Write-Host "Department permissions script completed. That's bloody lovely" -ForegroundColor Yellow
