Import-Module ActiveDirectory

$comp = Get-ADComputer -Identity "SRVSEC"
Move-ADObject -Identity $comp.DistinguishedName `
    -TargetPath "OU=Servers,DC=angletterre,DC=lan"
