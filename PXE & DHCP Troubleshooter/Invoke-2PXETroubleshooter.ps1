<#
.SYNOPSIS
  Invoke-2PXETroubleshooter.ps1

.DESCRIPTION
  Script to verify the installation and configuration of 2PXE/iPXE Anywhere.
  Performs the following checks:
  - 2PXE service installation, start type, and running status
  - 2PXE UDP port listeners (67, 69, 4011)
  - 2PXE HTTPS port detection via http.sys
  - 2Pint root certificate presence in Trusted Root store (with optional install)
  - SSL certificate bindings and trust chain validation for 2PXE ports
  - iPXE Anywhere WebService installation, start type, and running status
  - iPXE WS UDP port 516 (SYSLOG) listener
  - iPXE WS HTTPS port detection via http.sys (8051, 8052)
  - SSL certificate bindings and trust chain validation for iPXE ports
  - 2PXE and iPXE event logs for errors and warnings (last 48 hours or since service start)
  - Exports event log issues to text files in the script directory
  - Firewall rules for 2PXE (ports 67, 69, 4011, 8050) and iPXE (ports 8051, 8052)
  - IIS SMS_DP_SMSPKG web application anonymous authentication setting
  - WDS service status (should be disabled or not installed)
  - SccmPxe service status (should be disabled or not installed)

.NOTES
  Version:        1.1
  Author:         MB @ 2Pint Software
  Creation Date:  2023-02-27
  Purpose/Change: Initial script development
    - 2024-06-26 - Updated to check for any HTTPS ports the services are listening on instead of just default ports
                 - Verify SSL certificates bound to 2PXE/iPXE HTTPS ports and their trust chain to the 2Pint root certificate

.EXAMPLE
    Invoke-2PXETroubleshooter.ps1

#>
#Requires -RunAsAdministrator

# Determine script directory (works in PS 5.1 and later, even if $PSScriptRoot is empty)
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }

Function Write-Result {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
  
        [Parameter()]
        [ValidateSet(1, 2, 3)]
        [int]$LogLevel = 1
    )    

    switch ($LogLevel) {
        2 { $prefix = "Warning" ; $PrefixColor = "Yellow"; $TextColor = "Yellow" }
        3 { $prefix = " Error " ; $PrefixColor = "Red"   ; $TextColor = "Red" }
        Default { $prefix = "   OK  " ; $PrefixColor = "Green"; $TextColor = "Gray" }
    }

    Write-Host -nonewline -f "White" "["; Write-Host -nonewline -f $PrefixColor "$prefix"; Write-Host -nonewline -f "White" "] `t "; Write-Host -nonewline -f $TextColor "$Message`r`n" 
	
}
#Write-Result "Test" -LogLevel 3

#Get what process is listnening on specified ports for http.sys
$netshResult = Invoke-Command { netsh http show servicestate view=requestq verbose=no }
[string[]]$netshblocks = [regex]::Split($netshResult, 'Request queue name: Request queue is unnamed.     Version: 2.0')

$procID = "Process IDs:"
$URLGroups = "URL groups:"

$2PXEChecks = $false
$2PXEPortChecks = $false
$2PXEStartTime = $null
try {
    $2PXEService = Get-Service -Name "2PXE" -ErrorAction Stop
    $2PXEStartTime = $2pxeProcess.StartTime
    Write-Result "2PXE Service Installed"
    if ($2PXEService.StartType -eq "Automatic") {
        Write-Result "   - 2PXE Startype = Automatic"
    }
    else {
        Write-Result "   - 2PXE Startype = $($2PXEService.StartType), should be Automatic" -LogLevel 2
    }
    if ($2PXEService.Status -eq "Running") {
        $2PXEChecks = $True
        $2PXEPortChecks = $True
        Write-Result "   - 2PXE Status = Running"
    }
    else {
        Write-Result "   - 2PXE Status = $($2PXEService.Status)" -LogLevel 3
        Write-Result "2PXE Service not started, skipping 2PXE port related checks" -LogLevel 2
        $2PXEChecks = $True
    }
}
catch {
    Write-Result "2PXE Service not installed, skipping 2PXE related checks" -LogLevel 2
}



