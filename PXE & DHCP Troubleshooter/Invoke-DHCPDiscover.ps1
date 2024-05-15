
<#
.Synopsis
   DHCP Discover Script
.DESCRIPTION
   A script to send a DHCPDISCOVER request and report on DHCPOFFER responses 
   returned by all DHCP and ProxyDHCP (PXE) servers.
.NOTE
   Will also run through *ALL* Major vendor types. PXE,HTTP,x86,x64,arm & arm64
   Adapted from: 
      https://github.com/2pintsoftware/2Pint-iPXEAnywhere
   Adapted from: 
      http://www.indented.co.uk/2010/02/17/dhcp-discovery
   DHCP Packet Format (RFC 2131) :
      http://www.ietf.org/rfc/rfc2131.txt
#>

[CmdletBinding()]
param(
    $Timeout = 5
)

function New-DhcpDiscoverPacket {
    <#
        Build a DHCPDiscover packet to send
    #>
    param(
        [string]$MacAddressString = 'AA:BB:CC:DD:EE:FF',
        [string]$UUIDString = "AABBCCDD-AABB-AABB-AABB-AABBCCDDEEFF",
        [byte]$ProcessorArchitecture,
        [string]$Option60String,
        [int32]$SecondsElapsed = 0
    )

    write-verbose "Create Discover Packet MAC: $MacAddressString  UUID: $UUIDString  Option60: $Option60String"

    # Create the Byte Array
    $DhcpDiscover = New-Object Byte[] 240

    # Convert the MAC Address String into a Byte Array and copy to Discover Packet
    $MacAddressString = $MacAddressString -replace "-|:"           # drop extra characters 
    $MacAddress = [BitConverter]::GetBytes(([uint64]::Parse($MacAddressString,[Globalization.NumberStyles]::HexNumber)))
    [array]::Reverse($MacAddress)
    # Copy the MacAddress Bytes into the array (drop the first 2 bytes, too many bytes returned from UInt64)
    [array]::Copy($MACAddress,2,$DhcpDiscover,28,6)

    # Generate a Transaction ID (random) for this request, and copy to Discover Packet
    $XID = New-Object Byte[] 4
    [random]::new().nextBytes($xid)
    [array]::Copy($XID,0,$DhcpDiscover,4,4)

    $DhcpDiscover[0] = 1       # BOOTREQUEST 
    $DhcpDiscover[1] = 1       # Address Type to Ethernet
    $DhcpDiscover[2] = 6       # Hardware Address Length (number of bytes)
    $DhcpDiscover[3] = 0       # HOPS
    $DhcpDiscover[9] = $SecondsElapsed
    $DhcpDiscover[10] = 128    # Broadcast Flag
    
    $DhcpDiscover[236] = 99    # Magic Cookie values
    $DhcpDiscover[237] = 130
    $DhcpDiscover[238] = 83
    $DhcpDiscover[239] = 99

    # Set Option #53
    $DhcpDiscover += ( [byte] 53,1,1 )

    # Set Option #57
    $DhcpDiscover += ( [byte] 57,2,5,192 )

    # Set Option #60
    $Option60Array = [System.Text.Encoding]::ASCII.GetBytes($Option60String)
    $DhcpDiscover += ( [byte] 60, $Option60Array.length ) + $Option60Array

    # Set Option #93
    $DhcpDiscover += ( [byte] 93,2,0,$ProcessorArchitecture )

    # Set Option #94
    $DhcpDiscover += ( [byte] 94,3,1,3,0 )

    # Set Option #97
    $DhcpDiscover += ( [byte] 97,17,0 ) + [guid]::Parse($UUIDString).ToByteArray()

    # Set End Option #255
    $DhcpDiscover += ( [byte] 255 )

    return $DhcpDiscover
}

