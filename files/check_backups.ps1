##############################################################################
#
# NAME: 	check_backups.ps1
#
# AUTHOR: 	Vinny Petrone
# EMAIL: 	vpetrone@richmond.edu
#
# COMMENT:  Script to check for backup images for NCPA/NRPE
#
#			Return Values for NRPE:
#			Backup image is in NB catalog - OK (0)
#			Backup image is missing - WARNING (1)
#			Script errors - UNKNOWN (3)
#
# CHANGELOG:
# 1.0 2020-09-10 - script created
#
##############################################################################

$returnStateOK = 0
$returnStateWarning = 1
$returnStateCritical = 1
$returnStateUnknown = 3
$clientName = (hostname).ToLower()
$yesterday = (get-date).AddDays(-1) | get-date -format "MM/dd/yyyy HH:mm:ss"

### Make sure Netbackup client is installed
if (-not (Test-Path C:\"Program Files"\VERITAS\NetBackup\bin\bpclimagelist.exe)) {
    Write-Host "WARNING - Netbackup client is not installed on $clientName"
    exit $returnStateWarning
}

### Make sure Netbackup client can communicate with Callback
if (-not (C:\"Program Files"\VERITAS\NetBackup\bin\bpclntcmd.exe -pn 2>$null)) {
    Write-Host "WARNING - Netbackup client on $clientName gets no response from Callback. Contact Vinny to resolve issue with missing host certificate."
    exit $returnStateWarning
}

### Check to see if Netbackup is offline or down for maintenance
if (-not (Test-NetConnection -computername callback -port 13724 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationLevel Quiet)) {
    Write-Host "ATTENTION - Netbackup is currently offline or down for maintenance"
    exit $returnStateOK
}

### Use bpclimagelist.exe program to query the NB catalog for a backup image created in the past 24 hours
$backupVMware = C:\"Program Files"\VERITAS\NetBackup\bin\bpclimagelist.exe -client $clientName -s $yesterday -ct 40
$backupWindows = C:\"Program Files"\VERITAS\NetBackup\bin\bpclimagelist.exe -client $clientName -s $yesterday -ct 13

### Filter and split the image string into separate variables for data and time, and return a status
if ($backupVMware) {
    #$backupDateString = $backupVMware|sls '^[0-9]'
    $backupDateString = ($backupVMware)[2]
	$backupDay = ($backupDateString).ToString().Split()[0]
	$backupTime = ($backupDateString).ToString().Split()[1] 
	Write-Host "OK - last backup for $clientName was on $backupDay $backupTime"
        exit $returnStateOK	
} elseif ($backupWindows) {
    #$backupDateString = $backupWindows|sls '^[0-9]'
    $backupDateString = ($backupWindows)[2]
	$backupDay = ($backupDateString).ToString().Split()[0]
	$backupTime = ($backupDateString).ToString().Split()[1] 
        Write-Host "OK - last backup for $clientName was on $backupDay $backupTime"
	exit $returnStateOK
} else {
        Write-Host "WARNING - no backup found for $clientName in the past 24 hours"
        exit $returnStateWarning
}
    
Write-Host "UNKNOWN script state"
exit $returnStateUnknown
