<#

Written by Don Babb
Date: 7/16/2020
Version 1.0

Settings:

Default: Checking the Application log for EventType Error for the last 5 minutes.
You can modify the default settings in  the Param section.
.\check_eventlog.ps1

CLI
.\check_eventlog.ps1 -mins 5 -name Application -type error
.\check_eventlog.ps1 -mins 60 -name System -type error

Common EventLogs Options: Application, System, Security
Note: All log name option will work, even for 3rd party as long you are using correct event type selected for that log.
Event Type Options: Error, Warning, Information, FailureAudit, SuccessAudit or custom created.

Exlude Option:
Modify eventlog_exclude.txt
ID;SOURCE;MESSAGE
See text file for default excluded false alarms.

Nagios XI Service: NCPA agent
$USER1$/check_ncpa.py -H $HOSTADDRESS$ $ARG1$
-t '<TOKEN>' -P 5693 -M 'plugins/check_eventlog.ps1' -q 'args=-mins 5 -name Application -type Error'

Nagios CLI:
./check_ncpa.py -H <HOST> -t '<TOKEN>' -P 5693 -M 'plugins/check_eventlog.ps1' -q 'args=-mins 5 -name Application -type Error'

#>

Param(
[int] $mins = 5,
[string]$name = "Application",
[string]$type = "Error"
)

$exclude = "$PSScriptRoot\check_eventlog_exclude.txt"
$Starttime = (Get-Date).AddMinutes(-$mins)
$package = @()

# Exclude filter list function
Function exclude_filter{
try{
    $alerts = @()
    ForEach($log in $logs){
        ForEach ($line in Get-Content $exclude){ 
            $word = $line.split(";")
            ### 9/11/20 - added |-or $word[0] -eq '*'| to line below to allow wildcard in EventID field. Found some cases where EventID was out of bounds. (Vinny)
            if(($word[0] -eq $log.EventID -or $word[0] -eq '*') -and ($word[1] -eq $log.Source) -and ($log.Message -match $word[2])){ $add = $false ; break }
            # if(($word[0] -eq $log.EventID -or $word[0] -eq '*') -and ($word[1] -eq $log.Source) -and ($log.Message.Contains($word[2]))){ $add = $false ; break }
            else{ $add = $true }
        }
        if($add){ $alerts += "LOG: $name ID: $($log.EventID) SRC: $($log.Source) MSG: $($log.Message) - EOM" }      
    }
    $package = $alerts |sort -unique
    return $package            
}
catch{ write-host $_ ; exit 3 }
}

# Exection Body
try{
    $logs = Get-Eventlog -LogName $name -EntryType $type -After $Starttime
    $package = exclude_filter
    if($package){ 
        $package += " (CT=$($package.count))"
        Write-Host $package ; exit 1 } 
    else{ Write-Host "OK: No entries found in $name log..." ; exit 0 }   
}
catch{ write-host $_ ; exit 3 }    
