$ver = gwmi win32_operatingsystem | % caption
Write-Host "$ver" ; exit 0