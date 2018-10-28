param(
    [ValidateCount(2, 2)]
    [datetime[]]
    $DateRange,

    [string]
    $Operator
)

$vboServer = ""
$vboPort = "4443"

$username = ""
$password = ""

$reportPath = ""

function Get-AccessToken
{
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Server,

        [string]
        $Port = "4443",

        [Parameter(Mandatory=$true)]
        [string]
        $Username,

        [Parameter(Mandatory=$true)]
        [string]
        $Password
    )

    $uri = "https://${Server}:$Port/v2/token"
    $requestBody = "grant_type=password&username=$Username&password=$Password"
    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $requestBody

    return $response.access_token
}

function Get-Resource
{
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Server,

        [string]
        $Port = "4443",

        [Parameter(Mandatory=$true)]
        [string]
        $Resource,

        [Parameter(Mandatory=$true)]
        [string]
        $AccessToken
    )

    $baseUri = "https://${Server}:$Port/v2"
    $resourceUri = "$baseUri$Resource"
    $headers = @{
        Authorization = "Bearer $AccessToken"
    }
    $response = Invoke-RestMethod -Uri $resourceUri -Headers $headers

    return $response
}

function Get-RestoreSessions
{
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Server,

        [string]
        $Port = "4443",

        [Parameter(Mandatory=$true)]
        [string]
        $AccessToken,

        [ValidateCount(2, 2)]
        [datetime[]]
        $DateRange,

        [string]
        $Operator
    )

    $restoreSessions = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]

    $response = Get-Resource -Server $Server -Port $Port -Resource "/RestoreSessions" -AccessToken $AccessToken
    $restoreSessions.AddRange([System.Collections.Generic.List[PSCustomObject]]$response.results)
    if ($response._links.next)
    {
        do
        {
            $offset = $response.offset + $response.limit
            $resource = "/RestoreSessions?offset=$offset&limit=$($response.limit)"
            $response = Get-Resource -Server $Server -Port $Port -Resource $resource -AccessToken $AccessToken
            $restoreSessions.AddRange([System.Collections.Generic.List[PSCustomObject]]$response.results)
        }
        while ($response._links.next)
    }

    if ($DateRange)
    {
        $dateRangeUtc = $DateRange | ForEach-Object -Process {$_.ToUniversalTime()}
        $sessionFilter = {
            $creationTimeUtc = ([datetime]$_.creationTime).ToUniversalTime()
            $creationTimeUtc -ge $dateRangeUtc[0] -and $creationTimeUtc -lt $dateRangeUtc[1]
        }
        $restoreSessions = $restoreSessions | Where-Object -FilterScript $sessionFilter
    }
    if ($Operator)
    {
        $restoreSessions = $restoreSessions | Where-Object -FilterScript {$_.initiatedBy -eq $Operator}
    }

    return $restoreSessions | Sort-Object -Property creationTime
}

function Get-RestoreSessionEvents
{
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Server,

        [string]
        $Port = "4443",

        [Parameter(Mandatory=$true)]
        [string]
        $SessionId,

        [Parameter(Mandatory=$true)]
        [string]
        $AccessToken
    )

    $sessionEvents = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]

    $response = Get-Resource -Server $Server -Port $Port -Resource "/RestoreSessions/$SessionId/Events" `
        -AccessToken $AccessToken
    $sessionEvents.AddRange([System.Collections.Generic.List[PSCustomObject]]$response.results)
    if ($response._links.next)
    {
        do
        {
            $offset = $response.offset + $response.limit
            $resource = "/RestoreSessions/$SessionId/Events?offset=$offset&limit=$($response.limit)"
            $response = Get-Resource -Server $Server -Port $Port -Resource $resource -AccessToken $AccessToken
            $sessionEvents.AddRange([System.Collections.Generic.List[PSCustomObject]]$response.results)
        }
        while ($response._links.next)
    }

    return $sessionEvents
}

function ConvertFrom-EventMessageString
{
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [string]
        $EventMessage
    )

    $itemNamePattern = [regex]"(?<=^Item ).*(?= was \w+ successfully \(type:)"
    $itemTypePattern = [regex]"(?<=\(type: ).*(?=; source:)"
    $sourcePattern = [regex]"(?<=source: ).*(?=; target:)"
    $targetPattern = [regex]"(?<=target: ).*(?=\)$)"

    $itemDetails = [PSCustomObject]@{
        itemName = [regex]::Match($EventMessage, $itemNamePattern);
        itemType = [regex]::Match($EventMessage, $itemTypePattern);
        source = [regex]::Match($EventMessage, $sourcePattern);
        target = [regex]::Match($EventMessage, $targetPattern)
    }

    return $itemDetails
}

function New-OperatorActivityReport
{
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Server,

        [string]
        $Port = "4443",

        [Parameter(Mandatory=$true)]
        [string]
        $Username,

        [Parameter(Mandatory=$true)]
        [string]
        $Password,

        [ValidateCount(2, 2)]
        [datetime[]]
        $DateRange,

        [string]
        $Operator
    )

    $report = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]

    $accessToken = Get-AccessToken -Server $Server -Port $Port -Username $Username -Password $Password
    $filters = @{}
    if ($DateRange)
    {
        $filters["DateRange"] = $DateRange
    }
    if ($Operator)
    {
        $filters["Operator"] = $Operator
    }
    $restoreSessions = Get-RestoreSessions -Server $Server -Port $Port -AccessToken $accessToken @filters
    foreach ($session in $restoreSessions)
    {
        $sessionEvents = Get-RestoreSessionEvents -Server $Server -Port $Port -SessionId $session.id `
            -AccessToken $accessToken
        foreach ($event in $sessionEvents)
        {
            # Exclude restore session started/completed events
            if ($event.type -ne "None")
            {
                $itemDetails = ConvertFrom-EventMessageString -EventMessage $event.message
                $eventReport = [PSCustomObject]@{
                    timeUtc = ([datetime]$event.startTime).ToUniversalTime();
                    operator = $session.initiatedBy;
                    organization = $session.organization;
                    eventType = $event.type;
                    itemName = $itemDetails.itemName;
                    itemType = $itemDetails.itemType;
                    source = $itemDetails.source;
                    target = $itemDetails.target;
                    status = $event.status
                }
                $report.Add($eventReport)
            }
        }
    }

    return $report
}

$filters = @{}
if ($DateRange)
{
    $filters["DateRange"] = $DateRange
}
if ($Operator)
{
    $filters["Operator"] = $Operator
}
$report = New-OperatorActivityReport -Server $vboServer -Port $vboPort -Username $username -Password $password @filters
$report | Export-Csv -Path $reportPath -NoTypeInformation
