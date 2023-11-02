#always get the param data from request
param($RequestHeaders)
param($QueryStrings)


foreach ($key in $QueryStrings)
{
    Add-Content "c:\temp\querystrings.txt" $key
    Add-Content "c:\temp\querystrings.txt" $QueryStrings["$key"]
}

#This is how you get the values saved to a text file
foreach ($key in $RequestHeaders)
{
    Add-Content "c:\temp\headers.txt" $key
    Add-Content "c:\temp\headers.txt" $RequestHeaders["$key"]
}

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


return $true