
$Full_OU_Paths = @(
"contoso.com/Servers"
"fabrikam.net/Servers"
)

$OU_Paths = foreach ($Full_OU_Path in $Full_OU_Paths)
{Get-ADOrganizationalUnit -Filter * -Properties CanonicalName,Name,DistinguishedName | Where-Object -FilterScript {$_.CanonicalName -like "*$Full_OU_Path"} | Select-Object -ExpandProperty DistinguishedName}

$Servers = foreach ($OU_Path in $OU_Paths){
    ((Get-ADComputer -Filter "OperatingSystem -Like '*Windows Server*' -and Enabled -eq 'True' -and objectClass -eq 'computer'" `
     -SearchBase $OU_Path -SearchScope Subtree `
     -Properties DNSHostName,Name,Enabled,ObjectClass)| Select-Object -ExpandProperty DNSHostName)
    }

$Results = foreach ($Server in $Servers) {
    
# Resolve DNS name to IP address. This doesn't work if ICMP is blocked.

        If ((Test-Connection -ComputerName $Server -Count 1 -Quiet)) {
            $IPAddress = (Resolve-DnsName -Name $Server | where {$_.Type -eq "A"}).IPAddress
                                                                     }
            Else { $IPAddress = "Not Reachable"}

# Get windows Version from remote WMI

$OSCheck = Invoke-Command -ComputerName $Server -ScriptBlock {(Get-WMIObject win32_operatingsystem).Name}

# Error checking. Since we are filtering by OS version from AD, this will only report the version of the OS if it can reach it.
if ($OSCheck -imatch "Microsoft*") {$OSVersion = $OSCheck}
    else {$OSVersion = "No OS Found"}

# Get dotnet version from the remote registry

    $Version = Invoke-Command -ComputerName $Server -ScriptBlock {
    (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Release
    } -ErrorAction SilentlyContinue

# Translation table for the build numbers 

    Switch ($Version) {
        533325 {$VersionDecode = '.NET Framework 4.8.1'}
        528449 {$VersionDecode = '.NET Framework 4.8 - Windows 11 and Windows Server 2022'}
        528372 {$VersionDecode = '.NET Framework 4.8 - Windows 10 May 2020 Update and Windows 10 October 2020 Update and Windows 10 May 2021 Update'}
        528040 {$VersionDecode = '.NET Framework 4.8 - Windows 10 May 2019 Update and Windows 10 November 2019 Update'}
        528049 {$VersionDecode = '.NET Framework 4.8'}
        461814 {$VersionDecode = '.NET Framework 4.7.03062 - Windows 10 October 2018 Update'}
        461808 {$VersionDecode = '.NET Framework 4.7.2 - Windows 10 April 2018 Update and Windows Server, version 1803'}
        461308 {$VersionDecode = '.NET Framework 4.7.1 - Windows 10 Creators Update and Windows Server, version 1709'}
        461310 {$VersionDecode = '.NET Framework 4.7.1'}
        460798 {$VersionDecode = '.NET Framework 4.7 - Windows 10 Creators Update'}
        460805 {$VersionDecode = '.NET Framework 4.7'}
        394802 {$VersionDecode = '.NET Framework 4.6.2 - Windows 10 Anniversary Update and Windows Server 2016'}
        394806 {$VersionDecode = '.NET Framework 4.6.2'}
        394254 {$VersionDecode = '.NET Framework 4.6.1 - Windows 10 November Update'}
        394271 {$VersionDecode = '.NET Framework 4.6.1'}
        393295 {$VersionDecode = '.NET Framework 4.6 - Windows 10'}
        393297 {$VersionDecode = '.NET Framework 4.6'}
        379893 {$VersionDecode = '.NET Framework 4.5.2'}
        378675 {$VersionDecode = '.NET Framework 4.5.1'}
        378389 {$VersionDecode = '.NET Framework 4.5'}
        default {$VersionDecode = "1"}
        }

# Decode the build number into something useful

    if ($VersionDecode -ne "1"){
                if ($Version -is [int])    {
                    $dotNetVersion = $VersionDecode
                    $Build = $Version
                                           }
                    Else {
                            $dotNetVersion = "No Version Found"
                            $Build = "None"
                         }
                                   
# create the report's object                            
                                               
    New-Object -Type PSCustomObject -Property @{
                "Server Name"     = $Server
                Version           = $dotNetVersion
                Build             = $Build
                "IP Address"      = $IPAddress 
                "Operating System"= $OSVersion } | Select-object "Server Name",Version,Build,"IP Address", "Operating System"                       
                        

# Clear the variables for the next loop
                        $OSVersion = $null
                        $Build = $null
                        $Version = $null
                        $VersionDecode = $null

}}


$Results | Out-GridView
