# veeam-powershell
PowerShell scripts for Veeam Backup &amp; Replication and Veeam Backup for Microsoft Office 365

## Scripts for Veeam Backup &amp; Replication

Name | Description
---- | -----------
[Move-TenantBackupFiles](Move-TenantBackupFiles) | The script allows to move backup files of individual Cloud Connect tenants between extents of a scale-out repository, without the need to put the whole extent to the maintenance mode.
[New-CloudBinReport](New-CloudBinReport) | The script generates a report for Cloud Connect Backup tenants, showing the size of the deleted backups in a recycle bin.
[New-OrgBackupReport](New-OrgBackupReport) | The script generates a backup usage report for vCloud Director organizations.

## Scripts for Veeam Backup for Microsoft Office 365

Name | Description
---- | -----------
[New-OperatorActivityReport](New-OperatorActivityReport) | The script generates an operator activity report, showing which application items a restore operator had access to during a restore session.