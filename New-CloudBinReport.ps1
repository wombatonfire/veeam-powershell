Add-PSSnapin -Name VeeamPSSnapin

function New-CloudBinReport
{
    $report = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]

    $tenants = Get-VBRCloudTenant
    foreach ($tenant in $tenants)
    {
        if ($tenant.ResourcesEnabled)
        {
            $tenantQuota = [Veeam.Backup.Core.CTenantQuota]::DbFindByTenantId($tenant.Id)
            $binPath = [Veeam.Backup.Model.SPathConverter]::RepositoryPathToString(
                $tenantQuota.AbsoluteRecycleBinPath,
                $tenantQuota.CachedRepository.Type
            )
            $repoAccessor = [Veeam.Backup.Core.CRepositoryAccessorFactory]::Create($tenantQuota.CachedRepository)
            $binSize = $repoAccessor.FileCommander.GetDirSize($binPath)

            $tenantReport = [PSCustomObject]@{
                tenantName = $tenant.Name
                binSize = $binSize
            }
            $report.Add($tenantReport)
        }
    }

    return $report
}

New-CloudBinReport | Format-Table -Property @{Expression={$_.tenantName}; Label="Tenant"},
    @{Expression={[System.Math]::Round($_.binSize / 1GB, 2)}; Label="Bin size (GB)"}
