param(
    [Parameter(Mandatory=$true)]
    [string]
    $TenantName,

    [Parameter(Mandatory=$true)]
    [string]
    $SobrId,

    [Parameter(Mandatory=$true)]
    [string]
    $SourceExtentId,

    [Parameter(Mandatory=$true)]
    [string]
    $TenantFolder,

    [Parameter(Mandatory=$true)]
    [string]
    $TargetExtentId
)

Add-PSSnapin -Name VeeamPSSnapin

function Copy-StorageFiles
{
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [Veeam.Backup.Core.CExtendableRepository]
        $Sobr,

        [Parameter(Mandatory=$true)]
        [Veeam.Backup.Core.CRepositoryAccessor]
        $SourceExtentAccessor,

        [Parameter(Mandatory=$true)]
        [System.Collections.Generic.List[string]]
        $Files,

        [Parameter(Mandatory=$true)]
        [Veeam.Backup.Core.CRepositoryAccessor]
        $TargetExtentAccessor
    )

    $cloudBinEvacuatorType = [type]::GetType('Veeam.Backup.Core.CCloudBinEvacuator, Veeam.Backup.Core,
        Version=9.5.0.0, Culture=neutral, PublicKeyToken=bfd684de2276783a')
    $cloudBinEvacuatorArgs = @{
        repositoryAccessor = [Veeam.Backup.Core.CRepositoryAccessorFactory]::Create($Sobr);
        sourceExtent = $null;
        files = $null;
        session = [Veeam.Backup.Core.CBaseSession]::Get($VBRCurrentSessionId);
        tasksScheduler = $null;
        scanResultProvider = $null;
        storageTaskLogger = $null
    }
    $cloudBinEvacuator = [System.Activator]::CreateInstance(
        $cloudBinEvacuatorType,
        $cloudBinEvacuatorArgs.repositoryAccessor,
        $cloudBinEvacuatorArgs.sourceExtent,
        $cloudBinEvacuatorArgs.files,
        $cloudBinEvacuatorArgs.session,
        $cloudBinEvacuatorArgs.tasksScheduler,
        $cloudBinEvacuatorArgs.scanResultProvider,
        $cloudBinEvacuatorArgs.storageTaskLogger
    )
    $transferFileMethod = $cloudBinEvacuatorType.GetDeclaredMethod('TransferFile')

    $enableIntegrityStreams = [Veeam.Backup.Core.SVirtualSyntheticRepository]::IsVirtualSyntheticAvailableOnRepository(
        $TargetExtentAccessor.Repository
    )

    foreach ($file in $Files)
    {
        $sourceFilePath = [Veeam.Backup.Common.CFullPath]::FromString(
            $file,
            $SourceExtentAccessor.FileCommander,
            $true
        )
        try
        {
            $transferFileMethod.Invoke(
                $cloudBinEvacuator,
                @($sourceFilePath, $SourceExtentAccessor, $TargetExtentAccessor, $enableIntegrityStreams)
            )
        }
        catch
        {
            throw "Could not copy [$($sourceFilePath.Elements[-1])]."
        }
        
        Write-Host -Object "[$($sourceFilePath.Elements[-1])] has been copied."
    }
}

