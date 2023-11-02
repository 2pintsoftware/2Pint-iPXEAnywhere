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

$var = Find-DeviceInCM -bla
         

$menu = @"
#!ipxe

set debug true

#This calls the default param set named paramdata used in posts
$Paramdata

:start
menu iPXE Anywhere build menu
item --gap --          -------------------------------- Please choose an action           ------------------------  
item --key m configmgr Build with ConfigMgr
item --key l legacy    Build with legacy system
item --key p psd       Build from cloud (PSD)
item --gap --          --------------------------------                Advanced           ------------------------
item --key d mdop      Boot to MDOP image
item reboot            Reboot the computer
item
item --key x exit      Exit and continue boot order
choose --timeout 30000 --default exit selected || goto cancel
goto `${selected}


:configmgr
chain `${wsurl}/script/configmgr/boot.ps1##params=paramdata || shell


:legacy
echo Not implemented
prompt
goto start

:psd
chain `${wsurl}/script/psd/psd.ps1##params=paramdata || shell

goto start

:reboot
reboot

:exit
exit 1

"@



return $menu