if ($2PXEPortChecks) {
    try {
        $udpEndpoint67 = Get-NetUDPEndpoint -LocalPort 67 -ErrorAction Stop
        [array]$port67 = Get-Process -Id $udpEndpoint67.OwningProcess
        foreach ($port in $port67) {
            if ($port.Name -eq "2Pint.2pxe.Service") {
                Write-Result "   - 2PXE Service listening on port 67"
            }
            else {
                Write-Result "$($port.Name) listening on port 67 instead of 2PXE" -LogLevel 3
            }
        }
    }
    catch {
        Write-Result "   - Nothing listening on UDP port 67" -LogLevel 2
    }

    try {
        $udpEndpoint69 = Get-NetUDPEndpoint -LocalPort 69 -ErrorAction Stop
        [array]$port69 = Get-Process -Id $udpEndpoint69.OwningProcess
        foreach ($port in $port69) {
            if ($port.Name -eq "2Pint.2pxe.Service") {
                Write-Result "   - 2PXE Service listening on port 69"
            }
            else {
                Write-Result "$($port.Name) listening on port 69 instead of 2PXE" -LogLevel 3
            }
        }
    }
    catch {
        Write-Result "   - Nothing listening on UDP port 69" -LogLevel 2
    }

    try {
        $udpEndpoint4011 = Get-NetUDPEndpoint -LocalPort 4011 -ErrorAction Stop
        [array]$port4011 = Get-Process -Id $udpEndpoint4011.OwningProcess
        foreach ($port in $port4011) {
            if ($port.Name -eq "2Pint.2pxe.Service") {
                Write-Result "   - 2PXE Service listening on port 4011"
            }
            else {
                Write-Result "$($port.Name) listening on port 4011 instead of 2PXE" -LogLevel 3
            }
        }
    }
    catch {
        Write-Result "   - Nothing listening on UDP port 4011" -LogLevel 2
    }

    #Get process from http.sys - find what HTTPS ports the 2PXE service is listening on
    $port8050Process = $null
    $2pxeProcess = Get-Process -Name "2Pint.2pxe.Service" -ErrorAction SilentlyContinue
    if ($2pxeProcess) {
        $port8050Process = $2pxeProcess
        $2pxeHttpsPorts = @()
        foreach ($block in $netshblocks) {
            if ($block -match "HTTPS://") {
                $pidMatch = [regex]::Match($block, "$procID(.*?)$URLGroups")
                if ($pidMatch.Success -and $pidMatch.Groups[1].Value.Trim() -eq $2pxeProcess.Id.ToString()) {
                    $urlMatch = [regex]::Match($block, 'HTTPS://[^/]+:(\d+)/')
                    if ($urlMatch.Success) { $2pxeHttpsPorts += $urlMatch.Groups[1].Value }
                }
            }
        }
        if ($2pxeHttpsPorts.Count -gt 0) {
            if ($2pxeHttpsPorts -contains '8050') {
                Write-Result "   - 2PXE Service listening on default HTTPS port 8050"
            }
            else {
                Write-Result "   - 2PXE Service is NOT on default port 8050, currently listening on HTTPS port(s): $($2pxeHttpsPorts -join ', ')" -LogLevel 2
            }
            # Report any additional non-default ports
            $nonDefaultPorts = $2pxeHttpsPorts | Where-Object { $_ -ne '8050' }
            if ($nonDefaultPorts) {
                Write-Result "   - 2PXE Service also listening on non-default HTTPS port(s): $($nonDefaultPorts -join ', ')" -LogLevel 2
            }
        }
        else {
            Write-Result "   - 2PXE Service is running but not found on any HTTPS port in http.sys" -LogLevel 2
        }
    }
    else {
        Write-Result "   - 2PXE Service process not found" -LogLevel 3
    }
}

