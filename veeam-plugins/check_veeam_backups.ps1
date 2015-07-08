
#################################################################################
#################################################################################
####################  Made by Tytus Kurek on September 2012  ####################
#################################################################################
#################################################################################
###  This is a Nagios Plugin destined to check the last status and last run   ###
###        of Veeam Backup & Replication job passed as an argument.           ###
#################################################################################
#################################################################################

# Added by PJF
#     	Apr 2013   	- 	added condition for ongoing jobs 
#	Oct 2013   	-	corrected date format
#	Dec 2013	-	changed returned date value from strings to integers
#	Jan 2014	-	added condition for new jobs
#	Feb 2014	-	restructured the entire plugin using switch statement
#	Jun 2014	-	changed function used for checking last run time of jobs from ScheduleOptions.LatestRun to FindLastSession().creationtime
#	Nov 2014	-	Added wholesale changes to monitor Continous jobs and the Merging state.
#	Apr 2015	-	Reworked the output of the plugin to make it more informative.
#	May 2015	-	Added Merge details and Job duration to output

# Adding required SnapIn

asnp VeeamPSSnapin

# Global variables

$name = $args[0]
$period = $args[1]

# Veeam Backup & Replication job status check

$job = Get-VBRJob -Name $name

if ($job -eq $null)
{
	Write-Host "UNKNOWN Job is not scheduled: $name."
	exit 3
}

#################################################################################
# Determine "Current" and Previous Job Sessions
#################################################################################

$current_run = Get-VBRBackupSession -Name $name* | Where {$_.Result -eq "None" -and $_.State -eq "Working" -and $_.OrigJobName -eq $name } 
if ( !$current_run )
{
	$current_run = Get-VBRBackupSession -Name $name* | Where { $_.OrigJobName -eq $name } | Sort-Object CreationTime | Select -Last 1
	$previous_run = Get-VBRBackupSession -Name $name* | Where { $_.OrigJobName -eq $name } | Sort-Object CreationTime | Select -Last 2 | Select -First 1
}
else
{
	$previous_run = Get-VBRBackupSession -Name $name* | Where { $_.OrigJobName -eq $name } | Sort-Object CreationTime -Descending |  Where { $_.Result -ne "None" } | Select -First 1
}

#################################################################################
# Collect information regarding the last/ongoing execution of the job	
#################################################################################

# Current State of Job
$current_state = $current_run.State
# Full name of job's current run. Contains Backup Type and Retry information.
$current_type =  ($current_run.Name -Replace( "$name", "")).Trim()
# Current / Last Result of job
$current_result = $current_run.Result
# Progress of Current Job in %
$current_progress = $current_run.Progress.Percents
# Current Operation being performed by the job
$current_operation = $current_run.Operation

#################################################################################
# Calculate Duration of Current Job
#################################################################################

# Start Time of Current Run
# $current_start_time = $current_run.CreationTime
$duration = $(Get-Date) - $current_run.CreationTime
$duration_string = "{0:dd} days and {0:hh\:mm\:ss}" -f $duration

#################################################################################
# Collect information regarding the previous/penultimate execution of the job
#################################################################################

# Result of previous/penultimate run
$previous_result = $previous_run.Result
# List of VMs that failed during previous run 
$previous_failed = $previous_run.GetTaskSessionsByStatus("Failed")
$previous_failed_VMs = $previous_failed.Name -Join ", "
# List of VMs that returned warnings during previous run
$previous_warning = $previous_run.GetTaskSessionsByStatus("Warning")
$previous_warning_VMs = $previous_warning.Name -Join ", "

#################################################################################
# Determine Backup status
#################################################################################

