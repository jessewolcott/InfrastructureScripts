# Infrastructure Scripts

We all have to do things that clean up our environment, and the best way is to script them away, log it, and forget about it! I'm certainly not the first person to make these scripts or other flavors of them, but these are mine!

## ActiveServiceWatcher.ps1

This script will monitor an array of services to make sure they are running. Kick this off with a scheduled task. I want to write another one of these watching WMI events, but this one is more actively checking. 

## AD_Cleanup_Computer_Records.ps1

Set it and forget it! This script cleans up computers that have not logged into the domain in 30/60/90 days, based on the computer record's "LastLogonTimeStamp".

## DHCPReservationReport.ps1
Generates a report of DHCP reservations that exist on authoritative DHCPv4 servers in your domain (or array, if you so choose)

## dotnet4versioncheck.ps1

Scrapes specified AD OU's and returns their installed dotnet framework (v4), the OS version, the IP address and the hostname. 

## HyperVFileCopy.ps1

DMZ'd or otherwise restricted machines may need to have files copied into them. This script allows that to happen with an entire directory full of files. 

## OrphanedSessionKiller.ps1

Set your servers and schedule this task, and it will terminate disconnected sessions on your servers.

## VendorTerminationCheck.ps1

Schedule this script to email your vendor contacts to check if all the people that have access to your org still need it.

## ZebraKR203-WindowsUpdateFix.ps1

An MS update broke this commodity thermal printer. This script gets you up and running!
