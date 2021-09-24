##############################################################################
#
# NAME: 	check_windows_updates.ps1
#
# AUTHOR: 	Christian Kaufmann, Umwelt-Campus Birkenfeld
# EMAIL: 	c.kaufmann@umwelt-campus.de
#
# COMMENT:  Script to check for windows updates with Nagios + NRPE/NSClient++
#
#			Return Values for NRPE:
#			No updates available - OK (0)
#			Only Hidden Updates - OK (0)
#			Updates already installed, reboot required - WARNING (1)
#			Optional updates available - WARNING (1)
#			Critial updates available - CRITICAL (2)
#			Script errors - UNKNOWN (3)
#
# CHANGELOG:
# 1.2 2011-08-11 - cache updates, periodically update cache file
# 1.1 2011-05-11 - hidden updates only -> state OK
#				 - call wuauctl.exe to show available updates to user
# 1.0 2011-05-10 - initial version
#
##############################################################################
$Crit = $args[0]
$Warn = $args[1]

if (-not $Crit) { $Crit = 10 }
if (-not $Warn) { $Warn = 20 }

$returnStateOK = 0
$returnStateWarning = 1
$returnStateCritical = 1
$returnStateUnknown = 3

$updateCacheFile = "$PSScriptRoot/check_windows_updates-cache.xml"
$updateCacheExpireHours = "1"

$logFile = "$PSScriptRoot/check_windows_update.log"

function LogLine(	[String]$logFile = $(Throw 'LogLine:$logFile unspecified'), 
					[String]$row = $(Throw 'LogLine:$row unspecified')) {
	$logDateTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
	Add-Content -Encoding UTF8 $logFile ($logDateTime + " - " + $row) 
}

if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"){ 
	Write-Host "updates installed, reboot required"
	if (Test-Path $logFile) {
		Remove-Item $logFile | Out-Null
	}
	if (Test-Path $updateCacheFile) {
		Remove-Item $updateCacheFile | Out-Null
	}
	exit $returnStateWarning
}

if (-not (Test-Path $updateCacheFile)) {
	LogLine -logFile $logFile -row ("$updateCacheFile not found, creating....")
	$updateSession = new-object -com "Microsoft.Update.Session"
	$updates=$updateSession.CreateupdateSearcher().Search(("IsInstalled=0 and Type='Software'")).Updates
	Export-Clixml -InputObject $updates -Encoding UTF8 -Path $updateCacheFile
}

if ((Get-Date) -gt ((Get-Item $updateCacheFile).LastWriteTime.AddHours($updateCacheExpireHours))) {
	LogLine -logFile $logFile -row ("update cache expired, updating....")
	$updateSession = new-object -com "Microsoft.Update.Session"
	$updates=$updateSession.CreateupdateSearcher().Search(("IsInstalled=0 and Type='Software'")).Updates
	Export-Clixml -InputObject $updates -Encoding UTF8 -Path $updateCacheFile
} else {
	LogLine -logFile $logFile -row ("using valid cache file....")
	$updates = Import-Clixml $updateCacheFile
}

if ($updates.Count -eq 0) {
	Write-Host "OK - no pending updates."
	exit $returnStateOK
}

$critialTitles = "";
$countCritical = 0;
$countOptional = 0;
$countHidden = 0;

foreach ($update in $updates) {
	if ($update.IsHidden) {
		$countHidden++
	}
	elseif ($update.AutoSelectOnWebSites) {
		$criticalTitles += $update.Title + " "
		$countCritical++
	} else {
		$countOptional++
	}
}

if (($countCritical + $countOptional) -gt 0) {
    $returnString = "Updates: $countCritical critical, $countOptional optional"
    Write-Host $returnString
}

if ($countCritical -gt 0 -or $countOptional -gt 0) {
	#Start-Process C:\Windows\system32\wuauclt.exe -ArgumentList /detectnow -WindowStyle Hidden    
}

if ($countCritical -gt $Crit) {        
	exit $returnStateCritical       
} elseif ($countOptional -gt $Warn) {
        exit $returnStateWarning
} elseif ($countHidden -gt 0) {
	Write-Host "OK - $countHidden hidden updates."
	exit $returnStateOK
} else { exit $returnStateOK }

Write-Host "UNKNOWN script state"
exit $returnStateUnknown
