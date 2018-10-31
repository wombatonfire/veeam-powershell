## Move-TenantBackupFiles.ps1
The script allows to move backup files of individual Cloud Connect tenants between extents of a scale-out repository, without the need to put the whole extent to the maintenance mode.

> **WARNING: THE SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED. THE SCRIPT IS NOT SUPPORTED BY VEEAM TECHNICAL SUPPORT. USE AT YOUR OWN RISK. PERFORM CONFIGURATION BACKUP BEFORE EXECUTING THE SCRIPT.**

Scale-out backup repository supports backup evacuation from one extent to another. While being a useful feature, backup evacuation has several serious limitations, which affect its adoption:

- Source extent should be in the maintenance mode.
- Target extent is selected automatically and can't be specified by the administrator.
- "All or nothing" approach: there is no way to move individual backups.

In a Cloud Connect environment, putting extent to the maintenance mode will affect all the tenants, whose backups are stored on that extent. They will not be able to run the jobs or perform restore from the cloud repository.

Inability to choose the target extent decreases the infrastructure control, while "all or nothing" approach means that backup evacuation can't be used for extent rebalancing or backup files consolidation.

`Move-TenantBackupFiles.ps1` script overcomes these limitations and allows to move backup files of individual tenants between extents. Source extent continues to operate in the normal mode. Only the tenant, whose files are being moved, is disabled, no other tenants are affected. This approach ensures minimal service disruption.

Target extent is selected by the administrator, providing a way to rebalance the extents after adding a new one, or consolidate the backups of a specific tenant in one place. The latter may be useful in case the data locality policy was disregarded for any reason.

### How to use

1. Save both files (`Move-TenantBackupFiles.ps1` and `job_src.ps1`) in the same folder on the Cloud Connect server.
2. Run `Move-TenantBackupFiles.ps1` from the PowerShell console.
3. Use the interactive command-line interface to select which backup files to move and where to move them.
4. Monitor the progress of the job in the VB&R console > HISTORY > Orchestrated Tasks.

### Details

- Tenant will not be disabled if he has active jobs.
- Backup files will not be moved if the target extent has insufficient free space at the time the script is executed.
- Backup files are moved between extents using Veeam agents (VB&R components, not backup agents), thus all repository types should be supported. The script was tested with Windows and Linux repositories in different configurations. Please report if you have extents on EMC Data Domain or HP StoreOnce, and how the script works with them.
- Inside a single job, backup files are processed sequentially. Multiple jobs for different tenants or same tenant on different extents can run at the same time.
- Source backup files are deleted from the source extent only if all the storage files and backup metadata in a specific folder were successfully copied to the target extent. If the job fails on copy, the script should be executed again and the job has to be restarted.
- Tenant will not be reenabled if the job terminates with an error. In such case, the script should be executed again and the job has to be restarted.
- After all backup files are successfully copied, a scale-out repository is rescanned and the tenant is reenabled.

### Known issues

- Script fails on tenants with subtenants. This happens because of the differences in folder structure on the repository for tenants with and without subtenants. Currently, there is no workaround. Support for tenants with subtenants will be added in the next version.