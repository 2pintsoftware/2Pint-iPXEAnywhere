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

# Define networks that are using a Hosted Cache server
$SydneyHCS = @("192.168.20.0","192.168.21.0")

if($SydneyHCS -contains $($RequestNetworkInfo.DeployNetwork.NetworkId))
{
    # Specify the Hosted Cache server and port, this will allow iPXE to get content from the HCS
	# On the HCS the authentication level must be set to "None" otherwise iPXE won't be allowed to get data from the HCS (since the computer is not yet joined to the domain)
	# iPXE cannot put any data into the HCS so the content must be precached prior to booting.
	$peerdedicatehost = "set peerhost 192.168.20.10:1337"
}

$MiamiHCS = @("192.160.20.0","192.160.21.0")

if($MiamiHCS -contains $($RequestNetworkInfo.DeployNetwork.NetworkId))
{
	$peerdedicatehost = "set peerhost 192.160.20.10:1337"
}

$menu = @"
#!ipxe
#default section to set some key variable such as pictures etc.

#set peerdist $BCEnabled
$peerdedicatehost

:start
menu iPXE Anywhere build menu
item --gap --          -------------------------------- Please choose an action           ------------------------  
item --key m configmgr Build with ConfigMgr
item --gap --          --------------------------------                Advanced           ------------------------
item --key d mdop      Boot to MDOP image
item reboot            Reboot the computer
item
item --key x exit      Exit and continue boot order
choose --timeout 30000 --default configmgr selected || goto cancel
goto `${selected}


:configmgr
#This calls the default param set named paramdata used in posts
$Paramdata
chain -ar `${wsurl}/script?scriptname=configmgr/defaultconfigmgr.ps1##params=paramdata || shell

goto start

:reboot
reboot

:exit
exit 1

"@

return $menu