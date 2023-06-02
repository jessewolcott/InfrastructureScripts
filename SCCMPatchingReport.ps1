$Site_Server       = "" # SCCM Server FQDN - Example "SCCM.contoso.com"
$SCCM_Site         = "" # SCCM Site Name - Example "S01"
$WebServerFilePath = "" # Path to save this HTML - Example "C:\Temp\index.html"


<# 
Define your collection names. If you named everything the same, you can put a wildcard here (like if all your update 
device collections start with "Windows Servers - " you can put "Windows Servers - *" here. If you want to explicitly call out 
your device collections, put them in the array and this script will use that array instead of the search.
#> 
$CollectionSearch  = "Windows Servers - *"
$WindowsUpdateCollectionNames = @(
    #"UpdateServer.contoso.com"
)

## Find configmgr
if ($null -ne ((Get-Package -Name "Microsoft Endpoint Configuration Manager Console").Name)){
    Write-output "Found ConfigMgr"
    # Finding ConfigMgr Path
    if (Test-Path "D:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\Microsoft.ConfigurationManagement.exe"){
        Write-Output "Found path to ConfigMgr"
        $ConfigMgrPath = "D:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
        }
    if (Test-Path "C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\Microsoft.ConfigurationManagement.exe"){
        Write-Output "Found path to ConfigMgr"
        $ConfigMgrPath = "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
        }
    Import-module $ConfigMgrPath -ErrorAction SilentlyContinue
    
    Write-Output "Setting location of CMSITE"
    Set-Location -Path "$((Get-PSDrive -PSProvider CMSITE).name):\"         
    }        
    Else {
        Write-Output "Did not find ConfigMgr."
    }
## Find configmgr
## Get collections
if ($WindowsUpdateCollectionNames){
    $WindowsUpdateCollectionNames | foreach-object{Get-CMCollection -CollectionType Device -Name $_ -ErrorAction SilentlyContinue}
    }
    Else{
        $Collections = Get-CMCollection -CollectionType Device -Name $CollectionSearch -ForceWildcardHandling -ErrorAction SilentlyContinue | Where-Object {$_.Name -notmatch 'Unassigned'}}

## SCCM Client Inventory Report
$CollectionResults = ($Collections.Name) | Foreach-Object {
    $Schedule = ($_)
    Get-CMCollectionmember -CollectionName ($_) -DisableWildcardHandling | `
    ForEach-Object {
            New-Object -TypeName PSCustomObject -Property @{
                'Hostname'                      = $_.Name
                'MS Defender Last Connected'    = $_.ATPLastConnected
                'MS Defender Running'           = if($_.ATPSenseIsRunning -eq $true){'Running'}else{'Not Running'}
                'SCCM Client'                   = if($_.ClientActiveStatus -eq '1'){'Active'}else{'Inactive'}
                'Last Shutdown'                 = $_.CNLastOfflinetime
                'Last Boot Time'                = $_.CNLastOnlineTime
                'OS Build'                      = $_.DeviceOSBuild
                'Client Activity'               = if($_.Isactive -eq '1'){'Yes'}else{'No'}
                'Is Client known?'              = if($_.Unknown -eq $true){'UNKNOWN'}else{'Known'}
                'Collection Name'               = $Schedule
                }
                }
} | Select-Object 'Hostname','MS Defender Last Connected','MS Defender Running','SCCM Client','Last Shutdown','Last Boot Time','OS Build','Client Activity','Is Client known?','Collection' 
## SCCM Client Inventory Report

## Patch deployment report  

$ResultsTable = (($Collections.Name) | foreach-object {
      Get-CMDeployment -CollectionName $_ | `
        Select-object ApplicationName,CollectionName,Deploymenttime, numberErrors,Numberinprogress,numbersuccess,numbertargeted,DeploymentID | `
            Where-Object {($_.Applicationname -match "Windows Updates*") -and ($_.Deploymenttime -ge (Get-Date).AddDays(-30) ) -and ($_.Applicationname -notlike "*EXTERNAL*")}}) | `
                ForEach-Object {
                New-Object -TypeName PSCustomObject -Property @{
                    'Deployment Name'  = $_.ApplicationName
                    'Collection Name'  = $_.CollectionName
                    'Deployment Time'  = $_.Deploymenttime
                    'Errors'           = $_.numberErrors
                    'In Progress'      = $_.Numberinprogress
                    'Succeeded'        = $_.numbersuccess
                    'Devices Targeted' = $_.numbertargeted
                    'Deployment ID'    = $_.DeploymentID
                    } | Select-Object -Property 'Deployment Name','Collection Name','Deployment Time','Errors','In Progress','Succeeded','Devices Targeted','Deployment ID'
                }
## Patch deployment report 

## Software Installed (Detailed) report
$DeploymentStatistics = Get-CMdeployment | `
    Where-Object {($_.Creationtime -ge (Get-Date).AddDays(-30)) -and ($_.SoftwareName -notmatch "EXTERNAL") -and (($_.Applicationname -match "Update")) } |`
    Select-Object NumberErrors,NumberInProgress,NumberOther,NumberSuccess,NumberTargeted,NumberUnknown,SoftwareName,DeploymentID,ApplicationName,AssignmentId

$DeployInfoFromCI = ($DeploymentStatistics.DeploymentID | Foreach-object {(Get-CMSoftwareUpdateDeployment -DeploymentId ($_)).assignedcis})| Select-Object -Unique |`
     ForEach-Object { 
        $CIinfo = Get-CMConfigurationItem -Fast -Id $_ 
        $CINumber = $_
        New-Object -TypeName PSCustomObject -Property @{
            #Category    = $CIinfo.LocalizedCategoryInstanceNames
            'Name'          = $CIinfo.LocalizedDisplayName
            'Description'   = $CIinfo.LocalizedDescription
            'Associated CI' = $CINumber
            'More Info'     = $CIinfo.LocalizedInformativeURL
            }
        } | Select-Object Name,Description,'Associated CI','More Info' 
## Software Installed (Detailed) report

## Error, inprogress, unknown device Report
$InProgressReports = ($DeploymentStatistics | Where-Object {($_.NumberInProgress -ge 1)} | foreach-object {
    $DeploymentID = $_.AssignmentID
    Get-WMIObject -ComputerName $Site_Server -Namespace root\sms\site_$SCCM_Site -class SMS_SUMDeploymentAssetDetails -Filter "AssignmentID = $DeploymentID"
    } | Select-Object -Property DeviceName,CollectionName,IsCompliant,LastEnforcementMessageDesc | Where-Object {($_.IsCompliant -ne 1) -and ($_.IsCompliant -ne $Null)}) |
        foreach-object {
            New-Object -TypeName PSCustomObject -Property @{
            'Name' = $_.DeviceName
            'Collection Name' = $_.CollectionName
            'Status'     = $_.LastEnforcementMessageDesc
            }
        } | Select-Object Name,'Collection Name',Status

$ErrorReports = ($DeploymentStatistics | Where-Object {($_.NumberErrors -ge 1)} | foreach-object {
    $DeploymentID = $_.AssignmentID
    Get-WMIObject -ComputerName $Site_Server -Namespace root\sms\site_$SCCM_Site -class SMS_SUMDeploymentAssetDetails -Filter "AssignmentID = $DeploymentID"
    } | Select-Object -Property DeviceName,CollectionName,IsCompliant,LastEnforcementMessageDesc | Where-Object {($_.IsCompliant -ne 1) -and ($_.IsCompliant -ne $Null)}) |
        foreach-object {
            New-Object -TypeName PSCustomObject -Property @{
            'Name' = $_.DeviceName
            'Collection Name' = $_.CollectionName
            'Status'     = $_.LastEnforcementMessageDesc
            }
        } | Select-Object Name,'Collection Name',Status


$UnknownReports = ($DeploymentStatistics | Where-Object {($_.NumberUnknown -ge 1)} | foreach-object {
    $DeploymentID = $_.AssignmentID
    Get-WMIObject -ComputerName $Site_Server -Namespace root\sms\site_$SCCM_Site -class SMS_SUMDeploymentAssetDetails -Filter "AssignmentID = $DeploymentID"
    } | Select-Object -Property DeviceName,CollectionName,IsCompliant,LastEnforcementMessageDesc | Where-Object {($_.IsCompliant -eq $Null)}) |
        foreach-object {
            New-Object -TypeName PSCustomObject -Property @{
            'Name' = $_.DeviceName
            'Collection Name' = $_.CollectionName
            'Status'     = 'Device Unknown'
            }
        } | Select-Object Name,'Collection Name',Status

## Error, inprogress, unknown device Report

### HTML Generation

$MonthYear = Get-Date -UFormat "%b %Y"
New-HTML -Name "Monthly Updates - $MonthYear" {
    New-HTMLTab -Name "Overview" {
        New-HTMLSection -HeaderText "Monthly Updates - $MonthYear - Consolidated Results" -CanCollapse {
            Table -DataTable $ResultsTable -Title "Monthly Updates - $MonthYear"
            }
        New-HtmlSection -HeaderText "Devices with Errors" -CanCollapse{
            Table -DataTable $ErrorReports -Title "Devices with Errors - $MonthYear"
            }
        New-HtmlSection -HeaderText "Devices with Uppdates in Progress" -CanCollapse{
            Table -DataTable $InProgressReports -Title "Devices with Uppdates in Progress - $MonthYear"
            }        
        New-HtmlSection -HeaderText "Unknown Devices" -CanCollapse{
            Table -DataTable $UnknownReports -Title "Unknown Devices - $MonthYear"
            }
        }
    New-HTMLTab -Name "Detailed Deployment Info" {
        New-HTMLSection -HeaderText "Software Deployed" -CanCollapse {
            Table -DataTable $DeployInfoFromCI -Title "Software Deployed"
            }
        New-HTMLSection -HeaderText "Visualizations" -CanCollapse {
            New-HTMLChart -Title 'Patching Results' -TitleAlignment center {
                New-ChartBarOptions -Type barStacked 
                New-ChartLegend -Name 'Errors', 'In Progress', 'Succeeded','Unknown' -Color Red, Yellow, Green, Black
                $ResultsTable| foreach-object {
                    New-ChartBar -Name $_.'Collection Name' -Value $_.Errors, $_.'In Progress', $_.Succeeded, ($_.'Devices Targeted'-($_.Errors+$_.'In Progress'+$_.Succeeded))
                }           
            }
        }
    }
    New-HTMLTab -Name "SCCM Inventory" {
        New-HTMLSection -HeaderText "SCCM Client Status" -CanCollapse {
            Table -DataTable $CollectionResults -Title "Inventory"
        }
    }
   } -FilePath $WebServerFilePath

