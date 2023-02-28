<#
.SYNOPSIS
  Invoke-2PXETroubleshooter.ps1

.DESCRIPTION
  Script to verify the installation of 2PXE/iPXE

.NOTES
  Version:        1.0
  Author:         MB @ 2Pint Software
  Creation Date:  2023-02-27
  Purpose/Change: Initial script development

.EXAMPLE
    Invoke-2PXETroubleshooter.ps1

#>
#Requires -RunAsAdministrator


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
$netshResult = Invoke-Command -Computername localhost { netsh http show servicestate view=requestq verbose=no }
[string[]]$netshblocks = [regex]::Split($netshResult, 'Request queue name: Request queue is unnamed.     Version: 2.0')

$procID = "Process IDs:"
$URLGroups = "URL groups:"
foreach ($block in $netshblocks) {
    if ($block -match "HTTPS://\*:8050/") {
        $pattern = "$procID(.*?)$URLGroups"
        $result = [regex]::Match($block, $pattern).Groups[1].Value
        $port8050 = $result.trim()
    }
    ElseIf ($block -match "HTTPS://\+:8051/") {
        $pattern = "$procID(.*?)$URLGroups"
        $result = [regex]::Match($block, $pattern).Groups[1].Value
        $port8051 = $result.trim()
    }
    ElseIf ($block -match "HTTPS://\+:8052/") {
        $pattern = "$procID(.*?)$URLGroups"
        $result = [regex]::Match($block, $pattern).Groups[1].Value
        $port8052 = $result.trim()
    }
    
}

$2PXEChecks = $false
try {
    $2PXEService = Get-Service -Name "2PXE" -ErrorAction Stop
    Write-Result "2PXE Service Installed"
    if ($2PXEService.StartType -eq "Automatic") {
        Write-Result "   - 2PXE Startype = Automatic"
    }
    else {
        Write-Result "   - 2PXE Startype = $($2PXEService.StartType), should be Automatic" -LogLevel 2
    }
    if ($2PXEService.Status -eq "Running") {
        $2PXEChecks = $True
        Write-Result "   - 2PXE Status = Running"
    }
    else {
        Write-Result "   - 2PXE Status = $($2PXEService.Status)" -LogLevel 3
        Write-Result "2PXE Service not started, skipping 2PXE related checks" -LogLevel 2
    }
}
catch {
    Write-Result "2PXE Service not installed, skipping 2PXE related checks" -LogLevel 2
}



if ($2PXEChecks) {
    [array]$port67 = Get-Process -Id (Get-NetUDPEndpoint -LocalPort 67).OwningProcess
    foreach ($port in $port67) {
        if ($port.Name -eq "2Pint.2pxe.Service") {
            Write-Result "   - 2PXE Service listening on port 67"
        }
        else {
            Write-Result "$($port.Name) Service listening on port 67" -LogLevel 3
        }
    }
    [array]$port69 = Get-Process -Id (Get-NetUDPEndpoint -LocalPort 69).OwningProcess
    foreach ($port in $port69) {
        if ($port.Name -eq "2Pint.2pxe.Service") {
            Write-Result "   - 2PXE Service listening on port 69"
        }
        else {
            Write-Result "$($port.Name) Service listening on port 69" -LogLevel 3
        }
    }
    [array]$port4011 = Get-Process -Id (Get-NetUDPEndpoint -LocalPort 4011).OwningProcess
    foreach ($port in $port4011) {
        if ($port.Name -eq "2Pint.2pxe.Service") {
            Write-Result "   - 2PXE Service listening on port 4011"
        }
        else {
            Write-Result "$($port.Name) Service listening on port 4011" -LogLevel 3
        }
    }
    #Get process from http.sys
    $port8050Process = Get-Process -Id $port8050
    if ($port8050Process.Name -eq "2Pint.2pxe.Service") {
        $2PXEStartTime = $port8050Process.StartTime
        Write-Result "   - 2PXE Service listening on port 8050"
    }
    else {
        Write-Result "$($port8050Process.Name) Service listening on port 8050" -LogLevel 3
    }

    if ($2PXEStartTime) {
        
    }

}

