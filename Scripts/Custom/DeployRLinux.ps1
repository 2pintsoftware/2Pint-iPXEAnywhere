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

$deployrserver = 'https://deployr.company.com:7281/Content/Boot'

$menu = @"
#!ipxe
set kiosk $deployrserver/x64 

imgfree
kernel `${kiosk}/vmlinuz initrd=initrd.img root=live:`${kiosk}/squashfs.img nomodeset rhgb quiet rd.noverifyssl || shell
initrd `${kiosk}/initrd.img || shell
boot || shell

"@

return $menu
