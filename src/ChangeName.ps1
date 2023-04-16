param(
    [string]$newHostname = "DC1"
)


#################################### HOSTNAME CONFIGURATION ##########################################
#######################################################################################################

$CurrentHostname = $env:computername | Select-Object

# Change the hostname
if ( $CurrentHostname -ne $NewHostname) {    
    Rename-Computer -NewName $NewHostname -Force -Restart:$false
    Write-Host "Successfull ! New hostname : $NewHostname" 
    Write-Host "Computer restart is needed !" -ForegroundColor Red
    Restart-Computer -Confirm
}
else {
    Write-Host "Hostname of this computer is already $NewHostname"
}