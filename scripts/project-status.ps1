[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (git rev-parse --show-toplevel).Trim()
$workspaceRoot = $env:CENTRAL_ATENDIMENTO_WORKSPACE_ROOT
if (-not $workspaceRoot) {
  $workspaceRoot = [Environment]::GetEnvironmentVariable('CENTRAL_ATENDIMENTO_WORKSPACE_ROOT', 'User')
}
if (-not $workspaceRoot) {
  $workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot '..'))
}

$worktreePaths = @(git worktree list --porcelain | Where-Object { $_ -like 'worktree *' } | ForEach-Object {
  [System.IO.Path]::GetFullPath($_.Substring(9).Trim())
})
$additional = @($worktreePaths | Where-Object { $_ -ne [System.IO.Path]::GetFullPath($repoRoot) })
$status = @(git status --short)

[pscustomobject]@{
  projectId = 'CENTRAL_ATENDIMENTO_CHAT'
  workspaceRoot = [System.IO.Path]::GetFullPath($workspaceRoot)
  serverRoot = [System.IO.Path]::GetFullPath($repoRoot)
  mobileRoot = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot 'mobile'))
  branch = (git branch --show-current).Trim()
  headSha = (git rev-parse HEAD).Trim()
  origin = (git config --get remote.origin.url).Trim()
  upstream = (git config --get remote.upstream.url).Trim()
  originMain = (git rev-parse origin/main).Trim()
  clean = ($status.Count -eq 0)
  additionalActiveWorktrees = $additional.Count
  maxAdditionalWorktrees = 2
  mobileReserved = (Test-Path -LiteralPath (Join-Path $workspaceRoot 'mobile'))
  dockerPresent = [bool](Get-Command docker -ErrorAction SilentlyContinue)
} | ConvertTo-Json -Depth 4
