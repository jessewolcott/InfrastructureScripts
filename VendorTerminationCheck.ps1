# Vendor Monthly Termination Checks
# Keeping track of the vendors that support your business is tough. There are a lot of situations where, for whatever
# reason, IT is not alerted when a vendor no longer needs access. This is especially true in managed service 
# situations where one technician may have many vendors to notify when they separate. So, we can use this as a 
# scheduled task to send this every Monday, or the 1st of the month, or whatever you'd like. 

# Requirements:
#     - All variables in "Email Report Settings"
#     - One or more vendor groups in AD. Script assumes that one group is one email. The script pulls users, and does
#       not recurse
#

# Email Report Settings #
##↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓##
$CompanyName   = "Contoso, Inc"
$SmtpServer    = "YourSMTPRelay"
$From          = "Vendor Checks <vendorchecks@contoso.com>"
$CC            = "sysadmins@contoso.com"
$HelpdeskEmail = "helpdesk@contoso.com"
##↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑##
# Email Report Settings #

#  Specify Groups Here  #
##↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓##
$VendorGroups = @(
"Vendor Group - Fabrikam"
"Vendor Group - Other Company"
)
##↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑##
#  Specify Groups Here  #


## Module Check / install
<#
Install-Module -Name Mailozaurr -Force
Install-Module -Name PSWriteHTML -Force
$osInfo = (Get-CimInstance -ClassName Win32_OperatingSystem).ProductType
switch ($osInfo){
    1 
        {Install-Module -Name ActiveDirectory -Force}
    {($_ -eq "2") -or ($_ -eq "3")} 
        {Install-WindowsFeature RSAT-AD-PowerShell | Out-Null}
    }
#>
## Module Check / install
$Today = (Get-Date -format MM-dd-yyyy)
Start-Transcript -Path "$PSScriptRoot\Vendor-Termination-Check-$Today.txt"

Write-Output "Script started"
Write-Output "Today is $Today"

foreach ($VendorGroup in $VendorGroups){
    Write-Output "Starting process for $VendorGroup"
    Write-Output "Creating array for results"
    $cachedcombinedobject = @()

    Write-Output "Get Active Directory Group Members"
    $ADGroupInfo = (Get-ADGroup -Identity $VendorGroup -Properties * -ErrorAction SilentlyContinue)
    Write-Output "Poll AD for more information about the group members"
    $GroupMemberTemp = $ADGroupInfo | Get-ADGroupMember | Where-object {$_.objectClass -like 'user'} | Select-Object -ExpandProperty SAmaccountName                                      # select SamAccountnames 

    Write-Output "Getting info about each member and adding to report"
    foreach ($GroupMember in $GroupMemberTemp) { 
        
        Write-Output "$GroupMember - Pulling name, account and email"
        $GroupMemberInfo = Get-ADUser -Identity $GroupMember -Properties Name,SamAccountName,EmailAddress
        Write-Output "$GroupMember - Calculating last login"
        $LastLogin = (Get-ADUser -Identity $GroupMember -Properties LastLogon | Select Name, @{Name='LastLogon';Expression={[DateTime]::FromFileTime($_.LastLogon)}}).LastLogon
   

        Write-Output "$GroupMember - Adding results from $GroupMember to report"
        $cachedcombinedobject += [PSCustomObject]@{
            'Name'           = $GroupMemberInfo.Name
            'Logon Name'     = $GroupMemberInfo.SamAccountName
            'Email Address'  = $GroupMemberInfo.EmailAddress
            'Last Logon'     = $LastLogin
        }
        }

    # Email Extraction from "Notes" in the group's AD Record.
    Write-Output "Setting email extraction regex"
    $regex = "[a-z0-9!#\$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#\$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?"
    Write-Output "Creating list for email extraction"
    $ApproverEmail = [System.Collections.Generic.List[string]]::new()
    Write-Output "Get 'info' from group's Active Directory Object"
    ($ADGroupInfo | Select-Object -ExpandProperty info) -match $regex | Out-null
    Write-Output "Checking to see if 'info' has an email address in it"
    if ($null -ne $Matches){
        Write-Output "Found an email"
        $ApproverEmail.Add($Matches.Values)
        Write-Output "We will send this approval to $ApproverEmail"
        }
        Else { Write-Output "We did not find an email address. Please update the Group in Active Directory and run this script again. Exiting."
        break}

    $Body = EmailBody -FontFamily 'Calibri' -Size 15 {
                EmailText -Text 'Greetings from ', $CompanyName,'!' -LineBreak
                EmailText -Text 'Each month, ',$CompanyName,' performs an access check to verify that all users granted access have not been terminated, and do not need their access adjusted. You have been identified as the approver for ', $vendorGroup,'.' -LineBreak
                EmailText -Text 'Please review the following users that have access currently. If any of the listed users no longer in need of our resources, contact the Helpdesk by email at ',$HelpdeskEmail,'.' -LineBreak
                EmailText -Text 'This mailbox does not accept replies, and is not monitored.' -fontweight Bold
                EmailTable -DataTable $cachedcombinedobject
                EmailText -Text 'Kind regards,'
                EmailText -Text 'The ', $CompanyName,' IAM team'
                }

    $Subject = ("Vendor Access Check - $VendorGroup - $Today")
    $EmailHTMLSettings = @{ 
        To         = $ApproverEmail
        CC         = $CC
        Body       = $Body
        Subject    = $Subject  
        SmtpServer = $SmtpServer
        From       = $From
        BodyAsHTML = $true
        }  

    Send-MailMessage @EmailHTMLSettings 

    # Cleanup
    $cachedcombinedobject = $null
    Remove-Variable -Name cachedcombinedobject

}

Stop-Transcript
