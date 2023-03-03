$Product     = 'PROJECTPROFESSIONAL'

# Set this to $true or $false to test
$WhatIfPreference = $false
$ErrorActionPreference = "Continue"

# Module Check
# install-module Microsoft.Graph
# install-module Microsoft.Graph.Users
# install-module Microsoft.Graph.User.Actions
# install-module ActiveDirectory

$Today = (Get-Date -format MMddyyyy-HH-mm-ss)
Start-Transcript -Path "$PSScriptroot\RemoveAllUsersfromSKU-$Product-$Today.txt"

# Connect to Graph
Connect-Graph -Scopes User.ReadWrite.All, Organization.Read.All

# Get SKU from SKUPartNumber
[String]$SKUID = @((Get-MgSubscribedSku -All | Where-Object SkuPartNumber -eq $Product).SkuId)

# Who is assigned that license already? Fail if nothing was found in the previous step (and $SKUID is null)
if ($null -ne $SKUID){
    $Licensees = (Get-MgUser -Filter "assignedLicenses/any(x:x/skuId eq $SKUID )" -ConsistencyLevel eventual -CountVariable licensedUserCount -All).UserPrincipalName
    }
    Else {
        Write-Output "SKU ID is blank. Did you enter the right SKUPartNumber? Opening your current licenses. Enter a valid SkuPartNumber and rerun this script"
        Get-MgSubscribedSku -All | Select-Object -Property SkuPartNumber,SkuId,ConsumedUnits,CapabilityStatus,AppliesTo | Out-GridView
        Stop-Transcript -ErrorAction SilentlyContinue
        break
        }

Write-Output "Found $licensedUserCount users"

# If there are licensees, add to the group and remove the license
if (($Licensees.count) -ge 1){
    Foreach ($Licensee in $Licensees){
        Write-Output "Removing direct license from $Licensee"
        Set-MgUserLicense -UserId $Licensee -RemoveLicenses $SKUID -AddLicenses @() -Confirm:$false -ErrorAction SilentlyContinue
    }
}
    Else {
        Write-Output "No users are presently licensed" 
           }
Stop-Transcript -ErrorAction SilentlyContinue
