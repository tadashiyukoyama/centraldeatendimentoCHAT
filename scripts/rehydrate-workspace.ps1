[CmdletBinding()]
param(
  [switch]$ReadOnly,
  [switch]$CreateMissing
)

$ErrorActionPreference = 'Stop'

$repoRoot = (git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) {
  throw 'Execute este script dentro do clone do servidor.'
}

$portablePath = Join-Path $repoRoot '.workspace\project.portable.json'
$portable = Get-Content -Raw $portablePath | ConvertFrom-Json
if ($portable.projectId -ne 'CENTRAL_ATENDIMENTO_CHAT' -or [int]$portable.maxAdditionalWorktrees -ne 2) {
  throw 'Manifesto portátil incompatível com CENTRAL_ATENDIMENTO_CHAT.'
}

$workspaceRoot = $env:CENTRAL_ATENDIMENTO_WORKSPACE_ROOT
if (-not $workspaceRoot) {
  $workspaceRoot = [Environment]::GetEnvironmentVariable('CENTRAL_ATENDIMENTO_WORKSPACE_ROOT', 'User')
}
if (-not $workspaceRoot) {
  $workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot '..'))
}
$workspaceRoot = [System.IO.Path]::GetFullPath($workspaceRoot)

$requiredDirectories = @(
  'server', 'mobile', 'artifacts', 'private\credentials', 'private\env',
  'private\recovery\database', 'runtime\data\postgres', 'runtime\data\redis',
  'runtime\data\storage', 'runtime\cache', 'runtime\logs',
  'runtime\memory\short-term', 'runtime\temp', 'worktrees'
)
$missing = @($requiredDirectories | Where-Object {
  -not (Test-Path -LiteralPath (Join-Path $workspaceRoot $_) -PathType Container)
})

if ($missing.Count -gt 0 -and $CreateMissing -and -not $ReadOnly) {
  foreach ($relativePath in $missing) {
    New-Item -ItemType Directory -Force -Path (Join-Path $workspaceRoot $relativePath) | Out-Null
  }
  $missing = @($requiredDirectories | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $workspaceRoot $_) -PathType Container)
  })
}

if ($missing.Count -gt 0) {
  throw "Reidratação incompleta; diretórios ausentes: $($missing -join ', '). Use -CreateMissing explicitamente para criar a estrutura conhecida."
}

& (Join-Path $repoRoot 'scripts\verify-capsule.ps1') -WorkspaceRoot $workspaceRoot
$mode = 'read-only'
$created = $false
if ($CreateMissing -and -not $ReadOnly) {
  $mode = 'create-missing'
  $created = $true
}
Write-Output ([pscustomobject]@{
  mode = $mode
  created = $created
  credentialsOpened = $false
  dependenciesInstalled = $false
  mobileCloned = $false
} | ConvertTo-Json)
