param (
    [string]$domainName = "isec.local"
)


####################################### JOIN DOMAIN  ##################################################
#######################################################################################################

Write-Host
Write-Host "############## JOINING DOMAIN START ##############"

$stop = $false
while (-not $stop) {
    $CurrentDomain = (Get-ComputerInfo).CsDomain


    if ($CurrentDomain -eq $domainName) {
        Write-Host "Domain [$domainName] joined !" -ForegroundColor Green
        break
    }
    if (Test-Connection $domainName -Count 1 2>$null) {        
        
        Write-Host "Write a valid user/pass to join domain !" -ForegroundColor Green
        Add-Computer -DomainName $domainName -Restart:$true      
    }  else {
        Write-Host "Ping not received from $domainName" -ForegroundColor Red
    }
    
}

if ($CurrentDomain -eq $domainName) {
        Write-Host "This computer is on domain [$domainName]" -ForegroundColor Green      
    }


Write-Host "############## JOINING DOMAIN END ##############"