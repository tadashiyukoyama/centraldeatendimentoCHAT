[CmdletBinding()]
param(
  [int]$MaxAdditionalWorktrees = -1
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\WorkspaceContext.ps1')
$context = Get-WorkspaceContext

if ($MaxAdditionalWorktrees -ge 0 -and $MaxAdditionalWorktrees -ne $context.maxAdditionalWorktrees) {
  throw "O limite deve ser lido do manifesto portatil: $($context.maxAdditionalWorktrees)."
}

$worktreePaths = @(Get-WorkspaceRegisteredWorktreePaths)
$additional = @($worktreePaths | Where-Object {
  -not (Test-WorkspaceSamePath $_ $context.canonicalServerRoot)
})

[pscustomobject]$result = [pscustomobject]@{
  checkoutRoot = $context.checkoutRoot
  canonicalServerRoot = $context.canonicalServerRoot
  workspaceRoot = $context.workspaceRoot
  isLinkedWorktree = $context.isLinkedWorktree
  maxAdditionalWorktrees = $context.maxAdditionalWorktrees
  additionalActiveWorktrees = $additional.Count
  availableSlots = [Math]::Max(0, $context.maxAdditionalWorktrees - $additional.Count)
  paths = $additional
}
$result | ConvertTo-Json -Depth 5

if ($additional.Count -gt $context.maxAdditionalWorktrees) {
  throw "Orcamento excedido: $($additional.Count) worktrees adicionais ativos; maximo permitido: $($context.maxAdditionalWorktrees)."
}
