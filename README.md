# veeam-powershell
PowerShell scripts for Veeam Backup &amp; Replication

## New-OrgBackupReport.ps1
The script generates a backup usage report for vCloud Director organizations. The report contains the total number of VMs in backups and the total amount of space used on repositories, per organization.

Note that `$protectedVms` is a simple sum of all VMs in all backups, so if a particular VM is processed by multiple jobs it will be counted multiple times.

**IMPORTANT**: First version of this script used jobs to find the backups, thus the backups without a job were not counted. Current version uses quota to locate the backups, so that all backups are proccessed, even the ones without a corresponding job. Please upgrade if you use previous version.