[CmdletBinding()]
param(
  [string]$WorkspaceRoot = $env:CENTRAL_ATENDIMENTO_WORKSPACE_ROOT
)

$ErrorActionPreference = 'Stop'

$repoRoot = (git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) {
  throw 'Execute este script dentro do clone do servidor.'
}

if (-not $WorkspaceRoot) {
  $WorkspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot '..'))
}

$workspaceRoot = [System.IO.Path]::GetFullPath($WorkspaceRoot)
$portablePath = Join-Path $repoRoot '.workspace\project.portable.json'
if (-not (Test-Path -LiteralPath $portablePath -PathType Leaf)) {
  throw "Manifesto portátil ausente: $portablePath"
}

$portable = Get-Content -Raw $portablePath | ConvertFrom-Json
if ($portable.projectId -ne 'CENTRAL_ATENDIMENTO_CHAT') {
  throw 'projectId inesperado no manifesto portátil.'
}
if ([int]$portable.maxAdditionalWorktrees -ne 2) {
  throw 'O manifesto portátil deve limitar duas worktrees adicionais.'
}

$expectedServer = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot $portable.serverRelativePath))
$actualServer = [System.IO.Path]::GetFullPath($repoRoot)
if (-not [System.String]::Equals($expectedServer, $actualServer, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Git root inesperado. Esperado: $expectedServer; encontrado: $actualServer"
}

$requiredDirectories = @(
  'server',
  'mobile',
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

$missing = @($requiredDirectories | Where-Object {
  -not (Test-Path -LiteralPath (Join-Path $workspaceRoot $_) -PathType Container)
})
if ($missing.Count -gt 0) {
  throw "Diretórios obrigatórios ausentes: $($missing -join ', ')"
}

$mobileGit = Test-Path -LiteralPath (Join-Path $workspaceRoot 'mobile\.git')
$mobileCode = @(Get-ChildItem -LiteralPath (Join-Path $workspaceRoot 'mobile') -Force -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'README.md' })
if ($mobileGit -or $mobileCode.Count -gt 0) {
  throw 'A pasta mobile deve conter apenas o marcador README.md e não pode ter .git.'
}

$origin = (git config --get remote.origin.url).Trim()
$upstream = (git config --get remote.upstream.url).Trim()
if ($origin -notmatch 'tadashiyukoyama/centraldeatendimentoCHAT') {
  throw "origin inesperado: $origin"
}
if ($upstream -notmatch 'chatwoot/chatwoot') {
  throw "upstream inesperado: $upstream"
}

$trackedViolations = @(git ls-files | Where-Object {
  $_ -match '(^|/)(private|runtime|worktrees|artifacts)/' -or
  $_ -match '(^|/)\.env$' -or
  $_ -match '^infra/env/[^/]+\.env$'
})
if ($trackedViolations.Count -gt 0) {
  throw "Caminhos privados versionados: $($trackedViolations -join ', ')"
}

$codexViolations = @(
  (Join-Path $repoRoot '.codex'),
  (Join-Path $workspaceRoot 'mobile\.codex'),
  (Join-Path $workspaceRoot 'worktrees\.codex')
) | Where-Object { Test-Path -LiteralPath $_ }
if ($codexViolations.Count -gt 0) {
  throw "Configuração .codex fora do CODEX_HOME: $($codexViolations -join ', ')"
}

$worktrees = @(git worktree list --porcelain | Where-Object { $_ -like 'worktree *' } | ForEach-Object {
  [System.IO.Path]::GetFullPath($_.Substring(9).Trim())
})
$additional = @($worktrees | Where-Object {
  -not [System.String]::Equals($_, $actualServer, [System.StringComparison]::OrdinalIgnoreCase)
})
if ($additional.Count -gt 2) {
  throw "Mais de duas worktrees adicionais ativas: $($additional.Count)"
}

[pscustomobject]@{
  projectId = $portable.projectId
  workspaceRoot = $workspaceRoot
  serverRoot = $actualServer
  mobileReserved = $true
  mobileHasGit = $mobileGit
  mobileCodeFiles = $mobileCode.Count
  additionalActiveWorktrees = $additional.Count
  maxAdditionalWorktrees = 2
  origin = $origin
  upstream = $upstream
  trackedBoundaryViolations = $trackedViolations.Count
} | ConvertTo-Json -Depth 4
