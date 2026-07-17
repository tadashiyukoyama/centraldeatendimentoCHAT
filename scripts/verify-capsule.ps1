[CmdletBinding()]
param(
  [string]$WorkspaceRoot
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\WorkspaceContext.ps1')

if ($WorkspaceRoot) {
  $env:CENTRAL_ATENDIMENTO_WORKSPACE_ROOT = $WorkspaceRoot
}
$context = Get-WorkspaceContext
$portable = $context.portableManifest

foreach ($requiredPath in @($context.checkoutRoot, $context.canonicalServerRoot, $context.workspaceRoot)) {
  if (-not (Test-Path -LiteralPath $requiredPath -PathType Container)) {
    throw "Raiz obrigatoria ausente: $requiredPath"
  }
}

$expectedServer = [System.IO.Path]::GetFullPath((Join-Path $context.workspaceRoot $portable.serverRelativePath))
if (-not (Test-WorkspaceSamePath $expectedServer $context.canonicalServerRoot)) {
  throw "canonicalServerRoot nao corresponde ao manifesto: $expectedServer"
}
if (-not (Test-Path -LiteralPath $context.checkoutRoot -PathType Container)) {
  throw "checkoutRoot nao existe: $($context.checkoutRoot)"
}

$requiredDirectories = @(
  $context.canonicalServerRoot,
  $context.mobileRoot,
  $context.artifactsRoot,
  (Join-Path $context.privateRoot 'credentials'),
  (Join-Path $context.privateRoot 'env'),
  (Join-Path $context.privateRoot 'recovery\database'),
  (Join-Path $context.runtimeRoot 'data\postgres'),
  (Join-Path $context.runtimeRoot 'data\redis'),
  (Join-Path $context.runtimeRoot 'data\storage'),
  (Join-Path $context.runtimeRoot 'cache'),
  (Join-Path $context.runtimeRoot 'logs'),
  (Join-Path $context.runtimeRoot 'memory\short-term'),
  (Join-Path $context.runtimeRoot 'temp'),
  $context.worktreesRoot
)
$missing = @($requiredDirectories | Where-Object {
  -not (Test-Path -LiteralPath $_ -PathType Container)
})
if ($missing.Count -gt 0) {
  throw "Diretorios obrigatorios ausentes: $($missing -join ', ')"
}

$mobileGit = Test-Path -LiteralPath (Join-Path $context.mobileRoot '.git')
$mobileCode = @(Get-ChildItem -LiteralPath $context.mobileRoot -Force -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
  $_.FullName -ne (Join-Path $context.mobileRoot 'README.md')
})
if ($mobileGit -or $mobileCode.Count -gt 0) {
  throw 'A pasta mobile deve conter apenas o marcador README.md e nao pode ter .git.'
}

$registeredWorktrees = @(Get-WorkspaceRegisteredWorktreePaths)
$additional = @($registeredWorktrees | Where-Object {
  -not (Test-WorkspaceSamePath $_ $context.canonicalServerRoot)
})
if ($additional.Count -gt $context.maxAdditionalWorktrees) {
  throw "Mais de $($context.maxAdditionalWorktrees) worktrees adicionais ativas: $($additional.Count)"
}

$trackedFiles = @((Invoke-WorkspaceGit @('ls-files')) -split "`r?`n" | Where-Object { $_ })
$trackedViolations = @($trackedFiles | Where-Object {
  $_ -match '(^|/)(private|runtime|worktrees|artifacts)/' -or
  $_ -match '(^|/)\.env$' -or
  $_ -match '^infra/env/[^/]+\.env$'
})
if ($trackedViolations.Count -gt 0) {
  throw "Caminhos privados versionados: $($trackedViolations -join ', ')"
}

$codexCandidates = @(
  (Join-Path $context.checkoutRoot '.codex'),
  (Join-Path $context.mobileRoot '.codex'),
  (Join-Path $context.worktreesRoot '.codex')
)
$codexViolations = @($codexCandidates | Where-Object { Test-Path -LiteralPath $_ })
if ($codexViolations.Count -gt 0) {
  throw "Configuracao .codex fora do CODEX_HOME: $($codexViolations -join ', ')"
}

[pscustomobject]@{
  projectId = $context.projectId
  checkoutRoot = $context.checkoutRoot
  canonicalServerRoot = $context.canonicalServerRoot
  workspaceRoot = $context.workspaceRoot
  gitCommonDir = $context.gitCommonDir
  worktreesRoot = $context.worktreesRoot
  mobileRoot = $context.mobileRoot
  runtimeRoot = $context.runtimeRoot
  privateRoot = $context.privateRoot
  artifactsRoot = $context.artifactsRoot
  isLinkedWorktree = $context.isLinkedWorktree
  mobileReserved = $true
  mobileHasGit = $mobileGit
  mobileCodeFiles = $mobileCode.Count
  additionalActiveWorktrees = $additional.Count
  maxAdditionalWorktrees = $context.maxAdditionalWorktrees
  origin = $context.origin
  upstream = $context.upstream
  trackedBoundaryViolations = $trackedViolations.Count
} | ConvertTo-Json -Depth 5
