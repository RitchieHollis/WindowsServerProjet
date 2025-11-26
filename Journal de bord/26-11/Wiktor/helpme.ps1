Import-Module ActiveDirectory

$departments = Get-ADOrganizationalUnit -SearchBase "OU=Direction,DC=anglettere,DC=lan" -SearchScope OneLevel -Filter *

foreach ($ou in $departments) {
	Write-Host "Moving $($ou.DistinguishedName) to root"
	Set-ADOrganizationalUnit -Identity $ou.DistinguishedName -ProtectedFromAccidentalDeletion $false
	Move-ADObject -Identity $ou.DistinguishedName -TargetPath "DC=anglettere,Dc=lan"
	Set-ADOrganizationalUnit -Identity "OU=$($ou.Name),DC=anglettere,DC=lan" -ProtectedFromAccidentalDeletion $true
}

