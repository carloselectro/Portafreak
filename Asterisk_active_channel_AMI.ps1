# Script to get active channels in Asterisk via AMI
# version 1.0
# Auteur : Carl Fortin
# Date 16 september 2020


param(
    [Parameter(mandatory = $true)][string]$asterisk_ip,
    [Parameter(mandatory = $true)]$Port,
    [Parameter(mandatory = $true)][string]$external_context,
    [Parameter(mandatory = $true)][string]$ami_user,
    [Parameter(mandatory = $true)][string]$ami_pass

)

# Login info for Asterisk AMI
$login_info = @"
Action: Login`r`n 
ActionID: 1`r`n 
Username: $ami_user`r`n 
Secret: $ami_pass`r`n
"@

# This function will get the caller ID from an endpoint
function get_endpoint_caller_ID {

    param
    (
        [Parameter(mandatory = $true)][string]$ENDPOINT,
        [Parameter(mandatory = $true)]$writer,
        [Parameter(mandatory = $true)]$reader
    )

    $writer.WriteLine("Action: PJSIPShowEndpoint") | Out-Null
    $writer.WriteLine("ActionID: 1") | Out-Null
    $writer.WriteLine("Endpoint: $ENDPOINT") | Out-Null
    $writer.WriteLine("") | Out-Null
    
    while (-not($reader.EndOfStream)) {
        try {

            $buffer += $reader.ReadLine() + "`r`n"
            if ($buffer.Contains("EventList: Complete")) {
                break
            }
        }
        catch {

            Write-Host("Error getting info from Asterisk: $ErrorMessage" ) -ForegroundColor red

        }
    }
    # Remove emptyline
    $buffer = ($buffer -replace "(?m)(?s)`r`n\s*$", '').trim()
 
    # Regex to extract endpoints info
    $Regex = "(?ms)ObjectType: endpoint[\r|\n]+(.*)[\r|\n]{1}Event: EndpointDetailComplete"

    $Match = ($buffer -match $Regex)
    if ($Match) {
        $result = $Matches[1]
        #Write-Host("Match found!")
    }
    else {
        Write-host("No match found for caller ID!") -ForegroundColor Red
    }


    # Convert to custom object
    $obj = ($result | ConvertFrom-String -Delimiter  "`n|`r`n" )

    $endpoint_details = [PSCustomObject]@{
        Callerid     = ($obj | Select-Object -ExpandProperty "P65" ).ToString().Split(':')[1].Trim(' ')
        EndpointName = ($obj | Select-Object -ExpandProperty "P188" ).ToString().Split(':')[1].Trim(' ')
        Contacts     = ($obj | Select-Object -ExpandProperty "P181" ).ToString().Split(':')[1].Trim(' ')
    }
    return $endpoint_details.Callerid

}


try {

    $tcpConnection = New-Object System.Net.Sockets.TcpClient($asterisk_ip, $Port)
}
catch {

    Write-Host("Cannot conect to Asterisk with IP:$asterisk_ip and port:$Port" ) -ForegroundColor red
    Exit
}

$tcpConnection.ReceiveTimeout = 5000;

$tcpStream = $tcpConnection.GetStream()
$reader = New-Object System.IO.StreamReader($tcpStream)
$writer = New-Object System.IO.StreamWriter($tcpStream)
$writer.AutoFlush = $true

$buffer = New-Object System.Byte[] 4096

if ($tcpConnection.Connected) {
    $writer.WriteLine($login_info) | Out-Null
    Write-Host("Connection to Asterisk OK!") -ForegroundColor Green
    Start-Sleep(1)
    
   
    $writer.WriteLine("Action: CoreShowChannels") | Out-Null
    $writer.WriteLine("") | Out-Null
    while (-not($reader.EndOfStream)) {
        try {

            $buffer += $reader.ReadLine()
            if ($buffer.Contains("EventList: Complete")) {
                
                break
            }
        }
        catch {

            Write-Host("Error getting info from Asterisk: $ErrorMessage" ) -ForegroundColor red

        }
    }

}

# Convert object to String
$data = ($buffer  | Out-String )

# Regex to extract channels info
$Regex = "(?ms)Message: Channels will follow[\r|\n]+(.*)[\r|\n]{1}Event: CoreShowChannelsComplete"