if ($2PXEChecks) {
    # Check if the 2PintSoftware.com root certificate is in the Trusted Root store
    $2PintRootCert = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Issuer -match "2PintSoftware\.com" }
    if ($2PintRootCert) {
        Write-Result "   - 2Pint root certificate found in Trusted Root store (Thumbprint: $($2PintRootCert.Thumbprint))"
        Write-Result "   - Certificate Name: $($2PintRootCert.Subject), Expiration: $($2PintRootCert.NotAfter)"
    }
    else {
        Write-Result "   - 2Pint root certificate NOT found in Trusted Root store" -LogLevel 3
        $caCertPath = "C:\Program Files\2Pint Software\2PXE\x64\ca.crt"
        if (Test-Path $caCertPath) {
            Write-Result "   - Root certificate file found at $caCertPath" -LogLevel 2
            $installCert = Read-Host "   Do you want to install the 2Pint root certificate into the Trusted Root store? (Y/N)"
            if ($installCert -eq 'Y') {
                try {
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($caCertPath)
                    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
                    $store.Open("ReadWrite")
                    $store.Add($cert)
                    $store.Close()
                    $2PintRootCert = $cert
                    Write-Result "   - 2Pint root certificate installed successfully"
                }
                catch {
                    Write-Result "   - Failed to install root certificate: $_" -LogLevel 3
                }
            }
            else {
                Write-Result "   - Root certificate installation skipped by user" -LogLevel 2
            }
        }
        else {
            Write-Result "   - Root certificate file not found at $caCertPath, if the service has been installed in a custom location the x64\ca.crt must be manually installed" -LogLevel 2
        }
    }

    if ($2PXEPortChecks) {
        # Verify that the certificate bound to 2PXE HTTPS port(s) is trusted by the 2Pint root certificate
        $2pxeCertPorts = if ($2pxeHttpsPorts.Count -gt 0) { $2pxeHttpsPorts } else { @('8050') }
        foreach ($2pxePort in $2pxeCertPorts) {
            $sslCertOutput = netsh http show sslcert ipport=0.0.0.0:$2pxePort
            $certHashMatch = [regex]::Match(($sslCertOutput -join "`n"), 'Certificate Hash\s*:\s*([0-9a-fA-F]+)')
            if ($certHashMatch.Success) {
                $boundCertHash = $certHashMatch.Groups[1].Value
                Write-Result "   - SSL certificate bound to port $2pxePort (Hash: $boundCertHash)"

                # Look up the bound certificate in the personal store
                $boundCert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $boundCertHash }
                if ($boundCert) {
                    if ($2PintRootCert) {
                        # Build the certificate chain and check if the 2Pint root cert is in the chain
                        $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
                        $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
                        $chainBuilt = $chain.Build($boundCert)
                        $trustedByRoot = $false
                        foreach ($element in $chain.ChainElements) {
                            if ($element.Certificate.Thumbprint -eq $2PintRootCert.Thumbprint) {
                                $trustedByRoot = $true
                                break
                            }
                        }
                        if ($trustedByRoot) {
                            Write-Result "   - Port $2pxePort certificate is trusted by the 2Pint root certificate"
                            Write-Result "   - Certificate Name: $($boundCert.Subject), Issuer: $($boundCert.Issuer), Expiration: $($boundCert.NotAfter)"
                        }
                        else {
                            Write-Result "   - Port $2pxePort certificate is NOT trusted by the 2Pint root certificate" -LogLevel 3
                            if (-not $chainBuilt) {
                                Write-Result "   - Certificate chain errors: $($chain.ChainStatus | ForEach-Object { $_.StatusInformation })" -LogLevel 3
                            }
                        }
                    }
                    else {
                        Write-Result "   - Cannot verify trust chain for port $2pxePort, 2Pint root certificate not available" -LogLevel 2
                    }
                }
                else {
                    Write-Result "   - Could not find bound certificate for port $2pxePort in LocalMachine\My store" -LogLevel 3
                }
            }
            else {
                Write-Result "   - No SSL certificate bound to port $2pxePort" -LogLevel 3
            }
        }

    }
}
$iPXEChecks = $false
$iPXEPortChecks = $false
$iPXEStartTime = $null
try {
    $iPXEService = Get-Service -Name "iPXEWS" -ErrorAction Stop
    $iPXEStartTime = $iPXEProcess.StartTime
    Write-Result "iPXE WS Service Installed"
    if ($iPXEService.StartType -eq "Automatic") {
        Write-Result "   - iPXE WS Startype = Automatic"
    }
    else {
        Write-Result "   - iPXE WS Startype = $($iPXEService.StartType), should be Automatic" -LogLevel 2
    }
    if ($iPXEService.Status -eq "Running") {
        $iPXEChecks = $True
        $iPXEPortChecks = $True
        Write-Result "   - iPXE WS Status = Running"
    }
    else {
        Write-Result "   - iPXE WS Status = $($iPXEService.Status)" -LogLevel 3
        $iPXEChecks = $True
        Write-Result "iPXE WS Service not started, skipping iPXE WS related checks" -LogLevel 2
    }
}
catch {
    Write-Result "iPXE WS Service not installed, skipping iPXE WS related checks" -LogLevel 2
}

