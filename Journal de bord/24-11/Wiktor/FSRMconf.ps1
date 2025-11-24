<# 
Init-FSRM.ps1


Configuration de FSRM pour DCroot :
    - Création des départments/sous-départements/dossier en commun
    - Création des quotas templates 
    - Application des quotas sur les dossiers
    - Création du filtre pour bloquer tous les fichiers non acceptés (pas documents office/images)
    - Les screen des fichiers pour les dossiers

    Les valeurs se trouvent dans la partie CONFIG
#>


#---------CONFIG---------------

$BasePath = "D:\Shares"
$CommonFolderName = "Commun"

$Departments = @{
    "Direction" = @()
    "RH"        = @("Gestion", "Recrutement")
    "Compta"    = @()
    "Informatique" = @("Support", "Projet")
}

$UserHomesRoot = "D:\Homes"  

#sizes in MB
$DeptQuotaMB    = 500
$SubDeptQuotaMB = 100
$CommunQuotaMB  = 500
$HomeQuotaMB    = 200          

# E-mail for FSRM notifications (requires SMTP config in FSRM options) == ???
$AdminEmail = "admin@contoso.lan"  

$BlockedFileGroups = @(
    "Executables and Scripts",
    "Audio and Video Files",
    "Compressed Files"
    # etc.
)

#-------------------------------------------------

Write-Host "Init-FSRM starting..." -ForegroundColor Cyan

#check
Import-Module FileServerResourceManager -ErrorAction Stop

Write-Host "[1] Creating folder tree under $BasePath ..." -ForegroundColor Cyan

# Base + Commun
New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $BasePath $CommonFolderName) -Force | Out-Null

foreach ($dept in $Departments.Keys) {
    $deptPath = Join-Path $BasePath $dept
    New-Item -ItemType Directory -Path $deptPath -Force | Out-Null

    foreach ($sub in $Departments[$dept]) {
        $subPath = Join-Path $deptPath $sub
        New-Item -ItemType Directory -Path $subPath -Force | Out-Null
    }
}

if ($UserHomesRoot) {
    Write-Host "Creating user homes root at $UserHomesRoot..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $UserHomesRoot -Force | Out-Null
}

Write-Host "[2] Creating quota templates..." -ForegroundColor Cyan

function New-HardQuotaTemplate {
    param(
        [string]$Name,
        [int64]$SizeMB,
        [string]$Description
    )

    # Threshold actions: event log
    $thresholds = @(
        New-FsrmQuotaThreshold -Percentage 80 -Action (New-FsrmAction -Type Event),
        New-FsrmQuotaThreshold -Percentage 90 -Action (New-FsrmAction -Type Event),
        New-FsrmQuotaThreshold -Percentage 100 -Action (New-FsrmAction -Type Event)
    )

    New-FsrmQuotaTemplate -Name $Name `
        -Description $Description `
        -Size ($SizeMB * 1MB) `
        -Threshold $thresholds `
        -ErrorAction SilentlyContinue | Out-Null
}

New-HardQuotaTemplate -Name "Dept_${DeptQuotaMB}MB_Hard" `
                      -SizeMB $DeptQuotaMB `
                      -Description "Hard quota for department folders"

New-HardQuotaTemplate -Name "SubDept_${SubDeptQuotaMB}MB_Hard" `
                      -SizeMB $SubDeptQuotaMB `
                      -Description "Hard quota for sub-department folders"

New-HardQuotaTemplate -Name "Commun_${CommunQuotaMB}MB_Hard" `
                      -SizeMB $CommunQuotaMB `
                      -Description "Hard quota for Commun folder"

if ($UserHomesRoot) {
    New-HardQuotaTemplate -Name "Home_${HomeQuotaMB}MB_Hard" `
                          -SizeMB $HomeQuotaMB `
                          -Description "Hard quota for user home directories"
}

Write-Host "[3] Applying quotas to department/sub-dept /Commun..." -ForegroundColor Cyan

foreach ($dept in $Departments.Keys) {
    $deptPath = Join-Path $BasePath $dept
    if (Test-Path $deptPath) {
        New-FsrmQuota -Path $deptPath `
            -Template "Dept_${DeptQuotaMB}MB_Hard" `
            -ErrorAction SilentlyContinue | Out-Null
    }

    foreach ($sub in $Departments[$dept]) {
        $subPath = Join-Path $deptPath $sub
        if (Test-Path $subPath) {
            New-FsrmQuota -Path $subPath `
                -Template "SubDept_${SubDeptQuotaMB}MB_Hard" `
                -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

$communPath = Join-Path $BasePath $CommonFolderName
if (Test-Path $communPath) {
    New-FsrmQuota -Path $communPath `
        -Template "Commun_${CommunQuotaMB}MB_Hard" `
        -ErrorAction SilentlyContinue | Out-Null
}

if ($UserHomesRoot -and (Test-Path $UserHomesRoot)) {
    Write-Host "Applying auto-quota template for user homes under $UserHomesRoot ..." -ForegroundColor Cyan
    # Auto-quota: any new folder directly under $UserHomesRoot gets this template
    New-FsrmAutoQuota -Path $UserHomesRoot `
        -Template "Home_${HomeQuotaMB}MB_Hard" `
        -ReevaluateExistingQuotas:$true `
        -ErrorAction SilentlyContinue | Out-Null
}

Write-Host "[4] Creating file screen template ..." -ForegroundColor Cyan

#check
$existingGroups = Get-FsrmFileGroup
$validGroups = $existingGroups | Where-Object { $BlockedFileGroups -contains $_.Name } | Select-Object -ExpandProperty Name

if ($validGroups.Count -eq 0) {
    Write-Warning "None of the requested file groups were found on this server. Adjust `$BlockedFileGroups or create custom groups."
} else {
    New-FsrmFileScreenTemplate -Name "Block_NonOffice_NonImages" `
        -IncludeGroup $validGroups `
        -Active `
        -Action (New-FsrmAction -Type Event) `
        -ErrorAction SilentlyContinue | Out-Null

    Write-Host "[5] Applying file screens to shared folders ..." -ForegroundColor Cyan

    $pathsToScreen = @()

    foreach ($dept in $Departments.Keys) {
        $deptPath = Join-Path $BasePath $dept
        if (Test-Path $deptPath) { $pathsToScreen += $deptPath }

        foreach ($sub in $Departments[$dept]) {
            $subPath = Join-Path $deptPath $sub
            if (Test-Path $subPath) { $pathsToScreen += $subPath }
        }
    }

    if (Test-Path $communPath) { $pathsToScreen += $communPath }

    foreach ($p in $pathsToScreen | Sort-Object -Unique) {
        New-FsrmFileScreen -Path $p `
            -Template "Block_NonOffice_NonImages" `
            -ErrorAction SilentlyContinue | Out-Null
    }
}

Write-Host "Init-FSRM completed I guess" -ForegroundColor Green