function Read-DhcpPacket ([Byte[]]$Packet) {
  <#
    Parse a DHCP Packet, returning an object containing each field
  #>
    $Reader = New-Object IO.BinaryReader (New-Object IO.MemoryStream (@(,$Packet)))

    $DhcpResponse = New-Object Object

    # Get and translate the Op code
    $DhcpResponse | Add-Member NoteProperty Op $Reader.ReadByte()
    if ($DhcpResponse.Op -eq 1) {
        $DhcpResponse.Op = "BootRequest"
    }
    else {
        $DhcpResponse.Op = "BootResponse"
    }

    $DhcpResponse | Add-Member NoteProperty HType -Value $Reader.ReadByte()
    if ($DhcpResponse.HType -eq 1) { $DhcpResponse.HType = "Ethernet" }

    $DhcpResponse | Add-Member NoteProperty HLen $Reader.ReadByte()
    $DhcpResponse | Add-Member NoteProperty Hops $Reader.ReadByte()
    $DhcpResponse | Add-Member NoteProperty XID $Reader.ReadUInt32()
    $DhcpResponse | Add-Member NoteProperty Secs $Reader.ReadUInt16()
    $DhcpResponse | Add-Member NoteProperty Flags $Reader.ReadUInt16()
    # Broadcast is the only flag that can be present, the other bits are reserved
    if ($DhcpResponse.Flags -band 128) { $DhcpResponse.Flags = @("Broadcast") }

    $DhcpResponse | Add-Member NoteProperty CIAddr (( 1..4 | % { $Reader.ReadByte() } ) -join '.' )
    $DhcpResponse | Add-Member NoteProperty YIAddr (( 1..4 | % { $Reader.ReadByte() } ) -join '.' )
    $DhcpResponse | Add-Member NoteProperty SIAddr (( 1..4 | % { $Reader.ReadByte() } ) -join '.' )
    $DhcpResponse | Add-Member NoteProperty GIAddr (( 1..4 | % { $Reader.ReadByte() } ) -join '.' )

    $MacAddrBytes = New-Object Byte[] 16
    [void]$Reader.Read($MacAddrBytes,0,16)
    $MacAddress = [string]::Join( ":",$($MacAddrBytes[0..5] | ForEach-Object { [string]::Format('{0:X2}',$_) }))
    $DhcpResponse | Add-Member NoteProperty CHAddr $MacAddress
    
    $DhcpResponse | Add-Member NoteProperty SName $([string]::Join("",$Reader.ReadChars(64)).Trim([char]0x0));
    $DhcpResponse | Add-Member NoteProperty File $([string]::Join("",$Reader.ReadChars(128)).Trim([char]0x0));

    $DhcpResponse | Add-Member NoteProperty MagicCookie (( 1..4 | % { $Reader.ReadByte().tostring('') } ) -join '' )

    # Start reading Options

    $DhcpResponse | Add-Member NoteProperty Options @()
    while ($Reader.BaseStream.Position -lt $Reader.BaseStream.Length)
    {
        $Option = New-Object Object
        $Option | Add-Member NoteProperty OptionCode $Reader.ReadByte()
        $Option | Add-Member NoteProperty OptionName ""
        $Option | Add-Member NoteProperty Length 0
        $Option | Add-Member NoteProperty OptionValue ""

        if ($Option.OptionCode -ne 0 -and $Option.OptionCode -ne 255)
        {
            $Option.Length = $Reader.ReadByte()
        }

        switch ($Option.OptionCode)
        {
            0 { $Option.OptionName = "PadOption" }
            1 {
                $Option.OptionName = "SubnetMask"
                $Option.OptionValue = ( 1..4 | % { $Reader.ReadByte() } ) -join '.' 
              }
            3 {
                $Option.OptionName = "Router"
                $Option.OptionValue = ( 1..4 | % { $Reader.ReadByte() } ) -join '.' 
              }
            6 {
                $Option.OptionName = "DomainNameServer"
                $Option.OptionValue = @()
                for ($i = 0; $i -lt ($Option.Length / 4); $i++)
                {
                    $Option.OptionValue += ( 1..4 | % { $Reader.ReadByte() } ) -join '.'
                } 
               }
            7 {
                $Option.OptionName = "LogServer"
                $Option.OptionValue = ( 1..4 | % { $Reader.ReadByte() } ) -join '.' 
              }
            15 {
                $Option.OptionName = "DomainName"
                $Option.OptionValue = [string]::Join("",$Reader.ReadChars($Option.Length)) 
               }
            28 {
                $Option.OptionName = "BroadcastAddr"
                $Option.OptionValue = ( 1..4 | % { $Reader.ReadByte() } ) -join '.' 
              }
            51 {
                $Option.OptionName = "IPAddressLeaseTime"
                # Read as Big Endian
                $Value = ($Reader.ReadByte() * [Math]::Pow(256, 3)) + `
                    ($Reader.ReadByte() * [Math]::Pow(256, 2)) + `
                    ($Reader.ReadByte() * 256) + `
                    $Reader.ReadByte()
                    $Option.OptionValue = $(New-TimeSpan -Seconds $Value) }
            53 {
                $Option.OptionName = "DhcpMessageType"
                switch ($Reader.ReadByte())
                {
                    1 { $Option.OptionValue = "DHCPDISCOVER" }
                    2 { $Option.OptionValue = "DHCPOFFER" }
                    3 { $Option.OptionValue = "DHCPREQUEST" }
                    4 { $Option.OptionValue = "DHCPDECLINE" }
                    5 { $Option.OptionValue = "DHCPACK" }
                    6 { $Option.OptionValue = "DHCPNAK" }
                    7 { $Option.OptionValue = "DHCPRELEASE" }
                } }
            54 {
                $Option.OptionName = "DhcpServerIdentifier"
                $Option.OptionValue = ( 1..4 | % { $Reader.ReadByte() } ) -join '.' 
              }
            58 {
                $Option.OptionName = "RenewalTime"
                 # Read as Big Endian
                $Value = ($Reader.ReadByte() * [Math]::Pow(256, 3)) + `
                    ($Reader.ReadByte() * [Math]::Pow(256, 2)) + `
                    ($Reader.ReadByte() * 256) + `
                    $Reader.ReadByte()
                    $Option.OptionValue = $(New-TimeSpan -Seconds $Value) }
            59 {
                $Option.OptionName = "RebindingTime"
                 # Read as Big Endian
                $Value = ($Reader.ReadByte() * [Math]::Pow(256, 3)) + `
                    ($Reader.ReadByte() * [Math]::Pow(256, 2)) + `
                    ($Reader.ReadByte() * 256) + `
                    $Reader.ReadByte()
                    $Option.OptionValue = $(New-TimeSpan -Seconds $Value) }
            60 {
                $Option.OptionName = "VendorClass"
                $Option.OptionValue = [string]::Join("",$Reader.ReadChars($Option.Length)) 
                }
            67 {
                $Option.OptionName = "vendor-class-identifier"
                # Read as Big Endian
                $Value = ($Reader.ReadByte() * [math]::Pow(256,3)) + `
                     ($Reader.ReadByte() * [math]::Pow(256,2)) + `
                     ($Reader.ReadByte() * 256) + `
                     $Reader.ReadByte()
                $Option.OptionValue = $(New-TimeSpan -Seconds $Value) }
            97 {
                $Option.OptionName = "UUIDClientID"
                $reader.readbyte() | out-null
                $guid = $Reader.ReadBytes($Option.Length -1)
                $Option.OptionValue = [guid]::new($guid).tostring()
               }
            175 {
                $Option.OptionName = "EtherBoot"
                $Option.OptionValue = [string]::Join("",$Reader.ReadChars($Option.Length)) 
              }

            255 { $Option.OptionName = "EndOption" ; break }

            default {
                # For all options which are not decoded here
                $Option.OptionName = "Option[$($Option.OptionCode)]"
                $Buffer = New-Object Byte[] $Option.Length
                [void]$Reader.Read($Buffer,0,$Option.Length)
                $Option.OptionValue = $Buffer
            }
        }

        # Override the ToString method
        $Option | Add-Member ScriptMethod ToString `
             { return "$($this.OptionName) ($($this.OptionValue))" } -Force

        $DhcpResponse.Options += $Option
    }

    return $DhcpResponse

}

function New-UdpSocket {
  <#
    Create a UDP Socket with Broadcast and Address Re-use enabled.
  #>
    param(
        [int32]$SendTimeOut = 4,
        [int32]$ReceiveTimeOut = 4
    )

    $UdpSocket = New-Object Net.Sockets.Socket (
        [Net.Sockets.AddressFamily]::InterNetwork,
        [Net.Sockets.SocketType]::Dgram,
        [Net.Sockets.ProtocolType]::Udp)

    $UdpSocket.EnableBroadcast = $true
    $UdpSocket.ExclusiveAddressUse = $false
    $UdpSocket.SendTimeOut = $SendTimeOut * 1000
    $UdpSocket.ReceiveTimeOut = $ReceiveTimeOut * 1000

    return $UdpSocket
}

function Remove-Socket {
<#
Close down a Socket
#>
    param(
        [Net.Sockets.Socket]$Socket
    )

    $Socket.Shutdown("Both")
    $Socket.Close()
}

#region Main()

write-verbose "Create UDP Socket.      Timeouts: $Timeout"
$UdpSocket = New-UdpSocket -SendTimeOut $Timeout -ReceiveTimeOut $Timeout
$UdpSocket.SetSocketOption([Net.Sockets.SocketOptionLevel]::Socket,32,1)

Write-Verbose "Create UDP Port 68 Listener, and bind to UDP"
$EndPoint = [Net.EndPoint](New-Object Net.IPEndPoint ($([Net.IPAddress]::Any,68)))
$UdpSocket.Bind($EndPoint)

write-verbose "for each processor archiecture type, send a Discover Packet."
$RequiredArchitectures = @(
    @{ id = 0x07; vendor = 'PXEClient';  required = $true;  description = 'x64 UEFI' }
    @{ id = 0x0b; vendor = 'PXEClient';  required = $true;  description = 'ARM 64-bit UEFI' }
    @{ id = 0x10; vendor = 'HTTPClient'; required = $true;  description = 'x64 uefi boot from http' }
    @{ id = 0x13; vendor = 'HTTPClient'; required = $true;  description = 'arm uefi 64 boot from http' }

    @{ id = 0x00; vendor = 'PXEClient';  required = $false; description = 'x86 BIOS' }
    @{ id = 0x06; vendor = 'PXEClient';  required = $false; description = 'x86 UEFI' }
    @{ id = 0x0a; vendor = 'PXEClient';  required = $false; description = 'ARM 32-bit UEFI' }
    @{ id = 0x0f; vendor = 'HTTPClient'; required = $false; description = 'x86 uefi boot from http' }
    @{ id = 0x12; vendor = 'HTTPClient'; required = $false; description = 'arm uefi 32 boot from http' }
)

foreach ( $Arch in $RequiredArchitectures ) { 
    $DiscoverArgs = @{
        MacAddressString = "AA:BB:CC:DD:EE:{0:X2}" -f $Arch.id
        UUIDString = "AABBCCDD-AABB-AABB-AABB-AABBCCDDEE{0:X2}" -f $Arch.id
        ProcessorArchitecture = $Arch.id
        Option60String = $arch.Vendor + ( ":Arch:000{0:X2}:UNDI:003000" -f $Arch.id )
    }
    write-verbose "Send DHCP Discover packet for [$( $arch.description )]"
    $DiscoverArgs | out-string | write-verbose
    $CliEndPoint = [Net.EndPoint](New-Object Net.IPEndPoint ($([Net.IPAddress]::Broadcast,67)))
    $Message = New-DhcpDiscoverPacket -SecondsElapsed 4 @DiscoverArgs
    $BytesSent = $UdpSocket.SendTo($Message,$CliEndPoint)
    start-sleep -Milliseconds 100
}

write-verbose "Starting DHCP Listening Loop at $([datetime]::now.tostring('s'))"
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
while ( $stopwatch.ElapsedMilliseconds / 1000 -lt $timeout) {

    $BytesReceived = 0
    try
    {
        # Placeholder EndPoint for the Sender
        $SenderEndPoint = [Net.EndPoint](New-Object Net.IPEndPoint ($([Net.IPAddress]::Any,0)))

        # Receive Buffer - works with large DHCP packets
        $ReceiveBuffer = New-Object Byte[] 1472
        $BytesReceived = $UdpSocket.ReceiveFrom($ReceiveBuffer,[ref]$SenderEndPoint)
    }
    catch [Net.Sockets.SocketException]
    {
        # Catch a SocketException, Ignore when the Receive TimeOut value is reached
        if ( $_.exception.SocketErrorCode -ne 'TimedOut' ) {
            write-warning $error[0]
        }
        break
    }
    catch [System.Exception]
    {
        write-warning $error[0]
        break
    }


    if ($BytesReceived -eq 0) {
        write-verbose "`tNothing to do, Zero Byte packet received"
        continue
    }

    $pck = Read-DhcpPacket $ReceiveBuffer[0..$BytesReceived]

    if ($pck.SIAddr -eq "") {
        write-verbose "`tNothing to do, Server Address is null"
        continue
    }

    $pck | out-string | write-verbose 
    # Convert all options to hashtable
    $Result = [PSCustomObject]@{
        # Insert most common ...
        Time   = "$($stopwatch.ElapsedMilliseconds) ms"
        OPCode = $pck.op
        Server = $pck.SIAddr
        File   = $pck.File
    }

    $pck.Options | out-string | write-verbose
    foreach ($element in $pck.Options) {
        if (($element.OptionCode -notin 0,1,3,6,15,51,53,58,59,255)) {
            $result | add-member -MemberType NoteProperty -name $element.OptionName -value $element.OptionValue
        }
    }

    $result | write-output
    $result = $null

}

$stopwatch.Stop();
Remove-Socket $UdpSocket
write-verbose "Finished. Elapsed Time: $($stopwatch.ElapsedMilliseconds / 1000) seconds. Cleanup"

#endregion Main