if ($iPXEPortChecks) {
    try {
        $udpEndpoint516 = Get-NetUDPEndpoint -LocalPort 516 -ErrorAction Stop
        [array]$port516 = Get-Process -Id $udpEndpoint516.OwningProcess
        foreach ($port in $port516) {
            if ($port.Name -eq "iPXEAnywhere.Service") {
                Write-Result "   - iPXE WS Service listening on port 516 (SYSLOG)"
            }
            else {
                Write-Result "$($port.Name) listening on port 516 instead of iPXE WS" -LogLevel 3
            }
        }
    }
    catch {
        Write-Result "   - Nothing listening on UDP port 516 (SYSLOG)" -LogLevel 1
    }

    #Get process from http.sys - find what HTTPS ports the iPXE WS service is listening on
    $iPXEProcess = Get-Process -Name "iPXEAnywhere.Service" -ErrorAction SilentlyContinue
    $iPXEHttpsPorts = @()
    if ($iPXEProcess) {
        foreach ($block in $netshblocks) {
            if ($block -match "HTTPS://") {
                $pidMatch = [regex]::Match($block, "$procID(.*?)$URLGroups")
                if ($pidMatch.Success -and $pidMatch.Groups[1].Value.Trim() -eq $iPXEProcess.Id.ToString()) {
                    $urlMatch = [regex]::Match($block, 'HTTPS://[^/]+:(\d+)/')
                    if ($urlMatch.Success) { $iPXEHttpsPorts += $urlMatch.Groups[1].Value }
                }
            }
        }
        if ($iPXEHttpsPorts.Count -gt 0) {
            $defaultiPXEPorts = @('8051', '8052')
            $onDefault = $iPXEHttpsPorts | Where-Object { $_ -in $defaultiPXEPorts }
            $nonDefault = $iPXEHttpsPorts | Where-Object { $_ -notin $defaultiPXEPorts }
            foreach ($dp in $defaultiPXEPorts) {
                if ($dp -in $iPXEHttpsPorts) {
                    Write-Result "   - iPXE WS Service listening on default HTTPS port $dp"
                }
                else {
                    Write-Result "   - iPXE WS Service NOT listening on default HTTPS port $dp" -LogLevel 2
                }
            }
            if ($nonDefault) {
                Write-Result "   - iPXE WS Service also listening on non-default HTTPS port(s): $($nonDefault -join ', ')" -LogLevel 2
            }
        }
        else {
            Write-Result "   - iPXE WS Service is running but not found on any HTTPS port in http.sys" -LogLevel 2
        }
    }
    else {
        Write-Result "   - iPXE WS Service process not found" -LogLevel 3
    }

    # Check if the 2PintSoftware.com root certificate is available for iPXE trust verification
    if (-not $2PintRootCert) {
        $2PintRootCert = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Issuer -match "2PintSoftware\.com" }
    }

    # Verify SSL certificates bound to iPXE HTTPS port(s)
    $iPXECertPorts = if ($iPXEHttpsPorts.Count -gt 0) { $iPXEHttpsPorts } else { @('8051', '8052') }
    foreach ($iPXEPort in $iPXECertPorts) {
        $sslCertOutput = netsh http show sslcert ipport=0.0.0.0:$iPXEPort
        $certHashMatch = [regex]::Match(($sslCertOutput -join "`n"), 'Certificate Hash\s*:\s*([0-9a-fA-F]+)')
        if ($certHashMatch.Success) {
            $boundCertHash = $certHashMatch.Groups[1].Value
            Write-Result "   - SSL certificate bound to port $iPXEPort (Hash: $boundCertHash)"

            # Look up the bound certificate in the personal store
            $boundCert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $boundCertHash }
            if ($boundCert) {
                if ($2PintRootCert) {
                    # Build the certificate chain and check if the 2Pint root cert is in the chain
                    $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
                    $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
                    $chainBuilt = $chain.Build($boundCert)
                    $trustedByRoot = $false
                    foreach ($element in $chain.ChainElements) {
                        if ($element.Certificate.Thumbprint -eq $2PintRootCert.Thumbprint) {
                            $trustedByRoot = $true
                            break
                        }
                    }
                    if ($trustedByRoot) {
                        Write-Result "   - Port $iPXEPort certificate is trusted by the 2Pint root certificate"
                        Write-Result "   - Certificate Name: $($boundCert.Subject), Issuer: $($boundCert.Issuer), Expiration: $($boundCert.NotAfter)"
                    }
                    else {
                        Write-Result "   - Port $iPXEPort certificate is NOT trusted by the 2Pint root certificate" -LogLevel 3
                        if (-not $chainBuilt) {
                            Write-Result "   - Certificate chain errors: $($chain.ChainStatus | ForEach-Object { $_.StatusInformation })" -LogLevel 3
                        }
                    }
                }
                else {
                    Write-Result "   - Cannot verify trust chain for port $iPXEPort, 2Pint root certificate not available" -LogLevel 2
                }
            }
            else {
                Write-Result "   - Could not find bound certificate for port $iPXEPort in LocalMachine\My store" -LogLevel 3
            }
        }
        else {
            Write-Result "   - No SSL certificate bound to port $iPXEPort" -LogLevel 3
        }
    }
}

