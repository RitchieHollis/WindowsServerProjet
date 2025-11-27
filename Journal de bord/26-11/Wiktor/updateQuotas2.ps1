param(
    [string]$SharesRoot = 'C:\Shares',
    [string]$CsvPath = 'C:\Scripts\DeptResponsables.csv',
    [string]$AdminFallbackMail = 'admin@angleterre.lan'
)

Import-Module FileServerResourceManager -ErrorAction Stop

if (-not (Test-Path $CsvPath)) {
    throw "CSV des responsables introuvable : $CsvPath"
}

$Responsables = Import-Csv $CsvPath

Write-Host "== Mise à jour des quotas FSRM sous $SharesRoot ==" -ForegroundColor Cyan

function Get-MailToForQuota {
    param(
        [string]$Dept,
        [string]$SubDept
    )

    if ($SubDept) {
        # Responsable unique du sous-département
        $entry = $Responsables |
        Where-Object { $_.Department -eq $Dept -and $_.SubDept -eq $SubDept } |
        Select-Object -First 1
        if ($entry -and $entry.ManagerMail) {
            return $entry.ManagerMail.Trim()
        }
    }
    else {
        # Tous les responsables du département
        $mails = $Responsables |
        Where-Object { $_.Department -eq $Dept -and $_.ManagerMail } |
        Select-Object -Expand ManagerMail
        if ($mails) {
            return (($mails | ForEach-Object { $_.Trim() }) -join ';')
        }
    }

    return $AdminFallbackMail
}

function New-RespQuotaThresholds {
    param(
        [string]$MailTo
    )

    # 80%  -> mail only
    $th80 = New-FsrmQuotaThreshold -Percentage 80 -Action (
        New-FsrmAction -Type Email -MailTo $MailTo
    )

    # 90%  -> mail + event
    $th90 = New-FsrmQuotaThreshold -Percentage 90 -Action @(
        (New-FsrmAction -Type Email -MailTo $MailTo),
        (New-FsrmAction -Type Event)
    )

    # 100% -> mail + event
    $th100 = New-FsrmQuotaThreshold -Percentage 100 -Action @(
        (New-FsrmAction -Type Email -MailTo $MailTo),
        (New-FsrmAction -Type Event)
    )

    return @($th80, $th90, $th100)
}

<#
function Ensure-QuotaTemplate {
    param(
        [string]$Name,
        [int64] $SizeMB,
        [string]$MailTo
    )

    $description = "Quota avec mails responsables ($MailTo)"

    # 80% – email only
    $act80 = New-FsrmAction -Type Email -MailTo $MailTo
    $th80 = New-FsrmQuotaThreshold -Percentage 80 -Action $act80

    # 90% – email + event
    $act90 = @(
        New-FsrmAction -Type Email -MailTo $MailTo
        New-FsrmAction -Type Event
    )
    $th90 = New-FsrmQuotaThreshold -Percentage 90 -Action $act90

    # 100% – email + event
    $act100 = @(
        New-FsrmAction -Type Email -MailTo $MailTo
        New-FsrmAction -Type Event
    )
    $th100 = New-FsrmQuotaThreshold -Percentage 100 -Action $act100

    $thresholds = @($th80, $th90, $th100)

    # même logique que FSRMconf.ps1
    Remove-FsrmQuotaTemplate -Name $Name -ErrorAction SilentlyContinue

    New-FsrmQuotaTemplate `
        -Name        $Name `
        -Description $description `
        -Size        ($SizeMB * 1MB) `
        -Threshold   $thresholds `
        -ErrorAction SilentlyContinue | Out-Null
}
#>

# Tous les quotas sous C:\Shares
$quotas = Get-FsrmQuota | Where-Object { $_.Path -like "$SharesRoot*" }

foreach ($quota in $quotas) {
    <#
    $rel = $quota.Path.Substring($SharesRoot.Length).TrimStart('\')
    if (-not $rel) { continue }

    $parts = $rel -split '\\'
    $dept = $parts[0]
    $sub = if ($parts.Count -gt 1) { $parts[1] } else { $null }
#>
    # fallback: if we somehow didn't find a responsable, send to admin
    if (-not $mailTo) {
        $mailTo = 'admin@angleterre.lan'
    }

    # Get the current quota object again (fresh copy)
    $q = Get-FsrmQuota -Path $quota.Path

    if (-not $q) {
        Write-Warning "  !! No quota found on $($quota.Path), skipping."
        continue
    }

    # Rewrite every Email action's MailTo in all thresholds
    foreach ($th in $q.Thresholds) {
        foreach ($act in $th.Action) {
            if ($act.Type -eq 'Email') {
                $act.MailTo = $mailTo
            }
        }
    }

    # Push the modified thresholds back to FSRM
    Set-FsrmQuota -Path $q.Path -Threshold $q.Thresholds -ErrorAction Stop

    <#
    $mailTo = Get-MailToForQuota -Dept $dept -SubDept $sub

    Write-Host "[*] $($quota.Path)  -> Dept='$dept' Sub='$sub'  MailTo: $mailTo" -ForegroundColor Yellow

    # Rebuild thresholds with the correct responsable e-mail
    $thresholds = New-RespQuotaThresholds -MailTo $mailTo

    # Apply them directly on the existing quota
    Set-FsrmQuota -Path $quota.Path -Threshold $thresholds -ErrorAction Stop

    
    if ($dept -eq 'Commun') {
        $sizeMB = 500       # Commun = 500 MB
    }
    elseif ($sub) {
        $sizeMB = 100       # sous-dossiers (Dev, Site1, HotLine...) = 100 MB
    }
    else {
        $sizeMB = 500       # racine de département = 500 MB
    }

    #build a safe template name (no spaces)
    $subSafe = if ($sub) { $sub -replace '\s', '_' } else { 'ROOT' }
    $templateName = "RESP_{0}_{1}" -f ($dept -replace '\s', '_'), $subSafe

    Write-Host "[*] $($quota.Path)  ->  MailTo: $mailTo ; Template=$templateName"

    #create / overwrite the template with the right MailTo
    Ensure-QuotaTemplate -Name $templateName -SizeMB $sizeMB -MailTo $mailTo

    # 2) recréer le quota en utilisant ce template
    Remove-FsrmQuota -Path $quota.Path -ErrorAction SilentlyContinue
    New-FsrmQuota   -Path $quota.Path -Template $templateName -ErrorAction Stop
#>
}

Write-Host "== Mise à jour des quotas FSRM terminée ==" -ForegroundColor Green
