param (
    # The name of VM/Computer, if Null or not in the list then it will ask the user which one to configure
    $VM = $null 
)

function Read-HostQMC {
    param (
        $AnswersList,
        $Message
    )
    while ($true) {
        $userInput = Read-Host $Message
        if ($AnswersList.Contains($userInput)) {
            return $userInput
        }
    }    
}

function Run-ThisScriptAtNextLogon {
    param (
        $VM = $null 
    )
    # Add a new scheduled task so the script will run at restart
    $ScriptPath = (Get-Item $PSCommandPath).FullName
    if ($VM) { $TaskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`" -VM `"$VM`"" }
    else {$TaskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`"" }
    $TaskTrigger = New-ScheduledTaskTrigger -AtLogOn
    $TaskPrincipal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    $TaskSettings = New-ScheduledTaskSettingsSet
    $Task = New-ScheduledTask -Action $TaskAction -Principal $TaskPrincipal -Trigger $TaskTrigger -Settings $TaskSettings
    Register-ScheduledTask -TaskName "RunScriptAtLogon" -InputObject $Task | Out-Null
}

function Remove-ThisScriptAtNextLogon {
    # Remove the scheduled task
    $TaskExists = Get-ScheduledTask -TaskName "RunScriptAtLogon" -ErrorAction SilentlyContinue
    if ($TaskExists) {
        Unregister-ScheduledTask -TaskName "RunScriptAtLogon" -Confirm:$false
    }
}


# Read content of config file
$NameDC1 = (Get-Content $PSScriptRoot\general.conf)[0].Split()[2]
$NameDB1 = (Get-Content $PSScriptRoot\general.conf)[1].Split()[2]
$NameDB2 = (Get-Content $PSScriptRoot\general.conf)[2].Split()[2]

$IPDC1 = (Get-Content $PSScriptRoot\general.conf)[4].Split()[2]
$IPDB1 = (Get-Content $PSScriptRoot\general.conf)[5].Split()[2]
$IPDB2 = (Get-Content $PSScriptRoot\general.conf)[6].Split()[2]
$Mask = (Get-Content $PSScriptRoot\general.conf)[7].Split()[2]
$Gateway = (Get-Content $PSScriptRoot\general.conf)[8].Split()[2]
$DNS1 = (Get-Content $PSScriptRoot\general.conf)[9].Split()[2]
$DNS2 = (Get-Content $PSScriptRoot\general.conf)[10].Split()[2]
$InterfaceAlias = (Get-Content $PSScriptRoot\general.conf)[11].Split()[2] 
if ((Get-Content $PSScriptRoot\general.conf)[11].Split()[3]) { $InterfaceAlias = $InterfaceAlias + " " + (Get-Content $PSScriptRoot\general.conf)[11].Split()[3] }

$DHCPScopeStart = (Get-Content $PSScriptRoot\general.conf)[13].Split()[2]
$DHCPScopeEnd = (Get-Content $PSScriptRoot\general.conf)[14].Split()[2]
$DHCPSubnetMask = (Get-Content $PSScriptRoot\general.conf)[15].Split()[2]
$dhcpScopeName = "Main DHCP pool"

$domainName = (Get-Content $PSScriptRoot\general.conf)[17].Split()[2]
$domainNetBIOSName = (Get-Content $PSScriptRoot\general.conf)[18].Split()[2]

$DriveLetter = (Get-Content $PSScriptRoot\general.conf)[20].Split()[2]
$DataFolderName = (Get-Content $PSScriptRoot\general.conf)[21].Split()[2]
$ProfilesFolderName = (Get-Content $PSScriptRoot\general.conf)[22].Split()[2]


# Ask the user which VM to configure
if ($VM -ne $NameDC1 -and $VM -ne $NameDB1 -and $VM -ne $NameDB2) {
    Write-Host "Which VM to configure ?"
    Write-Host "1# $NameDC1"
    Write-Host "2# $NameDb1"
    Write-Host "3# $NameDB2"
    switch (Read-HostQMC -AnswersList "1","2","3" -Message "Number") {
    
        #DC1
        {$_ -eq "1" } { $VM = $NameDC1 }

        #DB1
        {$_ -eq "2" } { $VM = $NameDB1 }

        #DB2
        {$_ -eq "3" } { $VM = $NameDB2 }
    }
}


Write-Host "$VM chosen." -ForegroundColor Green 
Remove-ThisScriptAtNextLogon
switch ($VM) {
    #DC1
    {$_ -eq $NameDC1 } {

        Run-ThisScriptAtNextLogon -VM $VM

        #Check the hostname
        if ((hostname) -ne $NameDC1) {
            powershell -File "$PSScriptRoot\src\ChangeName.ps1" -NewHostname $NameDC1
        }

        # Check if IP is already set or not
        $CurrentIP = Get-NetIPConfiguration
        if (-not ($CurrentIP.IPV4Address.IPAddress -eq $IPDC1 -and $CurrentIP.IPV4Address.PrefixLength -eq $Mask `
                -and $CurrentIP.DNSServer.ServerAddresses -contains $DNS1 -and $CurrentIP.DNSServer.ServerAddresses -contains $DNS1 )) {        
        
             powershell -File "$PSScriptRoot\src\InterfaceConfig.ps1" -NewIP $IPDC1 -DNS1 $DNS1 -DNS2 $DNS2 `
                    -InterfaceAlias $InterfaceAlias -NewMask $Mask -NewGateway $Gateway                  
        }

        # DHCP Server
        powershell -File "$PSScriptRoot\src\InstallDHCPServer.ps1" -dhcpScopeName $dhcpScopeName -dhcpScopeStart $DHCPScopeStart `
                    -dhcpScopeEnd $DHCPScopeEnd -dhcpSubnetMask $DHCPSubnetMask -DNS1 $DNS1 -DNS2 $DNS2
        
        # AD DS Server and forest
        powershell -File "$PSScriptRoot\src\InstallADDSAndForest.ps1" -domainName $domainName -domainNetBIOSName $domainNetBIOSName `
                    -InstallDNS '$true'
        
        # Authorize DHCP on DC            
        $FQDN = ((hostname)+"."+$domainName)
        powershell -File "$PSScriptRoot\src\AuthorizeDHCPonDC.ps1" -FQDN $FQDN
        
        # Users, Groups, OU configuration
        powershell -File "$PSScriptRoot\src\UsersGrpOU_configuration.ps1" -domainName $domainName -ProfilePath "\\$FQDN\$ProfilesFolderName\%username%"
        
        Remove-ThisScriptAtNextLogon

    }

    #DB1
    {$_ -eq $NameDB1 } {

        Run-ThisScriptAtNextLogon -VM $VM

        #Check the hostname
        if ((hostname) -ne $NameDB1) {
            powershell -File "$PSScriptRoot\src\ChangeName.ps1" -NewHostname $NameDB1
        }

        # Check if IP is already set or not
        $CurrentIP = Get-NetIPConfiguration
        if (-not ($CurrentIP.IPV4Address.IPAddress -eq $IPDB1 -and $CurrentIP.IPV4Address.PrefixLength -eq $Mask `
                -and $CurrentIP.DNSServer.ServerAddresses -contains $DNS1 -and $CurrentIP.DNSServer.ServerAddresses -contains $DNS1 )) {        
        
             powershell -File "$PSScriptRoot\src\InterfaceConfig.ps1" -NewIP $IPDB1 -DNS1 $DNS1 -DNS2 $DNS2 `
                -InterfaceAlias $InterfaceAlias -NewMask $Mask -NewGateway $Gateway                  
        }

        # Join Domain
        powershell -File "$PSScriptRoot\src\JoinDomain.ps1" -domainName $domainName


        # Install AD DS and promute DC
        powershell -File "$PSScriptRoot\src\InstallADDSAndPromuteDC.ps1" -domainName $domainName -InstallDNS '$true'

        # Share Installation
        powershell -File "$PSScriptRoot\src\ShareInstallation.ps1" -Letter $DriveLetter -ProfilesFolderName $ProfilesFolderName `
                 -DataFolderName $DataFolderName


        Remove-ThisScriptAtNextLogon
    }

    #DB2
    {$_ -eq $NameDB2} {
        if ((hostname) -eq $NameDB2) {
            Remove-ThisScriptAtNextLogon
        } else {
            Run-ThisScriptAtNextLogon -VM $VM
            powershell -File "$PSScriptRoot\src\ChangeName.ps1" -NewHostname $NameDB2
        }
        powershell -File "$PSScriptRoot\src\InterfaceConfig.ps1" -NewIP $IPDB2 -DNS1 $DNS1 -DNS2 $DNS2 -InterfaceAlias $InterfaceAlias -NewMask $Mask -NewGateway $Gateway 
    }
}
pause