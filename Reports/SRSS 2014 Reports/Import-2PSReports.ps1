<#
.SYNOPSIS
    Import all 2Pint iPXE Anywhere reports (.rdl files) to a specific folder to a Reporting Service point
.DESCRIPTION
    Use this script to import all the reports (.rdl files) in the specified source path folder to a SSRS Reporting Server
.PARAMETER ReportServer (REQUIRED)
    Server where SQL Server Reporting Services are installed
.PARAMETER RootFolderName
    Defaults to '2Pint Software'
.PARAMETER FolderName
    Defaults to 'iPXE Anywhere Reports' - choose another if you like! If the folder exists it will be used,
    if it doesn't exist it will be created
.PARAMETER SourcePath
    Path to where .rdl files eligible for import are located - defaults to the current folder
.PARAMETER Credential
    PSCredential object created with Get-Credential or specify a username
.PARAMETER ShowProgress
    Show a progressbar displaying the current operation
.EXAMPLE
    .\Import-2PSReports.ps1 -ReportServer MyServer
    Imports all the reports in the current folder to a folder called '2Pint iPXE Reports' on a report server called 'MyServer'. 
    
    .\Import-2PSReports.ps1 -ReportServer MyServer -FolderName "Custom Reports" -SourcePath "C:\2Pint"
    Imports all the reports in 'C:\2Pint' to a folder called 'Custom Reports' on a report server called 'MyServer'. 

