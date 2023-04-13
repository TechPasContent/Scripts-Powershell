$CurrentHostname = $env:computername | Select-Object
$NewHostname = (Get-Content .\general.conf)[0].Split()[2]
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