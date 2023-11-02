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

$menu = @"
#!ipxe
#default section to set some key variable such as pictures etc.

#set debug true

#This calls the default param set named paramdata used in posts
$Paramdata

:start
menu iPXE Anywhere build menu
item --gap --          -------------------------------- Please choose an action           ------------------------  
item --key m configmgr Build with ConfigMgr
item --gap --          --------------------------------                Advanced           ------------------------
item reboot            Reboot the computer
item
item --key x exit      Exit and continue boot order
choose --timeout 30000 --default exit selected || goto cancel
goto `${selected}


:configmgr
chain -ar `${wsurl}/script?scriptname=configmgr/defaultconfigmgr.ps1##params=paramdata || shell

goto start

:reboot
reboot

:exit
#This only works if the computer is set to always try PXE first and the drive is set as second. If drive is set to number one and using F12 to PXE-boot change this to "reboot" instead.
exit 1

"@

return $menu