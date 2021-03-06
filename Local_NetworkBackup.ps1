#Execute
###############################################################################################
# Backup local machine using environment_settings.xml
#
###############################################################################################

### Read in environment_settings.xml to get Domain and Admin info
Set-Location $PSScriptRoot
$localDir = $pwd.Path
$settingsXMLFile = $localDir + '\' + 'environment_settings.xml'
$xml = [xml](Get-Content $settingsXMLFile) # Read XML file
# Allow authentication

$cryptKey = $xml.environment.backupusersalt # get encryption key from XML settings file
$cryptedPass = $xml.environment.backupuserpass # get encrypted password from XML settings file
$rmtShare = '\\' + $xml.environment.backupserver + '\' + $xml.environment.backupshare
$bakUser = $xml.environment.backupuser

$backupBlock = [ScriptBlock]::Create({
    function backupToServer {
        [CmdletBinding()] Param(
            [Parameter(Position = 0, Mandatory = $true)]
            [String]$cryptedPass,
            [Parameter(Position = 1, Mandatory = $true)]
            [String]$cryptKey,
            [Parameter(Position = 2, Mandatory = $true)]
            [String]$backupUser,
            [Parameter(Position = 3, Mandatory = $true)]
            [String]$backupLocation
        )
        $backupTgt = (Get-WmiObject Win32_OperatingSystem).SystemDrive # Local OS drive
        function stringToBytes ($keybitstring){
            $bitsplits = $keybitstring.Split(',') # Convert string back into list
            $bitsplitn = @() # List to hold integers
            $bitsplits | ForEach-Object { $bitsplitn += [Int32]$_ } # Convert strings into Int32
            [Byte[]]$key = $bitsplitn
            return [Byte[]]$key
        }
        [Byte[]]$key = stringToBytes -keybitstring $cryptKey
        $encryptPass1 = [String]$cryptedPass | ConvertTo-SecureString -Key $key # Decrypt with key
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($encryptPass1) # rotate into store
        $backupPass = [String]([System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)) # get string value
        ## Backup to network
        #WBADMIN START BACKUP -backupTarget:$backupLocation -user:$backupUser -password:$backupPass -include:$backupTgt -allCritical -quiet -noInheritAcl
        WBADMIN START BACKUP -backupTarget:$backupLocation -user:$backupUser -password:$backupPass -include:$backupTgt -vssFull -allCritical -quiet -noInheritAcl
    }
})

$backupBlock2 = [ScriptBlock]::Create($backupBlock.ToString() + "backupToServer -cryptedPass `"" + $cryptedPass + "`" -cryptKey `"" + $cryptKey + "`" -backupUser `"" + $bakUser + "`" -backupLocation `"" + $rmtShare + "`"")

Write-Host "Backing up this PC ($env:COMPUTERNAME)..." -ForegroundColor Cyan
$backupJobName = "$env:COMPUTERNAME" + '_backup'

# Run backup in foreground
Invoke-Command -ScriptBlock $backupBlock2

# Run backup in background as job
#Invoke-Command -ScriptBlock $backupBlock2 -AsJob -JobName $backupJobName
