[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (git rev-parse --show-toplevel).Trim()
$portablePath = Join-Path $repoRoot '.workspace\project.portable.json'
$portableText = Get-Content -Raw $portablePath
$violations = New-Object System.Collections.Generic.List[string]

if ($portableText -match '[A-Za-z]:[\\/]') {
  $violations.Add('project.portable.json contém caminho absoluto')
}

$oldPathNeedle = ('D:' + '\dev\workspaces\chatwoot')
$oldPathHits = @(rg --hidden --glob '!.git/**' --glob '!*.lock' -n -F $oldPathNeedle $repoRoot 2>$null)
if ($oldPathHits.Count -gt 0) {
  $violations.Add('referência operacional ao clone antigo')
}

$codexPaths = @(
  (Join-Path $repoRoot '.codex'),
  (Join-Path (Join-Path $repoRoot '..') 'mobile\.codex'),
  (Join-Path (Join-Path $repoRoot '..') 'worktrees\.codex')
) | Where-Object { Test-Path -LiteralPath $_ }
if ($codexPaths.Count -gt 0) {
  $violations.Add('diretório .codex fora do CODEX_HOME')
}

$trackedViolations = @(git ls-files | Where-Object {
  $_ -match '(^|/)(private|runtime|worktrees|artifacts)/' -or
  $_ -match '(^|/)\.env$' -or
  $_ -match '^infra/env/[^/]+\.env$'
})
if ($trackedViolations.Count -gt 0) {
  $violations.Add('segredo, env ou cápsula versionado')
}

$mobileRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot '..\mobile'))
if (Test-Path -LiteralPath (Join-Path $mobileRoot '.git')) {
  $violations.Add('mobile contém .git antes do bootstrap autorizado')
}

$result = [pscustomobject]@{
  oldPathReferences = $oldPathHits.Count
  codexViolations = $codexPaths.Count
  trackedBoundaryViolations = $trackedViolations.Count
  violations = $violations
  valid = ($violations.Count -eq 0)
}
$result | ConvertTo-Json -Depth 5
if ($violations.Count -gt 0) {
  throw ($violations -join '; ')
}
