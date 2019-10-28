$reportPath = ""

Add-PSSnapin -Name VeeamPSSnapin

function Get-VcdVAppLocation
{
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [Veeam.Backup.Core.CBackup]
        $Backup,

        [Parameter(Mandatory=$true,
        ParameterSetName="VM")]
        [guid]
        $VMObjectId,

        [Parameter(Mandatory=$true,
        ParameterSetName="vApp")]
        [guid]
        $VAppObjectId
    )

    if ($PSCmdlet.ParameterSetName -eq "VM")
    {
        $vmOib = $Backup.FindLastOib($VMObjectId)
        $vAppOib = $vmOib.FindParent()
    }
    elseif ($PSCmdlet.ParameterSetName -eq "vApp")
    {
        $vAppOib = $Backup.FindLastOib($VAppObjectId)
    }

    return $vAppOib.AuxData.OrigVApp.VCloudVAppLocation
}

function New-OrgBackupReport
{
    [CmdletBinding()]

    param(
        [switch]
        $AggregateByOrgVdc,

        [switch]
        $IncludeAllVcdBackups
    )

    if ($IncludeAllVcdBackups)
    {
        $selfServiceBackupIds = New-Object -TypeName System.Collections.Generic.List[guid]
    }

    $orgReports = @{}

    $vcdOrgItems = Find-VBRvCloudEntity | Where-Object -FilterScript {$_.Type -eq "Organization"}
    foreach ($item in $vcdOrgItems)
    {
        $vcdOrg = New-Object -TypeName Veeam.Backup.Model.CVcdOrganization `
            -ArgumentList $item.VcdId, $item.VcdRef, $item.Name
        $orgQuotaId = [Veeam.Backup.Core.CJobQuota]::FindByOrganization($vcdOrg).Id
        if ($orgQuotaId)
        {
            $orgBackupIds = [Veeam.Backup.DBManager.CDBManager]::Instance.Backups.FindBackupsByQuotaIds($orgQuotaId).Id
            if ($AggregateByOrgVdc)
            {
                foreach ($backupId in $orgBackupIds)
                {
                    if ($IncludeAllVcdBackups)
                    {
                        $selfServiceBackupIds.Add($backupId)
                    }

                    $backup = [Veeam.Backup.Core.CBackup]::Get($backupId)
                    $storages = $backup.GetAllStorages()
                    foreach ($object in $backup.GetObjects())
                    {
                        if ($object.Type -eq "VM")
                        {
                            $vcdVAppLocation = Get-VcdVAppLocation -Backup $backup -VMObjectId $object.Id
                        }
                        elseif ($object.Type -eq "NfcDir")
                        {
                            $vcdVAppLocation = Get-VcdVAppLocation -Backup $backup -VAppObjectId $object.Id
                        }
                        $orgVdcName = $vcdVAppLocation.OrgVdcName
                        if (!$orgReports.Contains($vcdOrg.OrgName))
                        {
                            $orgReports[$vcdOrg.OrgName] = @{}
                        }
                        if (!$orgReports[$vcdOrg.OrgName].Contains($orgVdcName))
                        {
                            $orgReports[$vcdOrg.OrgName][$orgVdcName] = [PSCustomObject]@{
                                protectedVms = 0;
                                usedSpace = 0
                            }
                        }
                        if ($object.Type -eq "VM")
                        {
                            $orgReports[$vcdOrg.OrgName][$orgVdcName].protectedVms += 1
                        }
                        $sizePerObjectStorage = ($storages | Where-Object -FilterScript {$_.ObjectId -eq $object.Id}).Stats.BackupSize
                        foreach ($size in $sizePerObjectStorage)
                        {
                            $orgReports[$vcdOrg.OrgName][$orgVdcName].usedSpace += $size
                        }
                    }
                }
            }
            else
            {
                foreach ($backupId in $orgBackupIds)
                {
                    if ($IncludeAllVcdBackups)
                    {
                        $selfServiceBackupIds.Add($backupId)
                    }

                    $backup = [Veeam.Backup.Core.CBackup]::Get($backupId)
                    if (!$orgReports.Contains($vcdOrg.OrgName))
                    {
                        $orgReports[$vcdOrg.OrgName] = [PSCustomObject]@{
                            protectedVms = 0;
                            usedSpace = 0
                        }
                    }
                    $orgReports[$vcdOrg.OrgName].protectedVms += ($backup.GetObjects() | Where-Object -FilterScript {$_.Type -eq "VM"}).Length
                    $sizePerStorage = $backup.GetAllStorages().Stats.BackupSize
                    foreach ($size in $sizePerStorage)
                    {
                        $orgReports[$vcdOrg.OrgName].usedSpace += $size
                    }
                }
            }
        }
    }

    if ($IncludeAllVcdBackups)
    {
        $allVcdBackups = Get-VBRBackup | Where-Object -FilterScript {$_.BackupPlatform.ToString() -eq "EVcd"}
        $nonSelfServiceVcdBackups = $allVcdBackups | Where-Object -FilterScript {$_.Id -notin $selfServiceBackupIds}
        foreach ($backup in $nonSelfServiceVcdBackups)
        {
            $storages = $backup.GetAllStorages()
            foreach ($object in $backup.GetObjects())
            {
                if ($object.Type -eq "VM")
                {
                    $vcdVAppLocation = Get-VcdVAppLocation -Backup $backup -VMObjectId $object.Id
                }
                elseif ($object.Type -eq "NfcDir")
                {
                    $vcdVAppLocation = Get-VcdVAppLocation -Backup $backup -VAppObjectId $object.Id
                }
                $orgName = $vcdVAppLocation.OrgName
                if ($AggregateByOrgVdc)
                {
                    $orgVdcName = $vcdVAppLocation.OrgVdcName
                    if (!$orgReports.Contains($orgName))
                    {
                        $orgReports[$orgName] = @{}
                    }
                    if (!$orgReports[$orgName].Contains($orgVdcName))
                    {
                        $orgReports[$orgName][$orgVdcName] = [PSCustomObject]@{
                            protectedVms = 0;
                            usedSpace = 0
                        }
                    }
                    if ($object.Type -eq "VM")
                    {
                        $orgReports[$orgName][$orgVdcName].protectedVms += 1
                    }
                    $sizePerObjectStorage = ($storages | Where-Object -FilterScript {$_.ObjectId -eq $object.Id}).Stats.BackupSize
                    foreach ($size in $sizePerObjectStorage)
                    {
                        $orgReports[$orgName][$orgVdcName].usedSpace += $size
                    }
                }
                else
                {
                    if (!$orgReports.Contains($orgName))
                    {
                        $orgReports[$orgName] = [PSCustomObject]@{
                            protectedVms = 0;
                            usedSpace = 0
                        }
                    }
                    if ($object.Type -eq "VM")
                    {
                        $orgReports[$orgName].protectedVms += 1
                    }
                    $sizePerObjectStorage = ($storages | Where-Object -FilterScript {$_.ObjectId -eq $object.Id}).Stats.BackupSize
                    foreach ($size in $sizePerObjectStorage)
                    {
                        $orgReports[$orgName].usedSpace += $size
                    }
                }
            }
        }
    }

    $report = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]

    if ($AggregateByOrgVdc)
    {
        foreach ($orgReportEntry in $orgReports.GetEnumerator())
        {
            foreach ($orgVdcReportEntry in $orgReportEntry.Value.GetEnumerator())
            {
                $report.Add([PSCustomObject]@{
                    orgName = $orgReportEntry.Key;
                    orgVdcName = $orgVdcReportEntry.Key;
                    protectedVms = $orgVdcReportEntry.Value.protectedVms
                    usedSpace = $orgVdcReportEntry.Value.usedSpace
                })
            }
        }
    }
    else
    {
        foreach ($orgReportEntry in $orgReports.GetEnumerator())
        {
            $report.Add([PSCustomObject]@{
                orgName = $orgReportEntry.Key;
                protectedVms = $orgReportEntry.Value.protectedVms;
                usedSpace = $orgReportEntry.Value.usedSpace
            })
        }
    }

    return $report
}

New-OrgBackupReport | Export-Csv -Path $reportPath -NoTypeInformation
