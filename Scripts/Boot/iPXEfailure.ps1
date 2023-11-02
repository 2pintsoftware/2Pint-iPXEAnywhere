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

#This script can be used to return a failure script to run if something goes very bad with the iPXE process.

$script = @"
#!ipxe
echo Roses are red, violets are blue
echo I don't sleep at night 'cause I'm thinking of you
echo Alone with my thoughts, trapped in this bed
echo Know I'd give the world just to see you boot again
"@

return $script