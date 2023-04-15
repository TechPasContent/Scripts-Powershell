$NewIp = (Get-Content .\general.conf)[4].Split()[2]
$domainName = (Get-Content $PSScriptRoot\general.conf)[10].Split()[2]
$Letter =(Get-Content $PSScriptRoot\general.conf)[13].Split()[2]
$domainName = (Get-Content $PSScriptRoot\general.conf)[10].Split()[2]
$DataFolderName = (Get-Content $PSScriptRoot\general.conf)[14].Split()[2]
$ProfilesFolderName = (Get-Content $PSScriptRoot\general.conf)[15].Split()[2]
$NewVolumeName = "Data"


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

################################### AUTHORIZE DHCP SERVER #############################################
#######################################################################################################

Write-Host
Write-Host "############## DHCP AUTHORISATION START ##############"

$FQDN = (hostname) + "." + $domainName
$CurretnDHCPInDC = Get-DhcpServerInDC
if ($CurretnDHCPInDC.IPAddress.IPAddressToString -eq $NewIP) {
    Write-Host "DHCP Server is already active in this DC."
} else {
    Add-DhcpServerInDC -DnsName $FQDN
    Write-Host "DHCP Server successully authorized on this Domain controller" -ForegroundColor Green
}


Write-Host "############## DHCP AUTHORISATION END ##############"


######################### CHECK VOLUME THAT STORE DATA OF AD USERS  ###################################
#######################################################################################################

Write-Host
Write-Host "############## CHECK VOLUME CONFIGURATION START ##############"

# Check if partition exists
$Partition =  Get-Partition | Where-Object DriveLetter -EQ $Letter
$Volume = Get-Volume | Where-Object DriveLetter -EQ $Letter
if ($Partition -or $Volume) {
    Write-Host -ForegroundColor Green "Partition [$Letter`:] successfully found."
} else {    
    Write-Host "[$Letter`:] has not been found." -ForegroundColor Red
    
    # Check if another letter is available
    $AvailableVolumes = Get-Volume | Where-Object {$_.DriveLetter -ne "C" -and $_.DriveLetter -ne $null -and $_.DriveLetter -ne "A" -and $_.DriveLetter -ne "B" -and $_.DriveType -eq "Fixed"}
    if ($AvailableVolumes) {
        Write-Host "Others volume found. Choose one to store AD users's data" -ForegroundColor DarkYellow
        $AvailableVolumes | Out-Default
        $stop = $false

        # Ask user which DriveLetter to use
        while (-not $stop) {
            $userInput = Read-Host "Volume to use (DriveLetter)"
            foreach ($l in $AvailableVolumes.DriveLetter) {
                if ($l -eq $userInput[0]) {
                    $Letter = $l
                    Write-Host "[$Letter`:] volume will store users data" -ForegroundColor Green
                    $stop = $true
                }
            }
        }
    } else {
        
        # Check if a disk is available
        $AvailableDisks = Get-Disk | Where-Object {-not $_.IsSystem} | Select-Object Number, FriendlyName, Size, AllocatedSize
        if ($AvailableDisks) {
            Write-Host "Additionnal disk(s) found."

            # Ask the user if disk can be partionned
            Write-Host "Following additionnal disk(s) are available."
            $AvailableDisks | Out-Default

            #Ask the user the disk to partition
            $stop = $false
            while (-not $stop) {
                $userInput = Read-Host "Number of the disk for data users"
                foreach ($d in $AvailableDisks.Number) {
                    $d = Convert-String -InputObject $d                
                    if ($userInput -eq $d) {
                        $chosenDisk = Get-Disk -Number $d
                        $stop = $true
                    }
                }
            }

            # Configure the disk
            switch ($chosenDisk) {
                {$_.PartitionStyle -eq 'raw'} {Initialize-Disk $chosenDisk.Number -PartitionStyle GPT}
                {$_.IsOffline -eq $true} {Set-Disk -InputObject $chosenDisk -IsOffline $false}
                {$_.IsReadOnly -eq $true} {Set-Disk -InputObject $chosenDisk -IsReadOnly $false} 
            }
            # Set Volume
            New-Volume -Disk $chosenDisk -DriveLetter $Letter -FriendlyName $NewVolumeName

        } else {
            Write-Host "No available disk has been found. Please insert one. Restart the script after this." -ForegroundColor Red
            return 
        }
    }    
}

Write-Host "############## CHECK VOLUME CONFIGURATION END ##############"


############################# USERS, GRP, OU CONFIGURATION ############################################
#######################################################################################################
Write-Host
Write-Host "############## AD CONFIGURATION START ##############"



