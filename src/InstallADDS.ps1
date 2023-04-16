param (
    [string]$domainName = "isec.local",
    [string]$domainNetBIOSName = "ISEC",
    [string]$InstallForest = '$false',
    [string]$InstallDNS = '$true',
    [bool]$Promute = $true
)

if ($InstallForest -eq '$true') {$bInstallForest = $true}
if ($InstallForest -eq '$false') {$bInstallForest = $false}
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

if ($bInstallForest -and $ComputerInfo.CsDomainRole -ne "PrimaryDomainController") {
        # Create a new forest
        Write-Host "Installing a new forest [$domainName]"
        if ($bInstallDNS) {Write-Host "Installing DNS."}
        Install-ADDSForest -DomainName $domainName -DomainNetBIOSName $domainNetBIOSName -Force -InstallDNS:$bInstallDNS
        Write-Host "New forest [$domainName] created successfully." -ForegroundColor Green
        # Restart the Server
        Write-Host "Restart the computer to apply changes." -ForegroundColor Red
}

Write-Host "############## AD END ##############"


