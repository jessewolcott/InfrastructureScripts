
<#
.SYNOPSIS
    Zebra KR203 won't print! Everything is broken! 
.DESCRIPTION
    Some versions of Windows 10 have an update applied that breaks the driver for the Zebra KR203, so that you can't disable bidirectional printing, or even open up the settings panel for the printer itself. When the driver is reinstalled (as it is packaged with many out of the box solutions) it is often redirected to the ZIHLM16.DLL driver inside of system32. This is bad and we don't like it.
    
    Ideally, you'd use a tool like SCCM or Tanium to watch this file and do the correct "watchful waiting". But if you need to fix the issue right now, right now, this script will get you there!
.EXAMPLE
    Run the script after your device installation.
.NOTES
    This script renames ZIHLM16.DLL to ZIHLM16-(date and time). If you run this every time that the machine logs in, or on some schedule, the drive could fill up. There are no protections against that here. 

    Additionally, this assumes that you have not renamed the printer. Disabling bidirectional printing is the scalpel approach, and may not resolve the issue, but that only targets printers specifically called "Zebra KR203"
#>

#What printer are we looking for? 
$printer = Get-CimInstance -ClassName 'Win32_Printer' -Filter 'Name = ''Zebra KR203'''

#Time / date generator for file rename
$FileLogdate = Get-Date -Format "MMddyyyy_HHmmss"

#Check if bidirectional printing is enabled, if so, disable
$SuspectDLL = "$env:SystemRoot\System32\ZIHLM16.DLL"
    IF($printer.EnableBIDI = $true){
        $printer.EnableBIDI = $false
        Set-CimInstance -InputObject $printer
        }
#rename the DLL to include the date
If (Test-Path -Path $SuspectDLL ) {
    Rename-Item -Path $SuspectDLL -NewName "ZIHLM16_$FileLogdate.DLL" -ErrorAction SilentlyContinue -Force
    }
    Else {
        # Act if file does not exist (or leave blank for nothing)
        }

Rename-Item -Path C:\Windows\System32\ZIHLM16.DLL -NewName "ZIHLM16_$FileLogdate.DLL" -ErrorAction SilentlyContinue

#spooler clear
stop-service -name "Spooler" -force

Get-ChildItem -Path "C:\Windows\System32\Spool\PRINTERS" -Include *.* -File -Recurse | foreach { $_.Delete()}

Start-Service -name "Spooler" -Force 

#Reboot
Restart-Computer -Force