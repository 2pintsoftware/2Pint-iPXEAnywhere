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

#We use StringBuilder for performance
$sb = [System.Text.StringBuilder]::new()

function InifyObject-Parameter {
    param (
        $Header,
        $Object
    )
    
    [void]$sb.AppendLine('[' + $Header + ']')
    
    if($Object.PsObject.Properties["Keys"] -ne $null)
    {
        foreach ($key in $Object.Keys) 
        { 
            [void]$sb.Append($key) 
            [void]$sb.Append('=')
            [void]$sb.AppendLine($($Object[$key]))
        }
        
        [void]$sb.AppendLine();
        return;
    }

    foreach($object_properties in $Object.PsObject.Properties)
    {
        if($object_properties.Value -like 'System.Data.Entity*') 
        {
            continue;
        }
        
        if($object_properties.Value -like 'iPXEAnywhere.Persistence.*') 
        {
            continue;
        }
        

        # Access the name of the property
        [void]$sb.Append($object_properties.Name) 
        #Write the .ini file =
        [void]$sb.Append('=')
        # Access the value of the property, note the AppendLine
        if($object_properties.TypeNameOfValue -like 'System.Collections.Generic.Dictionary*')
        {
            foreach ($key in $object_properties.Value.Keys) 
            { 
                [void]$sb.Append($key) 
                [void]$sb.Append(':')
                [void]$sb.Append($($object_properties.Value[$key]))
                [void]$sb.Append(',')
            }
     
            continue;
        }
        [void]$sb.AppendLine($object_properties.Value)
    }
    
    [void]$sb.AppendLine();
}
InifyObject-Parameter -Header iPXEVariables -Object $PostParams

InifyObject-Parameter -Header Machine -Object $Machine
InifyObject-Parameter -Header RequestStatusInfo -Object $RequestStatusInfo
InifyObject-Parameter -Header RequestNetworkInfo -Object $RequestNetworkInfo

InifyObject-Parameter -Header DeployNetworkRequest -Object $RequestNetworkInfo.DeployNetwork
InifyObject-Parameter -Header TargetNetworkRequest -Object $RequestNetworkInfo.TargetNetwork

InifyObject-Parameter -Header Machineinformation -Object $Machineinformation
InifyObject-Parameter -Header Model -Object $Machineinformation.Model

InifyObject-Parameter -Header DeployLocation -Object $DeployLocation
InifyObject-Parameter -Header TargetLocation -Object $TargetLocation
InifyObject-Parameter -Header DeployNetworkGroup -Object $DeployNetworkGroup
InifyObject-Parameter -Header TargetNetworkGroup -Object $TargetNetworkGroup
InifyObject-Parameter -Header DeployNetwork -Object $DeployNetwork
InifyObject-Parameter -Header TargetNetwork -Object $TargetNetwork

InifyObject-Parameter -Header DeployMachineKeyValues -Object $DeployMachineKeyValues
InifyObject-Parameter -Header TargetMachineKeyValues -Object $TargetMachineKeyValues

#$sb.ToString() | out-file 'c:\temp\var.ini'

return $sb.ToString()
