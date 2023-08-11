
$ScheduledTaskName   = ""       # What should we name your Scheduled Task?
$Website             = "https://www.google.com"   # What site should we launch?
$BrowserChoice       = "System"                     # Options are "Chrome", "Edge, "Firefox", and "System" (which uses your default)

Write-Output ("Creating a scheduled task called `""+$ScheduledTaskName+"`" that launches website `""+$Website+"`" using "+$BrowserChoice+" at login.")

# This script should be run as system, but we need the users ID
$CurrentUser         = (((Get-WMIObject -class Win32_ComputerSystem).username) -creplace '^[^\\]*\\', '')

Write-Output ("This task will be run during the interactive session of `""+$CurrentUser+"`".")
# Set up HKAY_CLASSES_ROOT as a drive so we can check the default app

if ($null -eq (Get-PSDrive -PSProvider Registry -Name HKCR -ErrorAction SilentlyContinue)){
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT}

# Get Default App
$DefaultBrowser = Get-ItemProperty 'HKCR:\\http\shell\open\command\' | Select-Object -ExpandProperty '(default)' | ForEach-Object { $_ -replace '("[^"]+")|\s.*', '$1' }

Switch ($BrowserChoice){
    'Edge' 
        {if (test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"){
        $Command = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"}
            Else{
                Write-Output "Microsoft Edge not found, defaulting to System"
                }
        }
    'Firefox' 
        {if (test-Path "C:\Program Files\Mozilla Firefox\firefox.exe"){
            $Command = "C:\Program Files\Mozilla Firefox\firefox.exe"}
                Else{
                    Write-Output "Firefox not found, defaulting to System"
                    }
            }
    'Chrome' 
        {if (test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe"){
            $Command = "C:\Program Files\Google\Chrome\Application\chrome.exe"}
                Else{
                    Write-Output "Chrome not found, defaulting to System"
                    }
                }
    'System' 
        {$Command = $DefaultBrowser}
    default
        {$Command = $DefaultBrowser}
}

# Create task
    $TaskParams = @{
        Action      = New-ScheduledTaskAction -Execute $Command -Argument $Website
        Trigger     = New-ScheduledTaskTrigger -AtLogOn
        Principal   = New-ScheduledTaskPrincipal -UserId $CurrentUser -LogonType Interactive
        Description = "Run $($ScheduledTaskName) at login as $($CurrentUser) if interactive session active."
    }

Write-Output "Creating scheduled task called $ScheduledTaskName."

Register-ScheduledTask -TaskName $ScheduledTaskName -InputObject (New-ScheduledTask @TaskParams) -Force       

# Check that the task was created
$task = Get-ScheduledTask -TaskName $ScheduledTaskName -ErrorAction SilentlyContinue
if ($null -ne $task){
    Write-Output "Created scheduled task: '$($task.ToString())'."
    }
    else{
        Write-Output "Created scheduled task: FAILED."
            }   

# Check that the task is not disabled
if ((Get-ScheduledTask -TaskName $ScheduledTaskName).State -eq 'Disabled'){
     Get-ScheduledTask -TaskName $ScheduledTaskName | Enable-ScheduledTask}
