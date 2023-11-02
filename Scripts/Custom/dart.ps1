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

$toolserver = https://<FQDN.your.server.with.the.Dart.wim>

$menu = @"
#!ipxe

set toolroot $toolserver/DaRT/ || shell
initrd --name boot.sdi `${toolroot}boot.sdi boot.sdi || shell
initrd --name wimboot `${toolroot}wimboot.x86_64.efi wimboot || shell
initrd --name BCD `${toolroot}BCD BCD || shell
initrd --name boot.wim `${toolroot}boot.wim boot.wim || shell
kernel wimboot gui || shell
boot || shell

"@


return $menu