# veeam-powershell
PowerShell scripts for Veeam Backup &amp; Replication

## New-CloudBinReport.ps1
The script generates a report for Cloud Connect Backup tenants, showing the size of the deleted backups in a recycle bin.

Backups deleted from a cloud repository are moved to the recycle bin if the service provider enabled *Insider Protection* option for the tenant. Files in the recycle bin do not consume the tenant quota, and this report provides insight into additional backup storage consumption.

## New-OrgBackupReport.ps1
The script generates a backup usage report for vCloud Director organizations. For each organization the report provides:

* The total number of VMs in backups.
* The total amount of space used on repositories.

Note that `$protectedVms` is a simple sum of all VMs in all backups, so if a particular VM is processed by multiple jobs it will be counted multiple times.

**IMPORTANT**: First version of this script used jobs to find the backups, thus the backups without a job were not counted. Current version uses quota to locate the backups, so that all backups are proccessed, even the ones without a corresponding job. Please upgrade if you use previous version.