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


if($PostParams["nomenu"] -ne $null)
{

$Paramdata = $Paramdata + 
@"

param --params paramdata nomenu true
#This selects what gets deployed
#Note: The machine still has to have deployment in offerid targetting the device!!!
param --params paramdata offerid ABC2000B
#Prompt or no prompt
param --params paramdata mandatory true

"@

}

$menu = @"
#!ipxe

#set debug true

#This calls the default param set named paramdata used in posts
$Paramdata

#Set the override to allow the 2PXE server to bypess the WS execution
param --params paramdata wsoverride 1 ||

#get existing object
#get all params from CM
#get all params from some other DB

#add to db
#wipe record
#build as new system


#If one wanted you could provide a menu of all servers to select from here.
set completeurl `${pxeurl}2PXE/boot##params=paramdata
echo `${completeurl}
chain `${completeurl} || 
set cmerr `${errno}
echo Call to CM failed or returned, exiting out.
prompt ||
exit 1

"@



return $menu