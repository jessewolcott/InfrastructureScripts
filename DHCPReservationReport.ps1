$DomainDHCP = 'Yes'

$DHCPServerArray = @()

if ($DomainDHCP -eq 'Yes'){
    $DomainName = (Get-ADDomain).forest
    $DHCPServers = (Get-DHCPServerinDC).DNSName
    }
    Else {
        $DomainName = "Local"
        $DHCPServers = $DHCPServerArray
        }

$Results = foreach ($DHCPServer in $DHCPServers){
            if (Test-Connection -ComputerName $DHCPServer -count 1 -Quiet){
                $DHCPServerInfo = Get-DHCPServerv4Scope -ComputerName $DHCPServer
                foreach ($Scope in ($DHCPServerInfo.ScopeId)){
                    Get-DhcpServerv4Reservation -ComputerName $DHCPServer -ScopeId $Scope
                }
            }
        }
$Results | Out-GridView -Title "DHCP Reservations-$DomainName" -ErrorAction SilentlyContinue
  
