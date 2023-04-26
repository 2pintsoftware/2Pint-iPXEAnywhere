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
# Set Menu Colours
#Normal text (status text, etc), White with transparent background
cpair --foreground 7 0 ||
#Regular text, White with transparent background
cpair --foreground 7 1 ||
#Selected Items, White with red background
cpair --foreground 7 --background 1 2 ||
#Items, Cyan with transparent background
cpair --foreground 6 3 ||
#default section to set some key variable such as pictures etc.
set peerdist $BCEnabled
$peerdedicatehost
#set debug true
#This calls the default param set named paramdata used in posts
$Paramdata
:start
menu iPXE Anywhere build menu
item --gap --          -------------------------------- Please choose an action           ------------------------  
item --key p psd       Build from cloud (PSD)
item --gap --          --------------------------------                Advanced           ------------------------
item reboot            Reboot the computer
item
item --key x exit      Exit and continue boot order
choose --timeout 30000 --default exit selected || goto cancel
goto `${selected}
:psd
chain `${wsurl}/script?scriptname=PSD/psd.ps1##params=paramdata || shell
goto start
:reboot
reboot
:exit
exit 1
"@

return $menu