if ($2PXEChecks) {
    if ([System.Diagnostics.EventLog]::Exists('2PXE')) {
        Write-Result "2PXE Eventlog Exists"
        Write-Result "2PXE Eventlog, checking events last 48 hours"
        
        $outEvents = $false
        if ($2PXEStartTime) {
            try {
                $events = Get-WinEvent -FilterHashtable @{LogName = '2PXE'; StartTime = $2PXEStartTime }
            }
            catch {
                Write-Result "No 2PXE events in the '2PXE' event log since service start time" -LogLevel 2
            }
        }
        else {
            try {
                $events = Get-WinEvent -FilterHashtable @{LogName = '2PXE'; StartTime = (Get-Date).AddHours(-48) } -ErrorAction Stop
            }
            catch {
                Write-Result "No 2PXE events in the '2PXE' event log for the last 48 hours" -LogLevel 2
            }
        }
        if ($events) {
            # Known safe warning messages that can be ignored (startup messages)
            $safeWarningPatterns = @(
                'EFI file does not exist:.*autoexec\.ipxe',
                'TFTP now serves:.* from memory stream of:\d+ bytes',
                'Reading EFI file from DISK:'
            )
            $safeWarningRegex = ($safeWarningPatterns | ForEach-Object { "($_)" }) -join '|'

            $allWarnings = $events | Where-Object { $_.LevelDisplayName -eq "Warning" }
            $actionableWarnings = $allWarnings | Where-Object { $_.Message -notmatch $safeWarningRegex }
            if ($actionableWarnings.Count -eq 0) {
                Write-Result "   - 2PXE EventLog, No Warnings"
            }
            else {
                $outEvents = $true
                Write-Result "   - 2PXE EventLog, $($actionableWarnings.Count) Warning(s) found" -LogLevel 2
            }
            $2PXEErrorCount = ($events.LevelDisplayName -eq "Error").Count
            if ($2PXEErrorCount -eq 0) {
                Write-Result "   - 2PXE EventLog, No Errors"
            }
            else {
                $outEvents = $true
                Write-Result "   - 2PXE EventLog, Errors found" -LogLevel 3
            
            }
            if ($outEvents) {
                # Exclude safe warnings from the output
                $issueEvents = $events | Where-Object { (1, 2, 3 -contains $_.Level) -and ($_.LevelDisplayName -ne "Warning" -or $_.Message -notmatch $safeWarningRegex) }
                $2PXEEventLogFile = Join-Path $ScriptDir "2PXE_EventIssues.txt"
                $issueEvents | Format-Table -AutoSize -Wrap TimeCreated, LevelDisplayName, Id, Message | Out-String | Out-File -FilePath $2PXEEventLogFile -Encoding UTF8
            }
        }
    }
}

