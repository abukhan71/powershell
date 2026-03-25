

cls
import-module dbatools
# remove-module -name "GetSQLInventoryInfo"
import-module "D:\admin\scripts\inv\ps\GetSQLInventoryInfo\GetSQLInventoryInfo.psm1"
set-dbatoolsInsecureConnection -sessionOnly
[Object[]]$ServerCollection = Invoke-DbaQuery -SqlInstance "dvvmsdb4199" -Query "select ServerFQDName as SQLInstanceName from dbareportdb.sqlinv.SQLInventoryServers where status='Active' order by 1" 
[Object[]]$ServerHostCollection = Invoke-DbaQuery -SqlInstance "dvvmsdb4199" -Query "select  distinct HostName+'.'+domainname as HostName from dbareportdb.sqlinv.SQLInventoryServers where status='Active' order by 1" 




Invoke-DbaQuery -SqlInstance "dvvmsdb4199" -Query  "truncate table dbareportdb.sqlinv.ADUsers_stg;
truncate table dbareportdb.sqlinv.ADGroups_stg;
truncate table dbareportdb.sqlinv.SQLPermission_stg;
truncate table dbareportdb.sqlinv.SQLADGroupMembers_stg;
truncate table dbareportdb.sqlinv.SQLADLoginTestRestult_stg;"

get-sqlinvADUsers -TargetServer @("amaprddc1b.DPI.NSW.GOV.AU", "PAZADDC4004.dec.int")
get-sqlinvADGroups -TargetServer @("amaprddc1b.DPI.NSW.GOV.AU", "PAZADDC4004.dec.int")

$ServerCollection | ForEach-Object -parallel  { import-module "D:\admin\scripts\inv\ps\GetSQLInventoryInfo\GetSQLInventoryInfo.psm1" 
get-sqlinvUserPermission  -TargetServer $_ 
get-sqlinvADGroupMembers  -TargetServer $_
get-sqlinvADLoginTest  -TargetServer $_ 
  } -AsJob -ThrottleLimit 3 | Receive-Job -Wait;



