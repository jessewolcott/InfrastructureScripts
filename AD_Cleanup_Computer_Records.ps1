# Synopsis 
# Active Directory Inactive Computers - Cleanup Script
# Developed by Jesse Wolcott, last modified May 2022

# DESCRIPTION
# This script uses Active Directory to process computer records that have not been "active" for the past 30, 60, and 90 days. 
# It uses the "LastLogonTimeStamp" from Active Directory to determine this. After 30 days of inactivity, the computer is set to disabled in Active Directory. 
# After 60 days of inactivity, the computer is moved to the specified stale computers OU, $Stale_OU. After 90 days of inactivity, the computer record is deleted

# EXAMPLE
# This script is best used as a daily task run by a service account. This service account must have access to move records in your OU, as well as access to any logging path that you want it to log to.

# OUTPUTS
# Use the $Log_Path to check the machines that were removed or disabled each day. This log is appended. 

# Set output log folder path. Do not include a trailing slash. Example: "\\site-file-server1\logs\ActiveDirectory"
$Log_Path = "\\site-file-server1\logs\ActiveDirectory"

# NOTES
# It is likely that you will want to run this manually the first time, and wait for fall out. It would not be a bad idea to warn the business, and do it on a Monday!

# --- SET SITE SPECIFIC VARIABLES --- #

# Active OU to search. Example: "OU=Computers,OU=Site,DC=contoso,DC=com"
$Active_OU = "OU=Computers,OU=Site,DC=contoso,DC=com"
# Stale OU target. Example: "OU=Stale Computers,OU=Site,DC=contoso,DC=com"
$Stale_OU = "OU=Stale Computers,OU=Site,DC=contoso,DC=com"


# --- END OF PROPERTY SPECIFIC SECTION --- #

# Check for ActiveDirectory module. Install/Import as necessary. Display error, fail, and exit if not available. Install manually and run again.
$ModuleToCheck = "ActiveDirectory"

Function Load-Module ($Module) {

    # If module is imported, break and continue
    If (Get-Module | Where-Object {$_.Name -eq $Module}) {
    }
    Else {

        # If module is not imported but available, then import
        If (Get-Module -ListAvailable | Where-Object {$_.Name -eq $Module}) {
            Import-Module $Module
        }
        Else {

            # If module is not imported, not available, but is in gallery, then install and import
            If (Find-Module -Name $Module | Where-Object {$_.Name -eq $Module}) {
                Install-Module -Name $Module -Force -Confirm:$False -Scope AllUsers
                Import-Module $Module
            }
            Else {

                # If module is not imported, not available and not in gallery, then alert and exit
                Write-Output "Module $Module is not installed nor available. Please install manually. Exiting now. Investigate and try again" -ForegroundColor Red
                Start-Sleep 3
                EXIT 1
            }
        }
    }
}

Load-Module $ModuleToCheck


# Set time variables
$30d = (Get-Date).Adddays(-(30))
$60d = (Get-Date).Adddays(-(60))
$90d = (Get-Date).Adddays(-(90))


# Identify machines (filtered here) that have not been logged into for 30 days in the active OU and disable them. Will also output machine name, current date, and result of attempt to csv
$Process30 = Get-ADComputer -Filter {(LastLogonTimeStamp -lt $30d) -and (Enabled -eq $true)} -ResultPageSize 2000 -resultSetSize $null -SearchBase $Active_OU -Properties Name, LastLogonTimeStamp, LastLogonDate, DistinguishedName | Where-Object {$_.DistinguishedName -notlike "*OU=Stale*"} | Select-Object -ExpandProperty Name | ForEach-Object {
    Get-ADComputer -Identity $($_)| Disable-ADAccount
              [PSCustomObject]@{
              "Computer" = $($_)
              "Disabled Successfully?" = $?
              "Date" = (Get-Date -Format "MM/dd/yyyy")
                    }
    }
#If any processing was completed, append to the csv
If ($Process30.Count -gt 0) {
    $Process30 | Export-CSV -Path "$Log_Path\ComputersInactive30.csv" -Encoding UTF8 -Append -NoTypeInformation -Force -ErrorAction SilentlyContinue
    } 
    Else {
    }


# Identify machines (filtered here) that have been disabled for 30 days (not logged in to for at least 60 days) in the active OU and move them to the stale OU. Will also output machine name, current date, and result of attempt to csv
$Process60 = Get-ADComputer -Filter {(LastLogonTimeStamp -lt $60d) -and (Enabled -eq $False) -and (OperatingSystem -notlike "*server*")} -ResultPageSize 2000 -resultSetSize $null -SearchBase $Active_OU -Properties Name, LastLogonTimeStamp, LastLogonDate, DistinguishedName | Where-Object {$_.DistinguishedName -notlike "*OU=Stale*"} | Select-Object -ExpandProperty Name -Property DistinguishedName | ForEach-Object { 
    Move-ADObject -Identity $($_.DistinguishedName) -TargetPath $Stale_OU
              [PSCustomObject]@{
              "Computer" = $($_)
              "Moved Successfully?" = $?
              "Date" = (Get-Date -Format "MM/dd/yyyy")
                    } 
    }
#If any processing was completed, append to the csv
If ($Process60.Count -gt 0) {
    $Process60 | Export-CSV -Path "$Log_Path\ComputersInactive60.csv" -Encoding UTF8 -Append -NoTypeInformation -Force -ErrorAction SilentlyContinue
    } 
    Else {
    }


# Identify machines (filtered here) that have been disabled for 30 days (not logged in to for at least 90 days) in the stale OU and delete the Active Directory record. Will also output machine name, current date, and result of attempt to csv
$ProcessDelete = Get-ADComputer -Filter {(LastLogonTimeStamp -lt $90d) -and (Enabled -eq $False)} -SearchBase $Stale_OU | ForEach-Object {
    Remove-ADObject -Identity $($_) -Confirm:$False -Recursive -ErrorAction SilentlyContinue
              [PSCustomObject]@{
              "Computer" = $($_.Name)
              "Deleted Successfully?" = $?
              "Date" = (Get-Date -Format "MM/dd/yyyy")
                    } 
    }
#If any processing was completed, append to the csv
If ($ProcessDelete.Count -gt 0) {
    $ProcessDelete | Export-CSV -Path "$Log_Path\ComputersDeleted.csv" -Encoding UTF8 -Append -NoTypeInformation -Force -ErrorAction SilentlyContinue
    } 
    Else {
    }