$Match = ($data -match $Regex)
if ($Match) {
    $result = $Matches[1]
    #Write-Host("Match found!")
}
else {
    Write-host("No match found!") -ForegroundColor Red
}

#$result | Out-File "C:\Active_Chan.txt"
$ACTIVE_CHANNEL_LIST = $null
# Array to add our channels info
[System.Collections.ArrayList]$ACTIVE_CHANNEL_LIST = @()

# Replace crlf betwen channel info by an exclamation point
[string]$temp = ($result -replace '(?ms)[\r|\n|\r\n]{2}^[\r|\n|\r\n]', '!')

# Convert to custom object
$obj = ($temp | ConvertFrom-String -Delimiter  "!" )


#If object returns nothing, there is no active channel
if ([string]::IsNullOrEmpty($obj)) {
    Write-Host("No active calls found!") -ForegroundColor Yellow
    exit
}

ForEach ($noteProperty in $obj.PSObject.Properties) {
    if ([string]::IsNullOrEmpty($noteProperty.Value)) {
        
        #Write-Host("Empty value : " + $noteProperty.Name)
    }
    else {
        $endpoint_channel_info = ($noteProperty.Value | ConvertFrom-String -Delimiter  "\r\n" )
        try {
            # App data is trickier to extract ...
            $ApplicationDatatmp = ($endpoint_channel_info | Select-Object -ExpandProperty "P17" ).ToString()
            $Appdata = ([regex]::split($ApplicationDatatmp, '(:\s)'))[2]

            $endpoint_obj = [PSCustomObject]@{
                Channel          = ($endpoint_channel_info | Select-Object -ExpandProperty "P2" ).ToString().Split(':')[1].Trim(' ')
                CallerIDNum      = ($endpoint_channel_info | Select-Object -ExpandProperty "P5" ).ToString().Split(':')[1].Trim(' ')
                CallerIDName     = ($endpoint_channel_info | Select-Object -ExpandProperty "P6" ).ToString().Split(':')[1].Trim(' ')
                ConnectedLineNum = ($endpoint_channel_info | Select-Object -ExpandProperty "P7" ).ToString().Split(':')[1].Trim(' ')
                Context          = ($endpoint_channel_info | Select-Object -ExpandProperty "P11" ).ToString().Split(':')[1].Trim(' ')
                Application      = ($endpoint_channel_info | Select-Object -ExpandProperty "P16" ).ToString().Split(':')[1].Trim(' ')
                ApplicationData  = $Appdata
                Duration         = ($endpoint_channel_info | Select-Object -ExpandProperty "P18" ).ToString().Split(' ')[1].Trim(' ')
                BridgeId         = ($endpoint_channel_info | Select-Object -ExpandProperty "P19" ).ToString().Split(':')[1].Trim(' ')
    
            }
            # Add our channels to our array list
            $ACTIVE_CHANNEL_LIST.Add( $endpoint_obj) | Out-Null

        }
        catch {
            Write-Host("Error adding channel info : $ErrorMessage" ) -ForegroundColor red
        }
        
  
    }
}
$PRETTY_ACTIVE_CHANNEL_LIST = $null
# Array to add our channels info readable by human
[System.Collections.ArrayList]$PRETTY_ACTIVE_CHANNEL_LIST = @()

