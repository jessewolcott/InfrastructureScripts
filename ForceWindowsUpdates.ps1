$UpdateLabel = "July2023"
Start-Transcript -Path ("C:\Program Files\_MEM\Updates\"+$UpdateLabel+"-Update.txt")

$Providers = Get-PackageProvider
$Repositories = Get-PSRepository

If ($Providers.name -notcontains 'NuGet'){
    Write-Output "Installing NuGet."
    Install-PackageProvider NuGet -Force
    Import-PackageProvider NuGet -Force
    }
    Else {Write-Output "NuGet provider found."}

If ($Repositories.name -notcontains 'PSGallery'){
    Write-Output "Adding PSGallery to Repositories"
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
    Else {Write-Output "PSGallery is already added as a repository."}

$InstallationPolicy = ($Repositories | Where-Object {$_.Name -eq 'PSGallery'}).InstallationPolicy

If ($InstallationPolicy -ne 'Trusted'){
    Write-Output "Adding PSGallery to trusted Repositories."
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
    Else {Write-Output "PSGallery is already trusted as a repository."}

$ModuleInfo = Get-Module PSWindowsUpdate -ErrorAction SilentlyContinue
$ModuleInfoFromPSGallery = Find-Module -Name "PSWindowsUpdate"

If ($null -eq $ModuleInfo){
    Write-Output "Installing PSWindowsUpdate."
    Install-Module -Name PSWindowsUpdate
    }
    Elseif ($ModuleInfo.Version -lt $ModuleInfoFromPSGallery.Version){
        "Found a newer version of PSWindowsUpdate. Updating."
        Update-Module -Name PSWindowsUpdate
        }

Write-Output "Running Windows Update. Computer will restart after transcript stops."

Get-WindowsUpdate –AcceptAll -Verbose

Stop-Transcript

Restart-Computer -Force

