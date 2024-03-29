# Script name:   	check_ms_windows_disk_load.ps1
# Version:			v2.02.151006
# Created on:    	10/10/2014
# Author:        	D'Haese Willem
# Purpose:       	Check MS Windows disk load by using Powershell to get all disk load related counters from Windows 
#					Performance Manager, computing averages for all gathered samples and calculating read / write rate, 
#					number of reads / writes, read / write latency and read / write queue length.
# On Github:		https://github.com/willemdh/check_ms_win_disk_load
# On OutsideIT:		http://outsideit.net/check-ms-win-disk-load
# Recent History:       	
#	16/12/14 => Fixed typo in perfdata output 'Number of Reads'
#	24/04/15 => Cleanup following ISESteroids recommendations
#	27/09/15 => Better Initialize-Args, math rounding and fixed some bugs in output and latency to ms
#	02/10/15 => Cleanup comments, fixed no argument bug
#	06/10/15 => issue with CurrentCulture, set to en-us first
# Copyright:
#	This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published
#	by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed 
#	in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
#	PARTICULAR PURPOSE. See the GNU General Public License for more details. You should have received a copy of the GNU General Public 
#	License along with this program.  If not, see <http://www.gnu.org/licenses/>.

#Requires –Version 2.0

[Int]$DefaultInt = -99

$DiskStruct = New-object PSObject -Property @{
    Hostname = ([System.Net.Dns]::GetHostByName((hostname.exe)).HostName).tolower();
    DiskLetter = 'C';
    Exitcode = 3;
    MaxSamples = 2;
    LogicalDiskId = 236;
    AvgDiskSecReadId = 208;
    AvgDiskSecReadValue = 0;
    AvgDiskSecWriteId = 210;
    AvgDiskSecWriteValue = 0;
    AvgDiskReadQueueId = 1402;
    AvgDiskReadQueueValue = 0;
    AvgDiskWriteQueueId = 1404;
    AvgDiskWriteQueueValue = 0;
    DiskReadsSecId = 214;
    DiskReadsSecValue = 0;
    DiskWritesSecId = 216;
    DiskWritesSecValue = 0;
    DiskReadBytesSecId = 220;
    DiskReadBytesSecValue = 0;
    DiskWriteBytesSecId = 222;
    DiskWriteBytesSecValue = 0;
    AvgDiskReadQueueWarn = $DefaultInt;
    AvgDiskReadQueueCrit = $DefaultInt;
    AvgDiskWriteQueueWarn = $DefaultInt;
    AvgDiskWriteQueueCrit = $DefaultInt;
	ReturnString = 'UNKNOWN: Please debug the script...'
}
	
#region Functions

