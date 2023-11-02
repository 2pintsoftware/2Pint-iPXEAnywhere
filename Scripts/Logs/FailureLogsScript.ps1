#This script checks for the return of type  HttpStatusCode from System.Net

#always get the param data from request
param(
	[Parameter(Mandatory=$true)]$RequestHeaders,
	[Parameter(Mandatory=$true)]$QueryStrings
)

foreach ($key in $QueryStrings)
{
	Add-Content "c:\temp\querystrings.txt" "$key is $QueryStrings["$key"]"
}

#This is how you get the values saved to a text file
foreach ($key in $RequestHeaders)
{
	Add-Content "c:\temp\headers.txt" "$key is $RequestHeaders["$key"]"
}

#Get the info from the upload query params, such as network, machine name etc.
$ComputerName = $QueryStrings["ComputerName"]
$LogFilesRoot = "C:\Temp\LogFiles\Failures"
$LogFilesFolder = "$LogFilesRoot\$ComputerName"

New-Item -Path $LogFilesFolder -ItemType Directory

return $true

#The following headers are available by default

#This is the original URL used for the upload
#BITS-Original-Request-URL: http://10.10.11.51/FailureLogs/test4.txt
#File local path
#BITS-Request-DataFile-Name: C:\Logs\Failure\BITS-Sessions\Requests\Anonymous-Null\\{00D3C19D-0651-48CF-AF37-B056ECF990F0}\requestfile.bin
#Which response file
#BITS-Response-DataFile-Name: C:\Logs\Failure\BITS-Sessions\Replies\Anonymous-Null\\{00D3C19D-0651-48CF-AF37-B056ECF990F0}\responsefile.bin
#Other headers
#Connection: Keep-Alive
#Content-Length: 0
#Accept: */*
#Host: 192.168.1.9:8051
#User-Agent : BITSExts 1.5

$LogFilesZip = $RequestHeaders["BITS-Request-DataFile-Name"];

$exists = Test-Path -Path $LogFilesZip

if($exists -eq $true)
{
	Expand-Archive -Path $LogFilesZip -DestinationPath "$LogFilesFolder\Expanded"
	
	#Also stored the compressed file if we want it for attaching to Teams, emails etc.
	#Copy-Item -Path $LogFilesZip -DestinationPath "$LogFilesFolder\Compressed"
}

#Customer implementation
#Send email
#Notify teams channel
#Create bugs in system
#Lower your salary etc.

#Return true will make the process exit and the machine reboots
return $true

#Return false, the BITS job will fail with an error, and the machine will stay up
return $false