# Entity Framework Migrations extension

This extension provides 3 new tasks which will allow you to perform Entity Framework code first migrations in 2 different ways

## Method 1: Generating SQL script

The first method allows you to generate a SQL script containing **all** migrations.  
This script can be obtained by manually running `Update-Database -SourceMigration 0 -Script` in the NuGet package manager console in Visual Studio.
You can then either manually run this script after the release or automatically during the release using a extension that allows you to run SQL scripts.

Task name: **Generate migration SQL script**

## Method 2: Utilizing migrate.exe

Entity Framework uses migrate.exe to apply migrations to a database as soon as you execute the `Update-Database` command.

This extension contains 2 tasks which should be used in conjunction with eachother.  
1 during the build phase and the other one during the release phase
 
- Task: **Copy Entity Framework migrate.exe** during build
- Task: **Apply Entity Framework migrations** during release

Please note that for this method the agent on which the release is run should have access to the database.  
Also, be cautious when using SqlFile() statements in your migrations, as the SQL files should be present in these locations.  
To workaround this, you could have your SQL files copied to output for example.