Function Initialize-Args {
    Param ( 
        [Parameter(Mandatory=$True)]$Args
    )
	
    try {
        For ( $i = 0; $i -lt $Args.count; $i++ ) { 
		    $CurrentArg = $Args[$i].ToString()
            if ($i -lt $Args.Count-1) {
				$Value = $Args[$i+1];
				If ($Value.Count -ge 2) {
					foreach ($Item in $Value) {
						Test-Strings $Item | Out-Null
					}
				}
				else {
	                $Value = $Args[$i+1];
					Test-Strings $Value | Out-Null
				}	                             
            } else {
                $Value = ''
            };

            switch -regex -casesensitive ($CurrentArg) {
                "^(-H|--Hostname)$" {
                    if ($value -match "^[a-zA-Z0-9._-]+$") {
                        $DiskStruct.Hostname = $value
                    } else {
                        throw "Hostname does not meet regex requirements (`"^[a-zA-Z0-9._-]+$`"). Value given is `"$value`"."
                    }
                    $i++
                }
                "^(-dl|--DiskLetter)$" {
                    if ($value -match "^[a-zA-Z]$") {
                        $DiskStruct.DiskLetter = $value
                    } else {
                        throw "Diskletter does not meet regex requirements (`"^[a-zA-Z]$`"). Value given is `"$value`"."
                    }
                    $i++
                }
                "^(-rqw|--ReadQueueWarn)$" {
                    if (($value -match "^[\d]+$") -and ([int]$value -lt 999999)) {
                        $DiskStruct.AvgDiskReadQueueWarn = $value
                    } else {
                        throw "Read queue warning does not meet regex requirements (`"^[\d]+$`"). Value given is `"$value`"."
                    }
                    $i++
                 }
                "^(-rqc|--ReadQueueCrit)$" {
                    if (($value -match "^[\d]+$") -and ([int]$value -lt 999999)) {
                        $DiskStruct.AvgDiskReadQueueCrit = $value
                    } else {
                        throw "Read queue critical does not meet regex requirements (`"^[\d]+$`"). Value given is `"$value`"."
                    }
                    $i++
                 }
                "^(-wqw|--WriteQueueWarn)$" {
                    if (($value -match "^[\d]+$") -and ([int]$value -lt 999999)) {
                        $DiskStruct.AvgDiskWriteQueueWarn = $value
                    } else {
                        throw "Write queue warning does not meet regex requirements (`"^[\d]+$`"). Value given is `"$value`"."
                    }
                    $i++
                 }
                "^(-wqc|--WriteQueueCrit)$" {
                    if (($value -match "^[\d]+$") -and ([int]$value -lt 999999)) {
                        $DiskStruct.AvgDiskWriteQueueCrit = $value
                    } else {
                        throw "Write queue critical does not meet regex requirements (`"^[\d]+$`"). Value given is `"$value`"."
                    }
                    $i++
                 }
                "^(-ms|--MaxSamples)$" {
                    if (($value -match "^[\d]+$") -and ([int]$value -lt 100)) {
                        $DiskStruct.MaxSamples = $value
                    } else {
                        throw "Write queue critical does not meet regex requirements (`"^[\d]+$`"). Value given is `"$value`"."
                    }
                    $i++
                 }
                "^(-h|--Help)$" {
                    Write-Help
                }
                default {
                    throw "Illegal arguments detected: $_"
                 }
            }
        }
    } 
    catch {
		Write-Host "Error: $_"
        Exit 2
	}	
}

