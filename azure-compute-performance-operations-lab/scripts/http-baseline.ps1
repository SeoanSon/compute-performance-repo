[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetUrl,
    [int]$DurationSeconds = 60,
    [int]$Concurrency = 8,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
if ($DurationSeconds -lt 1) { throw "DurationSeconds must be at least 1." }
if ($Concurrency -lt 1) { throw "Concurrency must be at least 1." }

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory) {
    New-Item -ItemType Directory -Force $outputDirectory | Out-Null
}

$end = [DateTime]::UtcNow.AddSeconds($DurationSeconds)
$jobs = @()
for ($worker = 1; $worker -le $Concurrency; $worker++) {
    $jobs += Start-Job -ArgumentList $TargetUrl, $end -ScriptBlock {
        param($url, $stopAt)
        $client = [Net.Http.HttpClient]::new()
        $client.Timeout = [TimeSpan]::FromSeconds(10)
        $rows = [Collections.Generic.List[object]]::new()
        while ([DateTime]::UtcNow -lt $stopAt) {
            $started = [Diagnostics.Stopwatch]::StartNew()
            try {
                $response = $client.GetAsync($url).GetAwaiter().GetResult()
                $statusCode = [int]$response.StatusCode
                $success = $response.IsSuccessStatusCode
                $response.Dispose()
                $rows.Add([pscustomobject]@{
                    TimestampUtc = [DateTime]::UtcNow.ToString("o")
                    Success = $success
                    StatusCode = $statusCode
                    ElapsedMs = [Math]::Round($started.Elapsed.TotalMilliseconds, 2)
                })
            } catch {
                $rows.Add([pscustomobject]@{
                    TimestampUtc = [DateTime]::UtcNow.ToString("o")
                    Success = $false
                    StatusCode = 0
                    ElapsedMs = [Math]::Round($started.Elapsed.TotalMilliseconds, 2)
                })
            }
        }
        $client.Dispose()
        $rows
    }
}

$rows = @($jobs | ForEach-Object { Receive-Job -Job $_ -Wait -AutoRemoveJob })
if ($rows.Count -eq 0) { throw "No requests were recorded." }
$rows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $OutputPath

$successful = @($rows | Where-Object Success)
$latencies = @($rows | ForEach-Object { [double]$_.ElapsedMs } | Sort-Object)
$p95Index = [Math]::Max(0, [Math]::Ceiling($latencies.Count * 0.95) - 1)
$p95 = $latencies[$p95Index]
$summary = [pscustomobject]@{
    TargetUrl = $TargetUrl
    DurationSeconds = $DurationSeconds
    Concurrency = $Concurrency
    Requests = $rows.Count
    Successful = $successful.Count
    SuccessRate = [Math]::Round(($successful.Count / $rows.Count) * 100, 2)
    RequestsPerSecond = [Math]::Round($rows.Count / $DurationSeconds, 2)
    P50Ms = [Math]::Round($latencies[[Math]::Max(0, [Math]::Ceiling($latencies.Count * 0.50) - 1)], 2)
    P95Ms = [Math]::Round($p95, 2)
    MaxMs = [Math]::Round($latencies[-1], 2)
}
$summary | Format-List
$summary | ConvertTo-Json | Set-Content -Encoding UTF8 "$OutputPath.summary.json"
