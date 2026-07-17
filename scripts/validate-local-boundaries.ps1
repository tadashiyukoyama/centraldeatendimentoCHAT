[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\WorkspaceContext.ps1')
$context = Get-WorkspaceContext
$portableText = Get-Content -LiteralPath $context.portableManifestPath -Raw
$violations = New-Object System.Collections.Generic.List[string]

if ($portableText -match '[A-Za-z]:[\\/]') {
  $violations.Add('project.portable.json contem caminho absoluto')
}

$legacyClonePath = Join-Path ([System.IO.Directory]::GetParent($context.workspaceRoot).FullName) 'chatwoot'
$oldPathNeedle = ConvertTo-WorkspaceAbsolutePath $legacyClonePath
$oldPathHits = @(& rg --hidden --glob '!.git/**' --glob '!*.lock' -n -F $oldPathNeedle $context.checkoutRoot 2>$null)
if ($oldPathHits.Count -gt 0) {
  $violations.Add('referencia operacional ao clone antigo')
}

$scriptDriveHits = @(& rg --hidden --glob 'scripts/**/*.ps1' --glob '.workspace/project.portable.json' --glob '!scripts/lib/WorkspaceContext.ps1' --glob '!scripts/validate-local-boundaries.ps1' -n -e '(^|[[:space:]])[A-Za-z]:[\\/]' $context.checkoutRoot 2>$null)
if ($scriptDriveHits.Count -gt 0) {
  $violations.Add('scripts ou manifesto portatil contem drive absoluto')
}

$codexCandidates = @(
  (Join-Path $context.checkoutRoot '.codex'),
  (Join-Path $context.mobileRoot '.codex'),
  (Join-Path $context.worktreesRoot '.codex')
)
$codexPaths = @($codexCandidates | Where-Object { Test-Path -LiteralPath $_ })
if ($codexPaths.Count -gt 0) {
  $violations.Add('diretorio .codex fora do CODEX_HOME')
}

$trackedFiles = @((Invoke-WorkspaceGit @('ls-files')) -split "`r?`n" | Where-Object { $_ })
$trackedViolations = @($trackedFiles | Where-Object {
  $_ -match '(^|/)(private|runtime|worktrees|artifacts)/' -or
  $_ -match '(^|/)\.env$' -or
  $_ -match '^infra/env/[^/]+\.env$'
})
if ($trackedViolations.Count -gt 0) {
  $violations.Add('segredo, env ou capsula versionado')
}

if (Test-Path -LiteralPath (Join-Path $context.mobileRoot '.git')) {
  $violations.Add('mobile contem .git antes do bootstrap autorizado')
}

$result = [pscustomobject]@{
  workspaceRoot = $context.workspaceRoot
  canonicalServerRoot = $context.canonicalServerRoot
  checkoutRoot = $context.checkoutRoot
  isLinkedWorktree = $context.isLinkedWorktree
  oldPathReferences = $oldPathHits.Count
  hardcodedDriveReferences = $scriptDriveHits.Count
  codexViolations = $codexPaths.Count
  trackedBoundaryViolations = $trackedViolations.Count
  violations = $violations
  valid = ($violations.Count -eq 0)
}
$result | ConvertTo-Json -Depth 5
if ($violations.Count -gt 0) {
  throw ($violations -join '; ')
}
