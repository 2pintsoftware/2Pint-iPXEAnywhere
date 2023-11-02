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


$File = [System.IO.FileInfo]::new("c:\Windows\System32\sc.exe")

return $File

