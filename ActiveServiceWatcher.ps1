# Set the date for the log
$TranscriptDate = (Get-Date -format MMddyyyy)

Start-Transcript -Append -IncludeInvocationHeader -Path $PSScriptRoot\$TranscriptDate-OnbaseServiceWatcher.txt

# What services are we watching?

$Services = @(
"SPOOLER"
)

# Set this Variable 
$UpdatedHour = ((Get-Date).Hour) 

# Set Problem_Detected to False to start.
$Problem_Detected = $false

DO {

   foreach ($Service in $Services) 
         {
    
    # Check if the service is running by getting its status. Start it if not running.

            if (((Get-Service -Name $Service -ErrorAction Continue).Status) -ne "Running"){
                Start-Service -Name $Service
                    }
            Elseif (((Get-Service -Name $Service -ErrorAction Continue).Status) -eq "Running"){
                Write-Host (get-date -format s) "- $Service is running." }       
                    }

    # Write out status, and update the time to check if we are in maintenance

            Write-Host (get-date -format s) "- Processes running. Sleeping for a minute"
            Start-Sleep 60
            $Problem_Detected = (((Get-Date).Hour) -imatch {'"01"'})
            Write-Host (get-date -format s) "- Problem_Detected is set to $Problem_Detected"         

} Until ($Problem_Detected -eq $True)

foreach ($Service in $Services){
    Write-Host (get-date -format s) "- Restarting $Service"
    Restart-Service -Name $Service 
    Write-Host (get-date -format s) "- $Service Restarted"
    }

Write-Host (get-date -format s) "- We are in maintenance. Exiting script, see you tomorrow!"                      
Stop-Transcript
