param (
    [string]$domainName = "isec.local"
)


####################################### JOIN DOMAIN  ##################################################
#######################################################################################################

$CurrentDomain = (Get-ComputerInfo).CsDomain

if ($CurrentDomain -ne $domainName) {
    Write-Host
    Write-Host "############## JOINING DOMAIN START ##############"

    Write-Host "Write a valid user/pass to join domain !" -ForegroundColor Green
    Add-Computer -DomainName $domainName -Restart:$false

    Write-Host "Domain [$domainName] joined !" -ForegroundColor Green
    Restart-Computer -Confirm:$true

    Write-Host "############## JOINING DOMAIN END ##############"
}
