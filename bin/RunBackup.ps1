

<#
backup script for sqlserver
backup all dtabase in local instance


9-7-2015 baruch - created
19-7-2014 baruch - add config file (XML) support
20-10-2014 bacuh - add all databases backup and clean archive
.\RunBackup.ps1   -FullBackup false
#>


<#
---notes---   
to enable scripts plese run as administrator
Set-ExecutionPolicy RemoteSigned
#>






[CmdletBinding()]
param (
   [string]$FullBackup = "true",
   [string]$Help = "true"
 )
#welcome banner
write-host "##########################################"
write-host "##########MS-SQL BACKUP Script############"
write-host "##########################################"

<# Variables #>
$myDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$BaseDir = Split-Path -Path $myDir -Parent
$configDir = $BaseDir+"\Config"
$adate = Get-Date
$ArchiveDirName = $adate.Year.ToString() + $adate.Month.ToString() + $adate.Day.ToString() +$adate.Hour.ToString() +$adate.Minute.ToString() + $adate.Second.ToString();

<#Read config file #>
[xml]$ConfigFile = Get-Content "$configDir\Settings.xml"
$BackupPath = $ConfigFile.Settings.Backup.BackupPath
$InstanceName = $ConfigFile.Settings.Backup.InstanceName
$ArchivePath = $ConfigFile.Settings.Backup.ArchivePath
$Alldatabases = $ConfigFile.Settings.backup.ALLDatabases
$DaysToKeep = $ConfigFile.Settings.backup.DaysToKeep


$Logfile = $BackupPath +"\"+"backup.log"
write-host "log in:" $Logfile

$logstring = $adate.ToString() + "backup starting"
Add-content $Logfile -value [string]$logstring

#create database list
If ($Alldatabases -like "true")
{
$logstring = $adate.ToString() + "Alldatabaes in settings is ture - backup all databases in instance " + $InstanceName
Add-content $Logfile -value [string]$logstring
$DatabaseName = sqlcmd -S $InstanceName  -Q "SELECT name FROM [sys].[databases]" -h -1 -W
}
Else
{
#get database list
$DatabaseName = $ConfigFile.Settings.Backup.Databases -split ","
}


<# if full backup before  o full backup creaet new archive dir  and move all log + data to dir #>
if ($FullBackup -like "true")
  {
    #write to log
    $logstring = $adate.ToString() + "Full database selected"
    Add-content $Logfile -value [string]$logstring
    #
    New-Item -ItemType directory -Path $ArchivePath\$ArchiveDirName
    Move-Item $BackupPath\*.BAK -Destination $ArchivePath\$ArchiveDirName\
    Move-Item $BackupPath\*.log -Destination $ArchivePath\$ArchiveDirName\
  }
<# Start Backup #>
#loop databases backup and copy files to archive
For ($i=0; $i -lt $DatabaseName.Length; $i++) {

    #write to log
    $logstring = $adate.ToString() + "Now Backup: " + $DatabaseName[$i]
    Add-content $Logfile -value [string]$logstring

    #create file names
    $BackupFileName = $BackupPath +"\"+ $DatabaseName[$i]+"Data"+".BAK"
    $BackuplogFileName = $BackupPath +"\"+ $DatabaseName[$i]+"LOG"+$ArchiveDirName+".BAK"
    #creaet temp backup script to run
    if ($FullBackup -like "true")
      {
          <#run full + log backup#>
        $Q = "ALTER DATABASE "+$DatabaseName[$i] +  " SET RECOVERY FULL;"
        Set-Content -Value $Q -Path $myDir\backupTempFile.sql
        $Q = "BACKUP LOG "+ $DatabaseName[$i] +" TO DISK =" +"'"+$BackuplogFileName + "'" +"WITH COMPRESSION,INIT"
        add-Content -Value $Q -Path $myDir\backupTempFile.sql
        $Q = "BACKUP DATABASE "+ $DatabaseName[$i] +" TO DISK =" +"'"+$BackupFileName + "'" +"WITH COMPRESSION"
        Add-Content -Value $Q -Path $myDir\backupTempFile.sql
      }
    else
      {
      <#run log backup#>
          $Q = "ALTER DATABASE "+$DatabaseName[$i] +  " SET RECOVERY FULL;"
          Set-Content -Value $Q -Path $myDir\backupTempFile.sql
          $Q = "BACKUP LOG "+ $DatabaseName[$i] +" TO DISK =" +"'"+$BackuplogFileName + "'" +"WITH COMPRESSION,INIT"
          add-Content -Value $Q -Path $myDir\backupTempFile.sql
      }
    <# run Backup  #>
    sqlcmd -S $InstanceName  -i $myDir\backupTempFile.sql
    <# clean sql temp file #>
    Set-Content -Value " " -Path $myDir\backupTempFile.sql
  }
