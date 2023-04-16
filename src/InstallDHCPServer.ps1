param(
    [string]$dhcpServer = "localhost",
    [string]$dhcpScopeName = "Main DHCP pool",
    [string]$dhcpScopeStart = "10.10.10.0",
    [string]$dhcpScopeEnd = "10.10.100.254",
    [string]$dhcpSubnetMask = "255.255.0.0",
    [string]$DNS1 = "10.10.0.1",
    [string]$DNS2 = "10.10.0.2"

)

########################################## DHCP SERVER ################################################
#######################################################################################################

Write-Host
Write-Host "############## DHCP START ##############"

# Install DHCP Server role
if ((Get-WindowsFeature -Name DHCP).installed) {
    Write-Host "DHCP Server is already installed."    
} else {
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
    Write-Host "DHCP Role added to the server successfully" -ForegroundColor Green
}


# Check if the DHCP scope already exists
$existingScopes = Get-DhcpServerv4Scope -ComputerName $dhcpServer
if ($existingScopes) {
    foreach ($scope in $existingScopes) {
        Remove-DhcpServerv4Scope -ScopeId $scope.ScopeId -Confirm:$false
    }
} 

# Add DHCP scope
Add-DhcpServerv4Scope -ComputerName $dhcpServer -Name $dhcpScopeName -StartRange $dhcpScopeStart -EndRange $dhcpScopeEnd -SubnetMask $dhcpSubnetMask
Write-Host "Scope [$dhcpScopeStart - $dhcpScopeEnd] added successfully." -ForegroundColor Green

# Get the IP address of the DHCP scope
$dhcpScope = Get-DhcpServerv4Scope -ComputerName $dhcpServer | Where-Object { $_.Name -eq $dhcpScopeName }
$dhcpScopeId = $dhcpScope.ScopeId

# Set DHCP scope options
Set-DhcpServerv4OptionValue -ComputerName $dhcpServer -ScopeId $dhcpScopeId -OptionId 6 -Value $DNS1, $DNS2  -Force  # DNS Servers
Set-DhcpServerv4OptionValue -ComputerName $dhcpServer -ScopeId $dhcpScopeId -OptionId 51 -Value 345600      # Lease Time (4 days)
Write-Host "Lease time set to 4 days"
Write-Host "DNS added : $DNS1, $DNS2"


Write-Host "############## DHCP END ##############"