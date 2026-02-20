$CMDatabaseServerName = '2CM.2p.garytown.com' # Adjust if your SQL Server instance name differs
$DatabaseName = 'iPXEAnywhere35'
$TableName = 'dbo.RequestStatusInfo'

#region Functions
function Get-SqlTableRows {
    <#
    .SYNOPSIS
    Query a SQL Server table and return all rows as PowerShell objects.

    .DESCRIPTION
    Connects to a SQL Server database and runs a simple "SELECT * FROM [Table]" query.
    Returns each row as a PowerShell object with properties matching the table columns.

    .PARAMETER Server
    The SQL Server instance name or network address.

    .PARAMETER Database
    The database name to query.

    .PARAMETER Table
    The table name to query. Can include schema (e.g. "dbo.RequestStatusInfo").

    .PARAMETER Credential
    Optional PSCredential for SQL Server authentication. If not supplied and -UseIntegratedSecurity
    is specified, integrated security will be used.

    .PARAMETER UseIntegratedSecurity
    Use Windows Integrated Security (trusted connection).

    .PARAMETER CommandTimeout
    Command timeout in seconds. Default is 30.

    .EXAMPLE
    Get-SqlTableRows -Server 'sql01.contoso.local' -Database 'iPXEAnywhere35' -Table 'dbo.RequestStatusInfo' -UseIntegratedSecurity

    .EXAMPLE
    $cred = Get-Credential
    Get-SqlTableRows -Server 'sql01' -Database 'MyDB' -Table 'MySchema.MyTable' -Credential $cred

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Server,
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Table,
        [Parameter(Mandatory = $false)][System.Management.Automation.PSCredential]$Credential,
        [switch]$UseIntegratedSecurity,
        [int]$CommandTimeout = 30
    )

    begin {
        Add-Type -AssemblyName System.Data | Out-Null
    }

    process {
        $conn = $null
        try {
            if ($UseIntegratedSecurity -or -not $Credential) {
                $connString = "Server=$Server;Database=$Database;Integrated Security=True;"
            } else {
                $netCred = $Credential.GetNetworkCredential()
                $user = $netCred.UserName
                $pass = $netCred.Password
                $connString = "Server=$Server;Database=$Database;User Id=$user;Password=$pass;"
            }

            if ($Table -match '\.') {
                $parts = $Table -split '\.'
                $safeTable = ('[' + ($parts -join '].[') + ']')
            } else {
                $safeTable = "[$Table]"
            }

            $query = "SELECT * FROM $safeTable;"

            $dt = New-Object System.Data.DataTable

            $conn = New-Object System.Data.SqlClient.SqlConnection $connString
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = $query
            $cmd.CommandTimeout = $CommandTimeout
            $cmd.Connection = $conn

            $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $cmd

            $adapter.Fill($dt) | Out-Null

            foreach ($row in $dt.Rows) {
                $props = @{}
                foreach ($col in $dt.Columns) {
                    $props[$col.ColumnName] = $row[$col.ColumnName]
                }
                [PSCustomObject]$props
            }

        } catch {
            Write-Error "Failed to query $Server\\$Database.$Table : $_"
        } finally {
            if ($null -ne $conn) {
                try { if ($conn.State -eq 'Open') { $conn.Close() } } catch { }
                try { $conn.Dispose() } catch { }
            }
        }
    }
}
#endregion Functions

# Example invocation: adjust `-Server` if your instance name differs.
# This matches the screenshot's database/table: iPXEAnywhere35.dbo.RequestStatusInfo
$ErrorActionPreference = 'Stop'
try {
    $rows = Get-SqlTableRows -Server $CMDatabaseServerName -Database $DatabaseName -Table $TableName -UseIntegratedSecurity
    # Show a quick preview
    #$rows | Select-Object -First 10 | Format-Table -AutoSize
    # Uncomment to open a grid view or export to CSV
    # $rows | Out-GridView -Title 'RequestStatusInfo'
    # $rows | Export-Csv -Path "$PSScriptRoot\RequestStatusInfo.csv" -NoTypeInformation
} catch {
    Write-Error "Failed to retrieve RequestStatusInfo: $_"
}

# --- Reporting: last 12 months by BootStartDate ---
if ($null -eq $rows -or $rows.Count -eq 0) {
    Write-Warning 'No rows retrieved; skipping BootStartDate report.'
} else {
    # Determine date property
    $first = $rows | Select-Object -First 1
    $availableProps = $first.PSObject.Properties.Name
    if ($availableProps -contains 'BootStartDate') { $dateProp = 'BootStartDate' }
    elseif ($availableProps -contains 'BootStart') { $dateProp = 'BootStart' }
    else { Write-Warning 'No BootStartDate/BootStart property found on rows; skipping report.'; return }

    # Determine machine identifier property to count distinct machines when available
    $candidateMachineProps = @('Machine_Id','MachineId','DeployMAC','DeployMACAddress','MachineId64')
    $machineProp = $candidateMachineProps | Where-Object { $availableProps -contains $_ } | Select-Object -First 1

    $now = Get-Date
    $startMonth = (Get-Date -Year $now.Year -Month $now.Month -Day 1).AddMonths(-11)

    $report = for ($i = 0; $i -lt 12; $i++) {
        $mStart = $startMonth.AddMonths($i)
        $mEnd = $mStart.AddMonths(1).AddSeconds(-1)

        $monthRows = $rows | Where-Object {
            $val = $_.$dateProp
            if ($null -eq $val) { return $false }
            if ($val -is [datetime]) { $dt = $val } else {
                try { $dt = [datetime]::Parse([string]$val) } catch { $dt = $null }
            }
            if ($null -eq $dt) { return $false }
            ($dt -ge $mStart) -and ($dt -le $mEnd)
        }

        if ($machineProp) {
            $count = ($monthRows | Where-Object { $_.$machineProp -ne $null } | Select-Object -ExpandProperty $machineProp -Unique).Count
        } else {
            $count = $monthRows.Count
        }

        [PSCustomObject]@{
            Month = $mStart.ToString('yyyy-MM')
            MonthName = $mStart.ToString('yyyy MMM')
            Count = $count
        }
    }

    $total12 = ($report | Measure-Object -Property Count -Sum).Sum

    ''
    Write-Host "BootStartDate summary for last 12 months (by month):" -ForegroundColor Cyan
    $report | Format-Table Month,MonthName,Count -AutoSize
    Write-Host "`nTotal (last 12 months): $total12" -ForegroundColor Yellow

    # Optional: export report
    # $report | Export-Csv -Path "$PSScriptRoot\BootStartDate_Last12Months.csv" -NoTypeInformation
}


