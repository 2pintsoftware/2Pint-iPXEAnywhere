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

<#
# Uncomment this section to dump what is in the variables.
# This will be triggered everytime a machine boot so be aware of file growth

$Machine | ConvertTo-Json | Out-File C:\temp\ws\machine.txt -Append
$RequestStatusInfo | ConvertTo-Json | Out-File C:\temp\ws\RequestStatusInfo.txt -Append
$RequestNetworkInfo | ConvertTo-Json | Out-File C:\temp\ws\RequestNetworkInfo.txt -Append
$Machineinformation | ConvertTo-Json | Out-File C:\temp\ws\Machineinformation.txt -Append
$QueryParams | ConvertTo-Json | Out-File C:\temp\ws\QueryParams.txt -Append
$PostParams | ConvertTo-Json | Out-File C:\temp\ws\PostParams.txt -Append
$Paramdata | Out-File C:\temp\ws\Paramdata.txt -Append
$DeployMachineKeyValues | ConvertTo-Json | Out-File C:\temp\ws\DeployMachineKeyValues.txt -Append
$TargetMachineKeyValues | ConvertTo-Json | Out-File C:\temp\ws\TargetMachineKeyValues.txt -Append
$DeployLocation | ConvertTo-Json | Out-File C:\temp\ws\DeployLocation.txt -Append
$DeployNetworkGroup | ConvertTo-Json | Out-File C:\temp\ws\DeployNetworkGroup.txt -Append
$DeployNetwork | ConvertTo-Json | Out-File C:\temp\ws\DeployNetwork.txt -Append
$TargetLocation | ConvertTo-Json | Out-File C:\temp\ws\TargetLocation.txt -Append
$TargetNetworkGroup | ConvertTo-Json | Out-File C:\temp\ws\TargetNetworkGroup.txt -Append
$TargetNetwork | ConvertTo-Json | Out-File C:\temp\ws\TargetNetwork.txt -Append
$ClaimsPrincipal | ConvertTo-Json | Out-File "c:\temp\ws\ClaimsPrincipal.txt"
$WindowsIdentity | ConvertTo-Json | Out-File "c:\temp\ws\WindowsIdentity.txt"
#>

# This will automatically approve all devices on subnet "10.10.137.0"
# Use this on locations where there is physical access is limited and you want to skip the authentication meny.
if($DeployNetwork.NetworkId.ToString() -eq "10.10.137.0")
{
    	$RequestStatusInfo.Approved = $true;
		$RequestStatusInfo.ApprovedBy = "BuildCenter";
		return $RequestStatusInfo
}

#One can return the request object approved directly from here
#if($Machine.Id -eq 2)
#	return $RequestStatusInfo;


if($PostParams["authmethod"] -ne $null)
{
	$secretPin = 42
	if($PostParams["authvalue"] -eq $secretPin)
	{
		$RequestStatusInfo.Approved = $true;
		$RequestStatusInfo.ApprovedBy = "PowerShell";
		return $RequestStatusInfo
	}

	#If not we let the default auth work its way bacck to show the menu again
}

if($PostParams["authmethod"] -eq "adurl")
{
    if($PostParams["authvalue"] -eq "ok")
    {
        $RequestStatusInfo.Approved = $true;
        $RequestStatusInfo.ApprovedBy = "AD";
        return $RequestStatusInfo
    }
    #If not we let the default auth work its way back to show the menu again
}


$menu = @"
#!ipxe

#set debug true

#This calls the default param set named paramdata used in posts
$Paramdata

:start
menu iPXE Anywhere authentication menu
item --gap --          -------------------------------- Please choose how to authenticate ------------------------  
item --key q qr        Use a QR code
item --key u user      Username and password
item --key p pin       Use a pin
item --key r retry     Retry request
item --gap --          --------------------------------                Advanced           ------------------------
item --key c config    Run the config tool
item shell             Drop to the iPXE shell
item reboot            Reboot the computer
item
item --key x exit      Exit and continue boot order
choose --timeout 30000 --default retry selected || goto cancel
goto `${selected}

:retry
echo `${pxeurl}/2PXE/boot##params=paramdata
chain `${pxeurl}/2PXE/boot##params=paramdata || shell

:shell
echo Type exit to return to menu
shell
goto start

:qr
echo Not implemented
prompt
goto start

:user
login || goto start
imgfetch https://`${username:uristring}:`${password:uristring}@yourserver:6500/test.txt || goto start
param --params paramdata authmethod adurl
param --params paramdata authvalue ok
chain `${pxeurl}/2PXE/boot##params=paramdata || shell
goto start

:pin
echo -n Please provide a pin:
read authvalue
param --params paramdata authmethod pin
param --params paramdata authvalue `${authvalue}

#In the case of using 2PXE files we always have to go via the 2PXE server as proxy or it will not pick up the secure token.
chain `${pxeurl}/2PXE/boot##params=paramdata || shell

goto start

:reboot
reboot

:exit
exit 1

"@

return $menu