# Case 1: Job is ongoing,i.e; Job State is Working
if ($current_state -eq "Working")
{
	# Output is determined by the result of the previous/penultimate run
	switch($previous_result)
	{
		"Warning"		
		{	
			if (($previous_warning.Count -eq 0) -or ($previous_warning.Count -gt 5))
			{
				Write-Host "WARN: $name. Previous Job State: WARNING. Current Job Type: $current_type. Current Job Progress: $current_progress %. Current Job Duration: $duration_string."
			}
			else
			{
				Write-Host "WARN: $name. Previous Job State: WARNING. Warning VMs: $previous_warning_VMs. Current Job Type: $current_type. Current Job Progress: $current_progress %. Current Job Duration: $duration_string."
			}
			exit 1
		}
		"Failed"
		{
			if (($previous_failed.Count -eq 0) -or ($previous_failed.Count -gt 5))
			{
				Write-Host "CRIT: $name. Previous Job State: FAILED. Current Job Type: $current_type. Current Job Progress: $current_progress %. Current Job Duration: $duration_string."
			}
			else
			{
				Write-Host "CRIT: $name. Previous Job State: FAILED. Failed VMs: $previous_failed_VMs. Current Job Type: $current_type. Current Job Progress: $current_progress %. Current Job Duration: $duration_string."
			}
			exit 2
		}
		"None"
		{
			Write-Host "UNKNOWN: Job $name has never been executed!!?"
			exit 3
		}		
		"Success"
		{
			$now = ((Get-Date).AddDays(-$period)).DayOfYear
			$previous_end_day = $previous_run.EndTime.DayOfYear

			# Handling date calculation at the begining of a new year
			$newyear = $now - $previous_end_day
			if ( $newyear -ge 364 )
				{
					$now =-$now
				}

			if ( $newyear -le -364 )
				{
					$previous_end_day =-$previous_end_day
				}

			# Checking freshness of backups
			if ($now -gt $previous_end_day)
				{
					Write-Host "WARN: $name. It's been more than $period days since the last run. Previous Job State: SUCCESS. Current Job Type: $current_type. Current Job Progress: $current_progress %. Current Job Duration: $duration_string."
					exit 1
				} 
			else
				{
					Write-Host "OK: $name. Previous Job State: SUCCESS. Current Job Type: $current_type. Current Job Progress: $current_progress %. Current Job Duration: $duration_string."
					exit 0
				}
		}
	}
}
# Case 2: Job is merging,i.e; Job State is Postprocessing
elseif ($current_state -eq "Postprocessing")
{
	# Output is determined by the result of the previous run
	switch($previous_result)
	{
		"Warning"		
		{	
			if (($previous_warning.Count -eq 0) -or ($previous_warning.Count -gt 5))
			{
				Write-Host "WARN: $name. Previous Job State: WARNING. Current Job Type: $current_type. Current Job Progress: $current_operation. Current Job Duration: $duration_string."
			}
			else
			{
				Write-Host "WARN: $name. Previous Job State: WARNING. Warning VMs: $previous_warning_VMs. Current Job Type: $current_type. Current Job Progress: $current_operation. Current Job Duration: $duration_string."
			}
			exit 1
		}
		"Failed"
		{
			if (($previous_failed.Count -eq 0) -or ($previous_failed.Count -gt 5))
			{
				Write-Host "CRIT: $name. Previous Job State: FAILED. Current Job Type: $current_type. Current Job Progress: $current_operation. Current Job Duration: $duration_string."
			}
			else
			{
				Write-Host "CRIT: $name. Previous Job State: FAILED. Failed VMs: $previous_failed_VMs. Current Job Type: $current_type. Current Job Progress: $current_operation. Current Job Duration: $duration_string."
			}
			exit 2
		}
		"None"
		{
			Write-Host "UNKNOWN: Job $name has never been executed!!?"
			exit 3
		}		
		"Success"
		{
			$now = ((Get-Date).AddDays(-$period)).DayOfYear
			$previous_end_day = $previous_run.EndTime.DayOfYear

			# Handling date calculation at the begining of a new year
			$newyear = $now - $previous_end_day
			if ( $newyear -ge 364 )
				{
					$now =-$now
				}

			if ( $newyear -le -364 )
				{
					$previous_end_day =-$previous_end_day
				}

			# Checking freshness of backups
			if ($now -gt $previous_end_day)
				{
					Write-Host "WARN: $name. It's been more than $period days since the last run. Previous Job State: SUCCESS. Current Job Type: $current_type. Current Job Progress: $current_operation. Current Job Duration: $duration_string."
					exit 1
				} 
			else
				{
					Write-Host "OK: $name. Previous Job State: SUCCESS. Current Job Type: $current_type. Current Job Progress: $current_operation. Current Job Duration: $duration_string."
					exit 0
				}
		}
	}
}
# Case 3: Job is stopped,i.e; Job State is Stopped
elseif ( $current_state -eq "Stopped" )
{
	$current_end_time = $current_run.EndTime
	# Ideally, a continuous job should never be stopped. Hence, checking the same.
	if ( $job.IsContinuous )
	{
		if ( $current_result -eq "Failed" )
		{
			Write-Host "CRIT: Continuous job $name has been stopped. Previous Job State: FAILED. Job ended at $current_end_time ."
			exit 2
		}
		elseif ( $current_result -eq "Warning" )
		{
			Write-Host "WARN: Continuous job $name has been stopped. Previous Job State: WARNING. Job ended at $current_end_time."
			exit 1
		}
		else
		{
			Write-Host "WARN: Continuous job $name has been stopped. Previous Job State: SUCCESS. Job ended at $current_end_time."
			exit 1
		}
	}
	else
	{
		$now = ((Get-Date).AddDays(-$period)).DayOfYear
		$current_end_day = $current_run.EndTime.DayOfYear

		# Handling date calculation at the begining of a new year
		$newyear = $now - $current_end_day
		if ( $newyear -ge 364 )
		{
			$now =-$now
		}

		if ( $newyear -le -364 )
		{
				$current_end_day =-$current_end_day
		}

		# Checking freshness of backups
		if ($now -gt $current_end_day)
		{
			Write-Host "WARNING! Last run of job: $name more than $period days ago. "
			exit 1
		} 
		else
		{
			Write-Host "OK! Last run of job: $name was successful."
			exit 0
		}
	}
}
# Case 4: Out of scope of plugin
else
{
	Write-Host "UNKNOWN: Problems were encountered while processing the plugin."
	exit 3
}
