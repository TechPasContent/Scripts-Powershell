$domainName = (Get-Content .\general.conf)[10].Split()[2]

################################### AUTHORIZE DHCP SERVER #############################################
#######################################################################################################

Write-Host
Write-Host "############## DHCP AUTHORISATION START ##############"

$FQDN = (hostname) + "." + $domainName
Add-DhcpServerInDC -DnsName $FQDN
Write-Host "DHCP Server successully authorized on this Domain controller" -ForegroundColor Green

Write-Host "############## DHCP AUTHORISATION END ##############"

############################# USERS, GRP, OU CONFIGURATION ############################################
#######################################################################################################
Write-Host
Write-Host "############## AD CONFIGURATION START ##############"

$ErrorActionPreference = 'SilentlyContinue'

# Protected from accidental deletion for OU
$bProtectedFromAccidentalDeletion = $false

# OU configuration
$rootPath = "DC=isec, DC=local"
$OUUtilisateurs = "OU=Utilisateurs, $rootPath"
$OUDirection = "OU=Direction, $OUUtilisateurs"
$OURD = "OU=R&D, $OUUtilisateurs"
$OUInformatique = "OU=Informatique, $OUUtilisateurs"
$OUCommunication = "OU=Communication, $OUUtilisateurs"
$OUComptabilite = "OU=Comptabilite, $OUUtilisateurs"
$OUPostesClients = "OU='Postes CLients', $rootPath"
$OUGroupes = "OU=Groupes, $rootPath"

# Users @(OU, Name, SamAccountName, Groups) 
$Users = @(
    @($OUComptabilite, "Michel BONNET", "bonnetm", @("GG_Comptabilite")),
    @($OUComptabilite, "Sarah MOULA", "moulas", @("GG_Comptabilite")),
    @($OUCommunication, "Alexis BAVARD", "bavarda", @("GG_Communication")),
    @($OUCommunication, "Aurelie PUB", "puba", @("GG_Communication")),
    @($OUInformatique, "Jean-Michel GEEK", "geekj", @("GG_Informatique")),
    @($OUInformatique, "Abdelhalim MMORPG", "mmorpga", @("GG_Informatique")),
    @($OURD, "Bob RECHERCHE", "rechercheb", @("GG_RD")),
    @($OURD, "Boubakar DESTRUCTION", "destructionb", @("GG_RD")),
    @($OUDirection, "Richard DIRIGEUR", "dirigeurr", @("GG_Direction")),
    @($OUDirection, "Gollum ACCOLYTE", "accolyteg",@("GG_Direction"))
    )
# Groups
$Groups = @("GG_Paris", "GG_LeHavre", "GG_Toulouse", "GG_Bordeaux",`
				"GG_Comptabilite", "GG_Communication", "GG_Informatique", "GG_RD", "GG_Direction", `
                "GDL_Direction_Partage", "GDL_Comptabilite_Partage", "GDL_Communication_Partage", `
                "GDL_Informatique_Partage", "GDL_RD_Partage", `
								"GDL_ProfilsItinerants")

# User configuration
$AccountPassword = Read-Host -AsSecureString "Users password. One for all !"
$ProfilePath = "\\$FQDN\Profils$\%username%"

# Add OU
New-ADOrganizationalUnit -Path $rootPath -Name "Utilisateurs" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
New-ADOrganizationalUnit -Path $OUUtilisateurs -Name "Direction" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
New-ADOrganizationalUnit -Path $OUUtilisateurs -Name "R&D" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
New-ADOrganizationalUnit -Path $OUUtilisateurs -Name "Informatique" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
New-ADOrganizationalUnit -Path $OUUtilisateurs -Name "Communication" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
New-ADOrganizationalUnit -Path $OUUtilisateurs -Name "Comptabilité" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
New-ADOrganizationalUnit -Path $rootPath -Name "Postes CLients" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
New-ADOrganizationalUnit -Path $rootPath -Name "Groupes" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
Write-Host "OU configured successfully." -ForegroundColor Green

# Add Groups
foreach ($g in $GG){
		New-ADGroup -GroupScope Global -GroupCategory Security -Name $g -Path $OUGroupes
}
Write-Host "Groups configured successfully." -ForegroundColor Green

# Add Users
foreach ($u in $Users){
    New-ADUser -Path $u[0] -Name $u[1] -SamAccountName $u[2] `
        -AccountPassword (ConvertTo-SecureString -String $AccountPassword -AsPlainText -Force) `
        -Enabled $true -CannotChangePassword $true -PasswordNeverExpires $true `
        -ProfilePath $ProfilePath
    # Set users members of groups
    foreach ($g in $u[3]){
        Add-ADGroupMember -Identity $g -Members $u[2]
    }        
}
Write-Host "Users configured successfully." -ForegroundColor Green
Write-Host "Profile path of users : $ProfilePath"

# Add GG in GDL
Add-ADGroupMember -Identity GDL_Direction_Partage -Members GG_Direction
Add-ADGroupMember -Identity GDL_Comptabilite_Partage -Members GG_Comptabilite
Add-ADGroupMember -Identity GDL_Communication_Partage -Members GG_Communication
Add-ADGroupMember -Identity GDL_RD_Partage -Members GG_RD
Add-ADGroupMember -Identity GDL_Informatique_Partage -Members GG_Informatique
Add-ADGroupMember -Identity GDL_ProfilsItinerants -Members GG_Comptabilite, GG_Communication, GG_Informatique, GG_RD, GG_Direction
Write-Host "GG placed in GDL successfully." -ForegroundColor Green


# New joined computers redirection
C:\Windows\System32\redircmp.exe "OU=Postes Clients, DC=isec, DC=local" | Out-Null
Write-Host "New computer will automatically be placed under [$OUPostesClients]."

Write-Host "############## AD CONFIGURATION END ##############"


################################## SHARE CONFIGURATION ################################################
#######################################################################################################

#New-Item -ItemType Directory -Name 