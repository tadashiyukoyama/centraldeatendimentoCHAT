[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\WorkspaceContext.ps1')
$context = Get-WorkspaceContext

$worktreePaths = @(Get-WorkspaceRegisteredWorktreePaths)
$additional = @($worktreePaths | Where-Object {
  -not (Test-WorkspaceSamePath $_ $context.canonicalServerRoot)
})
$statusText = Invoke-WorkspaceGit @('status', '--short')

[pscustomobject]@{
  projectId = $context.projectId
  workspaceRoot = $context.workspaceRoot
  canonicalServerRoot = $context.canonicalServerRoot
  checkoutRoot = $context.checkoutRoot
  gitCommonDir = $context.gitCommonDir
  mobileRoot = $context.mobileRoot
  runtimeRoot = $context.runtimeRoot
  privateRoot = $context.privateRoot
  credentialsRoot = $context.credentialsRoot
  artifactsRoot = $context.artifactsRoot
  worktreesRoot = $context.worktreesRoot
  isLinkedWorktree = $context.isLinkedWorktree
  branch = Invoke-WorkspaceGit @('branch', '--show-current')
  headSha = Invoke-WorkspaceGit @('rev-parse', 'HEAD')
  origin = $context.origin
  upstream = $context.upstream
  originMain = Invoke-WorkspaceGit @('rev-parse', 'origin/main')
  clean = [string]::IsNullOrWhiteSpace($statusText)
  additionalActiveWorktrees = $additional.Count
  maxAdditionalWorktrees = $context.maxAdditionalWorktrees
  mobileReserved = (Test-Path -LiteralPath $context.mobileRoot -PathType Container)
  dockerPresent = [bool](Get-Command docker -ErrorAction SilentlyContinue)
} | ConvertTo-Json -Depth 5
