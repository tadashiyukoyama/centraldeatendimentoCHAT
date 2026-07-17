[CmdletBinding()]
param(
  [string]$WorkspaceRoot = $env:CENTRAL_ATENDIMENTO_WORKSPACE_ROOT
)

$ErrorActionPreference = 'Stop'

if (-not $WorkspaceRoot) {
  throw 'Defina CENTRAL_ATENDIMENTO_WORKSPACE_ROOT para validar a cápsula local.'
}

$workspaceRoot = [System.IO.Path]::GetFullPath($WorkspaceRoot)
$manifestPath = Join-Path $workspaceRoot '.workspace\project.json'
$policyPath = Join-Path $workspaceRoot '.workspace\storage-policy.json'

foreach ($path in @($manifestPath, $policyPath)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Manifesto ausente: $path"
  }
}

$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
$policy = Get-Content -Raw $policyPath | ConvertFrom-Json
$requiredDirectories = @(
  'artifacts',
  'private\credentials',
  'private\env',
  'private\recovery\database',
  'runtime\data\postgres',
  'runtime\data\redis',
  'runtime\data\storage',
  'runtime\cache',
  'runtime\logs',
  'runtime\memory\short-term',
  'runtime\temp',
  'worktrees'
)

foreach ($relativePath in $requiredDirectories) {
  $path = Join-Path $workspaceRoot $relativePath
  if (-not (Test-Path -LiteralPath $path -PathType Container)) {
    throw "Diretório ausente: $path"
  }
}

if ([int]$manifest.maxAdditionalWorktrees -ne 3 -or [int]$policy.maxAdditionalWorktrees -ne 3) {
  throw 'A política da cápsula deve permitir exatamente três worktrees adicionais.'
}

[pscustomobject]@{
  projectId = $manifest.projectId
  repository = $manifest.repository
  canonicalClone = $manifest.canonicalClone
  maxAdditionalWorktrees = $manifest.maxAdditionalWorktrees
  requiredDirectories = $requiredDirectories.Count
} | ConvertTo-Json
