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




$toolserver = 'https://yourPSDServer/boot'

$menu = @"
#!ipxe
#This section is only needed if pulling from a non 2PXE server
params --name secureheader
param --params secureheader tokenid `${tokenid}
param --params secureheader requestid `${requestid}
param --params secureheader statusid `${statusid}
initrd --name cross.crt https://your2PXEServer.something.local:8050//2PXE/certificate/cross.crt##params=secureheader cross.crt
certstore cross.crt
#End of section
set toolroot $toolserver/ || shell
initrd --name boot.sdi `${toolroot}boot.sdi boot.sdi || shell
initrd --name wimboot `${toolroot}wimboot.x86_64.efi wimboot || shell
initrd --name BCD `${toolroot}BCD BCD || shell
initrd --name boot.wim `${toolroot}LiteTouchPE_x64.wim boot.wim || shell
kernel wimboot gui || shell
boot || shell

"@


return $menu