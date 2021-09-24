#Version 1.0

# Variables
Param([int]$mins = 5)
$exclude = "$PSScriptRoot\logon_exclude.txt"
$res = @()
$nag_out = $null
$logs = $null

# Search Event Log
$logs = get-eventlog system -source Microsoft-Windows-Winlogon -After (Get-Date).AddMinutes(-$mins)

# Get Logon Events
ForEach ($log in $logs) {if($log.instanceid -eq 7001) {$type = "Logon"} Else {Continue} 
$res += New-Object PSObject -Property @{Time = $log.TimeWritten; "Event" = $type; User = (New-Object System.Security.Principal.SecurityIdentifier $log.ReplacementStrings[1]).Translate([System.Security.Principal.NTAccount])}}

#$res | Format-Table -AutoSize

ForEach ($logon in $res){ 
    # Exlude list
    ForEach ($id in Get-Content $exclude){if( $logon.User -eq $id ){$filter = $true ; break}else{ $filter = $false  }}
        
    # Nagios output string
    if(!$filter){$z = $logon.User ; $nag_out += "$z ; "}
}

if($nag_out){ $nag_out = $nag_out.TrimEnd("; ") ; Write-Host $nag_out ; exit 1 }else{Write-Host "No successful logons..." ; exit 0 }
