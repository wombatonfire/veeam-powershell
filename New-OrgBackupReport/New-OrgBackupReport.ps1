Add-PSSnapin -Name VeeamPSSnapin

function New-OrgBackupReport
{
    $report = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]

    $vcdOrgItems = Find-VBRvCloudEntity | Where-Object -FilterScript {$_.Type -eq "Organization"}
    foreach ($item in $vcdOrgItems)
    {
        $vcdOrg = New-Object -TypeName Veeam.Backup.Model.CVcdOrganization `
            -ArgumentList $item.VcdId, $item.VcdRef, $item.Name
        $orgQuotaId = [Veeam.Backup.Core.CJobQuota]::FindByOrganization($vcdOrg).Id
        if ($orgQuotaId)
        {
            $protectedVms = 0
            $usedSpace = 0

            $orgBackupIds = [Veeam.Backup.DBManager.CDBManager]::Instance.Backups.FindBackupsByQuotaIds($orgQuotaId).Id
            foreach ($backupId in $orgBackupIds)
            {
                $backup = [Veeam.Backup.Core.CBackup]::Get($backupId)
                $protectedVms += ($backup.GetObjects() | Where-Object -FilterScript {$_.Type -eq "VM"}).Length
                $sizePerStorage = $backup.GetAllStorages().Stats.BackupSize
                foreach ($size in $sizePerStorage)
                {
                    $usedSpace += $size
                }
            }

            $orgReport = [PSCustomObject]@{
                orgName = $vcdOrg.OrgName;
                protectedVms = $protectedVms;
                usedSpace = $usedSpace
            }
            $report.Add($orgReport)
        }
    }

    return $report
}

New-OrgBackupReport | Format-Table -Property @{Expression={$_.orgName}; Label="Organization"},
    @{Expression={$_.protectedVms}; Label="Protected VMs"},
    @{Expression={[System.Math]::Round($_.usedSpace / 1GB, 2)}; Label="Used space (GB)"}
