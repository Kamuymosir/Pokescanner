$ErrorActionPreference = "Stop"

param(
  [Parameter(Mandatory = $true)]
  [string]$TerminalRoot,

  [Parameter(Mandatory = $true)]
  [string]$SourceFile,

  [string]$ExpertName = ""
)

function Resolve-MetaEditorPath {
  param([string]$Root)

  $candidates = @(
    (Join-Path $Root "MetaEditor64.exe"),
    (Join-Path $Root "metaeditor64.exe"),
    (Join-Path $Root "MetaEditor.exe"),
    (Join-Path $Root "metaeditor.exe")
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  throw "MetaEditor executable not found under: $Root"
}

$terminalRoot = (Resolve-Path $TerminalRoot).Path
$sourceFile = (Resolve-Path $SourceFile).Path
$metaEditor = Resolve-MetaEditorPath -Root $terminalRoot

if ([string]::IsNullOrWhiteSpace($ExpertName)) {
  $ExpertName = [System.IO.Path]::GetFileNameWithoutExtension($sourceFile)
}

$expertsDir = Join-Path $terminalRoot "MQL5\Experts"
if (-not (Test-Path $expertsDir)) {
  New-Item -ItemType Directory -Path $expertsDir -Force | Out-Null
}

$targetSource = Join-Path $expertsDir "$ExpertName.mq5"
Copy-Item -LiteralPath $sourceFile -Destination $targetSource -Force

$logDir = Join-Path $terminalRoot "automation\logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$compileLog = Join-Path $logDir "compile-$ExpertName.log"
Remove-Item -LiteralPath $compileLog -ErrorAction SilentlyContinue

Write-Host "Compiling: $targetSource"
Write-Host "MetaEditor: $metaEditor"
Write-Host "Log: $compileLog"

$process = Start-Process -FilePath $metaEditor `
  -ArgumentList "/portable", "/compile:$targetSource", "/log:$compileLog" `
  -Wait -PassThru -NoNewWindow

if (-not (Test-Path $compileLog)) {
  throw "Compile log was not generated: $compileLog"
}

$compileText = Get-Content -LiteralPath $compileLog -Raw
$compileText | Write-Host

if ($compileText -match "0 errors, 0 warnings" -or $compileText -match "0 error\(s\), 0 warning\(s\)") {
  Write-Host "Compilation succeeded."
  exit 0
}

throw "Compilation failed or warnings were detected. Review: $compileLog"
