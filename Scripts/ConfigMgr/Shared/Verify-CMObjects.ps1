<# 
    2Pint functions to Verify the CM Objects Status
    Version:        24.09.24
    Author:         @ 2Pint Software
    Creation Date:  2023-02-03
    Purpose/Change: Initial script development
    

#>


$CMSites = @(
    @{  
        Site = 'PS1'
        SiteDB = 'CM_PS1'
        Providers = @( 'CM01.corp.viamonstra.com' )
        SQL = 'CM01.corp.viamonstra.com'
    }
)


Function Verify-CMObjectUnknwon {
    <#
.SYNOPSIS
  Queries the CM DB and returns

.DESCRIPTION
  Queries a SQL database and returs the result

.PARAMETER SQLServerFQDN
    FQDN for the CM SQL server
    cmsql.contoso.org
    If not specified the value in CMServerFQDN will be used for SQL queries.

.PARAMETER SiteDB
    Name of the site DB
    
.INPUTS
    Not much

.OUTPUTS
    A string of "OK" if all is OK

.NOTES
  Version:        1.0
  Author:         @ 2Pint Software
  Creation Date:  2023-02-07
  Purpose/Change: Initial script development

.EXAMPLE
  
#>
    Param(
        [Parameter(Mandatory = $true)][string]$SMBIOSGUID,
        [Parameter(Mandatory = $true)][string]$MACAddress
    )
    Process {

        #region Load External support functions

        $scriptPath = "E:\Program Files\2Pint Software\iPXE AnywhereWS\Scripts"

        $CMFile = "$scriptPath\ConfigMgr\Shared\Manage-CMObjects.ps1" 

        if((Test-Path $CMFile) -eq $false)
        {
            throw [System.IO.FileNotFoundException] "Could not find: $CMFile"
        }

        #Load the main CM functions
        . $CMFile

        #endregion 

        foreach ( $CMSite in $CMSites ) 
        {
        Write-Host "Site: $CMSite"

            foreach ( $Provider in $CMSite.Providers ) 
            {

        
                $adminsvc =  $Provider        # Like: "CM01.corp.viamonstra.com";
                $SQLServerFQDN = $CMSite.SQL  # Like: "CM01.corp.viamonstra.com";
                $SiteDB = $CMSite.SiteDB      # Like: "CM_PS1";
                $SiteCode = $CMSite.Site      # Like: "PS1";

                #Write-Host "Provider: $adminsvc"
                #Write-Host "SQLServerFQDN: $SQLServerFQDN"
                #Write-Host "SiteDB: $SiteDB"
                #Write-Host "SiteCode: $SiteCode"

                $devicelookupSMBIOS = Get-CMObject -KeyIdentifier "SMBIOS" -Value "$SMBIOSGUID" -CMServerFQDN $adminsvc -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB -SiteCode $SiteCode -UseWMI
                $devicelookupMAC = Get-CMObject -KeyIdentifier "MACAddress" -Value "$MACAddress" -CMServerFQDN $adminsvc -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB -SiteCode $SiteCode -UseWMI


                if(($devicelookupMAC -eq $null) -or ($devicelookupSMBIOS -eq $null))
                {
                    #Failure
                    $errorData = @"
#!ipxe
echo Failed to query for records!
shell
"@
                    return $errorData;

                }
                #elseif(($devicelookupMAC -eq $false) -and ($devicelookupSMBIOS -eq $false))
                elseif($devicelookupSMBIOS -eq $false)
                {
                    # No record to delete return $true
                    break # COntinue with next server
                }
                elseif(((($devicelookupMAC -is [array]) -eq $false) -and (($devicelookupMAC -is [array]) -eq $false) -and ($devicelookupSMBIOS.ResourceId -eq $devicelookupMAC.ResourceId)) -or ($devicelookupSMBIOS.ResourceID -and $devicelookupMAC -eq $false))
                {
                    #Single reuturn from both resources that matches
                    $UUID = $devicelookupSMBIOS.SMSUniqueIdentifier.ToString();
                    #This means we dont have any client in there with the UUID or MAC, good to go, machine is unknown
                    try{
                    $removeRecord = Remove-CMObject -KeyIdentifier UUID -Value $UUID -UseWMI -CMServerFQDN $adminsvc -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB -SiteCode $SiteCode
                    }catch{}
                    #Write-Host "Reached the Remove-CMObject section"
                    
                    #              "Remove-CMObject -KeyIdentifier UUID -Value $UUID -UseWMI -CMServerFQDN $adminsvc -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB -SiteCode $SiteCode" | out-file "c:\temp\ws\cmd.txt"
                    if($removeRecord -eq $true)
                    {
                        #Success
                        break # COntinue with next server
                    }
                    else
                    {
                        $errorData = @"
#!ipxe
echo Failed to delete the record
shell
"@

                        return $errorData;
                    }
                }

                elseif ( (($devicelookupMAC -is [array]) -eq $true) -and (($devicelookupSMBIOS -is [array]) -eq $false) )
                {

                    foreach ( $dlMAC in $devicelookupMAC ) {
                        foreach ( $dlSMBIOS in $devicelookupSMBIOS ) {

                            if ( $dlSMBIOS.SMSUniqueIdentifier -eq $dlMAC.SMSUniqueIdentifier ) {
                                write-verbose "FOUND:  $( $devicelookupMAC.SMSUniqueIdentifier.ToString() )  and $( $devicelookupSMBIOS.SMSUniqueIdentifier.ToString()  )"

                                $UUID = $devicelookupSMBIOS.SMSUniqueIdentifier.ToString();
                                try{
                                    $removeRecord = Remove-CMObject -KeyIdentifier UUID -Value $UUID -UseWMI -CMServerFQDN $adminsvc -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB -SiteCode $SiteCode
                                }catch{}
                                

                                if($removeRecord -eq $true)
                                {
                                    #Success
                                    break # COntinue with next server
                                }
                                else
                                {
                                    $errorData = @"
#!ipxe
echo Failed to delete the record
shell
"@

                                    return $errorData;
                                }

                            }
                        }
                    }
                }

                elseif(($devicelookupSMBIOS[0].ResourceId -eq $null) -and ($devicelookupMAC[0].ResourceId -eq $null))
                {
                            $errorData = @"
#!ipxe
echo Too many records to deal with!
echo BIOS lookup found: $($devicelookupSMBIOS)
echo Mac lookup found: $($devicelookupMAC)
echo Please contact the Configuration Manager team with these details
shell
"@

                        return $errorData;
                }
                else
                {
                    if(($devicelookupSMBIOS.Count -eq 1) -and ($devicelookupMAC.Count -eq 1))
                    {
                        #Two conflicting records
                    }


                     $errorData = @"
#!ipxe
echo Resource ID's usings the same GUID: $($devicelookupSMBIOS.Count) ($SMBIOSGUID)
echo Resource ID's usings the MAC: $($devicelookupMAC.Count) ($MACAddress)
echo
echo First entries:
echo SMBIOS - $($devicelookupSMBIOS[0].ResourceId) - $($devicelookupSMBIOS[0].Name)
echo MAC - $($devicelookupMAC[0].ResourceId) - $($devicelookupMAC[0].Name)
shell
"@

                    return $errorData;
                    #Compare if SMBIOS entry is also the MAC entry
                    #If so, safe to whack it safely, if not, we return a screen
                    #Device is in DB, clear it Out

                }

            }

        }
        return $true
    }
}

# create alias to deal with typo
Set-Alias Verify-CMObjectUnknown Verify-CMObjectUnknwon 

#Verify-CMObjectUnknwon -SMBIOSGUID "10251B42-E829-F830-D924-225491D13C84" -MACAddress "00:50:56:9B:17:29"