$DC1 = $domainName.Split(".")[1]
$DC2 = $domainName.Split(".")[0]
$ErrorActionPreference = 'SilentlyContinue'
$bProtectedFromAccidentalDeletion = $false

# OU configuration
$rootPath = "DC=$DC2, DC=$DC1"
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

# User configuration
$ProfilePath = "\\$FQDN\$ProfilesSharedPath\%username%"


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




################################## SHARE CONFIGURATION ################################################
#######################################################################################################

Write-Host
Write-Host "############## SHARE CONFIGURATION START ##############"


$ProfilesFolderPath = $Letter + ":\" 
$ProfilesFolder = $ProfilesFolderPath + $ProfilesFolderName
$DataFolderPath = $Letter + ":\"
$DataFolder = $DataFolderPath + $DataFolderName
$DirectionFolderName = "Direction"
$DirectionFolder = $DataFolder + "\" + $DirectionFolderName
$CommunicationFolderName = "Communication"
$CommunicationFolder = $DataFolder+ "\" +$CommunicationFolderName
$InformatiqueFolderName = "Informatique"
$InformatiqueFolder = $DataFolder + "\" + $InformatiqueFolderName
$ComptaFolderName = "Comptabilité"
$ComptaFolder = $DataFolder + "\" +$ComptaFolderName
$RDFolderName = "R&D"
$RDFolder = $DataFolder + "\" + $RDFolderName

# Folders creation
New-Item -ItemType Directory -Name $ProfilesFolderName -Path $ProfilesFolderPath | Out-Null
Write-Host "$ProfilesFolderPath$ProfilesFolderName created"

New-Item -ItemType Directory -Name $DataFolderName -Path $DataFolderPath | Out-Null
Write-Host "$DataFolderPath$DataFolderName created"

New-Item -ItemType Directory -Name $DirectionFolderName -Path $DataFolder | Out-Null
Write-Host "$DirectionFolder created"

New-Item -ItemType Directory -Name $CommunicationFolderName -Path $DataFolder | Out-Null
Write-Host "$CommunicationFolder created"

New-Item -ItemType Directory -Name $InformatiqueFolderName -Path $DataFolder | Out-Null
Write-Host "$InformatiqueFolder created"

New-Item -ItemType Directory -Name $ComptaFolderName -Path $DataFolder | Out-Null
Write-Host "$ComptaFolder created"

New-Item -ItemType Directory -Name $RDFolderName -Path $DataFolder | Out-Null
Write-Host "$RDFolder created"

# Sharing folders
$DataShared = Get-SmbShare -Name $DataFolderName 2>$null
if ($DataShared) {
    Remove-SmbShare -InputObject $DataShared -Confirm:$false
}

$ProfilesShared = Get-SmbShare -Name $ProfilesFolderName 2>$null
if ($ProfilesShared) {
    Remove-SmbShare -InputObject $ProfilesShared -Confirm:$false
}

