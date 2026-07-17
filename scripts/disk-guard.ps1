[CmdletBinding()]
param(
  [switch]$ReadOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = (git rev-parse --show-toplevel).Trim()
$workspaceRoot = $env:CENTRAL_ATENDIMENTO_WORKSPACE_ROOT
if (-not $workspaceRoot) {
  $workspaceRoot = [Environment]::GetEnvironmentVariable('CENTRAL_ATENDIMENTO_WORKSPACE_ROOT', 'User')
}
if (-not $workspaceRoot) {
  $workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot '..'))
}

function Get-DirectoryBytes([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return 0 }
  $sum = (Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
  if ($null -eq $sum) { return 0 }
  return [int64]$sum
}

$paths = @(
  [pscustomobject]@{ name = 'server'; path = [System.IO.Path]::GetFullPath($repoRoot) },
  [pscustomobject]@{ name = 'runtime'; path = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot 'runtime')) },
  [pscustomobject]@{ name = 'artifacts'; path = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot 'artifacts')) },
  [pscustomobject]@{ name = 'worktrees'; path = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot 'worktrees')) }
) | ForEach-Object {
  [pscustomobject]@{ name = $_.name; path = $_.path; bytes = Get-DirectoryBytes $_.path }
}

$drives = @(Get-PSDrive C,D | Select-Object Name,Used,Free)
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
  mode = 'read-only'
  drives = $drives
  knownProjectPaths = $paths
  pendingBoundaries = $pending
  deletionPerformed = $false
  cDriveProtectionClaimed = $false
} | ConvertTo-Json -Depth 5
