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

#set peerdist $BCEnabled
$peerdedicatehost

#set debug true



:start
menu iPXE Anywhere build menu
item --gap --          -------------------------------- Please choose an action           ------------------------  
item --key u ubuntulive    Build Ubuntu Live ISO
item --key n netboot   Start Netboot
item --gap --          --------------------------------                Advanced           ------------------------
item reboot            Reboot the computer
item
item --key x exit      Exit and continue boot order
choose --timeout 30000 --default configmgr selected || goto cancel
goto `${selected}

:ubuntulive
set mirror http://dp01.corp.2pintsoftware.com/Linux/BaseOS/Ubuntu2204
kernel `${mirror}/casper/vmlinuz root=/dev/ram0 ramdisk_size=5500000 ip=dhcp url=http://dp01.corp.2pintsoftware.com/Linux/BaseOS/Ubuntu2204/ubuntu-22.04.3-desktop-amd64.iso
initrd `${mirror}/casper/initrd
shim   `${mirror}/EFI/BOOT/BOOTX64.EFI
boot

:netboot
# dhcp
console
chain --autofree https://boot.netboot.xyz

goto start

:reboot
reboot

:exit
exit 1

"@

return $menu