$iPXEChecks = $false
try {
    $iPXEService = Get-Service -Name "iPXEWS" -ErrorAction Stop
    Write-Result "iPXE Service Installed"
    if ($iPXEService.StartType -eq "Automatic") {
        Write-Result "   - iPXE Startype = Automatic"
    }
    else {
        Write-Result "   - iPXE Startype = $($iPXEService.StartType), should be Automatic" -LogLevel 2
    }
    if ($iPXEService.Status -eq "Running") {
        $iPXEChecks = $True
        Write-Result "   - iPXE Status = Running"
    }
    else {
        Write-Result "   - iPXE Status = $($iPXEService.Status)" -LogLevel 3
        Write-Result "iPXE Service not started, skipping 2PXE related checks" -LogLevel 2
    }
}
catch {
    Write-Result "iPXE Service not installed, skipping iPXE related checks" -LogLevel 2
}

if ($2PXEChecks) {
    [array]$port514 = Get-Process -Id (Get-NetUDPEndpoint -LocalPort 514).OwningProcess
    foreach ($port in $port514) {
        if ($port.Name -eq "iPXEAnywhere.Service") {
            Write-Result "   - iPXE Service listening on port 514"
        }
        else {
            Write-Result "$($port.Name) Service listening on port 514" -LogLevel 3
        }
    }
    #Get process from http.sys
    $port8051Process = Get-Process -Id $port8051
    if ($port8051Process.Name -eq "iPXEAnywhere.Service") {
        $iPXEStartTime = $port8051Process.StartTime
        Write-Result "   - iPXE Service listening on port 8051"
    }
    else {
        Write-Result "$($port8051Process.Name) Service listening on port 8051" -LogLevel 3
    }
    $port8052Process = Get-Process -Id $port8052
    if ($port8052Process.Name -eq "iPXEAnywhere.Service") {
        Write-Result "   - iPXE Service listening on port 8052"
    }
    else {
        Write-Result "$($port8052Process.Name) Service listening on port 8052" -LogLevel 3
    }

}

if ($2PXEChecks -and $2PXEStartTime) {
    if ([System.Diagnostics.EventLog]::Exists('2PXE')) {
        Write-Result "2PXE Eventlog Exists"
        Write-Result "2PXE Eventlog, checking events created after $2PXEStartTime"
        
        $outEvents = $false
        $events = Get-WinEvent -FilterHashtable @{LogName = '2PXE'; StartTime = $2PXEStartTime }
        $2PXEWarningCount = ($events.LevelDisplayName -eq "Warning").Count
        if ($2PXEWarningCount -le 14) {
            Write-Result "   - 2PXE EventLog, No Warnings"
        }
        else {
            $outEvents = $true
            Write-Result "   - 2PXE EventLog, Warnings found" -LogLevel 2
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
            $events | Where-Object { 1, 2, 3 -contains $_.Level } | Out-GridView -Title "2PXE Event issues"
        }
    }
}

if ($iPXEChecks -and $iPXEStartTime) {
    if ([System.Diagnostics.EventLog]::Exists('iPXE Anywhere WebService')) {
        Write-Result "iPXE Eventlog Exists"
        Write-Result "iPXE Eventlog, checking events created after $iPXEStartTime"
        
        $outEvents = $false
        $events = Get-WinEvent -FilterHashtable @{LogName = 'iPXE Anywhere WebService'; StartTime = $iPXEStartTime }
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
            $events | Where-Object { 1, 2, 3 -contains $_.Level } | Out-GridView -Title "iPXE Event issues"
        }
    }
}

#Check Firewall rules
if ($2PXEChecks) {
    Write-Result "2PXE Firewall Rules"
    try {
        $2PXEFirewallRule67 = Get-NetFirewallRule -DisplayName "2Pint Software 2PXE - DHCP Udp Ports:67" -ErrorAction stop
        Write-Result "   - 2PXE Firewall rule for DHCP UDP port 67"
        if ($port8051Process) {
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
        if ($port8051Process) {
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
        if ($port8051Process) {
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
