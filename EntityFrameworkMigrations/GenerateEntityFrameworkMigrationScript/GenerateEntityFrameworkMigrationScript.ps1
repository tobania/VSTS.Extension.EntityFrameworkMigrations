[CmdletBinding()]
param(
    [Parameter(mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Project,

    [Parameter(mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$BuildConfiguration,

    [Parameter(mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AssemblyName,

	[string]$ConfigurationTypeSelector,
    [string]$ConfigurationFile,
    [string]$ConnectionStringName,
    [string]$ConnectionString,
    [string]$ConnectionStringProviderName = "System.Data.SqlClient",
    [string]$MigrationsConfigurationTypeName,
    
    [Parameter(mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory,

	[Parameter(mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[string]$OutputFile = "migrations.sql",

    [string]$UseVerbose
)
begin {
    if($VerbosePreference -eq "SilentlyContinue" -And $UseVerbose -eq "true") {
        $VerbosePreference = "continue"
    }

    Write-Host "Script started."
    Write-Host "Starting pre-execution checks."

    $WorkingFolder = Split-Path -Path $Project

    # Check if assembly exists
    Write-Verbose "Checking if $WorkingFolder\bin\$BuildConfiguration\$AssemblyName.dll exists..."
    if(-Not (Test-Path "$WorkingFolder\bin\$BuildConfiguration\$AssemblyName.dll")){
        Write-Error "$WorkingFolder\bin\$BuildConfiguration\$AssemblyName.dll does not exist."
        exit 1
    }

    if($ConfigurationTypeSelector -eq "configurationFile"){
		# Check if the config file exists
		Write-Verbose "Determing which configuration file to use..."
		if(($PSBoundParameters.ContainsKey('ConfigurationFile')) -And (Test-Path "$ConfigurationFile")) {
			 Write-Verbose "Using provided $ConfigurationFile"
		} elseif ((-Not $PSBoundParameters.ContainsKey('ConfigurationFile')) -And (Test-Path "$WorkingFolder\Web.config")) {
			Write-Verbose "Using Web.config by default"
			$ConfigurationFile = "Web.config"
		} elseif ((-Not $PSBoundParameters.ContainsKey('ConfigurationFile')) -And (Test-Path "$WorkingFolder\App.config")) {
			Write-Verbose "Using App.Config by default"
			$ConfigurationFile = "App.config"
		} else {
			Write-Error "No configuration file provided and no default config (Web.config or App.config) exists in $WorkingFolder"
			exit 1
		}
		
		# Validate connection string / name
		Write-Verbose "Checking if connection string name has been provided"
		if(([string]::IsNullOrWhiteSpace($ConnectionStringName))){
			Write-Error "You must provide the name of your connection string"
			exit 2
		}
		
	}
	else{
		# Check if connection string has been provided
		Write-Verbose "Checking if connection string has been provided."
		if([string]::IsNullOrWhiteSpace($ConnectionString)){
			Write-Error "You must provide a connection string."
			exit 2
		}
		
		# Check if provider name has been provided
		Write-Verbose "Checking if provider name has been provided."
		if([string]::IsNullOrWhiteSpace($ConnectionStringProviderName)){
			Write-Error "You must provide a provider name."
			exit 2
		}
	}

    # Check if entity framework dll exists
    Write-Verbose "Checking if EntityFramework.dll exists..."
    if(-Not (Test-Path "$WorkingFolder\bin\$BuildConfiguration\EntityFramework.dll")) {
        Write-Error "$WorkingFolder\bin\$BuildConfiguration\EntityFramework.dll does not exist."
        exit 1
    }

    # Import entity framework
    Write-Verbose "Importing EntityFramework.dll"
    Import-Module "$WorkingFolder\bin\$BuildConfiguration\EntityFramework.dll"

    # Check if the output file already exists
    Write-Verbose "Checking if $OutputDirectory\$OutputFile exists..."
    if(Test-Path "$OutputDirectory\$OutputFile"){
        Write-Verbose "$OutputDirectory\$OutputFile already exists, deleting"
        Remove-Item "$OutputDirectory\$OutputFile"
    }

    Write-Host "Finished pre-execution checks."

}

process {
    Write-Host "Starting process."

    $dbConnectionInfo = $null;

    Write-Host "Creating connection..."
    
    if($ConfigurationTypeSelector -eq "manual"){
        Write-Verbose "Using connection string and provider name to create DbConnectionInfo"
        Write-Verbose "dbConnectionInfo = new System.Data.Entity.Infrastructure.DbConnectionInfo(""$ConnectionString"", ""$ConnectionStringProviderName"")"
        $dbConnectionInfo = New-Object -TypeName System.Data.Entity.Infrastructure.DbConnectionInfo -ArgumentList @($ConnectionString, $ConnectionStringProviderName)
    } else {
       Write-Verbose "Using connection string name to create DbConnectionInfo"
       Write-Verbose "dbConnectionInfo = new System.Data.Entity.Infrastructure.DbConnectionInfo(""$ConnectionStringName"")"
       $dbConnectionInfo = New-Object -TypeName System.Data.Entity.Infrastructure.DbConnectionInfo -ArgumentList @($ConnectionStringName)
    }

    Write-Verbose "toolingFacade = new System.Data.Entity.Migrations.Design.ToolingFacade(""$AssemblyName"",""$AssemblyName"",""$MigrationsConfigurationTypeName"", ""$WorkingFolder\bin\$BuildConfiguration\"", ""$ConfigurationFile"", """", dbConnectionInfo)"
    $toolingFacade = New-Object -TypeName System.Data.Entity.Migrations.Design.ToolingFacade -ArgumentList @($AssemblyName,$AssemblyName,$MigrationsConfigurationTypeName, "$WorkingFolder\bin\$BuildConfiguration\", "$ConfigurationFile", "", $dbConnectionInfo)

    Write-Host "Retrieving pending migrations..."
    $pendingMigrations = $toolingFacade.GetPendingMigrations()
    Write-Verbose "Detected pending migrations:"
    Write-Verbose ($pendingMigrations | Out-String)
    Write-Host "Found $($pendingMigrations.Count) pending migrations."

    #Write-Host "Retrieving applied migrations..."
    #$executedMigrations = $toolingFacade.GetDatabaseMigrations()
    #Write-Verbose "Detected applied migrations:"
    #Write-Verbose ($executedMigrations | Out-String)
    #Write-Host "Found $($executedMigrations.Count) applied migrations."

    #$allMigrations = $executedMigrations + $pendingMigrations

    #Write-Verbose "Entire list of migrations:"
	#Write-Verbose ($allMigrations | Out-String)
    
    # Use "0" as source migration so it generate a script which checks if migrations have been applied or not
    $sourceMigration = "0" #$allMigrations[0]
    #$targetMigration = $allMigrations[$allMigrations.Count - 1];
    $targetMigration = $pendingMigrations[$pendingMigrations.Count - 1];

    Write-Host "Generating migration script..."
    Write-Verbose "Generating migration script from ""$sourceMigration"" to ""$targetMigration"""
    $script = $toolingFacade.ScriptUpdate($sourceMigration, $targetMigration, $false)

    Write-Host "Saving migration script to $OutputDirectory\$OutputFile"
    $script | Out-File "$OutputDirectory\$OutputFile"

    Write-Host "Process finished."
}

end {
    Write-Host "Script finished."
}