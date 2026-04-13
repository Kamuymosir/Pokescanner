param(
  [Parameter(Mandatory = $true)]
  [string]$TerminalRoot,

  [Parameter(Mandatory = $true)]
  [string]$ExpertName,

  [Parameter(Mandatory = $true)]
  [string]$SetFilesGlob,

  [Parameter(Mandatory = $true)]
  [string]$Symbol,

  [Parameter(Mandatory = $true)]
  [string]$Period,

  [Parameter(Mandatory = $true)]
  [string]$FromDate,

  [Parameter(Mandatory = $true)]
  [string]$ToDate,

  [string]$Model = "4",
  [string]$ReportPrefix = "ascendant-batch",
  [int]$Limit = 0,
  [switch]$Portable,
  [switch]$StopOnError
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$runBacktest = Join-Path $scriptDir "run_backtest.ps1"

if (-not (Test-Path -LiteralPath $runBacktest)) {
  throw "run_backtest.ps1 not found: $runBacktest"
}

$setFiles = Get-ChildItem -Path $SetFilesGlob -File | Sort-Object Name
if ($Limit -gt 0) {
  $setFiles = $setFiles | Select-Object -First $Limit
}

if (-not $setFiles) {
  throw "No set files matched: $SetFilesGlob"
}

$summaryRows = New-Object System.Collections.Generic.List[object]
$index = 0

foreach ($setFile in $setFiles) {
  $index++
  $reportName = "{0}-{1:000}" -f $ReportPrefix, $index

  Write-Host "[$('{0:000}' -f $index)] running $($setFile.Name) -> $reportName"

  try {
    $args = @(
      "-File", $runBacktest,
      "-TerminalRoot", $TerminalRoot,
      "-ExpertName", $ExpertName,
      "-SetFile", $setFile.FullName,
      "-Symbol", $Symbol,
      "-Period", $Period,
      "-FromDate", $FromDate,
      "-ToDate", $ToDate,
      "-ReportName", $reportName,
      "-Model", $Model
    )

    if ($Portable) {
      $args += "-Portable"
    }

    & pwsh @args
    $exitCode = $LASTEXITCODE

    $summaryRows.Add([pscustomobject]@{
      RunId      = $reportName
      SetFile    = $setFile.Name
      ExitCode   = $exitCode
      Status     = if ($exitCode -eq 0) { "completed" } else { "failed" }
      ReportName = $reportName
    })

    if ($StopOnError -and $exitCode -ne 0) {
      throw "Backtest failed for $($setFile.Name) with exit code $exitCode"
    }
  }
  catch {
    $summaryRows.Add([pscustomobject]@{
      RunId      = $reportName
      SetFile    = $setFile.Name
      ExitCode   = -1
      Status     = "failed"
      ReportName = $reportName
    })

    if ($StopOnError) {
      throw
    }
  }
}

$terminalRootResolved = (Resolve-Path $TerminalRoot).Path
$automationDir = Join-Path $terminalRootResolved "automation"
New-Item -ItemType Directory -Path $automationDir -Force | Out-Null
$summaryPath = Join-Path $automationDir "batch-summary.csv"
$summaryRows | Export-Csv -LiteralPath $summaryPath -NoTypeInformation -Encoding UTF8

Write-Host "Batch summary written to: $summaryPath"
exit 0
