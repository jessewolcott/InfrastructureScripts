$Product     = 'PROJECTPROFESSIONAL'
$DomainGroup = 'M365 Project License Assignees'
$DomainGroupOU = "contoso.com/Groups/LicenseGroups"

# Set this to $true or $false to test
$WhatIfPreference = $false
$ErrorActionPreference = "Continue"

# Module Check
# install-module Microsoft.Graph
# install-module Microsoft.Graph.Users
# install-module Microsoft.Graph.User.Actions
# install-module ActiveDirectory

$Today = (Get-Date -format MMddyyyy-HH-mm-ss)
Start-Transcript -Path "$PSScriptroot\MoveDirectLicenseToAD-$Product-$Today.txt"

# Connect to Graph
Connect-Graph -Scopes User.ReadWrite.All, Organization.Read.All

# Get SKU from SKUPartNumber
[String]$SKUID = @((Get-MgSubscribedSku -All | Where-Object SkuPartNumber -eq $Product).SkuId)

# Who is assigned that license already? Fail if nothing was found in the previous step (and $SKUID is null)
if ($null -ne $SKUID){
    $Licensees = (Get-MgUser -Filter "assignedLicenses/any(x:x/skuId eq $SKUID )" -ConsistencyLevel eventual -CountVariable licensedUserCount -Select UserPrincipalName).UserPrincipalName
    }
    Else {
        Write-Output "SKU ID is blank. Did you enter the right SKUPartNumber? Opening your current licenses. Enter a valid SkuPartNumber and rerun this script"
        Get-MgSubscribedSku -All | Select-Object -Property SkuPartNumber,SkuId,ConsumedUnits,CapabilityStatus,AppliesTo | Out-GridView
        Stop-Transcript -ErrorAction SilentlyContinue
        break
        }

# Check if Domain Group Exists
if ($null -ne (Get-ADGroup -filter "Name -eq '$($DomainGroup)'")){
    Write-Output "AD Group found - $DomainGroup"
    }
    Else {
            $Decision = $Host.UI.PromptForChoice("Confirmation", "No AD group was found. If you continue, licenses will be removed but no users will be added to a group. Are you sure? You can also attempt to create the group.", ('&Yes', '&No', '&Create'), 1)
            Switch ($Decision){
                0 {Write-Output "Confirmed that licenses will be removed and group not altered" ; continue}
                1 {Write-Output "Process terminated" ; Stop-Transcript -ErrorAction SilentlyContinue ; break}
                2 {
                    Write-Output "Trying to create group"  
                    $OU_Path = (Get-ADOrganizationalUnit -Filter * -Properties CanonicalName,Name,DistinguishedName | Where-Object -FilterScript {$_.CanonicalName -like "*$DomainGroupOU"} | Select-Object -ExpandProperty DistinguishedName)
                    New-ADGroup -Name $DomainGroup -GroupCategory Security -GroupScope Global -Path $OU_Path -Description "Microsoft Licensing Group for $Product"                    
                    continue}
            }            
        }


# If there are licensees, add to the group and remove the license
if (($Licensees.count) -ge 1){
    Foreach ($Licensee in $Licensees){
            if ($null -ne $DomainGroup) {
                Write-Output "Adding $Licensee to $DomainGroup"
                Add-ADGroupMember -Identity $DomainGroup -Members ((Get-Aduser -filter "UserPrincipalName -eq '$($Licensee)'").SAMaccountname) -Verbose 
                }
        Write-Output "Removing direct license from $Licensee"
        Set-MgUserLicense -UserId $Licensee -RemoveLicenses $SKUID -AddLicenses @() -Confirm:$false 
    }
}
    Else {
        Write-Output "No users are presently licensed" 
           }
Stop-Transcript -ErrorAction SilentlyContinue
