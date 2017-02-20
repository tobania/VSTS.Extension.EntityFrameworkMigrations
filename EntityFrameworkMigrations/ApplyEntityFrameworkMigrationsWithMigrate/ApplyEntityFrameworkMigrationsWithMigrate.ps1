[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[string] $WorkingFolder,

	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[string] $BinFolder = "bin",
	
	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[string] $MigrateExeFolder = "Migrate",

	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[string] $ConfigurationFile,

	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[string] $TargetAssembly,

	[string] $TargetDbContextConfiguration,
	
	[string] $UseVerbose
)

begin {
	if($VerbosePreference -eq "SilentlyContinue" -And $UseVerbose -eq "true") {
        $VerbosePreference = "continue"
    }

	Write-Host "Preparing script... (Verbose = $UseVerbose)"

	# Check if Entity Framework DLLs exist inside the $BinFolder
	Write-Verbose "Checking if $WorkingFolder\$BinFolder\EntityFramework.dll exists..."
	if( -Not (Test-Path "$WorkingFolder\$BinFolder\EntityFramework.dll")){
		Write-Error "EntityFramework.dll was not found in the provided bin folder"
		exit 1
	}

	# Check if the provided assembly exists inside the $BinFolder
	Write-Verbose "Checking if $WorkingFolder\$BinFolder\$TargetAssembly exists..."
	if( -Not (Test-Path "$WorkingFolder\$BinFolder\$TargetAssembly")){
		Write-Error "$TargetAssembly was not found inside $BinFolder"
		exit 2
	}

	# Check if migrate exists in the build artifacts
	Write-Verbose "Checking if $WorkingFolder\$MigrateExeFolder\migrate.exe exists..."
	if( -Not (Test-Path "$WorkingFolder\$MigrateExeFolder\migrate.exe")){
		Write-Error "$WorkingFolder\$MigrateExeFolder\migrate.exe was not found."
		exit 3
	}

	# Check if configuration file exists
	Write-Verbose "Checking if $WorkingFolder\$ConfigurationFile exists..."
	if( -Not (Test-Path "$WorkingFolder\$ConfigurationFile")){
		Write-Error "$WorkingFolder\$ConfigurationFile was not found."
		exit 4
	}

	#Copy migrate.exe to the bin folder
	Write-Verbose "Copying $WorkingFolder\$MigrateExeFolder\migrate.exe to $WorkingFolder\$BinFolder"
	Copy-Item "$WorkingFolder\$MigrateExeFolder\migrate.exe" -Destination "$WorkingFolder\$BinFolder"

	# If we are running on .NET 4.0, we also have to copy over a configuration file for migrate.exe
	Write-Verbose "Checking if $WorkingFolder\$MigrateExeFolder\migrate.exe.config exists (in case of .NET 4.0)"
	if(Test-Path "$WorkingFolder\$MigrateExeFolder\migrate.exe.config"){
		Write-Verbose "Copying $WorkingFolder\$MigrateExeFolder\migrate.exe.config to $WorkingFolder\$BinFolder"
		Copy-Item "$WorkingFolder\$MigrateExeFolder\migrate.exe.config" -Destination "$WorkingFolder\$BinFolder"
	}

	Write-Verbose "Working inside: $WorkingFolder"
	Write-Verbose "Bin folder: $WorkingFolder\$BinFolder"
	Write-Verbose "Assembly containing migrations: $TargetAssembly"
	Write-Verbose "Using DbContext configuration: $TargetDbContextConfiguration"
	Write-Verbose "Using configuration file: $WorkingFolder\$ConfigurationFile"
	Write-Verbose "MigrateExe folder: $MigrateExeFolder"

	Write-Host "Finished preparations"
}

process {
	Write-Host "Applying migrations to database"

	#Run migrate
	Write-Host "Starting migrate.exe"
	

	$tmp = $TargetAssembly

	if(-Not [string]::IsNullOrWhiteSpace($TargetDbContextConfiguration)){
		if($UseVerbose -eq "true"){
			Write-Verbose "Running $WorkingFolder\$BinFolder\migrate.exe $TargetAssembly $TargetDbContextConfiguration /startupConfigurationFile=""$WorkingFolder\$ConfigurationFile"" /verbose"
			& "$WorkingFolder\$BinFolder\migrate.exe" $TargetAssembly $TargetDbContextConfiguration "/startupConfigurationFile=""$WorkingFolder\$ConfigurationFile""" "/verbose"
		} else {
			Write-Verbose "Running $WorkingFolder\$BinFolder\migrate.exe $TargetAssembly $TargetDbContextConfiguration /startupConfigurationFile=""$WorkingFolder\$ConfigurationFile"""
			& "$WorkingFolder\$BinFolder\migrate.exe" $TargetAssembly $TargetDbContextConfiguration "/startupConfigurationFile=""$WorkingFolder\$ConfigurationFile"""
		}
	} else {
		if($UseVerbose -eq "true"){
			Write-Verbose "Running $WorkingFolder\$BinFolder\migrate.exe $TargetAssembly /startupConfigurationFile=""$WorkingFolder\$ConfigurationFile"" /verbose"
			& "$WorkingFolder\$BinFolder\migrate.exe" $TargetAssembly "/startupConfigurationFile=""$WorkingFolder\$ConfigurationFile""" "/verbose"
		} else {
			Write-Verbose "Running $WorkingFolder\$BinFolder\migrate.exe $TargetAssembly /startupConfigurationFile=""$WorkingFolder\$ConfigurationFile"""
			& "$WorkingFolder\$BinFolder\migrate.exe" $TargetAssembly "/startupConfigurationFile=""$WorkingFolder\$ConfigurationFile"""
		}
	}

	$MigrateExitCode = $LASTEXITCODE

	#Cleanup migrate from bin folder
	Write-Verbose "Cleaning $WorkingFolder\$BinFolder\migrate.exe"
	Remove-Item "$WorkingFolder\$BinFolder\migrate.exe"

	if(Test-Path "$WorkingFolder\$BinFolder\migrate.exe.config"){
		Write-Verbose "Cleaning $WorkingFolder\$BinFolder\migrate.exe.config"
		Remove-Item "$WorkingFolder\$BinFolder\migrate.exe.config"
	}


	if($MigrateExitCode -gt 0){
		Write-Error "Migrate.exe failed with error code $MigrateExitCode"
		exit 5
	}
}

end {
	Write-Host "Migrations applied to database."
}