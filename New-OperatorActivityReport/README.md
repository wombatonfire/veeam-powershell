## New-OperatorActivityReport.ps1
The script generates an operator activity report, showing which application items a restore operator had access to during a restore session. The report contains the following fields:

- Time of the event in UTC.
- Operator login.
- Organization name for which a restore session was initiated.
- Event type. Possible types: *Save*, *Export*, *Send*, *Restore*, *View*.
- Item name.
- Item type.
- Source path of the item.
- Target path of the item (if applicable).
- Event status.

Events can be filtered by providing a date range in the `-DateRange` parameter and/or operator login in the `-Operator` parameter. By default events from all available restore sessions are included.

### How to use

The script is implemented in PowerShell, but it uses REST API for interacting with the backup server, thus PowerShell cmdlets for Veeam Backup for Microsoft Office 365 are not required.

1. Specify the values for the following variables in the script:

- `$vboServer` - address of the backup server;
- `$vboPort` (default value is provided);
- `$username` - user account with access rights to the backup server;
- `$password`;
- `$reportPath` - path to the csv file with a report.

2. Save the script.
3. Run the script from the PowerShell console, providing optional `-DateRange` and/or `-Operator` parameters if needed.

For example:

    PS C:\Users\Administrator> C:\PSScripts\New-OperatorActivityReport.ps1
    PS C:\Users\Administrator> C:\PSScripts\New-OperatorActivityReport.ps1 -DateRange 2018-08-01, 2018-09-01
    PS C:\Users\Administrator> C:\PSScripts\New-OperatorActivityReport.ps1 -DateRange "2018-09-01 15:00", "2018-09-01 18:00"
    PS C:\Users\Administrator> C:\PSScripts\New-OperatorActivityReport.ps1 -Operator "domain\username"
    PS C:\Users\Administrator> C:\PSScripts\New-OperatorActivityReport.ps1 -DateRange 2018-08-01, 2018-09-01 -Operator "domain\username"

If date is specified without time, midnight is assumed. If time is provided, it is assumed to be in local time zone. Start timestamp is included in the range, end timestamp is not.

Generated report in a csv format will be saved to the file specified in the `$reportPath` variable.

Note that, while date range for the script should be provided in local time zone, timestamps in the report are in UTC. This is done to avoid ambiguity and support data exchange when report users are located in different time zones.