.NOTES
    Script name: Import-2PSeports.ps1
    Author:      Nickolaj Andersen
    Tweaks by 2Pint Software 
    Contact:     @2pintsoftware info@2pintsoftware.com
    DateCreated: 2014-11-26
    Updated: 2016-04-22
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [parameter(Mandatory=$true,HelpMessage="Site Server where SQL Server Reporting Services are installed")]
    [ValidateScript({Test-Connection -ComputerName $_ -Count 1})]
    [string]$ReportServer,
    [parameter(Mandatory=$false,HelpMessage="Need a folder name Dude!")]
    [string]$RootFolderName = "2PintSoftware",
    [parameter(Mandatory=$false,HelpMessage="If specified, search is restricted to within this folder if it exists")]
    [string]$FolderName= "iPXEAnywhere",
    [parameter(Mandatory=$false,HelpMessage="Path to where .rdl files are located - defaults to folder where script is run from")]
    [ValidateScript({Test-Path -Path $_ -PathType Container})]
    [string]$SourcePath = ".\",
    [Parameter(Mandatory=$false,HelpMessage="PSCredential object created with Get-Credential or specify an username")]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty,
    [parameter(Mandatory=$false,HelpMessage="Show a progressbar displaying the current operation")]
    [switch]$ShowProgress 
)
Begin {
    # Build the Uri
    $SSRSUri = "http://$($ReportServer)/ReportServer/ReportService2010.asmx"
    # Build the default or custom path for a Reporting Service point
    if ($RootFolderName -like "2PintSoftware") {
        $SSRSRootFolderName = -join ("/","$($RootFolderName)")
    }
    else {
        $SSRSRootFolderName = -join ("/","$($RootFolderName)")
    }
    # Build Server path
    if ($FolderName) {
        $SSRSRootPath = -join ($SSRSRootFolderName,"/",$FolderName)
    }
    else {
        $SSRSRootPath = $SSRSRootFolderName
    }
    #write-host $SSRSRootPath
    # Configure arguments being passed to the New-WebServiceProxy cmdlet by splatting
    $ProxyArgs = [ordered]@{
        "Uri" = $SSRSUri
        "UseDefaultCredential" = $true
    }
    if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
        $ProxyArgs.Remove("UseDefaultCredential")
        $ProxyArgs.Add("Credential", $Credential)
    }
    else {
        Write-Verbose -Message "Credentials was not provided, using default"
    }
    # Determine ShowProgress count
    if ($PSBoundParameters["ShowProgress"]) {
        $ProgressCount = 0
    }
}
Process {
    #try {
        # Functions
        function Create-Report {
            param(
            [parameter(Mandatory=$true)]
            [string]$FilePath,
            [parameter(Mandatory=$true)]
            [string]$ServerPath,
            [parameter(Mandatory=$true)]
            [bool]$ShowProgress
            )
            $RDLFiles = Get-ChildItem -Path $FilePath -Filter "*.rdl"
            $RDLFilesCount = ($RDLFiles | Measure-Object).Count
            if (($RDLFiles | Measure-Object).Count -ge 1) {
                foreach ($RDLFile in $RDLFiles) {
                    # Show progress
                    if ($PSBoundParameters["ShowProgress"]) {
                        $ProgressCount++
                        Write-Progress -Activity "Importing Reports" -Id 1 -Status "$($ProgressCount) / $($RDLFilesCount)" -CurrentOperation "$($RDLFile.Name)" -PercentComplete (($ProgressCount / $RDLFilesCount) * 100)
                    }
                    if ($PSCmdlet.ShouldProcess("Report: $($RDLFile.BaseName)","Validate")) {
                        $ValidateReportName = $WebServiceProxy.ListChildren($SSRSRootPath, $true) | Where-Object { ($_.TypeName -like "Report") -and ($_.Name -like "$($RDLFile.BaseName)") }
                    }
                    if ($ValidateReportName -eq $null) {
                        if ($PSCmdlet.ShouldProcess("Report: $($RDLFile.BaseName)","Create")) {
                            # Get the file name without the extension
                            $RDLFileName = [System.IO.Path]::GetFileNameWithoutExtension($RDLFile.Name)
                            # Read the content of the file as a byte stream
                            $ByteStream = Get-Content -Path $RDLFile.FullName -Encoding Byte
                            # Create an array that will contain any warning returned by the webservice
                            $Warnings = @()
                            # Create the Report
                            Write-Host "Importing report '$($RDLFileName)'"
                            $WebServiceProxy.CreateCatalogItem("Report",$RDLFileName,$SSRSRootPath,$true,$ByteStream,$null,[ref]$Warnings) | Out-Null
                        }
                        # Get name of iPXE data source
                        $iPXEDataSource = $WebServiceProxy.ListChildren("/", $true) | Where-Object {($_.Name -like "iPXE*") -and ($_.TypeName -like "DataSource")}
                        if ($iPXEDataSource -ne $null) {

                                # Get current Report that we recently created
                                $CurrentReport = $WebServiceProxy.ListChildren($SSRSRootFolderName, $true) | Where-Object { ($_.TypeName -like "Report") -and ($_.Name -like "$($RDLFileName)") -and ($_.CreationDate -ge (Get-Date).AddMinutes(-5)) }
                                $reportPath = $CurrentReport.Path
                                

                                # Determine namespace
                                $proxyNamespace = $WebServiceProxy.GetType().Namespace
                                
                               $myDataSource = New-Object ("$proxyNamespace.DataSource") 
                               $myDataSource[0].Name = $iPXEDataSource.Name
                               $myDataSource[0].Item = New-Object ("$proxyNamespace.DataSourceReference")
                               $myDataSource[0].Item.Reference = $iPXEDataSource.Path


                                # Set new data source for current report
                                Write-host "Changing data source for report: '$($RDLFileName)'"
                                $WebServiceProxy.SetItemDataSources($reportPath,  @($myDataSource))
                            
                        }
                        else {
                            Write-Warning -Message "Unable to determine default iPXE data source, will not edit data source for report '$($RDLFileName)'"
                        }
                    }
                    else {
                        Write-Warning -Message "A report with the name '$($RDLFile.BaseName)' already exists, skipping import"
                    }
                }
            }
            else {
                Write-Warning -Message "No .rdl files were found in the specified path"
            }
        }
        # Set up a WebServiceProxy
        $WebServiceProxy = New-WebServiceProxy @ProxyArgs -ErrorAction Stop
        if ($foldername) {
            Write-Verbose -Message "FolderName was specified"
            if ($WebServiceProxy.ListChildren("/", $true) | Select-Object ID, Name, Path, TypeName | Where-Object { ($_.TypeName -eq "Folder") -and ($_.Name -like "$($FolderName)") }) {
                Create-Report -FilePath $SourcePath -ServerPath $SSRSRootPath -ShowProgress $ShowProgress
            }
            else {

                    
                        Write-Host "Creating folder '$($RootFolderName)'"
                        # Get the namespace of the webservice
                        $TypeName = $WebServiceProxy.GetType().Namespace
                        # Create a property object and add some properties
                        $Property = New-Object -TypeName (-join ($TypeName,".Property"))
                        $Property.Name = "$($RootFolderName)"
                        $Property.Value = "$($RootFolderName)"
                        # We also need a Property array object defining the property object created earlier
                        $Properties = New-Object -TypeName (-join ($TypeName,".Property","[]")) 1
                        $Properties[0] = $Property
                        # Create the folders in SSRS
                        $WebServiceProxy.CreateFolder($RootFolderName,"/",$Properties) | Out-Null
                        #Create subfolder

                        $Property = New-Object -TypeName (-join ($TypeName,".Property"))
                        $Property.Name = "$($FolderName)"
                        $Property.Value = "$($FolderName)"
                        # We also need a Property array object defining the property object created earlier
                        $Properties = New-Object -TypeName (-join ($TypeName,".Property","[]")) 1
                        $Properties[0] = $Property
                        # Create the folders in SSRS
                        $WebServiceProxy.CreateFolder($FolderName,"$($SSRSRootFolderName)",$Properties) | Out-Null

                    Create-Report -FilePath $SourcePath -ServerPath $SSRSRootPath -ShowProgress $ShowProgress
                }
               # else {
                   # Write-Warning -Message "Unable to find a folder matching '$($FolderName)'"
               # }
            }
        
        else {
            Create-Report -FilePath $SourcePath -ServerPath $SSRSRootPath -ShowProgress $ShowProgress
        }
    }
    #catch [Exception] {
    #    Throw $_.Exception.Message
    #}
#}
End {
    if ($PSBoundParameters["ShowProgress"]) {
        Write-Progress -Activity "Importing Reports" -Completed -ErrorAction SilentlyContinue
    }
}