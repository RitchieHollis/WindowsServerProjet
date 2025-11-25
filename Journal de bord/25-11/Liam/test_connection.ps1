param(
    [Parameter(Mandatory)]
    [string]$UserName
)

$Password = Read-Host "Mot de passe pour $UserName" -AsSecureString

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

Add-Type -AssemblyName System.DirectoryServices.AccountManagement

$Domain = (Get-ADDomain).DNSRoot

Write-Host "`n=== TEST AUTHENTIFICATION ==="

$Context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext("Domain", $Domain)

$Result = $Context.ValidateCredentials($UserName, $PlainPassword)

if ($Result -eq $true) {
    Write-Host "[OK] Mot de passe correct." -ForegroundColor Green

    try {
        $User = Get-ADUser -Identity $UserName -Properties * -ErrorAction Stop
        Write-Host "[OK] L'utilisateur existe dans l'AD et a été récupéré." -ForegroundColor Green
        Write-Host "Nom complet : $($User.Name)"
        Write-Host "OU : $($User.DistinguishedName)"
        Write-Host "Compte actif : $(-not $User.Enabled -eq $false)"
    }
    catch {
        Write-Host "[ATTENTION] Mot de passe correct, mais impossible de lire l'utilisateur." -ForegroundColor Yellow
    }
}
else {
    Write-Host "[ERREUR] Identifiants incorrects." -ForegroundColor Red
}
