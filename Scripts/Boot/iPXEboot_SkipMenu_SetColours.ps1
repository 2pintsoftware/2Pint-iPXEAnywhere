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

#This script will set custom background colours, skip the iPXE menu and go straight into the ConfigMgr menu

$menu = @"
#!ipxe
#default section to set some key variable such as pictures etc.

# Set Menu Colours

#Normal text (status text, etc), White with transparent background
cpair --foreground 7 0 ||

#Regular text, White with transparent background
cpair --foreground 7 1 ||

#Selected Items, White with red background
cpair --foreground 7 --background 1 2 ||

#Items, Cyan with transparent background
cpair --foreground 6 3 ||


#set debug true

#This calls the default param set named paramdata used in posts
$Paramdata

chain -ar `${wsurl}/script?scriptname=configmgr/defaultconfigmgr.ps1##params=paramdata || shell

"@
return $menu