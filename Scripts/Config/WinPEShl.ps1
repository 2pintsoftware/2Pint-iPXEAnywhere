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
);

$architecture = "x64";
$configMgr = $false;

#determine if we are from ConfigMgr or standalone

#Standard x64 for both BIOS and UEFI
if($RequestStatusInfo["platform"] -eq "x64")
{
    $architecture = "x64";
}
elseif($RequestStatusInfo["platform"] -eq "i386")
{
    $architecture = "i386";
}
elseif($RequestStatusInfo["platform"] -eq "amd64")
{

}
else{

}

[string]$winpeshl = @"
[LaunchApps]
%SYSTEMDRIVE%\sms\bin\$architecture\TsProgressUI.exe,/register:winpe
%windir%\system32\Cmd.exe
%windir%\system32\iPXEWinPEClient.exe,/NetworkInit
%windir%\system32\iPXEWinPEClient.exe,/SkipNetworkInit
%SYSTEMDRIVE%\sms\bin\$architecture\TsBootShell.exe
%windir%\system32\iPXEWinPEClient.exe,/PostCheck

"@

return $winpeshl
