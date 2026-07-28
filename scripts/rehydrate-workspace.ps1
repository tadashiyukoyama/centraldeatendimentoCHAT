[CmdletBinding()]
param(
  [switch]$ReadOnly,
  [switch]$CreateMissing,
  [string]$WorkspaceRoot
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\WorkspaceContext.ps1')

if ($WorkspaceRoot) {
  $env:CENTRAL_ATENDIMENTO_WORKSPACE_ROOT = $WorkspaceRoot
}
$context = Get-WorkspaceContext

$requiredDirectories = @(
  $context.canonicalServerRoot,
  $context.mobileRoot,
  $context.artifactsRoot,
  $context.credentialsRoot,
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

if ($missing.Count -gt 0 -and $CreateMissing -and -not $ReadOnly) {
  foreach ($path in $missing) {
    New-Item -ItemType Directory -Force -Path $path | Out-Null
  }
  $missing = @($requiredDirectories | Where-Object {
    -not (Test-Path -LiteralPath $_ -PathType Container)
  })
}

if ($missing.Count -gt 0) {
  throw "Reidratacao incompleta; diretorios ausentes: $($missing -join ', '). Use -CreateMissing explicitamente para criar a estrutura conhecida."
}

& (Join-Path $PSScriptRoot 'verify-capsule.ps1')
$mode = 'read-only'
$created = $false
if ($CreateMissing -and -not $ReadOnly) {
  $mode = 'create-missing'
  $created = $true
}

[pscustomobject]@{
  mode = $mode
  created = $created
  checkoutRoot = $context.checkoutRoot
  canonicalServerRoot = $context.canonicalServerRoot
  workspaceRoot = $context.workspaceRoot
  isLinkedWorktree = $context.isLinkedWorktree
  credentialsOpened = $false
  dependenciesInstalled = $false
  mobileCloned = $false
} | ConvertTo-Json -Depth 4
