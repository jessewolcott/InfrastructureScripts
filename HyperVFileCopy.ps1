# Install the Hyper-V PowerShell module
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell
Start-Transcript -Path "$PSScriptRoot\logs\FileCopy-$Today.txt

$Today = (Get-Date -format MMddyyyy-HH-mm-ss)



$Destination = "C:\Temp"
$TargetVM = "TargetVMName"
$HyperVHost = "hyper-v.contoso.com"
$HyperVHostShare = "\\$HyperVHost\C`$\Temp"
$SourceFileDirectory = "$PSScriptRoot\Source"

# Search Directory for files and load up an object

$FilestoCopy = @((Get-ChildItem -Path $SourceFileDirectory -Recurse).Name)

# Check to see if the temp dir on the vm host exists

if ((Test-Path $HyperVHostShare -PathType Container) -eq $false) {
    Write-Host "No temp directory found on Hyper V Host. Creating one now"
    New-Item -Path $HyperVHostShare -ItemType Directory | Out-Null
    }
    Else { Write-Host "Temp directory found on Hyper V Host." }

# Check for Hyper V tools

While ((Get-VM -ComputerName $HyperVHost -Name $TargetVM | Get-VMIntegrationService -Name "Guest Service Interface" | Select VMName, Enabled).Enabled -ne $true){

    Get-VM $HyperVHost | Get-VMIntegrationService -Name "Guest Service Interface" | Enable-VMIntegrationService


    }

# Copy files from third machine to the hyperv host

Foreach ($Filetocopy in $FilestoCopy){
    Copy-Item -Path $SourceFileDirectory\$Filetocopy -Destination "$HyperVHostShare\" -Verbose -force
    Copy-VMFile -ComputerName $HyperVHost -DestinationPath $Destination -Name $TargetVM -SourcePath "C:\Temp\$Filetocopy" -FileSource Host -Verbose

    }

Stop-Transcript
