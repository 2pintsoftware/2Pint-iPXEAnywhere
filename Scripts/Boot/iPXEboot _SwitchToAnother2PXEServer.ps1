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


$newServer = "https://dp03.corp.2PintSoftware.com:8050/"
$other2pxe = "$($newServer)2PXE/boot"

#We have to remove the key variables from the old environment to not confuse the new environment and mimic a new one.
#If one wants to automate the full end-end deployment from here, one can connect tot he WS URL auth part and create a record in the DB.
#The following command removes the wsurl, pxeurl and token parameters to that they are empty.
#If not, the new call from the new 2PXE server will use the wsurl variable which at this point is set to the old environment.
$ParamdataArray = ($Paramdata -split '\r\n') | Select-String -Pattern 'pxeurl', 'wsurl', 'tokenid', 'requestid', 'statusid', 'updatedparams' -NotMatch

#At this point we have an array of lines, so make it back to string via out-string
$NewParamdata = $ParamdataArray | Out-string

$menu = @"
#!ipxe
#default section to set some key variable such as pictures etc.

:start
menu iPXE Anywhere build menu
item --gap --          -------------------------------- Please choose an action           ------------------------  
item --key m configmgr Build with ConfigMgr
item --key l qa    Build with QA 2PXE system
item --gap --          --------------------------------                Advanced           ------------------------
item --key d mdop      Boot to MDOP image
item reboot            Reboot the computer
item
item --key x exit      Exit and continue boot order
choose --timeout 30000 --default configmgr selected || goto cancel
goto `${selected}


:configmgr
#This calls the default param set named paramdata used in posts
$Paramdata
chain `${wsurl}/script?scriptname=configmgr/defaultconfigmgr.ps1##params=paramdata || shell

:legacy
#We then add the pxeURL to the new server as it will otherwise be read by the $bootroot value and be stored under the wrong 2PXE server for the PXEURL value
#bootroot is set from the option 175 DHCP value
$NewParamdata
set bootroot $newServer
chain $other2pxe##params=paramdata
shell

goto start

:reboot
reboot

:exit
exit 1

"@

return $menu