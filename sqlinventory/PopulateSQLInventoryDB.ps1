

cls
import-module dbatools
# remove-module -name "GetSQLInventoryInfo"
import-module "D:\admin\scripts\inv\ps\GetSQLInventoryInfo\GetSQLInventoryInfo.psm1"
set-dbatoolsInsecureConnection -sessionOnly
[Object[]]$ServerCollection = Invoke-DbaQuery -SqlInstance "dvvmsdb4199" -Query "select ServerFQDName as SQLInstanceName from dbareportdb.sqlinv.SQLInventoryServers where status='Active' order by 1" 
[Object[]]$ServerHostCollection = Invoke-DbaQuery -SqlInstance "dvvmsdb4199" -Query "select  distinct HostName+'.'+domainname as HostName from dbareportdb.sqlinv.SQLInventoryServers where status='Active' order by 1" 




Invoke-DbaQuery -SqlInstance dvvmsdb4199.dec.int -Query  `
"truncate table dbareportdb.sqlinv.SQLInventoryServers_stg; 
truncate table dbareportdb.sqlinv.SQLInventoryDatabases_stg;
truncate table dbareportdb.sqlinv.SQLServerPort_stg;
truncate table dbareportdb.sqlinv.SQLSpatialDBs_stg;
truncate table dbareportdb.sqlinv.SQLCPUPerDB_stg;
truncate table dbareportdb.sqlinv.SQLDefaultTrace_stg;
truncate table dbareportdb.sqlinv.SQLLogins_stg;"


$ServerCollection | ForEach-Object -parallel  { import-module "D:\admin\scripts\inv\ps\GetSQLInventoryInfo\GetSQLInventoryInfo.psm1" 
get-sqlinvServers -TargetServer $_                  
get-sqlinvDatabases -TargetServer $_
get-sqlinvCPUPerDB -TargetServer $_ 
get-sqlinvSpatialDB -TargetServer $_ 
get-sqlinvTrace  -TargetServer $_
get-sqlinvLogins  -TargetServer $_
} -AsJob -ThrottleLimit 6 | Receive-Job -Wait;


# Invoke-DbaQuery -SqlInstance "dvvmsdb4199" -Query `
#"truncate table dbareportdb.sqlinv.ADUsers_stg;
# truncate table dbareportdb.sqlinv.ADGroups_stg;
# truncate table dbareportdb.sqlinv.SQLUserPermission_stg;
# truncate table dbareportdb.sqlinv.SQLADGroupMembers_stg;
#truncate table dbareportdb.sqlinv.SQLADLoginTestRestult_stg;


# measure-command {$ServerHost | ForEach-Object -parallel  { import-module "D:\admin\scripts\inv\ps\GetSQLInventoryInfo\GetSQLInventoryInfo" 
# get-sqlinvADUsers -TargetServer @("amaprddc1b.DPI.NSW.GOV.AU", "PAZADDC4004.dec.int")
# get-sqlinvADGroups -TargetServer @("amaprddc1b.DPI.NSW.GOV.AU", "PAZADDC4004.dec.int")
# get-sqlinvUserPermission  -TargetServer $_ 
# get-sqlinvADGroupMembers  -TargetServer $_
# get-sqlinvADLoginTest  -TargetServer $_ 
#   } -AsJob | Receive-Job -Wait;}



