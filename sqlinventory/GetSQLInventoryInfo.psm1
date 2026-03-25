cls
import-module dbatools
set-dbatoolsInsecureConnection -sessionOnly
[Object[]]$ServerCollection = Invoke-DbaQuery -SqlInstance "dvvmsdb4199" -Query "select top 10 ServerFQDName as SQLInstanceName from dbareportdb.sqlinv.SQLInventoryServers where status='Active' order by 1" 
[Object[]]$ServerHostCollection = Invoke-DbaQuery -SqlInstance "dvvmsdb4199" -Query "select  distinct HostName+'.'+domainname as HostName from dbareportdb.sqlinv.SQLInventoryServers where status='Active' order by 1" 


function Write-GlobalErrorLog {
    param(
        
        [Parameter(Mandatory = $true)]
        [System.Exception]$Exception,
         
        [Parameter(Mandatory = $false)]
        [string]$FunctionName,

        [Parameter(Mandatory = $false)]
        [string]$SourceServer,
        
        [Parameter(Mandatory = $false)]
        [string]$SourceDatabase,

        [Parameter(Mandatory = $false)]
        [string]$ServerName = "dvvmsdb4199",                        

        [Parameter(Mandatory = $false)]
        [string]$DatabaseName = "DBAReportDB"

    )

    try {
        #Add-Content -Path $LogFilePath -Value $LogEntry -ErrorAction Stop
        $Exception | Select-Object @{Name = 'TimeStamp'; Expression = { Get-Date } }, @{Name = 'SourceServer'; Expression = { $SourceServer } }, @{Name = 'FunctionName'; Expression = { $FunctionName } }, Message | Write-DbaDbTableData -SqlInstance $ServerName -Database $DatabaseName -schema sqlinv  -Table SQLINVError_log -AutoCreateTable 
    }
    catch {
        Write-Warning "Failed to write to log: $($_.Exception.Message)"
    }

}

