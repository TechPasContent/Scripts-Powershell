param (
    [string]$domainName = "isec.local",
    [string]$InstallDNS = '$true'
)

if ($InstallDNS -eq '$true') {$bInstallDNS = $true}
if ($InstallDNS -eq '$false') {$bInstallDNS = $false}


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
}
$ComputerInfo = Get-ComputerInfo

if (("PrimaryDomainController", "BackupDomainController") -notcontains $ComputerInfo.CsDomainRole ) {
        
        if ($ComputerInfo.CsDomain -eq $domainName) {
            # Promute DC
            Install-ADDSDomainController -InstallDns:$bInstallDNS -DomainName $domainName -Force
            
            # Restart the Server
            Write-Host "Completely upgraded to DC. Restart the server to apply changes." -ForegroundColor Red
            pause
        } else {
            Write-Host "# ERROR # This server is not on the domain [$domainName]." -ForegroundColor Red
        }
        

} else {
    Write-Host "This server is already a DC." -ForegroundColor Green
}

Write-Host "############## AD END ##############"