Function Test-Strings {
    Param ( [Parameter(Mandatory=$True)][string]$String )
    $BadChars=@("``", '|', ';', "`n")
    $BadChars | ForEach-Object {
        If ( $String.Contains("$_") ) {
            Write-Host "Error: String `"$String`" contains illegal characters."
            Exit $DiskStruct.ExitCode
        }
    }
    Return $true
} 

Function Write-Help {
	Write-Host @"
check_ms_windows_disk_load.ps1:
This script is designed to monitor Microsoft Windows disk load.
Arguments:
    -H 	 | --Hostname			=> Optional hostname of remote system, default is localhost, not yet tested on remote host.
    -dl  | --DiskLetter			=> Diskletter to get data from.
    -rqw | --ReadQueueWarn  	=> Warning threshold for read queue length.
    -rqc | --ReadQueueCrit		=> Critical threshold for read queue length.
    -wqw | --WriteQueueWarn  	=> Warning threshold for write queue length.
    -wqc | --WriteQueueCrit		=> Critical threshold for write queue length.
    -ms  | --MaxSamples 		=> Amount of samples to take.
    -h   | --Help 				=> Print this help output.
"@
    Exit $DiskStruct.ExitCode;
} 	
	
function Get-PerformanceCounterID
{
    param
    (
        [Parameter(Mandatory=$true)]
        $Name
    )
 
    if ($script:perfHash -eq $null)
    {
        Write-Progress -Activity 'Retrieving PerfIDs' -Status 'Working'
 
        $key = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib\CurrentLanguage'
        $counters = (Get-ItemProperty -Path $key -Name Counter).Counter
        $script:perfHash = @{}
        $all = $counters.Count
 
        for($i = 0; $i -lt $all; $i+=2)
        {
           Write-Progress -Activity 'Retrieving PerfIDs' -Status 'Working' -PercentComplete ($i*100/$all)
           $script:perfHash.$($counters[$i+1]) = $counters[$i]
        }
    }
 
    $script:perfHash.$Name
}

Function Get-PerformanceCounterLocalName
{
  param
  (
    [UInt32]
    $ID,
 
    $ComputerName = $env:COMPUTERNAME
  )
 
  $code = '[DllImport("pdh.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern UInt32 PdhLookupPerfNameByIndex(string szMachineName, uint dwNameIndex, System.Text.StringBuilder szNameBuffer, ref uint pcchNameBufferSize);'
 
  $Buffer = New-Object System.Text.StringBuilder(1024)
  [UInt32]$BufferSize = $Buffer.Capacity
 
  $t = Add-Type -MemberDefinition $code -PassThru -Name PerfCounter -Namespace Utility
  $rv = $t::PdhLookupPerfNameByIndex($ComputerName, $id, $Buffer, [Ref]$BufferSize)
 
  if ($rv -eq 0)
  {
    $Buffer.ToString().Substring(0, $BufferSize-1)
  }
  else
  {
    Throw 'Get-PerformanceCounterLocalName : Unable to retrieve localized name. Check computer name and performance counter ID.'
  }
}

function Get-DiskLoadCounters 
{ 
	$PerfCounterArray = @()
	
	$LogicalDisk = Get-PerformanceCounterLocalName $DiskStruct.LogicalDiskId
	
	$AvgDiskSecRead = Get-PerformanceCounterLocalName $DiskStruct.AvgDiskSecReadId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskSecRead"
	
	$AvgDiskSecWrite = Get-PerformanceCounterLocalName $DiskStruct.AvgDiskSecWriteId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskSecWrite"
	
	$AvgDiskReadQueue = Get-PerformanceCounterLocalName $DiskStruct.AvgDiskReadQueueId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskReadQueue"	
	
	$AvgDiskWriteQueue = Get-PerformanceCounterLocalName $DiskStruct.AvgDiskWriteQueueId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskWriteQueue"	
	
	$AvgDiskReadsSec = Get-PerformanceCounterLocalName $DiskStruct.DiskReadsSecId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskReadsSec"	
	
	$AvgDiskWritesSec = Get-PerformanceCounterLocalName $DiskStruct.DiskWritesSecId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskWritesSec"	
	
	$AvgDiskReadBytesSec = Get-PerformanceCounterLocalName $DiskStruct.DiskReadBytesSecId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskReadBytesSec"	
	
	$AvgDiskWriteBytesSec = Get-PerformanceCounterLocalName $DiskStruct.DiskWriteBytesSecId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskWriteBytesSec"		
	
	$PfcValues = (Get-Counter $PerfCounterArray -MaxSamples $DiskStruct.MaxSamples)

	$AvgDiskSecReadValues = @()
	$AvgDiskSecWriteValues = @()
	$AvgDiskReadQueueValues = @()
	$AvgDiskWriteQueueValues = @()
	$AvgDiskReadsSecValues = @()
	$AvgDiskWritesSecValues = @()
	$AvgDiskReadBytesSecValues = @()
	$AvgDiskWriteBytesSecValues = @()
		
	for ($y=0; $y -lt $DiskStruct.MaxSamples; $y++) {			
		$AvgDiskSecReadValues += $PfcValues[$y].CounterSamples[0].CookedValue		
		$AvgDiskSecWriteValues += $PfcValues[$y].CounterSamples[1].CookedValue	
		$AvgDiskReadQueueValues += $PfcValues[$y].CounterSamples[2].CookedValue
		$AvgDiskWriteQueueValues += $PfcValues[$y].CounterSamples[3].CookedValue
		$AvgDiskReadsSecValues += $PfcValues[$y].CounterSamples[4].CookedValue
		$AvgDiskWritesSecValues += $PfcValues[$y].CounterSamples[5].CookedValue
		$AvgDiskReadBytesSecValues += $PfcValues[$y].CounterSamples[6].CookedValue
		$AvgDiskWriteBytesSecValues += $PfcValues[$y].CounterSamples[7].CookedValue	
	}
	
	$AvgObjDiskSecReadValues = $AvgDiskSecReadValues | Measure-Object -Average
	$AvgObjDiskSecWriteValues = $AvgDiskSecWriteValues | Measure-Object -Average
	$AvgObjDiskReadQueueValues = $AvgDiskReadQueueValues | Measure-Object -Average
	$AvgObjDiskWriteQueueValues = $AvgDiskWriteQueueValues | Measure-Object -Average
	$AvgObjDiskReadsSecValues = $AvgDiskReadsSecValues | Measure-Object -Average
	$AvgObjDiskWritesSecValues = $AvgDiskWritesSecValues | Measure-Object -Average
	$AvgObjDiskReadBytesSecValues = $AvgDiskReadBytesSecValues | Measure-Object -Average
	$AvgObjDiskWriteBytesSecValues = $AvgDiskWriteBytesSecValues  | Measure-Object -Average

	$OldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
	[System.Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'
	$DiskStruct.AvgDiskSecReadValue = [decimal]('{0:N5}' -f ($AvgObjDiskSecReadValues.average * 1000))
	$DiskStruct.AvgDiskSecWriteValue = [decimal]('{0:N5}' -f ($AvgObjDiskSecWriteValues.average * 1000))
    $DiskStruct.AvgDiskReadQueueValue = [decimal]('{0:N5}' -f ($AvgObjDiskReadQueueValues.average))
    $DiskStruct.AvgDiskWriteQueueValue = [decimal]('{0:N5}' -f ($AvgObjDiskWriteQueueValues.average))
    $DiskStruct.DiskReadsSecValue = [decimal]('{0:N5}' -f ($AvgObjDiskReadsSecValues.average))
    $DiskStruct.DiskWritesSecValue = [decimal]('{0:N5}' -f ($AvgObjDiskWritesSecValues.average))
    $DiskStruct.DiskReadBytesSecValue = [decimal]('{0:N5}' -f ($AvgObjDiskReadBytesSecValues.average / 1024 / 1024))
    $DiskStruct.DiskWriteBytesSecValue = [decimal]('{0:N5}' -f ($AvgObjDiskWriteBytesSecValues.average / 1024 / 1024))
	[System.Threading.Thread]::CurrentThread.CurrentCulture = $OldCulture

	$ReadQueueCritThreshReached = $false
	$ReadQueueWarnThreshReached = $false
	$WriteQueueCritThreshReached = $false
	$WriteQueueWarnThreshReached = $false

	if ($DiskStruct.AvgDiskReadQueueCrit -ne $DefaultInt -and $DiskStruct.AvgDiskReadQueueValue -gt $DiskStruct.AvgDiskReadQueueCrit) {
		$DiskStruct.ExitCode = 2
		$ReadQueueCritThreshReached = $true
		$OutputReadQueue = "CRITICAL: Read Queue Threshold ($($DiskStruct.AvgDiskReadQueueCrit)) Passed!"
	}
	elseif ($DiskStruct.AvgDiskReadQueueWarn -ne $DefaultInt -and $DiskStruct.AvgDiskReadQueueValue -gt $DiskStruct.AvgDiskReadQueueWarn) {
		$DiskStruct.ExitCode = 1
		$ReadQueueWarnThreshReached = $true
		$OutputReadQueue = "WARNING: Read Queue Threshold ($($DiskStruct.AvgDiskReadQueueWarn)) Passed!"
	}
	if ($DiskStruct.AvgDiskWriteQueueCrit -ne $DefaultInt -and $DiskStruct.AvgDiskWriteQueueValue -gt $DiskStruct.AvgDiskWriteQueueCrit) {
		$DiskStruct.ExitCode = 2
		$WriteQueueCritThreshReached = $true
		$OutputWriteQueue = "CRITICAL: Write Queue Threshold ($($DiskStruct.AvgDiskWriteQueueCrit)) Passed!"
	}
	elseif ($DiskStruct.AvgDiskWriteQueueWarn -ne $DefaultInt -and $DiskStruct.AvgDiskWriteQueueValue -gt $DiskStruct.AvgDiskWriteQueueWarn) {
		$DiskStruct.ExitCode = 1
		$WriteQueueWarnThreshReached = $true
		$OutputWriteQueue = "WARNING: Write Queue Threshold ($($DiskStruct.AvgDiskWriteQueueWarn)) Passed!"
	}
									
	if ($ReadQueueCritThreshReached -eq $false -and $ReadQueueWarnThreshReached -eq $false -and $WriteQueueCritThreshReached -eq $false -and $WriteQueueWarnThreshReached -eq $false) {	
		$DiskStruct.ReturnString = "OK: Drive $($DiskStruct.DiskLetter): Avg of $($DiskStruct.MaxSamples) samples: {Rate (Read: $($DiskStruct.DiskReadBytesSecValue)MB/s)(Write: $($DiskStruct.DiskWriteBytesSecValue)MB/s)} {Avg Nr of (Reads: $($DiskStruct.DiskReadsSecValue)r/s)(Writes: $($DiskStruct.DiskWritesSecValue)w/s)} {Latency (Read: $($DiskStruct.AvgDiskSecReadValue)ms)(Write: $($DiskStruct.AvgDiskSecWriteValue)ms)} {Queue Length (Read: $($DiskStruct.AvgDiskReadQueueValue)ql)(Write: $($DiskStruct.AvgDiskWriteQueueValue)ql)} | "
		$DiskStruct.ExitCode = 0
	}
	else {
		$DiskStruct.ReturnString = "$OutputReadQueue $OutputWriteQueue : Drive $($DiskStruct.DiskLetter): Avg of $($DiskStruct.MaxSamples) samples: {Rate (Read: $($DiskStruct.AvgDiskReadBytesSecValue)MB/s)(Write: $($DiskStruct.AvgDiskWriteBytesSecValue)MB/s)} {Avg Nr of (Reads: $($DiskStruct.DiskReadsSecValue)r/s)(Writes: $($DiskStruct.DiskWritesSecValue)w/s)} {Latency (Read: $($DiskStruct.AvgDiskSecReadValue)ms)(Write: $($DiskStruct.AvgDiskSecWriteValue)ms)} {Queue Length (Read: $($DiskStruct.AvgDiskReadQueueValue)ql)(Write: $($DiskStruct.AvgDiskWriteQueueValue)ql)} | "
	}
	
	$DiskStruct.ReturnString += "'Read_Latency'=$($DiskStruct.AvgDiskSecReadValue)ms "
	$DiskStruct.ReturnString += "'Write_Latency'=$($DiskStruct.AvgDiskSecWriteValue)ms "
	$DiskStruct.ReturnString += "'Read_Queue'=$($DiskStruct.AvgDiskReadQueueValue)ql "
	$DiskStruct.ReturnString += "'Write_Queue'=$($DiskStruct.AvgDiskWriteQueueValue)ql "
	$DiskStruct.ReturnString += "'Number_of_Reads'=$($DiskStruct.DiskReadsSecValue)r/s "
	$DiskStruct.ReturnString += "'Number_of_Writes'=$($DiskStruct.DiskWritesSecValue)w/s "
	$DiskStruct.ReturnString += "'Read_Rate'=$($DiskStruct.DiskReadBytesSecValue)MB/s "
	$DiskStruct.ReturnString += "'Write_Rate'=$($DiskStruct.DiskWriteBytesSecValue)MB/s "	
}

#endregion Functions

# Main function 

if ($Args) {
    if($Args[0].ToString() -ne "$ARG1$"){
	    if($Args.count -ge 1){Initialize-Args $Args}
    }
}

Get-DiskLoadCounters

Write-Host $DiskStruct.ReturnString

Exit $DiskStruct.ExitCode