param(
    [string]$InterfaceAlias = "Ethernet",
    [string]$NewIp = "10.10.0.1",
    [int]$NewMask = 16,
    [string]$NewGateway = "10.10.0.254",
    [string]$DNS1 = "10.10.0.1",
    [string]$DNS2 = "10.10.0.2",
    [string]$confFilePath = "$PSScriptRoot\..\general.conf"
)

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

    # Write new interfaceAlias in file
    if (Test-Path -Path $confFilePath) {
        $confFile = Get-Content -Path $confFilePath
        $confFile[11] = "InterfaceAlias = $InterfaceAlias"
        Set-Content -Path $confFilePath -Value $confFile
        Write-Host "Conf file modified with new interface name." -ForegroundColor DarkYellow
    } 
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