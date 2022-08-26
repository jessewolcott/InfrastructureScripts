
Start-Transcript -Append -IncludeInvocationHeader -Path $PSScriptRoot\ServiceWatcher.txt

$Services = @(
"PrintNotify"
"wercplsupport"
)

$MaintenanceHours = '"01" -or "02" -or "15"'

DO {

   foreach ($Service in $Services) 
         {

            #Date Time for transcript
            $tstime = (get-date -format s)

    
            if (((Get-Service -Name $Service).Status) -ne "Running"){
                Write-Output "$tstime - $Service is not running. Attempting to start"
                Start-Service -Name $Service
                Start-Sleep 60
                    }
            Elseif (((Get-Service -Name $Service).Status) -eq "Running"){
                Write-Output "$tstime - $Service is running." }
           
                    }
                
            Write-Output "$tstime - Processes running. Sleeping for a minute"
            Start-Sleep 10
            $UpdatedHour = (Get-Date -format HH)             

} Until ({'"01" -or "02" -or "15"'} -eq $UpdatedHour)

Write-Output "$tstime - $UpdatedHour - We are in maintenance (1:00AM to 2:59AM). Exiting script, see you tomorrow!"                      
Stop-Transcript