if ($iPXEChecks) {
    if ([System.Diagnostics.EventLog]::Exists('iPXE Anywhere WebService')) {
        Write-Result "iPXE Eventlog Exists"
        Write-Result "iPXE Eventlog, checking events last 48 hours"
        
        $outEvents = $false
        if ($iPXEStartTime) {
            try {
                $events = Get-WinEvent -FilterHashtable @{LogName = 'iPXE Anywhere WebService'; StartTime = $iPXEStartTime }
            }
            catch {
                Write-Result "No iPXE events in the 'iPXE Anywhere WebService' event log since last service start time" -LogLevel 2
            }
        }
        else {
            try {
                $events = Get-WinEvent -FilterHashtable @{LogName = 'iPXE Anywhere WebService'; StartTime = (Get-Date).AddHours(-48) } -ErrorAction Stop
            }
            catch {
                Write-Result "No iPXE events in the 'iPXE Anywhere WebService' event log for the last 48 hours" -LogLevel 2
            }
        }
        if ($events) {
            $iPXEWarningCount = ($events.LevelDisplayName -eq "Warning").Count
            if ($iPXEWarningCount -eq 0) {
                Write-Result "   - iPXE EventLog, No Warnings"
            }
            else {
                $outEvents = $true
                Write-Result "   - iPXE EventLog, Warnings found" -LogLevel 2
            }
            $2PXEErrorCount = ($events.LevelDisplayName -eq "Error").Count
            if ($2PXEErrorCount -eq 0) {
                Write-Result "   - iPXE EventLog, No Errors"
            }
            else {
                $outEvents = $true
                Write-Result "   - iPXE EventLog, Errors found" -LogLevel 3
            
            }
            if ($outEvents) {
                $iPXEEventLogFile = Join-Path $ScriptDir "iPXE_EventIssues.txt"
                $events | Where-Object { 1, 2, 3 -contains $_.Level } | Format-Table -AutoSize -Wrap TimeCreated, LevelDisplayName, Id, Message | Out-String | Out-File -FilePath $iPXEEventLogFile -Encoding UTF8
            }
        }
    }
}

#Check Firewall rules
if ($2PXEChecks) {
    Write-Result "2PXE Firewall Rules"
    try {
        $2PXEFirewallRule67 = Get-NetFirewallRule -DisplayName "2Pint Software 2PXE - DHCP Udp Ports:67" -ErrorAction stop
        Write-Result "   - 2PXE Firewall rule for DHCP UDP port 67"
        if ($port8050Process -and $2PXEPortChecks) {
            if ($(($2PXEFirewallRule67 | Get-NetFirewallApplicationFilter).Program) -eq $port8050Process.Path) {
                Write-Result "   - 2PXE Firewall rule path for DHCP UDP port 67"
            }
            else {
                Write-Result "   - 2PXE Firewall rule path for DHCP UDP port 67 point to $(($2PXEFirewallRule67 |Get-NetFirewallApplicationFilter).Program) and service is in $($port8050Process.Path)"  -LogLevel 3
            }
        }

    }
    catch {
        Write-Result "Missing Rule: 2Pint Software 2PXE - DHCP Udp Ports:67" -LogLevel 3
    }

    try {
        $2PXEFirewallRule69 = Get-NetFirewallRule -DisplayName "2Pint Software 2PXE - TFTP Udp Ports:69" -ErrorAction stop
        Write-Result "   - 2PXE Firewall rule for TFTP UDP port 69"
        if ($port8050Process -and $2PXEPortChecks) {
            if ($(($2PXEFirewallRule69 | Get-NetFirewallApplicationFilter).Program) -eq $port8050Process.Path) {
                Write-Result "   - 2PXE Firewall rule path for TFTP UDP port 69"
            }
            else {
                Write-Result "   - 2PXE Firewall rule path for TFTP UDP port 69 point to $(($2PXEFirewallRule69 |Get-NetFirewallApplicationFilter).Program) and service is in $($port8050Process.Path)" -LogLevel 3
            }
        }

    }
    catch {
        Write-Result "Missing Rule: 2Pint Software 2PXE - TFTP Udp Ports:69" -LogLevel 3
    }

    try {
        $2PXEFirewallRule4011 = Get-NetFirewallRule -DisplayName "2Pint Software 2PXE - PXE Udp Ports:4011" -ErrorAction stop
        Write-Result "   - 2PXE Firewall rule for PXE UDP port 4011"
        if ($port8050Process -and $2PXEPortChecks) {
            if ($(($2PXEFirewallRule4011 | Get-NetFirewallApplicationFilter).Program) -eq $port8050Process.Path) {
                Write-Result "   - 2PXE Firewall rule path for PXE UDP port 4011"
            }
            else {
                Write-Result "   - 2PXE Firewall rule path for PXE UDP port 4011 point to $(($2PXEFirewallRule4011 |Get-NetFirewallApplicationFilter).Program) and service is in $($port8050Process.Path)" -LogLevel 3
            }
        }

    }
    catch {
        Write-Result "Missing Rule: 2Pint Software 2PXE - PXE Udp Ports:4011" -LogLevel 3
    }

    try {
        $2PXEFirewallRule8050 = Get-NetFirewallRule -DisplayName "2Pint Software 2PXE - HTTP Tcp Ports:8050" -ErrorAction stop
        Write-Result "   - 2PXE Firewall rule for HTTP UDP port 8050"
    }
    catch {
        Write-Result "Missing Rule: 2Pint Software 2PXE - DHCP Udp Ports:67" -LogLevel 3
    }
}

