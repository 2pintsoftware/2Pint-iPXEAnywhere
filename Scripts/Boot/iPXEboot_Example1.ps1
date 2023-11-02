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

enum NetworkGroupType
{
    Regular = 0
    WellConnected = 1
    VPN = 2
    DataCenter = 8
    BuildDepot = 16
}


enum NetworkGroupFlags
{
    LocalInternetBreakOut = 4
    DisableGreenLeader = 16
    RoamingLocation = 32
    DirectRoute = 64
    MeasureOverridesTemplate = 128
    CentralSwitching = 256
    DisableBranchCacheForiPXE = 512
}

<#
# Uncomment this section to dump what is in the variables.
# This will be triggered everytime a machine boot so be aware of file growth

$Machine | ConvertTo-Json | Out-File C:\temp\ws\machine.txt -Append
$RequestStatusInfo | ConvertTo-Json | Out-File C:\temp\ws\RequestStatusInfo.txt -Append
$RequestNetworkInfo | ConvertTo-Json | Out-File C:\temp\ws\RequestNetworkInfo.txt -Append
$Machineinformation | ConvertTo-Json | Out-File C:\temp\ws\Machineinformation.txt -Append
$QueryParams | ConvertTo-Json | Out-File C:\temp\ws\QueryParams.txt -Append
$PostParams | ConvertTo-Json | Out-File C:\temp\ws\PostParams.txt -Append
$Paramdata | Out-File C:\temp\ws\Paramdata.txt -Append
$DeployMachineKeyValues | ConvertTo-Json | Out-File C:\temp\ws\DeployMachineKeyValues.txt -Append
$TargetMachineKeyValues | ConvertTo-Json | Out-File C:\temp\ws\TargetMachineKeyValues.txt -Append
$DeployLocation | ConvertTo-Json | Out-File C:\temp\ws\DeployLocation.txt -Append
$DeployNetworkGroup | ConvertTo-Json | Out-File C:\temp\ws\DeployNetworkGroup.txt -Append
$DeployNetwork | ConvertTo-Json | Out-File C:\temp\ws\DeployNetwork.txt -Append
$TargetLocation | ConvertTo-Json | Out-File C:\temp\ws\TargetLocation.txt -Append
$TargetNetworkGroup | ConvertTo-Json | Out-File C:\temp\ws\TargetNetworkGroup.txt -Append
$TargetNetwork | ConvertTo-Json | Out-File C:\temp\ws\TargetNetwork.txt -Append
#>

$BCEnabled = 0;
#Detect and set dedicated peerhost
#set peerhost 10.10.137.4
$peerdedicatehost = "echo Using distributed cache";

#Can be used to detect if we are switching URL
if($RequestNetworkInfo.PXEURL -ne $PostParams.pxeurl)
{

}

if($DeployNetworkGroup -ne $null)
{

    #Default settings can be read from the objects
    if($DeployNetworkGroup.Type -eq [NetworkGroupType]::BuildDepot)
    {   
        $BCEnabled = 0 
    }

    if($DeployNetworkGroup.NetworkGroupFlags -band [NetworkGroupFlags]::DisableBranchCacheForiPXE)
    {
        $BCEnabled = 0
    }



    if($false)
    {
        $peerdedicatehost = "set peerhost 10.10.137.4";
    }
        
}


if($RequestStatusInfo.OfferId)
{
    $customfastboot = @"
#!ipxe

#Set the picture here as this might take some time...
$Paramdata

console --picture `${pxeurl}2PXE/file/boot/wait.png##params=paramdata && || shell

#This calls the default param set named paramdata used in posts
$Paramdata
set peerdist $BCEnabled

$peerdedicatehost

#These are the required params to force a boot with no menu
param --params paramdata nomenu true

#This selects what gets deployed
#Note: The machine still has to have deployment in offerid targetting the device!!!
param --params paramdata offerid $RequestStatusInfo.OfferId

#Prompt or no prompt
param --params paramdata mandatory true

chain `${wsurl}/script?scriptname=configmgr/defaultconfigmgr.ps1##params=paramdata || shell

"@

    return $customfastboot

}


$menu = @"
#!ipxe
#default section to set some key variable such as pictures etc.

set peerdist $BCEnabled
$peerdedicatehost

#set debug true

#This calls the default param set named paramdata used in posts
$Paramdata

:start
menu iPXE Anywhere build menu
item --gap --          -------------------------------- Please choose an action           ------------------------  
item --key m configmgr Build with ConfigMgr
item --key l legacy    Build with legacy system
item --key w switch    Switch environment
item --key p psd       Build from cloud (PSD)
item --gap --          --------------------------------                Advanced           ------------------------
item --key d mdop      Boot to MDOP image
item reboot            Reboot the computer
item
item --key x exit      Exit and continue boot order
choose --timeout 30000 --default exit selected || goto cancel
goto `${selected}


:configmgr
chain -ar `${wsurl}/script?scriptname=configmgr/defaultconfigmgr.ps1##params=paramdata ||
echo ended up back in ipxeboot.ps1
prompt
exit 1

:switch
chain `${wsurl}/script?scriptname=custom/switchtoprod.ps1##params=paramdata || shell
goto start

:legacy
echo Not implemented
prompt
goto start

:psd
chain `${wsurl}/script/script?scriptname=psd/psd.ps1##params=paramdata || shell

goto start

:reboot
reboot

:exit
exit 1

"@

return $menu