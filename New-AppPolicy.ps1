#install-module ExchangeOnlineManagement
$AzureAdmin         = "" # Azure Admin user
$EnterpriseAppID    = "" # AppId or Client ID for App
$EnterpriseAppGroup = "" # Mail-enabled security group used to limit access

# What address should we test?
$TestMailbox = "bgates@contoso.com"

$CreatePolicy = 'Yes'
$RemovePolicy = 'No'
$TestPolicy   = 'Yes'

if ($null -eq (Get-ConnectionInformation)){
    Write-Output "Exchange Online not connected. Attempting connection with $AzureAdmin"
    Connect-ExchangeOnline -UserPrincipalName $AzureAdmin
    }


$ExchangeParams = @{
    AppId               = $EnterpriseAppID
    PolicyScopeGroupId  = $EnterpriseAppGroup
    AccessRight         = "RestrictAccess"
    Description         = "Restrict this app to members of distribution group $EnterpriseAppGroup"
    }

if ($CreatePolicy -eq 'Yes'){New-ApplicationAccessPolicy @ExchangeParams}
if ($RemovePolicy -eq 'Yes'){Get-ApplicationAccessPolicy | where-object {$_.AppId -eq $EnterpriseAppID} | Remove-ApplicationAccessPolicy}

if ($TestPolicy -eq 'Yes'){
    Write-Output "Testing policy"
    $TestResult = (Test-ApplicationAccessPolicy -AppId $EnterpriseAppID -Identity $TestMailbox -ErrorAction SilentlyContinue).AccessCheckResult
    switch ($TestResult){
        "Granted" {Write-Output "$Testmailbox is readable by $EnterpriseAppID"}
        "Denied" {Write-Output "$Testmailbox is NOT readable by $EnterpriseAppID"}
        default {Write-Output "$Testmailbox was not found in Exchange"}
    }
}
