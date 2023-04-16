param (
    [string]$FQDN = "DC1.isec.local"

)

################################### AUTHORIZE DHCP SERVER #############################################
#######################################################################################################
Write-Host
Write-Host "############## DHCP AUTHORISATION START ##############"


$CurretnDHCPInDC = Get-DhcpServerSetting
$CurrentIP = (Get-NetIPAddress).IPv4Address
if ($CurretnDHCPInDC.IsAuthorized) {
    Write-Host "DHCP Server is already authorized on DC."
} else {
    Add-DhcpServerInDC -DnsName $FQDN
    Write-Host "DHCP Server successully authorized on this Domain controller" -ForegroundColor Green
}

Add-DhcpServerSecurityGroup -ComputerName $FQDN
Restart-Service -Name DHCPServer
Set-ItemProperty –Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 –Name ConfigurationState –Value 2

Write-Host "############## DHCP AUTHORISATION END ##############"
