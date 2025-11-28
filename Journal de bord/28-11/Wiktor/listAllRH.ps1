Import-Module ActiveDirectory

[string]$groupName = "Ressources Humaines"

try {
    $group = Get-ADGroup -Identity $groupName -ErrorAction Stop
}
catch {
    Write-Error "Nope."
    return
}

Get-ADGroupMember -Identity $group -Recursive |
Where-Object { $_.objectClass -eq 'user' } |
Get-ADUser -Properties Enabled, LastLogonDate |
Select-Object SamAccountName, Name, Enabled, LastLogonDate |
Sort-Object SamAccountName