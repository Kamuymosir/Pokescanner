$ErrorActionPreference = "Stop"

param(
  [Parameter(Mandatory = $true)]
  [string]$TerminalRoot,

  [Parameter(Mandatory = $true)]
  [string]$ExpertName,

  [Parameter(Mandatory = $true)]
  [string]$SetFile,

  [Parameter(Mandatory = $true)]
  [string]$Symbol,

  [Parameter(Mandatory = $true)]
  [string]$Period,

  [Parameter(Mandatory = $true)]
  [string]$FromDate,

  [Parameter(Mandatory = $true)]
  [string]$ToDate,

  [Parameter(Mandatory = $true)]
  [string]$ReportName,

  [string]$Model = "4",
  [switch]$Portable
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$iniTemplate = Join-Path $scriptDir "ascendant_tester.ini.tpl"

if (-not (Test-Path -LiteralPath $iniTemplate)) {
  throw "INI template not found: $iniTemplate"
}

$terminalRoot = (Resolve-Path $TerminalRoot).Path
$setFile = (Resolve-Path $SetFile).Path
$terminalPath = Join-Path $terminalRoot "terminal64.exe"
$testerProfiles = Join-Path $terminalRoot "MQL5\Profiles\Tester"
$reportsDir = Join-Path $terminalRoot "reports"
$automationDir = Join-Path $terminalRoot "automation"
$configsDir = Join-Path $automationDir "configs"

if (-not (Test-Path -LiteralPath $terminalPath)) {
  throw "terminal64.exe not found: $terminalPath"
}

New-Item -ItemType Directory -Path $testerProfiles -Force | Out-Null
New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $configsDir -Force | Out-Null

$setFileName = [System.IO.Path]::GetFileName($setFile)
$setTarget = Join-Path $testerProfiles $setFileName
Copy-Item -LiteralPath $setFile -Destination $setTarget -Force

$iniContent = Get-Content -LiteralPath $iniTemplate -Raw
$iniContent = $iniContent.Replace("__EXPERT_NAME__", $ExpertName)
$iniContent = $iniContent.Replace("__SET_FILE__", $setFileName)
$iniContent = $iniContent.Replace("__SYMBOL__", $Symbol)
$iniContent = $iniContent.Replace("__PERIOD__", $Period)
$iniContent = $iniContent.Replace("__MODEL__", $Model)
$iniContent = $iniContent.Replace("__FROM_DATE__", $FromDate)
$iniContent = $iniContent.Replace("__TO_DATE__", $ToDate)
$iniContent = $iniContent.Replace("__REPORT_PATH__", "reports/$ReportName")

$configPath = Join-Path $configsDir "$ReportName.ini"
Set-Content -LiteralPath $configPath -Value $iniContent -Encoding ASCII

$args = @("/config:$configPath")
if ($Portable) {
  $args = @("/portable") + $args
}

Write-Host "Running MT5 tester..."
Write-Host "Terminal: $terminalPath"
Write-Host "Config:   $configPath"
Write-Host "Set file: $setTarget"

$proc = Start-Process -FilePath $terminalPath -ArgumentList $args -PassThru -Wait
Write-Host "MT5 exited with code $($proc.ExitCode)"
exit $proc.ExitCode
