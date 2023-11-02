param(
    $Request, 
    $ClaimsPrincipal, 
    $WindowsIdentity, 
    $QueryParams, 
    $PostParams
)

<#
$Request | ConvertTo-Json | Out-File "c:\temp\ws\Request.txt"
$ClaimsPrincipal | ConvertTo-Json | Out-File "c:\temp\ws\ClaimsPrincipal.txt"
$WindowsIdentity | ConvertTo-Json | Out-File "c:\temp\ws\WindowsIdentity.txt"
$QueryParams | ConvertTo-Json | Out-File "c:\temp\ws\QueryParams.txt"
$PostParams | ConvertTo-Json | Out-File "c:\temp\ws\PostParams.txt"
#>

if($WindowsIdentity.Name -eq "2pstest2\administrator")
{
    return $true;
}
    

return $false  

#Below code requires ActiveDirectory module to be installed.
#Import-Module ActiveDirectory

$user = $WindowsIdentity.Name
$group = "iPXE Anywhere Web Service"
$members = Get-ADGroupMember -Identity $group -Recursive | Select -ExpandProperty Name

If ($members -contains $user) {
      return $true;
 } Else {
        return $false;
}

