[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty()]
    [string] $PackagesConfig,

	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[string] $PackagesFolder,

	[ValidateNotNullOrEmpty()]
    [string] $EFPackageName = "EntityFramework",

	[ValidateNotNullOrEmpty()]
	[string] $OutputDirectory = "$(Build.ArtifactStagingDirectory)\Migrate",

	[string]$UseVerbose
)

begin {
	if($VerbosePreference -eq "SilentlyContinue" -And $UseVerbose -eq "true") {
        $VerbosePreference = "continue"
    }

	# Check if packages folder exists
    Write-Verbose "Checking if $PackagesFolder exists..."
    if(-Not (Test-Path $PackagesFolder)) {
        Write-Error "$PackagesFolder does not exist."
        exit 1
    }

	# Check if packages.config exists
    Write-Verbose "Checking if $PackagesConfig exists..."
    if(-Not (Test-Path $PackagesConfig)) {
        Write-Error "$PackagesConfig does not exist."
        exit 2
    }

	# Check if output folder exists
    Write-Verbose "Checking if $OutputDirectory exists..."
    if(-Not (Test-Path $OutputDirectory)) {
		# Create new directory which will hold all required DLLs, exe's and configurations.
		Write-Verbose "Creating output directory $OutputDirectory"
		New-Item -Force -Type Directory $OutputDirectory
    }

	Write-Host "Starting copy of migrate.exe to $OutputDirectory"
	Write-Verbose "Using packages.config: $PackagesConfig"
}

process {
	# Load packages.config
	Write-Verbose "Loading $PackagesConfig"
	[xml]$Cfg = Get-Content $PackagesConfig

	# Find the version of entity framework currently installed
	Write-Verbose "Attempting to find package $EFPackageName in $PackagesConfig"
	$EF = $Cfg.packages.package | where { $_.id -eq $EFPackageName }

	if($EF -eq $null){
		Write-Error "Package $EFPackageName is not listed in $PackagesConfig"
		exit 1;
	}

	Write-Verbose "Parsing installed Entity Framework version"
	$EFVersion = [version]$EF.version
	$EFTargetFramework = $EF.targetFramework

	Write-Verbose "$EFPackageName is installed with version $EFVersion for framework $EFTargetFramework"

	if($EFVersion -lt [version]"4.1.0"){
		Write-Error "Code first migrations are only supported in Entity Framework version 4.1 or higher";
		exit 3;
	}

	# Compose the directory in which the EF package tools are located (which contains the migrate.exe)
	$EFTools = "$PackagesFolder\$EFPackageName.$EFVersion\tools\"
	Write-Verbose "Entity Framework tools directory: $EFTools"

	# Copy the migrate.exe to the working folder
	Write-Verbose "$EFTools\migrate.exe to $OutputDirectory"
	Copy-Item -Force "$EFTools\migrate.exe" -Destination "$OutputDirectory\migrate.exe"

	# If .NET 4 is installed, we must copy the Redirect.config as migrate.exe.config
	# TODO: Use the targetFramework property from packages.config to determine wether or not its .NET 4?
	If ($EFTargetFramework -eq "net40")
	{
		Write-Verbose "Entity Framework is installed for .NET 4, copying configuration file for Migrate.exe"
		If (Test-Path ($EFTools + "Redirect.config"))
		{
			Write-Verbose "Copying $EFTools\Redirect.config to $OutputDirectory\migrate.exe.config"
			Copy-Item -Force "$EFTools\Redirect.config" -Destination "$OutputDirectory\migrate.exe.config"
		}
	}
}

end {
	Write-Host "Finished copying migrate.exe to $OutputDirectory"
}