if ($iPXEChecks) {
    Write-Result "iPXE Firewall Rules"
    try {
        $iPXEFirewallRule8051 = Get-NetFirewallRule -DisplayName "2Pint Software iPXE WebService iPXE endpoint - HTTP(s) Tcp Ports:8051" -ErrorAction stop
        Write-Result "   - iPXE Firewall rule for HTTP TCP port 8051"
    }
    catch {
        Write-Result "Missing Rule: 2Pint Software iPXE WebService iPXE endpoint - HTTP(s) Tcp Ports:8051" -LogLevel 3
    }
    
    try {
        $iPXEFirewallRule8052 = Get-NetFirewallRule -DisplayName "2Pint Software iPXE WebService Admin endpoint - HTTP(s)  Tcp Ports:8052" -ErrorAction stop
        Write-Result "   - iPXE Firewall rule for HTTP TCP port 8052"
    }
    catch {
        Write-Result "Missing Rule: 2Pint Software iPXE WebService Admin endpoint - HTTP(s)  Tcp Ports:8052" -LogLevel 3
    }
}

Write-Result "Checking for external issues"
#Check that IIS SMS_DP_SMSPKG web app has enabled Anonymous Authentication
try {
    $iissites = Get-Website -ErrorAction Stop
    foreach ($iissite in $iissites) {
        $webapp = $null
        $webapp = Get-WebApplication -Site $iissite.name -Name "SMS_DP_SMSPKG*"
        if ($webapp) {
            $webappvalue = (Get-WebConfigurationProperty -Filter "/system.webServer/security/authentication/anonymousAuthentication" -Name Enabled -PSPath "IIS:\Sites\$($iissite.name)\$($webapp.path.Trim('/'))").Value
            If ($webappvalue) {
                Write-Result "IIS:\Sites\$($iissite.name)\$($webapp.path.Trim('/')) Anonymous Authentication = Enabled"
            }
            else {
                Write-Result "IIS:\Sites\$($iissite.name)\$($webapp.path.Trim('/')) Anonymous Authentication = Disabled" -LogLevel 2
                Write-Result "   - If using ConfigMgr with full PKI and not using a network access account this should be enabled" -LogLevel 2
            }
       
        }
    }
}
catch {
    Write-Result "IIS not installed or WebAdministration module not available, skipping IIS checks" -LogLevel 1
    $iissites = $null
}


#Check SSL Cipher availability for iPXE
$cipherNames = @(
    "TLS_DHE_RSA_WITH_AES_256_GCM_SHA384"
)