<# clean and move files to archive #>
Set-Content -Value " " -Path $myDir\backupTempFile.sql
#write to log
$logstring = $adate.ToString() + "Clean and copy to Archive:" +  $ArchivePath+"\"+$ArchiveDirName
Add-content $Logfile -value [string]$logstring




<# clean archive from old files #>
write-host "clean files "
dir  $ArchivePath\ -recurse |  where { ((get-date)-$_.creationTime).days -gt $DaysToKeep } |  remove-item -force
<#DEBUG NOTES#>

#sqlcmd  -S S1-DATABASE-MAC\GSLADB -i .\backup.sql

<# clean and move files to archive #>
#Copy-Item c:\Backup\Files\* -Destination c:\Backup\Archive\
#Get-ChildItem c:\Backup\Archive\ -filter "*.BAK" | Rename-Item -NewName {$_.name -replace 'BAK',$newbakupfile }

<# clean archive#>
#dir c:\Backup\Archive\  -recurse |  where { ((get-date)-$_.creationTime).days -gt 14 } |  remove-item -force
#Get-ChildItem c:\Backup\Archive\ -filter "*.BAK" | Rename-Item -NewName {$_.name -replace 'BAK',$newbakupfile }
#$Logfile = "D:\Apps\Logs\$(gc env:computername).log"

#Function ###
#{
#   Param ([string]$logstring)

   #Add-content $Logfile -value $logstring
#}


<#

RESTORE DATABASE tpcc FROM disk='C:\scripts\backup\tpccDATA.BAK' WITH norecovery;
RESTORE LOG tpcc FROM DISK ='C:\scripts\backup\tpccLOG20151020191920.BAK' WITH norecovery;
RESTORE LOG tpcc FROM DISK ='C:\scripts\backup\tpccLOG20151020192010.BAK' WITH norecovery;
RESTORE DATABASE tpcc WITH RECOVERY;
GO

-- To permit log backups, before the full database backup, modify the database
-- to use the full recovery model.
USE master;
GO
ALTER DATABASE AdventureWorks2012
   SET RECOVERY FULL;
GO
-- Create AdvWorksData and AdvWorksLog logical backup devices.
USE master
GO
EXEC sp_addumpdevice 'disk', 'AdvWorksData',
'Z:\SQLServerBackups\AdvWorksData.bak';
GO
EXEC sp_addumpdevice 'disk', 'AdvWorksLog',
'X:\SQLServerBackups\AdvWorksLog.bak';
GO

-- Back up the full AdventureWorks2012 database.
BACKUP DATABASE AdventureWorks2012 TO AdvWorksData;
GO
-- Back up the AdventureWorks2012 log.
BACKUP LOG AdventureWorks2012
   TO AdvWorksLog;
GO

RESTORE LOG <database_name> FROM <backup_device> WITH NORECOVERY;
RESTORE DATABASE <database_name> WITH RECOVERY;
GO





RESTORE LOG NewDatabase

FROM DISK = ''D: \BackupFiles\TestDatabase_TransactionLogBackup1.trn'

WITH NORECOVERY

RESTORE LOG NewDatabase

FROM DISK = ''D: \BackupFiles\ TestDatabase_TransactionLogBackup2.trn'

WITH NORECOVERY

RESTORE LOG NewDatabase

FROM DISK = ''D: \BackupFiles\ TestDatabase_TransactionLogBackup3.trn'

WITH NORECOVERY

RESTORE LOG NewDatabase

FROM DISK = ''D: \BackupFiles\ TestDatabase_TransactionLogBackup4.trn'

WITH RECOVERY

#>
