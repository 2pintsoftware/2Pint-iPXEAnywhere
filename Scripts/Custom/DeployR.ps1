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

$2pxeserver = 'https://server.company.com:8050/2PXE/File/Boot/'
$deployrserver = 'https://server.company.com:7281/Content/Boot/'

$menu = @"
#!ipxe

# Uncomment below row if you want to disable branchcache peering. Will increase the download speed in environments with peering is disabled.
# set peerdist 0

set 2pxeserver $2pxeserver || shell
set deployrserver $deployrserver || shell
$paramdata
initrd --name wimboot `${2pxeserver}wimboot.x86_64.efi##params=paramdata wimboot || shell
initrd --name BCD `${deployrserver}BCD BCD || shell
initrd --name boot.wim `${deployrserver}winpe_amd64.wim boot.wim || shell
kernel wimboot gui || shell
boot || shell

"@


return $menu
