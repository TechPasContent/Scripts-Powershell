$DNS1 = (Get-Content .\general.conf)[1].Split()[2]
$DNS2 = (Get-Content .\general.conf)[2].Split()[2]
$InterfaceAlias = (Get-Content .\general.conf)[3].Split()[2]
$NewIp = (Get-Content .\general.conf)[4].Split()[2]
$NewMask = (Get-Content .\general.conf)[5].Split()[2]
$NewGateway = (Get-Content .\general.conf)[6].Split()[2]
$dhcpScopeStart = (Get-Content .\general.conf)[7].Split()[2]
$dhcpScopeEnd = (Get-Content .\general.conf)[8].Split()[2]
$dhcpSubnetMask = (Get-Content .\general.conf)[9].Split()[2]
$domainName = (Get-Content .\general.conf)[10].Split()[2]
$domainNetBIOSName = (Get-Content .\general.conf)[11].Split()[2]
$bInstallDNS = "$" + (Get-Content .\general.conf)[12].Split()[2]


#################################### INTERFACE CONFIGURATION ##########################################
#######################################################################################################
Write-Host
Write-Host "############## IPv4 START ##############"


# Check if the Interface Alias exists
$CurrentInterfaces = Get-NetAdapter 
$UserInput = $InterfaceAlias
if ($CurrentInterfaces.Name.Contains($InterfaceAlias)) {
    Write-Host "The interface '$InterfaceAlias' has been successfully found." -ForegroundColor Green
} else {
    while (-not $CurrentInterfaces.Name.Contains($UserInput) -or $UserInput -eq "") {
        Write-Host "Interface Alias parameter is not set correctly. No interface on this machine named '$UserInput'." -ForegroundColor Red
        Write-Host "Following interfaces are available : "
        foreach ($i in $CurrentInterfaces.Name) {
            Write-Host "# " -NoNewline
            Write-Host $i -ForegroundColor Green
        }
        $UserInput = Read-Host "Name of the interface to configure"
    }
    $InterfaceAlias = $UserInput   
}
  
Write-Host "Changing IP Address on $InterfaceAlias"
try { 
 
    # Flush the default gateway
	Remove-NetRoute -InterfaceAlias $InterfaceAlias -Confirm:$false -ErrorAction Ignore

	# Change the IP address  
    Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -Confirm:$false -ErrorAction Ignore
    New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $NewIp -PrefixLength $NewMask -DefaultGateway $NewGateway | Out-Null		
    Write-Host "New IP address" $NewIp "/" $NewMask -ForegroundColor Green

    # Change DNS
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNS1, $DNS2
    Write-Host "Configured DNS :" $DNS1 "," $DNS2
}
catch {
    Write-Host "An error occured" -ForegroundColor Red
    return
}

Write-Host "############## IPv4 END ##############"

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

# Configure DHCP settings
$dhcpServer = "localhost"
$dhcpScopeName = "Main DHCP pool"


# Check if the DHCP scope already exists
$existingScopes = Get-DhcpServerv4Scope -ComputerName $dhcpServer | Where-Object { $_.Name -like $dhcpScopeName }
if ($existingScopes) {
    Write-Host "DHCP scope '$dhcpScopeName' already exists." -ForegroundColor Yellow
} else {
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
}

Write-Host "############## DHCP END ##############"

########################################## AD SERVER ##################################################
#######################################################################################################

Write-Host
Write-Host "############## AD START ##############"

# Install Active Directory Feature
if ((Get-WindowsFeature -Name AD-Domain-Services).installed) {
    Write-Host "AD-DS Server is already installed."    
} else {
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Write-Host "AD-DS Role added to the server successfully" -ForegroundColor Green

    # Create a new forest
    Install-ADDSForest -DomainName $domainName -DomainNetBIOSName $domainNetBIOSName -SafeModeAdministratorPassword $adminPassword -Force -InstallDNS:$bInstallDNS
    Write-Host "New forest created successfully." -ForegroundColor Green

    # Restart the Server
    Restart-Computer -Confirm
}

Write-Host "############## AD END ##############"