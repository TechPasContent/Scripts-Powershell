param (
    [string]$domainName = "isec.local",
    [string]$ProfilePath = "\\DB1.isec.local\Profils_Utilisateurs\%username%"

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

############################# USERS, GRP, OU CONFIGURATION ############################################
#######################################################################################################

Write-Host
Write-Host "############## AD CONFIGURATION START ##############"



$DCa = $domainName.Split(".")[1]
$DCb = $domainName.Split(".")[0]
$ErrorActionPreference = 'SilentlyContinue'
$bProtectedFromAccidentalDeletion = $false

# OU configuration
$rootPath = "DC=$DCb, DC=$DCa"
$OUUtilisateurs = "OU=Utilisateurs, $rootPath"
$OUDirection = "OU=Direction, $OUUtilisateurs"
$OURD = "OU=R&D, $OUUtilisateurs"
$OUInformatique = "OU=Informatique, $OUUtilisateurs"
$OUCommunication = "OU=Communication, $OUUtilisateurs"
$OUComptabilite = "OU=Comptabilite, $OUUtilisateurs"
$OUPostesClients = "OU='Postes Clients', $rootPath"
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


function Set-ADConfiguration {
    $AccountPassword = Read-Host -AsSecureString "Users password. One for all !"
    # Add OU
    New-ADOrganizationalUnit -Path $rootPath -Name "Utilisateurs" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
    New-ADOrganizationalUnit -Path $OUUtilisateurs -Name "Direction" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
    New-ADOrganizationalUnit -Path $OUUtilisateurs -Name "R&D" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
    New-ADOrganizationalUnit -Path $OUUtilisateurs -Name "Informatique" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
    New-ADOrganizationalUnit -Path $OUUtilisateurs -Name "Communication" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
    New-ADOrganizationalUnit -Path $OUUtilisateurs -Name "Comptabilité" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
    New-ADOrganizationalUnit -Path $rootPath -Name "Postes Clients" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
    New-ADOrganizationalUnit -Path $rootPath -Name "Groupes" -ProtectedFromAccidentalDeletion $bProtectedFromAccidentalDeletion
    Write-Host "OU configured successfully." -ForegroundColor Green

    # Add Groups
    foreach ($g in $Groups){
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
}

$ActualOU = Get-ADOrganizationalUnit -Filter * | Where-Object {$_.Name -notmatch "poste*" -and $_.Name -notmatch "domain*"}

if ($ActualOU) {
    Write-Host "Configured Organizational Unit Found !" -ForegroundColor Red
    foreach ($ou in $ActualOU) {
        $print = $ou.Name
        Write-Host "[OU] $print"
    }
    switch ((Read-HostQMC -AnswersList "y","n" -Message "Delete non default OU found (y/n)")) {
        {$_ -eq "y"} {
            foreach ($ou in $ActualOU) { 
            $ouName = $ou.Name
            Remove-ADOrganizationalUnit -Identity $ou.DistinguishedName-Recursive -Confirm:$false
            Write-Host "OU [$ouName] completely removed." -ForegroundColor Red
        }
    } {$_ -eq "n"} {
           
        }
    }    
}

Set-ADConfiguration

Write-Host "############## AD CONFIGURATION END ##############"
