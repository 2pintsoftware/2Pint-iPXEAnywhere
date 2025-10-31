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

$2pxeserver = 'https://server.company.com/Remoteinstall/Boot/'
$deployrserver = 'https://server.company.com:7281/Content/Boot/'

$menu = @"
#!ipxe
set 2pxeserver $2pxeserver || shell
set deployrserver $deployrserver || shell
initrd --name boot.sdi `${2pxeserver}boot.sdi boot.sdi || shell
initrd --name wimboot `${2pxeserver}wimboot.x86_64.efi wimboot || shell
initrd --name BCD `${deployrserver}BCD BCD || shell
initrd --name boot.wim `${deployrserver}winpe_amd64.wim boot.wim || shell
kernel wimboot gui || shell
boot || shell

"@


return $menu
