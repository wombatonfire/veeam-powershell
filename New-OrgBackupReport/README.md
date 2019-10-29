## New-OrgBackupReport.ps1
The script generates a backup usage report for vCloud Director organizations. For each organization the report provides:

- The total number of VMs in backups.
- The total amount of space used on repositories.

Note that `$protectedVms` is a simple sum of all VMs in all backups, so if a particular VM is processed by multiple jobs it will be counted multiple times.

The usage data can be aggregated on the organization level or for individual organization vDCs.

The backup scope of the report is customizable. It can be limited to the self-service backups, created by the organization administrators via self-service backup portal, or it can also include the backups, managed by the provider and created directly on the backup server.

### How to use

1. Specify a path to an output CSV file in the `$reportPath` variable on the first line of the script.
2. If necessary, add the configuration parameters for the `New-OrgBackupReport` command on the last line of the script. See the [Details](#details) section for parameter description.
3. Run the script. The report will be saved in the CSV file.

### Details

The central part of the script is the `New-OrgBackupReport` function. By default, it's called without parameters, which creates a report for self-service backups with aggregation on the organization level.

To change the aggregation level and/or backup scope of the report, two additional parameters can be provided for the `New-OrgBackupReport` function:

- `-AggregateByOrgVdc` - a switch parameter used to enable data aggregation on the organization vDC level. Useful when backups for different organization vDCs are billed differently.
- `-IncludeAllVcdBackups` - a switch parameter used to include usage statistics for all vCD backups. Backups, managed by the provider and created directly on the backup server, are included in the report and attributed to the correct organization.

`-AggregateByOrgVdc` and `-IncludeAllVcdBackups` parameters are independent and can be used together or on their own.

**IMPORTANT**: `-AggregateByOrgVdc` and `-IncludeAllVcdBackups` parameters REQUIRE the backups to be stored in per-VM backup files ("Use per-VM backup files" option in advanced settings of a backup repository). This is because the size of the backups is calculated using backup files, and, when a backup file contains several VMs from different organizations/vDCs, it's impossible to reliably attribute per-VM consumption to the correct organization/vDC.

The `usedSpace` column in the report is in bytes. You might want to convert it to GB or TB. This can be achieved by using `Select-Object` cmdlet between `New-OrgBackupReport` and `Export-Csv` on the last line of the script, e.g.:

Convert the `usedSpace` to GB, round the value to 2 decimal places and pretty-print the column names for a report with aggregation per organization (3 columns):

```powershell
New-OrgBackupReport | Select-Object -Property @{Expression={$_.orgName}; Label="Organization"},
    @{Expression={$_.protectedVms}; Label="Protected VMs"},
    @{Expression={[System.Math]::Round($_.usedSpace / 1GB, 2)}; Label="Used space (GB)"} | Export-Csv -Path $reportPath -NoTypeInformation
```

Convert the `usedSpace` to GB, round the value to 2 decimal places and pretty-print the column names for a report with aggregation per organization vDC (4 columns):

```powershell
New-OrgBackupReport | Select-Object -Property @{Expression={$_.orgName}; Label="Organization"},
    @{Expression={$_.orgVdcName}; Label="vDC"},
    @{Expression={$_.protectedVms}; Label="Protected VMs"},
    @{Expression={[System.Math]::Round($_.usedSpace / 1GB, 2)}; Label="Used space (GB)"} | Export-Csv -Path $reportPath -NoTypeInformation
```