function get-sqlinvServers {
    Param(
        [object[]] $TargetServer,
        [string] $SourceServer = "dvvmsdb4199",
        [string] $FName = 'get-sqlinvServers'
    )

    import-module dbatools
    set-dbatoolsInsecureConnection -sessionOnly

    try {

    
        # Invoke-DbaQuery -SqlInstance $SourceServer -Query "Insert into dbareportdb.sqlinv.SQLInventoryArchive
        # select 'ServerArchive' ArchiveType, getdate() ArchiveDate,
        # (select * from [DBAReportDB].[sqlinv].[SQLInventoryServers_stg] for xml auto) ArchiveData;
        # truncate table dbareportdb.sqlinv.SQLInventoryServers_stg; truncate table dbareportdb.sqlinv.SQLServerPort_stg"

        [object[]]$Servers = $TargetServer
        foreach ($Server in $Servers) { 
            [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
            $s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $Server.SQLInstanceName 
            $s | Select-Object Name, Version, EngineEdition, ResourceVersion, BuildClrVersion, BuildNumber, Collation, ClusterName, ComputerNamePhysicalNetBIOS, DefaultFile, DefaultLog, Edition, HostPlatform `
                , InstallDataDirectory, InstallSharedDirectory, InstanceName, LoginMode, OSVersion, PhysicalMemory, PhysicalMemoryUsageInKB, Platform, Processors, ProcessorUsage `
                , Product, ProductLevel, ProductUpdateLevel, ResourceLastUpdateDateTime, ResourceVersionString, RootDirectory, ServerType, ServiceAccount, ServiceInstanceId, ServiceName, ServiceStartMode, Status `
                , TcpEnabled, ServerVersion, DatabaseEngineType, DatabaseEngineEdition, State, DomainInstanceName | ConvertTo-DbaDataTable | `
                Write-DbaDbTableData -SqlInstance $SourceServer -Database dbareportdb -schema sqlinv  -Table SQLInventoryServers_stg -AutoCreateTable  

            Get-DBATcpPort $Server.SQLInstanceName -ExcludeIpv6 | ConvertTo-DbaDataTable | Write-DbaDbTableData -SqlInstance $SourceServer -Database dbareportdb -schema sqlinv  -Table SQLServerPort_stg -AutoCreateTable 

            if ($null -eq $_.Exception) {
                Write-GlobalErrorLog -Exception "Action Completed" -SourceServer $Server.SQLInstanceName -FunctionName $FName
            }     
        }



    }

    catch {
        Write-GlobalErrorLog -Exception $_.Exception -SourceServer $Server.SQLInstanceName -FunctionName $FName
    }
}





function get-sqlinvDatabases {
    Param(
        [Object[]]$TargetServer,
        [string] $SourceServer = "dvvmsdb4199",
        [string] $FName = 'get-sqlinvdatabases'
    )

    import-module dbatools
    set-dbatoolsInsecureConnection -sessionOnly

    try {
        # Invoke-DbaQuery -SqlInstance $SourceServer -Query "Insert into dbareportdb.sqlinv.SQLInventoryArchive
        # select 'DatabaseArchive' ArchiveType, getdate() ArchiveDate,
        # (select * from [DBAReportDB].[sqlinv].[SQLInventoryDatabases_stg] for xml auto) ArchiveData
        # truncate table dbareportdb.sqlinv.SQLInventoryDatabases_stg"


        $Servers = $TargetServer
        foreach ($Server in $Servers) {
            Get-DbaDatabase -SQLInstance $Server.SQLInstanceName -IncludeLastUsed | `
                Select-Object BackupStatus, ComputerName, InstanceName, SQLInstance, SizeMB, Compatibility, Encrypted, LastFullBackup, LastDiffBackup, LastLogBackup, LastRead, LastWrite, DatabaseEngineType, DatabaseEngineEdition, `
                Name, Parent, ActiveConnections, AutoClose, AvailabilityDatabaseSynchronizationState, AvailabilityGroupName, BrokerEnabled, Collation, CompatibilityLevel, CreateDate, DataSpaceUsage, ID, IndexSpaceUsage, IsAccessible, IsFullTextEnabled, IsReadCommittedSnapshotOn, `
                LastBackupDate, LastDifferentialBackupDate, LastGoodCheckDBTime, LastLogBackupDate, Owner, PrimaryFilePath, ReadOnly, RecoveryModel, Size, SnapshotIsolationState, SpaceAvailable, Status, Trustworthy, UserAccess, ServerVersion, State `
            | ConvertTo-DbaDataTable | Write-DbaDbTableData -SqlInstance $SourceServer -Database dbareportdb -schema sqlinv  -Table SQLInventoryDatabases_stg -AutoCreateTable
        
            if ($null -eq $_.Exception) {
                Write-GlobalErrorLog -Exception "Action Completed" -SourceServer $Server.SQLInstanceName -FunctionName $FName
            }     
              
        }
    }
    catch {
        Write-GlobalErrorLog -Exception $_.Exception -SourceServer $Server.SQLInstanceName -FunctionName $FName
    }

           
        
}


function get-sqlinvCPUPerDB {
    Param(
        [object[]] $TargetServer,
        [string] $SourceServer = "dvvmsdb4199",
        [string] $FName = 'get-sqlinvCPUPerDB'
    )

    import-module dbatools
    set-dbatoolsInsecureConnection -sessionOnly

    try {

        # Invoke-DbaQuery -SqlInstance $SourceServer -Query "truncate table dbareportdb.sqlinv.SQLCPUPerDB_stg"

        $Query = "Select @@SERVERNAME as SQLInstanceName,
T.[Database],
T.[CPUTimeAsPercentage],
creation_time,
last_execution_time
   FROM
    (SELECT 
        [Database],
        CONVERT (DECIMAL (6, 3), [CPUTimeInMiliSeconds] * 1.0 / 
        SUM ([CPUTimeInMiliSeconds]) OVER () * 100.0) AS [CPUTimeAsPercentage],
		creation_time,
		last_execution_time
     FROM 
      (SELECT 
          dm_execplanattr.DatabaseID,
          DB_Name(dm_execplanattr.DatabaseID) AS [Database],
          SUM (dm_execquerystats.total_worker_time) AS CPUTimeInMiliSeconds,
		  Max(creation_time) creation_time,
		  Max(last_execution_time) last_execution_time
     FROM sys.dm_exec_query_stats dm_execquerystats
       CROSS APPLY 
        (SELECT 
            CONVERT (INT, value) AS [DatabaseID]
         FROM sys.dm_exec_plan_attributes(dm_execquerystats.plan_handle)
         WHERE attribute = N'dbid'
        ) dm_execplanattr
       GROUP BY dm_execplanattr.DatabaseID
      ) AS CPUPerDb
    )  AS T" 
                   
        [object[]]$Servers = $TargetServer
        foreach ($Server in $Servers) { 
            Invoke-DBAQuery -SQLInstance $Server.SQLInstanceName -Query $Query -AppendServerInstance | `
                Write-DbaDbTableData -SqlInstance $SourceServer -Database dbareportdb -schema sqlinv  -Table SQLCPUPerDB_stg -AutoCreateTable 
            if ($null -eq $_.Exception) {
                Write-GlobalErrorLog -Exception "Action Completed" -SourceServer $Server.SQLInstanceName -FunctionName $FName 
            }
        }

        Invoke-DbaQuery -SqlInstance $SourceServer -CommandType StoredProcedure -Query "dbareportdb.sqlinv.usp_populate_CPUPerDB"
    }  

    

    catch {
        Write-GlobalErrorLog -Exception $_.Exception -SourceServer $Server.SQLInstanceName -FunctionName $FName
    }           


} 

function get-sqlinvSpatialDB {
    Param(
        [object[]] $TargetServer,
        [string] $SourceServer = "dvvmsdb4199",
        [string] $FName = 'get-sqlinvSpatialDB'
    )
    import-module dbatools
    set-dbatoolsInsecureConnection -sessionOnly

    try {

        # Invoke-DbaQuery -SqlInstance $SourceServer -Query "truncate table dbareportdb.sqlinv.SQLSpatialDBs_stg"
        [object[]]$Servers = $TargetServer

        foreach ($Server in $Servers) {
  
            $SpatialDBs = Get-DbaDBTable $Server.SQLInstanceName  -Table sde_layers  | select sqlinstance, database  
            $SpatialDBs | Write-DbaDbTableData -SqlInstance $SourceServer -Database dbareportdb -schema sqlinv  -Table SQLSpatialDBs_stg -AutoCreateTable

            if ($null -eq $_.Exception) {
                Write-GlobalErrorLog -Exception "Action Completed" -SourceServer $Server.SQLInstanceName -FunctionName $FName 
            }
        }
    }
    catch {
        Write-GlobalErrorLog -Exception $_.Exception -SourceServer $Server.SQLInstanceName -FunctionName $FName
    }

}


function get-sqlinvTrace {
    Param(
        [object[]] $TargetServer,
        [string] $SourceServer = "dvvmsdb4199",
        [string] $FName = 'get-sqlinvTrace'
    )

    import-module dbatools
    set-dbatoolsInsecureConnection -sessionOnly
    try {   
        
        
        # Invoke-DbaQuery -SqlInstance $SourceServer -Query "truncate table dbareportdb.sqlinv.SQLDefaultTrace_stg"
        [object[]]$Servers = $TargetServer
        foreach ($Server in $Servers) {
            if (test-dbaconnection $Server.SQLInstanceName | select connectsuccess) {
                $TraceFile = Invoke-DbaQuery -SqlInstance $Server.SQLInstanceName -Query "select path FROM master.sys.traces WHERE is_default = 1"         
                $sql = "SELECT Distinct        
cast(StartTime as date) StartTime,        
HostName,        
ApplicationName,        
ServerName,        
DatabaseName,        
LoginName       
FROM master.sys.fn_trace_gettable('$($TraceFile.path)', DEFAULT)        
where DatabaseName not in ('SpotlightPlaybackDatabase','SpotlightStatisticsRepository','ReportServerTempDB','ReportServer','tempdb','master','msdb')                        
and ApplicationName not like 'Spotlight%' 
and loginname not in ('dpi\sqlback','dpi\sqlsrvc','dpi\sqlstart')
and loginname not like 'dec\svc-%'
and loginname not like 'NT %'"


                $DefaultTrace = Invoke-DbaQuery -SqlInstance $Server.SQLInstanceName -Query $sql 
                $DefaultTrace | Write-DbaDbTableData -SqlInstance $SourceServer -Database dbareportdb -schema sqlinv  -Table SQLDefaultTrace_stg -AutoCreateTable

                if ($null -eq $_.Exception) {
                    Write-GlobalErrorLog -Exception "Action Completed" -SourceServer $Server.SQLInstanceName -FunctionName $FName 
                }
            }

            else {
                Write-GlobalErrorLog -Exception "Connection Issue" -SourceServer $Server.SQLInstanceName -FunctionName $FName 
            }

          
        }

          

        Invoke-DbaQuery -SqlInstance $SourceServer -CommandType StoredProcedure -Query "dbareportdb.sqlinv.usp_populate_ServerSideTraceData"

    }

    catch {
        Write-GlobalErrorLog -Exception $_.Exception -SourceServer $Server.SQLInstanceName -FunctionName $FName
    }
                   
}
 

                



function get-sqlinvADUsers {
    Param(
        [string[]] $TargetServer = "amaprddc1b.DPI.NSW.GOV.AU",
        [string] $SourceServer = "dvvmsdb4199",
        [string] $FName = 'get-sqlinvADUsers'
    )
    set-dbatoolsInsecureConnection -sessionOnly

    try {
        # Invoke-DbaQuery -SqlInstance $SourceServer -Query "truncate table dbareportdb.sqlinv.ADUsers_stg"
        $DCServers = $TargetServer  

        foreach ($DCServer in $DCServers) {
            Get-ADUser -server $DCServer -Filter * -Properties SID, CanonicalName, sAMAccountName, `
                GivenName, SurName, DisplayName, emailaddress, `
                StreetAddress, City, State, PostalCode, `
                HomePhone, MobilePhone, OfficePhone, Fax, `
                Company, Organization, Department, Title, Description, Office, `
                accountExpires, Enabled, PasswordLastSet, `
                PasswordLastSet, PasswordNeverExpires, PasswordExpired, `
                LastLogonDate, whenCreated  | `
                Select-Object -Property SID, CanonicalName, sAMAccountName, `
                GivenName, SurName, DisplayName, emailaddress, `
                StreetAddress, City, State, PostalCode, `
                HomePhone, MobilePhone, OfficePhone, Fax, `
                Company, Organization, Department, Title, Description, Office, `
            @{Name = 'AccountExpires'; Expression = { [DATETIME]::fromFileTime($_.accountExpires) } }, Enabled, PasswordLastSet, `
            @{n = "PasswordExpirationDate"; e = { $_.PasswordLastSet.AddDays($maxPasswordAge) } }, PasswordNeverExpires, PasswordExpired, LastLogonDate, whenCreated | `
                Write-DbaDbTableData -SqlInstance $SourceServer -Database dbareportdb -schema sqlinv -Table ADUsers_stg -AutoCreateTable
        }


        if ($null -eq $_.Exception) {
            Write-GlobalErrorLog -Exception "Action Completed" -FunctionName $FName
        }     
    
    
    }

    catch {
        Write-GlobalErrorLog -Exception $_.Exception   -FunctionName $FName
    }
}


function get-sqlinvADGroups {
    Param(
        [string[]] $TargetServer = "amaprddc1b.DPI.NSW.GOV.AU",
        [string] $SourceServer = "dvvmsdb4199",
        [string] $FName = 'get-sqlinvADGroups'
    )
    set-dbatoolsInsecureConnection -sessionOnly

    try {
        # Invoke-DbaQuery -SqlInstance $SourceServer -Query "truncate table dbareportdb.sqlinv.ADGroups_stg"

        $DCServers = $TargetServer
        foreach ($DCServer in $DCServers) {
            Get-ADGroup -Server $DCServer -Filter *  -Properties SID, SamAccountName, Name, Description, DistinguishedName, CanonicalName, GroupCategory, GroupScope, whenCreated | `
                select-object -property  SID, SamAccountName, Name, Description, DistinguishedName, CanonicalName, GroupCategory, GroupScope, whenCreated  | `
                Write-DbaDbTableData -SqlInstance $SourceServer -Database dbareportdb -schema sqlinv -Table ADGroups_stg -AutoCreateTable

        }

        if ($null -eq $_.Exception) {
            Write-GlobalErrorLog -Exception "Action Completed"  -FunctionName $FName
        }     
        
    }

    catch {
        Write-GlobalErrorLog -Exception $_.Exception  -FunctionName $FName
    }
}


function get-sqlinvADGroupMembers {
    Param(
        [object[]] $TargetServer,
        [string] $SourceServer = "dvvmsdb4199",
        [string] $FName = 'get-sqlinvADGroupMembers'
    )
    set-dbatoolsInsecureConnection -sessionOnly

    try {
    
        # Invoke-DbaQuery -SqlInstance $SourceServer -Query "truncate table dbareportdb.sqlinv.SQLADGroupMembers_stg"
       
        [object[]]$Servers = $TargetServer
        foreach ($Server in $Servers) {
    
            find-dbaloginInGroup -SqlInstance $server.SQLInstanceName | Write-DbaDbTableData -SqlInstance $SourceServer -database DBAReportDB -schema sqlinv -table SQLADGroupMembers_stg -AutoCreateTable
    
  
            if ($null -eq $_.Exception) {
                Write-GlobalErrorLog -Exception "Action Completed"  -SourceServer $Server.SQLInstanceName -FunctionName $FName    
            }

        }

    }

    catch {
        Write-GlobalErrorLog -Exception $_.Exception  -SourceServer $Server.SQLInstanceName -FunctionName $FName
    }
}


function get-sqlinvLogins {
    Param(
        [Object[]]$TargetServer,
        [string] $SourceServer = "dvvmsdb4199",
        [string] $FName = 'get-sqlinvlogins'
    )

    import-module dbatools
    set-dbatoolsInsecureConnection -sessionOnly

    try {
        # Invoke-DbaQuery -SqlInstance $SourceServer -Query "Insert into dbareportdb.sqlinv.SQLInventoryArchive
        # select 'DatabaseArchive' ArchiveType, getdate() ArchiveDate,
        # (select * from [DBAReportDB].[sqlinv].[SQLInventoryDatabases_stg] for xml auto) ArchiveData
        # truncate table dbareportdb.sqlinv.SQLInventoryDatabases_stg"


        $Servers = $TargetServer
        foreach ($Server in $Servers) {
            get-dbalogin $server.SQLInstanceName | Write-DbaDbTableData -SqlInstance dvvmsdb4199 -database DBAReportDB -schema sqlinv -table SQLLogins_stg -AutoCreateTable
        }
        
        if ($null -eq $_.Exception) {
            Write-GlobalErrorLog -Exception "Action Completed" -SourceServer $Server.SQLInstanceName -FunctionName $FName
        }     
              
    }
    
    catch {
        Write-GlobalErrorLog -Exception $_.Exception -SourceServer $Server.SQLInstanceName -FunctionName $FName
    }

       
}

function get-sqlinvADLoginTest {
    Param(
        [Object[]]$TargetServer,
        [string] $SourceServer = "dvvmsdb4199",
        [string] $FName = 'get-sqlinvADloginTest'
    )

    import-module dbatools
    set-dbatoolsInsecureConnection -sessionOnly

    try {
        # Invoke-DbaQuery -SqlInstance $SourceServer -Query "Insert into dbareportdb.sqlinv.SQLInventoryArchive
        # select 'DatabaseArchive' ArchiveType, getdate() ArchiveDate,
        # (select * from [DBAReportDB].[sqlinv].[SQLInventoryDatabases_stg] for xml auto) ArchiveData
        # truncate table dbareportdb.sqlinv.SQLInventoryDatabases_stg"


        $Servers = $TargetServer
        foreach ($Server in $Servers) {
            Test-DbaWindowsLogin -sqlinstance $server.sqlinstancename | `
                Write-DbaDbTableData -SqlInstance "dvvmsdb4199" -Database dbareportdb -schema sqlinv  -Table  SQLADLoginTestRestult_stg -AutoCreateTable 
        }
        if ($null -eq $_.Exception) {
            Write-GlobalErrorLog -Exception "Action Completed" -SourceServer $Server.SQLInstanceName -FunctionName $FName
        }     
              
    }
    
    catch {
        Write-GlobalErrorLog -Exception $_.Exception -SourceServer $Server.SQLInstanceName -FunctionName $FName
    }

       
}


function get-sqlinvUserPermission {
    Param(
        [Object[]]$TargetServer,
        [string] $SourceServer = "dvvmsdb4199",
        [string] $FName = 'get-sqlinvUserPermission'
    )

    import-module dbatools
    set-dbatoolsInsecureConnection -sessionOnly

    try {
        # Invoke-DbaQuery -SqlInstance $SourceServer -Query "Insert into dbareportdb.sqlinv.SQLInventoryArchive
        # select 'DatabaseArchive' ArchiveType, getdate() ArchiveDate,
        # (select * from [DBAReportDB].[sqlinv].[SQLInventoryDatabases_stg] for xml auto) ArchiveData
        # truncate table dbareportdb.sqlinv.SQLInventoryDatabases_stg"


        $Servers = $TargetServer
        foreach ($Server in $Servers) {
            Get-DbaPermission -sqlinstance $server.sqlinstancename -IncludeServerLevel  -ExcludeSystemObjects -ExcludeDatabase msdb,model,tempdb,distribution, dbadb, dbareportdb, datamanagement | Select-Object sqlinstance,database,securable,permissionname,securabletype,grantee,granteetype | `
                Write-DbaDbTableData -SqlInstance "dvvmsdb4199" -Database dbareportdb -schema sqlinv  -Table  SQLPermission_stg -AutoCreateTable   
        }
           
      
        if ($null -eq $_.Exception) {
            Write-GlobalErrorLog -Exception "Action Completed" -SourceServer $Server.SQLInstanceName -FunctionName $FName
        }     
              
    }
    
    catch {
        Write-GlobalErrorLog -Exception $_.Exception -SourceServer $Server.SQLInstanceName -FunctionName $FName
    }

       
}


Export-ModuleMember -Function get-sqlinvServers, get-sqlinvDatabases, get-sqlinvCPUPerDB, get-sqlinvSpatialDB, get-sqlinvTrace, get-sqlinvADUsers, get-sqlinvADGroups, get-sqlinvADGroupMembers, get-sqlinvLogins, get-sqlinvADLoginTest, get-sqlinvUserPermission