ForEach ($channel in $ACTIVE_CHANNEL_LIST) {
    $endpoint_connected = $null
    $endpoint_connected = ($ACTIVE_CHANNEL_LIST |  Where-Object { $_.BridgeId -eq $channel.BridgeId -and $channel.BridgeId -ne "" })
   
    # Check if Bridge info already added to our list
    If (($PRETTY_ACTIVE_CHANNEL_LIST | Where-Object { $_.BridgeId -eq $channel.BridgeId } | Select-Object -ExpandProperty BridgeId) -ne $channel.BridgeId ) {

        if ($endpoint_connected) {
            Write-Host("User " + $endpoint_connected[0].CallerIDName + " talking with " + $endpoint_connected[1].CallerIDName + " ...")
            $Caller_Channel_data = $endpoint_connected |  Where-Object { $_.ApplicationData -ne "(Outgoing Line)" } | Select-Object -ExpandProperty Channel
            $Caller_Name = $endpoint_connected |  Where-Object { $_.ApplicationData -ne "(Outgoing Line)" } | Select-Object -ExpandProperty CallerIDName
            $Caller_number = $endpoint_connected |  Where-Object { $_.ApplicationData -ne "(Outgoing Line)" } | Select-Object -ExpandProperty CallerIDNum
           

            # Callee info will be the (Outgoing Line)
            $Callee_Channel_data = $endpoint_connected |  Where-Object { $_.ApplicationData -eq "(Outgoing Line)" } | Select-Object -ExpandProperty Channel
            $Callee_Name = $endpoint_connected |  Where-Object { $_.ApplicationData -eq "(Outgoing Line)" } | Select-Object -ExpandProperty CallerIDName
            $Callee_number = $endpoint_connected |  Where-Object { $_.ApplicationData -eq "(Outgoing Line)" } | Select-Object -ExpandProperty CallerIDNum

            
            $Context_data = $endpoint_connected |  Where-Object { $_.ApplicationData -eq "(Outgoing Line)" } | Select-Object -ExpandProperty Context
            $Application_data = $endpoint_connected |  Where-Object { $_.ApplicationData -ne "(Outgoing Line)" } | Select-Object -ExpandProperty ApplicationData
            $Channel_data = $channel.BridgeId
            # If the user dialed outside get the callerid of user otherwise it's an internal call
            If ($Context_data -eq $external_context) {
               
                # Get the endpoint name by extracting from caller channel name
                $found = $Caller_Channel_data -match '(?<=PJSIP\/).*(?=-)'
                if ($found) {
                    $Endpoint = $Matches[0]
                }
                else {
                    Write-Host("No match found for channel name when getting calleid")
                    $Endpoint = "Unknown"
                }
                $Caller_Name_data = (get_endpoint_caller_ID -ENDPOINT $Endpoint -writer $writer -reader $reader)


                # Get the dialed number by extracting from applicationdata
                $found = $Application_data -match '(?<=PJSIP\/).*(?=@)'
                if ($found) {
                    $called_number = $Matches[0]
                     # Format number for nicer display
                    If ($called_number.Length -eq 10) {
                        $Callee_Name_data = ("{0:(###) ###-####}" -f [int64]($called_number))
                    }
                    elseIf ($called_number.Length -eq 11) {
                        $Callee_Name_data = ("{0:# (###) ###-####}" -f [int64]($called_number))
                    }
                    else {
                        $Callee_Name_data = $called_number
                    }
                }
                else {
                    Write-Host("No match found for dialed number for : " + $channel.ApplicationData)
                    $Callee_Name_data = "Unknown"
                }
               

            }
            else {

                $Caller_Name_data = "$Caller_Name $Caller_number"
                $Callee_Name_data = "$Callee_Name $Callee_number"
            }

        }
        # Users not bridged
        else {


            $Caller_Channel_data = $channel.Channel
            $Caller_Name_data = $channel.CallerIDName + " " + $channel.CallerIDNum
            $Channel_data = $channel.BridgeId
            $Application_data = $channel.ApplicationData
            $Context_data = $channel.Context
            $Callee_Name_data = ""
            $Callee_Channel_data = ""
            Write-Host("User " + $channel.CallerIDName + " not connected with anyone ...")
        }

        #Write-Host($channel.CallerIDName)
        $out_grid_title_obj = [PSCustomObject]@{
            "Source Channel"      = $Caller_Channel_data
            "Source Name"         = $Caller_Name_data
            Direction           = "------>"
            "Destination Name"    = $Callee_Name_data
            "Destination Channel" = $Callee_Channel_data
            Context             = $Context_data
            Application         = $channel.Application
            Duration            = $channel.Duration
            ApplicationData     = $Application_data
            BridgeId            = $Channel_data
        }

        $PRETTY_ACTIVE_CHANNEL_LIST.Add($out_grid_title_obj) | Out-Null
    }
    else {

        #Write-Host("BridgeID already added!")
    }
}

# Disconnect from AMI
$writer.WriteLine("Action: Logoff`r`n") | Out-Null
$writer.Dispose()
$reader.Dispose()

$PRETTY_ACTIVE_CHANNEL_LIST | out-gridview 