New-SmbShare -Path $ProfilesFolder -FullAccess "Administrateurs" -Name $ProfilesFolderName -CachingMode None | Out-Null
Grant-SmbShareAccess -Name $ProfilesFolderName -AccountName "GDL_ProfilsItinerants" -AccessRight Change -Confirm:$false | Out-Null
New-SmbShare -Path $DataFolder -FullAccess "Administrateurs" -Name $DataFolderName -CachingMode None | Out-Null
Grant-SmbShareAccess -Name $DataFolderName -AccountName "GDL_Direction_Partage", "GDL_Comptabilite_Partage", "GDL_Communication_Partage", `
                "GDL_Informatique_Partage", "GDL_RD_Partage" -AccessRight Change -Confirm:$false | Out-Null

# This function reset acl on a folder, and create new access rights with a list
function Set-ACLList {
    param (
        $Folder,
        $FolderOwner,
        $AccessRuleList
    )
    Set-Acl -Path $Folder -AclObject (New-Object System.Security.AccessControl.DirectorySecurity)
    $acl = Get-Acl -Path $Folder
    $acl.SetOwner($FolderOwner)
    $acl.SetAccessRuleProtection($true,$false)
    foreach ($ar in $AccessRuleList) {
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($ar)
        $acl.SetAccessRule($AccessRule)
    }
    $acl | Set-Acl $Folder
}

# Roaming profiles folder
$AccessRuleList = @(
        ("CREATEUR PROPRIETAIRE","FullControl","ContainerInherit, ObjectInherit", "InheritOnly","Allow"),
        ("BUILTIN\Administrateurs","FullControl","Allow"),
        ("AUTORITE NT\Système","FullControl", "ContainerInherit, ObjectInherit","None","Allow"),
        ("ISEC\GDL_ProfilsItinerants","AppendData, Synchronize","Allow")
)
Set-ACLList -Folder $ProfilesFolder -FolderOwner "BUILTIN\Administrateurs" -AccessRuleList $AccessRuleList

# Data folder
$AccessRuleList = @(
        ("CREATEUR PROPRIETAIRE","FullControl","ContainerInherit, ObjectInherit", "InheritOnly","Allow"),
        ("BUILTIN\Administrateurs","FullControl","Allow"),
        ("AUTORITE NT\Système","FullControl", "ContainerInherit, ObjectInherit","None","Allow")
)
Set-ACLList -Folder $DataFolder -FolderOwner "BUILTIN\Administrateurs" -AccessRuleList $AccessRuleList

# Direction folder
$AccessRuleList = @(
        ("CREATEUR PROPRIETAIRE","FullControl","ContainerInherit, ObjectInherit", "InheritOnly","Allow"),
        ("BUILTIN\Administrateurs","FullControl","Allow"),
        ("AUTORITE NT\Système","FullControl", "ContainerInherit, ObjectInherit","None","Allow"),
        ("ISEC\GDL_Direction_Partage","Write, ReadAndExecute, Synchronize","ContainerInherit, ObjectInherit","None","Allow")
)
Set-ACLList -Folder $DirectionFolder -FolderOwner "BUILTIN\Administrateurs" -AccessRuleList $AccessRuleList

# Communication folder
$AccessRuleList = @(
        ("CREATEUR PROPRIETAIRE","FullControl","ContainerInherit, ObjectInherit", "InheritOnly","Allow"),
        ("BUILTIN\Administrateurs","FullControl","Allow"),
        ("AUTORITE NT\Système","FullControl", "ContainerInherit, ObjectInherit","None","Allow"),
        ("ISEC\GDL_Communication_Partage","Write, ReadAndExecute, Synchronize","ContainerInherit, ObjectInherit","None","Allow")
)
Set-ACLList -Folder $CommunicationFolder -FolderOwner "BUILTIN\Administrateurs" -AccessRuleList $AccessRuleList

# Informatique folder
$AccessRuleList = @(
        ("CREATEUR PROPRIETAIRE","FullControl","ContainerInherit, ObjectInherit", "InheritOnly","Allow"),
        ("BUILTIN\Administrateurs","FullControl","Allow"),
        ("AUTORITE NT\Système","FullControl", "ContainerInherit, ObjectInherit","None","Allow"),
        ("ISEC\GDL_Informatique_Partage","Write, ReadAndExecute, Synchronize","ContainerInherit, ObjectInherit","None","Allow")
)
Set-ACLList -Folder $InformatiqueFolder -FolderOwner "BUILTIN\Administrateurs" -AccessRuleList $AccessRuleList

# Comptabilite folder
$AccessRuleList = @(
        ("CREATEUR PROPRIETAIRE","FullControl","ContainerInherit, ObjectInherit", "InheritOnly","Allow"),
        ("BUILTIN\Administrateurs","FullControl","Allow"),
        ("AUTORITE NT\Système","FullControl", "ContainerInherit, ObjectInherit","None","Allow"),
        ("ISEC\GDL_Comptabilite_Partage","Write, ReadAndExecute, Synchronize","ContainerInherit, ObjectInherit","None","Allow")
)
Set-ACLList -Folder $ComptaFolder -FolderOwner "BUILTIN\Administrateurs" -AccessRuleList $AccessRuleList

# R&D folder
$AccessRuleList = @(
        ("CREATEUR PROPRIETAIRE","FullControl","ContainerInherit, ObjectInherit", "InheritOnly","Allow"),
        ("BUILTIN\Administrateurs","FullControl","Allow"),
        ("AUTORITE NT\Système","FullControl", "ContainerInherit, ObjectInherit","None","Allow"),
        ("ISEC\GDL_RD_Partage","Write, ReadAndExecute, Synchronize","ContainerInherit, ObjectInherit","None","Allow")
)
Set-ACLList -Folder $RDFolder -FolderOwner "BUILTIN\Administrateurs" -AccessRuleList $AccessRuleList

Write-Host "Shared folders confirguration complete ! Access Rights are correctly configured." -ForegroundColor Green

Write-Host "############## SHARE CONFIGURATION END ##############"


pause