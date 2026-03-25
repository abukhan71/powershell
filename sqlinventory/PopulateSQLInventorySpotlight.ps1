cls

[string] $SourceServer ="dvvmsdb4199"
[string] $TargetServer ='_' #'lidcodb99.dec.int'


import-module dbatools
set-dbatoolsInsecureConnection -sessionOnly

Invoke-DbaQuery -SqlInstance $SourceServer -Query "truncate table dbareportdb.sqlinv.SQLSpotlightAlarms_stg"
$Servers = Invoke-DbaQuery -SqlInstance $SourceServer -Query "select ServerFQDName as SQLInstanceName from dbareportdb.sqlinv.SQLInventoryServers where ServerFQDName in ('dvvmsdb4199.dec.int','pvamsdb4199.dec.int','amaprdsql06b.dpi.nsw.gov.au\prodsql2017')"
foreach ($Server in $Servers){ 

$sql="select 
		pd.timecollected,
		mo.monitored_object_name,
		mo.monitored_object_display_name + '(' + te.technology_name + ')' as monitored_object_display_name,
		max(case when sn.statistic_name = 'severity' then cast(pd.raw_value as int) end) as 'severity',
		max(case when sn.statistic_name = 'text' then cast(pd.raw_value as nvarchar(100)) end) as 'text',
		max(case when sn.statistic_name = 'action' then cast(pd.raw_value as nvarchar(100)) end) as 'action',
		max(case when sn.statistic_name = 'rule' then cast(pd.raw_value as nvarchar(100)) end) as 'AlarmName',
		case max(case when sn.statistic_name = 'severity' then cast(pd.raw_value as int) end) 
			when 0 then 'Disabled'
			when 1 then 'Normal'
			when 2 then 'Information'
			when 3 then 'Low'
			when 4 then 'Medium'
			when 5 then 'High'
			else 'Unknown'
		end as 'severityname'
	from
		[dbo].[spotlight_perfdata] pd		
		inner join [dbo].[spotlight_stat_names] sn on pd.statistic_name_id = sn.statistic_name_id
												--and sn.statistic_class_id = 58
		inner join [dbo].[spotlight_monitored_objects] mo on pd.monitored_object_id = mo.monitored_object_id	
		inner join [dbo].[spotlight_technologies] te on mo.technology_id = te.technology_id											
	where
		pd.timecollected between CONVERT(nvarchar,getdate()-1,126) and CONVERT(nvarchar,getdate(),126)
	group by 
		pd.timecollected, pd.statistic_key_id, mo.monitored_object_name, mo.monitored_object_display_name + '(' + te.technology_name + ')'
		having max(case when sn.statistic_name = 'severity' then cast(pd.raw_value as int) end) in (4,5)"

$DefaultTrace=Invoke-DbaQuery -SqlInstance $Server.SQLInstanceName -Database SpotlightStatisticsRepository -Query $sql
$DefaultTrace | Write-DbaDbTableData -SqlInstance $SourceServer -Database dbareportdb -schema sqlinv  -Table SQLSpotlightAlarms_stg -AutoCreateTable -BatchSize 5000
}

Invoke-DbaQuery -SqlInstance $SourceServer -CommandType StoredProcedure -Query "dbareportdb.sqlinv.usp_populate_SpotlightAlarms"