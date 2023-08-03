$Today = Get-Date -format "MMddyyyy"
Start-Transcript -Path "$PSScriptRoot\BeyondTrust-Jumpclient-Cleanup-$Today.log"

$AppId          = ""
$client_secret  = ""
$BeyondTrustURL = "https://yourtenantID.beyondtrustcloud.com"

$body = @{
    client_id     = $AppId
    client_secret = $client_secret
    grant_type    = "client_credentials"
}

try { 
    Write-Output "Getting BeyondTrust API Auth Token"
    $tokenRequest = Invoke-WebRequest -Method Post -Uri "$BeyondTrustURL/oauth2/token" -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing -ErrorAction Stop }
catch { Write-Output "Unable to obtain access token, moving on..."}

if ($tokenRequest){
    $token = ($tokenRequest.Content | ConvertFrom-Json).access_token

    $authHeader1 = @{
    'Content-Type'='application\json'
    'Authorization'="Bearer $token"
    }

    $URL=("$BeyondTrustURL/api/config/v1/jump-client")
    $RequestContent = (Invoke-WebRequest -Headers $AuthHeader1 -Uri $URL -Method GET).Content | ConvertFrom-Json
    $LostDevices    = $RequestContent | Where-Object {$_.is_Lost -match "true"} 
    $Uninstalled    = $RequestContent | Where-Object {$_.connection_type -match "uninstalled"}
    
    # Deduplicate
    Write-Output "Deduplication begin."
    $Uniques     = $RequestContent | Select-Object Name -Unique 
    $Duplicates  = Compare-Object -Property Name -ReferenceObject $RequestContent -DifferenceObject $Uniques -PassThru 
    $Deduplicate = foreach ($Duplicate in ($Duplicates.Name)){
        $DuplicateComputer = $RequestContent | Where-Object {$_.Name -match $Duplicate} 
        $DuplicateLatest   = $DuplicateComputer | Sort-Object -Property last_connect_timestamp | Select-Object -Last 1
        Compare-Object -Property Name -ReferenceObject $DuplicateLatest -DifferenceObject $DuplicateComputer -Passthru
    }
    If($Deduplicate){
        Write-Output ("Found "+$Deduplicate.count+" machines with duplicate entries.")
        $Deduplicate.Name
        foreach ($MachineID in ($Deduplicate.id)){
            Write-Output "Found machine ID $MachineID in the Jump Client list multiple times. Removing the oldest."
            Write-Output "Attempting to remove..."
            $DeleteURL=("$BeyondTrustURL/api/config/v1/jump-client/"+$MachineID)
            Write-Output $DeleteURL
            }
        }


    # Lost Devices
    Write-Output "Lost devices begin."
    If($LostDevices){
        Write-Output ("Found "+$LostDevices.count+" machines considered `"lost`".")
        $LostDevices.Name
        foreach ($MachineID in ($LostDevices.id)){
            Write-Output "Found machine ID $MachineID in the Jump Client list categorized as `"lost`"."
            Write-Output "Attempting to remove..."
            $DeleteURL=("$BeyondTrustURL/api/config/v1/jump-client/"+$MachineID)
            Write-Output $DeleteURL            
            }
        }
    # Uninstalled Devices
    Write-Output "Uninstalled devices begin."
    If($Uninstalled){
        Write-Output ("Found "+$Uninstalled.count+" machines considered `"uninstalled`".")
        $LostDevices.Name
        foreach ($MachineID in ($Uninstalled.id)){
            Write-Output "Found machine ID $MachineID in the Jump Client list categorized as `"uninstalled`"."
            Write-Output "Attempting to remove..."
            $DeleteURL=("$BeyondTrustURL/api/config/v1/jump-client/"+$MachineID)
            Write-Output $DeleteURL
                 }
        }
        }
        Else{
            Write-output "No token found"
            }
Stop-Transcript
