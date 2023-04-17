## WARNING ! Assuming this server is on a domain, with grps/OU configured

param (
    [char]$Letter = 'E',
    [string]$domainName = "isec.local",
    [string]$ProfilesFolderName = "Profils_Utilisateurs",
    [string]$DataFolderName = "Commun",
    [string]$DirectionFolderName = "Direction",
    [string]$CommunicationFolderName = "Communication",
    [string]$InformatiqueFolderName = "Informatique",
    [string]$ComptaFolderName = "Comptabilité",
    [string]$RDFolderName = "R&D"
)

# Just checking if folder exists. If not, create it
function Create-Folder {
    param (
        [string]$FolderName,
        [string]$FolderPath
    )
    if (Test-Path -Path ($FolderPäth + "\" + $FolderName)) {
        New-Item -ItemType Directory -Name $FolderName -Path $FolderPäth | Out-Null
        Write-Host "[$FolderName] created." -ForegroundColor Green
    } else {
        Write-Host "[$FolderName] already exists." -ForegroundColor Green
    }
}


# If folder is shared then remove the share and share it again. If not share then just share it
function Share-Folder {
    param (
        [string]$FolderName,
        [string]$FolderPath
    )
    $Path = $FolderPath + $FolderName
    $ProfilesShared = Get-SmbShare -Name $FolderName 2>$null
    if ($ProfilesShared) {
        Remove-SmbShare -InputObject $ProfilesShared -Confirm:$false
    }
    New-SmbShare -Path $Path -FullAccess "Administrateurs" -Name $FolderName -CachingMode None | Out-Null
    Write-Host "[$Path] is shared."
}

# This function reset acl on a folder, and create new access rights with a list
function Set-ACLList {
    param (
        $Folder,
        $FolderOwner,
        $AccessRuleList
    )
    $Account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $FolderOwner;

    Set-Acl -Path $Folder -AclObject (New-Object System.Security.AccessControl.DirectorySecurity)
    $acl = Get-Acl -Path $Folder
    try { $acl.SetOwner($Account) } 
    catch { Write-Host "# ERROR # Impossible to set owner [$FolderOwner] to [$Folder]. Did you set your AD properly ?" -ForegroundColor Red}
    $acl.SetAccessRuleProtection($true,$false)
    foreach ($ar in $AccessRuleList) {
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($ar)
        $acl.SetAccessRule($AccessRule)
    }
    $acl | Set-Acl $Folder
}

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



################################## SHARE CONFIGURATION ################################################
#######################################################################################################

Write-Host
Write-Host "############## SHARE CONFIGURATION START ##############"


$ProfilesFolderPath = $Letter + ":\" 
$ProfilesFolder = $ProfilesFolderPath + $ProfilesFolderName
$DataFolderPath = $Letter + ":\"
$DataFolder = $DataFolderPath + $DataFolderName
$DirectionFolder = $DataFolder + "\" + $DirectionFolderName
$CommunicationFolder = $DataFolder+ "\" +$CommunicationFolderName
$InformatiqueFolder = $DataFolder + "\" + $InformatiqueFolderName
$ComptaFolder = $DataFolder + "\" +$ComptaFolderName
$RDFolder = $DataFolder + "\" + $RDFolderName


# Folders creation
Create-Folder -FolderName $ProfilesFolderName -FolderPath $ProfilesFolderPath
Create-Folder -FolderName $DataFolderName -FolderPath $DataFolderPath
Create-Folder -FolderName $DirectionFolderName -FolderPath $DataFolder
Create-Folder -FolderName $CommunicationFolderName -FolderPath $DataFolder
Create-Folder -FolderName $InformatiqueFolderName -FolderPath $DataFolder
Create-Folder -FolderName $ComptaFolderName -FolderPath $DataFolder
Create-Folder -FolderName $RDFolderName -FolderPath $DataFolder

# Sharing folders
Share-Folder -FolderName $DataFolderName -FolderPath $DataFolderPath
Share-Folder -FolderName $ProfilesFolderName -FolderPath $ProfilesFolderPath

# Grant group access to shares
Grant-SmbShareAccess -Name $ProfilesFolderName -AccountName "GDL_ProfilsItinerants" -AccessRight Change -Confirm:$false | Out-Null
Grant-SmbShareAccess -Name $DataFolderName -AccountName "GDL_Direction_Partage", "GDL_Comptabilite_Partage", "GDL_Communication_Partage", `
                "GDL_Informatique_Partage", "GDL_RD_Partage" -AccessRight Change -Confirm:$false | Out-Null


# ACL configuration
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
