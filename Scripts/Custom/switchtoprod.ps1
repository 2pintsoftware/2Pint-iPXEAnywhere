param(
    $Machine, 
    $RequestStatusInfo, 
    $RequestNetworkInfo, 
    $Machineinformation, 
    $QueryParams, 
    $PostParams, 
    $Paramdata, 
    $DeployMachineKeyValues,
    $TargetMachineKeyValues,
    $DeployLocation,
    $DeployNetworkGroup,
    $DeployNetwork,
    $TargetLocation,
    $TargetNetworkGroup,
    $TargetNetwork
)

$newServer = "https://dp02.2pstest2.local:8050/"
$other2pxe = "$newServer2PXE/boot"

#We have to remove the key variables from the old environment to not confuse the new environment and mimic a new one.
#If one wants to automate the full end-end deployment from here, one can connect tot he WS URL auth part and create a record in the DB.
#The following command removes the wsurl, pxeurl and token parameters to that they are empty. 
#If not, the new call from the new 2PXE server will use the wsurl variable which at this point is set to the old environment.
$ParamdataArray = ($Paramdata -split '\r\n') | Select-String  -Pattern 'pxeurl', 'wsurl', 'tokenid', 'requestid', 'statusid', 'updatedparams'  -NotMatch
#At this point we have an array of lines, so make it back to string via out-string
$Paramdata = $ParamdataArray | Out-string


$menu = @"
#!ipxe

#This calls the default param set named paramdata used in posts
$Paramdata

#We then add the pxeURL to the new server as it will otherwise be read by the $bootroot value and be stored under the wrong 2PXE server for the PXEURL value
#bootroot is set from the option 175 DHCP value, so change it so we dont go back
set bootroot $newServer

:start
echo $other2pxe##params=paramdata
shell
chain $other2pxe##params=paramdata
shell
goto start

:exit
exit 1

"@


return $menu