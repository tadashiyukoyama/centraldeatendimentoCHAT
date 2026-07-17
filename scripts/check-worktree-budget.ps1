[CmdletBinding()]
param(
  [int]$MaxAdditionalWorktrees = 2
)

$ErrorActionPreference = 'Stop'

$canonical = (git rev-parse --show-toplevel).Trim()
if (-not $canonical) {
  throw 'Execute este script dentro de um clone Git.'
}

$canonicalPath = [System.IO.Path]::GetFullPath($canonical)
$worktreePaths = @(git worktree list --porcelain | Where-Object { $_ -like 'worktree *' } | ForEach-Object {
  [System.IO.Path]::GetFullPath($_.Substring(9).Trim())
})

$additional = @($worktreePaths | Where-Object {
  -not [System.String]::Equals($_, $canonicalPath, [System.StringComparison]::OrdinalIgnoreCase)
})

[pscustomobject]$result = [pscustomobject]@{
  canonical = $canonicalPath
  maxAdditionalWorktrees = $MaxAdditionalWorktrees
  additionalActiveWorktrees = $additional.Count
  availableSlots = [Math]::Max(0, $MaxAdditionalWorktrees - $additional.Count)
  paths = $additional
}

$result | ConvertTo-Json -Depth 4

if ($additional.Count -gt $MaxAdditionalWorktrees) {
  throw "Orçamento excedido: $($additional.Count) worktrees adicionais ativos; máximo permitido: $MaxAdditionalWorktrees."
}