$cipherFound = $false
try {
    # Get supported ciphers on this OS
     $arrayCiphers = Get-TlsCipherSuite -ErrorAction Stop
     $supportedCiphers = @($arrayCiphers.Name)
    
    if ($supportedCiphers.Count -eq 0) {
        Write-Result "Unable to retrieve supported ciphers using Get-TlsCipherSuite, falling back to registry check" -LogLevel 2
        # Fall back to registry checking
        foreach ($cipherName in $cipherNames) {
            $cipherPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\$cipherName"
            
            if (Test-Path $cipherPath) {
                $cipherEnabled = (Get-ItemProperty -Path $cipherPath -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
                if ($null -eq $cipherEnabled -or $cipherEnabled -eq 0xffffffff -or $cipherEnabled -eq 1) {
                    Write-Result "SSL Cipher $cipherName is enabled"
                    $cipherFound = $true
                    break
                }
                else {
                    Write-Result "SSL Cipher $cipherName is disabled" -LogLevel 2
                }
            }
        }
        if (-not $cipherFound) {
            Write-Result "No compatible SSL ciphers are enabled for iPXE" -LogLevel 2
            Write-Result "   - Recommended: Enable $($cipherNames[0]) for proper iPXE operation" -LogLevel 2
        }
    }
    else {
        # Check each cipher against supported list
        foreach ($cipherName in $cipherNames) {
            if ($cipherName -in $supportedCiphers) {
                # Cipher is supported, now check if it's explicitly disabled in registry
                $cipherPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\$cipherName"
                
                if (Test-Path $cipherPath) {
                    $cipherEnabled = (Get-ItemProperty -Path $cipherPath -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
                    if ($cipherEnabled -eq 0) {
                        Write-Result "SSL Cipher $cipherName is supported but explicitly disabled" -LogLevel 2
                        continue
                    }
                }
                
                # Cipher is supported and enabled (or enabled by default)
                Write-Result "SSL Cipher $cipherName is enabled"
                $cipherFound = $true
                break
            }
            else {
                Write-Result "SSL Cipher $cipherName is not supported on this OS version" -LogLevel 2
            }
        }
        
        if (-not $cipherFound) {
            Write-Result "No compatible SSL ciphers are available for iPXE" -LogLevel 2
            Write-Result "   - Recommended: Update Windows Server or enable $($cipherNames[0]) if available" -LogLevel 2
        }
    }
}
catch {
    Write-Result "Unable to check SSL Cipher status" -LogLevel 2
}


#Check WDSService
try {
    $WDSService = Get-Service -Name "WDSServer" -ErrorAction Stop
    Write-Result "WDS Service Installed" -LogLevel 3
    if ($WDSService.StartType -eq "Disabled") {
        Write-Result "   - WDS Startype = Disabled" -LogLevel 2
    }
    else {
        Write-Result "   - WDS Startype = $($WDSService.StartType), should be disabled or not installed" -LogLevel 3
    }
    if ($WDSService.Status -eq "Running") {
        Write-Result "   - WDS Status = Running" -LogLevel 3
    }
    else {
        Write-Result "   - WDS Status = $($WDSService.Status)" -LogLevel 2
    }
}
catch {
    Write-Result "WDS Service not installed"
}

#Check SccmPxe Service
try {
    $SccmPxeService = Get-Service -Name "SccmPxe" -ErrorAction Stop
    Write-Result "SccmPxe Service Installed" -LogLevel 3
    if ($SccmPxeService.StartType -eq "Disabled") {
        Write-Result "   - SccmPxe Startype = Disabled" -LogLevel 2
    }
    else {
        Write-Result "   - SccmPxe Startype = $($SccmPxeService.StartType), should be disabled or not installed" -LogLevel 3
    }
    if ($SccmPxeService.Status -eq "Running") {
        Write-Result "   - SccmPxe Status = Running" -LogLevel 3
    }
    else {
        Write-Result "   - SccmPxe Status = $($SccmPxeService.Status)" -LogLevel 2
    }
}
catch {
    Write-Result "SccmPxe Service not installed"
}
Write-host ""

if($2PXEEventLogFile){
    Write-Result "2PXE Event Log Issues exported to: $2PXEEventLogFile" -LogLevel 2
}

if($iPXEEventLogFile){
    Write-Result "iPXE Event Log Issues exported to: $iPXEEventLogFile" -LogLevel 2
}