function Copy-Metadata
{
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [Veeam.Backup.Core.CRepositoryAccessor]
        $SourceExtentAccessor,

        [Parameter(Mandatory=$true)]
        [string]
        $SourceFilePath,

        [Parameter(Mandatory=$true)]
        [Veeam.Backup.Core.CRepositoryAccessor]
        $TargetExtentAccessor,

        [Parameter(Mandatory=$true)]
        [string]
        $TargetFilePath
    )

    $sourceMetaFileArgs = @{
        fileComm = $SourceExtentAccessor.FileCommander;
        filePath = [Veeam.Backup.Common.CFullPath]::FromString(
            $SourceFilePath,
            $SourceExtentAccessor.FileCommander,
            $true
        );
        type = [Veeam.Backup.Core.CBackupMetaType]::Vbm
    }
    $sourceMetaFile = New-Object -TypeName Veeam.Backup.Core.CBackupMetaFile -ArgumentList `
        $sourceMetaFileArgs.fileComm,
        $sourceMetaFileArgs.filePath,
        $sourceMetaFileArgs.type
    $metaContent = $sourceMetaFile.LoadContent()

    $targetMetaFileArgs = @{
        fileComm = $TargetExtentAccessor.FileCommander;
        filePath = [Veeam.Backup.Common.CFullPath]::FromString(
            $TargetFilePath,
            $TargetExtentAccessor.FileCommander,
            $true
        );
        type = [Veeam.Backup.Core.CBackupMetaType]::Vbm
    }
    $targetMetaFile = New-Object -TypeName Veeam.Backup.Core.CBackupMetaFile -ArgumentList `
        $targetMetaFileArgs.fileComm,
        $targetMetaFileArgs.filePath,
        $targetMetaFileArgs.type
    try
    {
        $targetMetaFile.Save($metaContent)
    }
    catch
    {
        throw "Could not copy backup metadata."
    }
    
    Write-Host -Object "Backup metadata has been copied."
}

[Veeam.Backup.Core.CCredentilasStroreInitializer]::InitLocal()

$sobr = [Veeam.Backup.Core.CBackupRepository]::Get([guid]$SobrId)
$sourceExtent = [Veeam.Backup.Core.CBackupRepository]::Get([guid]$SourceExtentId)
$targetExtent = [Veeam.Backup.Core.CBackupRepository]::Get([guid]$TargetExtentId)

$sourceExtentAccessor = [Veeam.Backup.Core.CRepositoryAccessorFactory]::Create($sourceExtent)
$targetExtentAccessor = [Veeam.Backup.Core.CRepositoryAccessorFactory]::Create($targetExtent)

$tenantFolderPath = [Veeam.Backup.Core.CFileCommanderHelper]::CombinePath($sourceExtent.FriendlyPath, $TenantFolder)

foreach ($folder in $sourceExtentAccessor.FileCommander.EnumItems($tenantFolderPath))
{
    if ($sourceExtentAccessor.FileCommander.GetDirSize($folder.FullName))
    {
        Write-Host -Object "Started processing backup files in [$($folder.Name)]."
        
        $storageFiles = New-Object -TypeName System.Collections.Generic.List[string]
        $sourceMetaFile = $null
        
        foreach ($file in $sourceExtentAccessor.FileCommander.EnumItems($folder.FullName))
        {
            if ($file.Name.EndsWith("vbm"))
            {
                $sourceMetaFile = $file
            }
            else
            {
                $storageFiles.Add($file.FullName)
            }
        }
        
        Copy-StorageFiles -Sobr $sobr -SourceExtentAccessor $sourceExtentAccessor -Files $storageFiles `
            -TargetExtentAccessor $targetExtentAccessor
        
        $targetMetaFilePath = [Veeam.Backup.Core.CFileCommanderHelper]::CombinePath(
            $targetExtent.FriendlyPath,
            $TenantFolder,
            $folder.Name,
            $sourceMetaFile.Name
        )
        Copy-Metadata -SourceExtentAccessor $sourceExtentAccessor -SourceFilePath $sourceMetaFile.FullName `
            -TargetExtentAccessor $targetExtentAccessor -TargetFilePath $targetMetaFilePath
        
        foreach ($file in $storageFiles)
        {
            $sourceExtentAccessor.FileCommander.DeleteFile($file)
        }
        $sourceExtentAccessor.FileCommander.DeleteFile($sourceMetaFile.FullName)
        Write-Host -Object "Source backup files have been deleted."
    }
}

$rescanSession = Sync-VBRBackupRepository -Repository $sobr
[Veeam.Backup.Core.CBaseSession]::Wait4Complete($rescanSession.Id)
Write-Host -Object "[$($sobr.Name)] has been rescanned."

Get-VBRCloudTenant -Name $TenantName | Enable-VBRCloudTenant
Write-Host -Object "[$TenantName] has been enabled."

[Veeam.Backup.SSH.CSshConnection]::ClearCache()
