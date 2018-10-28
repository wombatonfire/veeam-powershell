## New-CloudBinReport.ps1
The script generates a report for Cloud Connect Backup tenants, showing the size of the deleted backups in a recycle bin.

Backups deleted from a cloud repository are moved to the recycle bin if the service provider enabled *Insider Protection* option for the tenant. Files in the recycle bin do not consume the tenant quota, and this report provides insight into additional backup storage consumption.