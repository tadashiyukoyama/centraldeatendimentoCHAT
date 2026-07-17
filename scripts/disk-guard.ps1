[CmdletBinding()]
param(
  [switch]$ReadOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\WorkspaceContext.ps1')
$context = Get-WorkspaceContext

function Get-DirectoryBytes {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return [int64]0 }
  $measure = @(Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum)
  if ($measure.Count -eq 0) { return [int64]0 }
  $sumProperty = $measure[0].PSObject.Properties['Sum']
  if ($null -eq $sumProperty -or $null -eq $sumProperty.Value) { return [int64]0 }
  return [int64]$sumProperty.Value
}

$paths = @(
  [pscustomobject]@{ name = 'checkout'; path = $context.checkoutRoot },
  [pscustomobject]@{ name = 'runtime'; path = $context.runtimeRoot },
  [pscustomobject]@{ name = 'artifacts'; path = $context.artifactsRoot },
  [pscustomobject]@{ name = 'worktrees'; path = $context.worktreesRoot }
) | ForEach-Object {
  [pscustomobject]@{ name = $_.name; path = $_.path; bytes = Get-DirectoryBytes $_.path }
}

$driveNames = @($context.workspaceRoot, $context.checkoutRoot, $context.gitCommonDir | ForEach-Object {
  $root = [System.IO.Path]::GetPathRoot($_)
  if ($root -match '^(?<drive>[A-Za-z]):[\\/]$') { $Matches.drive.ToUpperInvariant() }
}) | Sort-Object -Unique
$drives = @($driveNames | ForEach-Object {
  Get-PSDrive -Name $_ -ErrorAction SilentlyContinue | Select-Object Name, Used, Free
})

$pending = @(
  'Docker Desktop storage',
  'WSL2 virtual disk',
  'Docker images and volumes',
  'pnpm cache',
  'Bundler cache',
  'temporary files and logs',
  'Android SDK, Gradle and build artifacts'
)

[pscustomobject]@{
  mode = if ($ReadOnly) { 'read-only' } else { 'report-only' }
  workspaceRoot = $context.workspaceRoot
  observedDriveRoots = $driveNames
  drives = $drives
  knownProjectPaths = $paths
  pendingBoundaries = $pending
  deletionPerformed = $false
  cDriveProtectionClaimed = $false
} | ConvertTo-Json -Depth 6
