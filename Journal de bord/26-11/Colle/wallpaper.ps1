param(
	[Parameter(Mandatory = $true, Position = 0)]
	[string]$WallpaperPath
)

Set-StrictMode -Version Latest
try {
	$resolved = Resolve-Path -Path $WallpaperPath -ErrorAction Stop
} catch {
	Write-Error "Cannot resolve path: $WallpaperPath"; exit 2
}

$sourceFile = $resolved.ProviderPath
if (-not (Test-Path -Path $sourceFile -PathType Leaf)) {
	Write-Error "Provided path is not a file: $sourceFile"; exit 3
}

$server = $env:COMPUTERNAME
$localFolder = Join-Path -Path $env:SystemDrive -ChildPath "Wallpapers"
if (-not (Test-Path -Path $localFolder)) {
	Write-Output "Creating folder $localFolder"
	New-Item -Path $localFolder -ItemType Directory -Force | Out-Null
}

$fileName = [System.IO.Path]::GetFileName($sourceFile)
$destFile = Join-Path -Path $localFolder -ChildPath $fileName

try {
	Copy-Item -Path $sourceFile -Destination $destFile -Force -ErrorAction Stop
	Write-Output "Copied wallpaper to $destFile"
} catch {
	Write-Error "Failed to copy wallpaper: $_"; exit 4
}

# Create SMB share with desired share permissions if possible
if (Get-Command -Name New-SmbShare -ErrorAction SilentlyContinue) {
	try {
		$existing = Get-SmbShare -Name "Wallpapers" -ErrorAction SilentlyContinue
		if ($null -eq $existing) {
			Write-Output "Creating SMB share 'Wallpapers' -> $localFolder"
			New-SmbShare -Name "Wallpapers" -Path $localFolder -FullAccess "Administrators" -ReadAccess "Authenticated Users" | Out-Null
		} else {
			Write-Output "SMB share 'Wallpapers' already exists. Skipping creation."
		}
	} catch {
		Write-Warning "Failed to create SMB share automatically: $_"; Write-Warning "You may need to create the share manually.";
	}
} else {
	Write-Warning "New-SmbShare cmdlet not available on this system. Share not created automatically.";
}

# Set NTFS permissions: Administrators = FullControl, Authenticated Users = Read & Execute
try {
	$acl = Get-Acl -Path $localFolder
	$administrators = New-Object System.Security.Principal.NTAccount("BUILTIN","Administrators")
	$authUsers = New-Object System.Security.Principal.NTAccount("Authenticated Users")

	$fullControl = [System.Security.AccessControl.FileSystemRights]::FullControl
	$readExecute = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute
	$inheritFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
	$propFlags = [System.Security.AccessControl.PropagationFlags]::None

	$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule($administrators, $fullControl, $inheritFlags, $propFlags, "Allow")
	$authRule = New-Object System.Security.AccessControl.FileSystemAccessRule($authUsers, $readExecute, $inheritFlags, $propFlags, "Allow")

	# Remove existing conflicting Authenticated Users rules for clarity, then add ours
	$acl.Access | Where-Object { $_.IdentityReference -like '*Authenticated Users' } | ForEach-Object { $acl.RemoveAccessRule($_) } | Out-Null
	$acl.SetAccessRule($adminRule)
	$acl.AddAccessRule($authRule)
	Set-Acl -Path $localFolder -AclObject $acl
	Write-Output "Set NTFS permissions on $localFolder"
} catch {
	Write-Warning "Failed to set NTFS permissions: $_"
}

# Create or update GPO to enforce the wallpaper
$gpoName = "Force-Wallpaper"
$uncPath = "\\$server\Wallpapers\$fileName"

if (Get-Command -Name New-GPO -ErrorAction SilentlyContinue) {
	try {
		Import-Module GroupPolicy -ErrorAction SilentlyContinue
		$gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
		if ($null -eq $gpo) {
			Write-Output "Creating GPO: $gpoName"
			$gpo = New-GPO -Name $gpoName -Comment "Enforce desktop wallpaper to $uncPath"
		} else {
			Write-Output "GPO '$gpoName' exists; updating values"
		}

		# Registry-based policy under HKCU\Control Panel\Desktop
		Set-GPRegistryValue -Name $gpoName -Key "HKCU\Control Panel\Desktop" -ValueName "Wallpaper" -Type String -Value $uncPath
		# WallpaperStyle: 2 = Stretch (common choice). Adjust as desired.
		Set-GPRegistryValue -Name $gpoName -Key "HKCU\Control Panel\Desktop" -ValueName "WallpaperStyle" -Type String -Value "2"

		# Link the GPO at the domain root if possible
		if (Get-Command -Name Get-ADDomain -ErrorAction SilentlyContinue) {
			Import-Module ActiveDirectory -ErrorAction SilentlyContinue
			$domainDN = (Get-ADDomain).DistinguishedName
			Write-Output "Linking GPO to domain root ($domainDN) and enforcing it"
			# New-GPLink will add the link; if it already exists, this will still succeed
			New-GPLink -Name $gpoName -Target $domainDN -Enforced $true -LinkEnabled $true -ErrorAction Stop
		} else {
			Write-Warning "ActiveDirectory module not available - cannot link GPO to domain automatically. Please link $gpoName to the domain root manually."
		}
	} catch {
		Write-Warning "GPO creation/modification failed: $_"
	}
} else {
	Write-Warning "GroupPolicy module/cmdlets not available. GPO not created. Install RSAT/GroupPolicy module and run as a user with permissions."
}

Write-Output "Deployment complete. Shared file available at: $uncPath"
Write-Output "Note: Users may need to log off/log on or run gpupdate /force to apply the policy."

exit 0

