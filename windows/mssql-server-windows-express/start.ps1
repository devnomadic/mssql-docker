# The script sets the sa password and start the SQL Service 
# Also it attaches additional database from the disk
# The format for attach_dbs

param(
[Parameter(Mandatory=$false)]
[string]$sa_password,

[Parameter(Mandatory=$false)]
[string]$ACCEPT_EULA,

[Parameter(Mandatory=$false)]
[string]$attach_dbs,

[Parameter(Mandatory = $false)]
[string]$DataVolume
)


if($ACCEPT_EULA -ne "Y" -And $ACCEPT_EULA -ne "y")
{
	Write-Verbose "ERROR: You must accept the End User License Agreement before this container can start."
	Write-Verbose "Set the environment variable ACCEPT_EULA to 'Y' if you accept the agreement."

    exit 1 
}

# start the service
Write-Verbose "Starting SQL Server"
NET START MSSQL`$SQLEXPRESS /f /T3608

if($sa_password -eq "_") {
    $secretPath = $env:sa_password_path
    if (Test-Path $secretPath) {
        $sa_password = Get-Content -Raw $secretPath
    }
    else {
        Write-Verbose "WARN: Using default SA password, secret file not found at: $secretPath"
    }
}

if($sa_password -ne "_")
{
    Write-Verbose "Changing SA login credentials"
    $sqlcmd = "ALTER LOGIN sa with password=" +"'" + $sa_password + "'" + ";ALTER LOGIN sa ENABLE;"
    & sqlcmd -Q $sqlcmd
}

Get-ChildItem -Path $DataVolume | foreach {Remove-Item -Path $_.FullName -Force}

$TSQL = "ALTER
DATABASE msdb MODIFY
FILE ( NAME = MSDBData , FILENAME
=
'$DataVolume\MSDBData.mdf')

ALTER
DATABASE msdb MODIFY
FILE ( NAME = MSDBLog , FILENAME
=
'$DataVolume\MSDBLog.ldf')

ALTER
DATABASE model MODIFY
FILE ( NAME = modeldev , FILENAME
=
'$DataVolume\model.mdf')

ALTER
DATABASE model MODIFY
FILE ( NAME = modellog , FILENAME
=
'$DataVolume\modellog.ldf')

ALTER
DATABASE tempdb MODIFY
FILE ( NAME = tempdev , FILENAME
=
'$DataVolume\temp.mdf')

ALTER
DATABASE tempdb MODIFY
FILE ( NAME = templog , FILENAME
=
'$DataVolume\temp.ldf')

SELECT name, physical_name AS CurrentLocation, state_desc

FROM
sys.master_files

WHERE database_id in
(DB_ID(N'master'),DB_ID(N'model'),DB_ID(N'msdb'));
"

#Invoke-Sqlcmd -Query $TSQL -ServerInstance ".\"
& sqlcmd -Q $TSQL

$RegPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL14.SQLEXPRESS\MSSQLServer\Parameters"

if (Test-Path -Path $RegPath ) {
    Write-Verbose "'MSSQLServer\Parameters' Path exists"
    $Parameters = Get-ItemProperty -Path $RegPath

    $ParametersHash = @(
        $Parameters.SQLArg0
        $Parameters.SQLArg1
        $Parameters.SQLArg2
    )

    $i = 0
    foreach ($item in $ParametersHash) {
        switch -Regex ($item) {
            '-d' {Set-ItemProperty -Path $RegPath -Name "SQLArg$i" -Value "-d$DataVolume\master.mdf"}
            '-l' {Set-ItemProperty -Path $RegPath -Name "SQLArg$i" -Value "-l$DataVolume\mastlog.ldf"}
        }
        $i++
    }
}
else {
    Write-Verbose "'MSSQLServer\Parameters' Path does not exist"
}


Stop-Service MSSQL`$SQLEXPRESS

Copy-Item -Path 'C:\Program Files\Microsoft SQL Server\MSSQL14.SQLEXPRESS\MSSQL\DATA\*.*' -Destination "$DataVolume"

Start-Service MSSQL`$SQLEXPRESS


$attach_dbs_cleaned = $attach_dbs.TrimStart('\\').TrimEnd('\\')

$dbs = $attach_dbs_cleaned | ConvertFrom-Json

if ($null -ne $dbs -And $dbs.Length -gt 0)
{
    Write-Verbose "Attaching $($dbs.Length) database(s)"
	    
    Foreach($db in $dbs) 
    {            
        $files = @();
        Foreach($file in $db.dbFiles)
        {
            $files += "(FILENAME = N'$($file)')";           
        }

        $files = $files -join ","
        $sqlcmd = "IF EXISTS (SELECT 1 FROM SYS.DATABASES WHERE NAME = '" + $($db.dbName) + "') BEGIN EXEC sp_detach_db [$($db.dbName)] END;CREATE DATABASE [$($db.dbName)] ON $($files) FOR ATTACH;"

        Write-Verbose "Invoke-Sqlcmd -Query $($sqlcmd)"
        & sqlcmd -Q $sqlcmd
    }
}

Write-Verbose "Started SQL Server."

$lastCheck = (Get-Date).AddSeconds(-2) 
while ($true) 
{ 
    Get-EventLog -LogName Application -Source "MSSQL*" -After $lastCheck | Select-Object TimeGenerated, EntryType, Message	 
    $lastCheck = Get-Date 
    Start-Sleep -Seconds 2 
}
