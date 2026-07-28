Set-StrictMode -Version 2.0

function Invoke-WorkspaceGit {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $output = & git @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    $details = ($output | Out-String).Trim()
    if (-not $details) { $details = "git $($Arguments -join ' ') falhou." }
    throw $details
  }

  return (($output | Out-String).Trim())
}

function ConvertTo-WorkspaceAbsolutePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  return [System.IO.Path]::GetFullPath($Path.Trim())
}

function Test-WorkspaceSamePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Left,
    [Parameter(Mandatory = $true)]
    [string]$Right
  )

  return [System.String]::Equals(
    (ConvertTo-WorkspaceAbsolutePath $Left),
    (ConvertTo-WorkspaceAbsolutePath $Right),
    [System.StringComparison]::OrdinalIgnoreCase
  )
}

function ConvertTo-WorkspaceRepositorySlug {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RemoteUrl
  )

  $value = $RemoteUrl.Trim()
  if ($value -match '^https?://github\.com/(?<slug>[^/]+/[^/]+?)(?:\.git)?$') {
    return $Matches.slug.ToLowerInvariant()
  }
  if ($value -match '^git@github\.com:(?<slug>[^/]+/[^/]+?)(?:\.git)?$') {
    return $Matches.slug.ToLowerInvariant()
  }
  if ($value -match '^ssh://git@github\.com/(?<slug>[^/]+/[^/]+?)(?:\.git)?$') {
    return $Matches.slug.ToLowerInvariant()
  }

  throw "Remote GitHub nao suportado: $RemoteUrl. Use HTTPS ou SSH para o repositorio esperado."
}

function Get-WorkspaceManifestValue {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Manifest,
    [Parameter(Mandatory = $true)]
    [string]$PropertyName
  )

  $property = $Manifest.PSObject.Properties[$PropertyName]
  if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
    throw "Campo obrigatorio ausente no manifesto portatil: $PropertyName"
  }

  return [string]$property.Value
}

function Get-WorkspaceRegisteredWorktreePaths {
  $lines = (Invoke-WorkspaceGit @('worktree', 'list', '--porcelain')) -split "`r?`n"
  $paths = New-Object System.Collections.Generic.List[string]
  foreach ($line in $lines) {
    if ($line.StartsWith('worktree ')) {
      $path = $line.Substring(9).Trim()
      if ($path) { $paths.Add((ConvertTo-WorkspaceAbsolutePath $path)) }
    }
  }
  return @($paths)
}

function Get-WorkspaceContext {
  [CmdletBinding()]
  param(
    [switch]$IgnoreWorkspaceEnvironment
  )

  $checkoutRoot = ConvertTo-WorkspaceAbsolutePath (Invoke-WorkspaceGit @('rev-parse', '--show-toplevel'))
  $gitCommonDir = ConvertTo-WorkspaceAbsolutePath (Invoke-WorkspaceGit @('rev-parse', '--path-format=absolute', '--git-common-dir'))

  $commonLeaf = [System.IO.Path]::GetFileName($gitCommonDir.TrimEnd('\', '/'))
  if ($commonLeaf -ne '.git') {
    throw "Git common dir nao termina em .git: $gitCommonDir"
  }
  $canonicalServerRoot = ConvertTo-WorkspaceAbsolutePath ([System.IO.Directory]::GetParent($gitCommonDir).FullName)
  $portableManifestPath = Join-Path $canonicalServerRoot '.workspace\project.portable.json'
  if (-not (Test-Path -LiteralPath $portableManifestPath -PathType Leaf)) {
    throw "Manifesto portatil ausente no clone canonico: $portableManifestPath"
  }

  try {
    $portableManifest = Get-Content -LiteralPath $portableManifestPath -Raw | ConvertFrom-Json
  } catch {
    throw "Manifesto portatil invalido: $portableManifestPath. $($_.Exception.Message)"
  }

  if ([int]$portableManifest.schemaVersion -ne 1) {
    throw 'schemaVersion inesperado no manifesto portatil.'
  }
  $serverRelativePath = Get-WorkspaceManifestValue $portableManifest 'serverRelativePath'
  $workspaceEnvironmentVariable = Get-WorkspaceManifestValue $portableManifest 'workspaceEnvironmentVariable'
  if ($workspaceEnvironmentVariable -ne 'CENTRAL_ATENDIMENTO_WORKSPACE_ROOT') {
    throw "Variavel de workspace inesperada: $workspaceEnvironmentVariable"
  }

  $workspaceRoot = $null
  $processWorkspaceRoot = $null
  $userWorkspaceRoot = $null
  if (-not $IgnoreWorkspaceEnvironment) {
    $processWorkspaceRoot = [Environment]::GetEnvironmentVariable($workspaceEnvironmentVariable, 'Process')
    $userWorkspaceRoot = [Environment]::GetEnvironmentVariable($workspaceEnvironmentVariable, 'User')
  }
  if (-not [string]::IsNullOrWhiteSpace($processWorkspaceRoot)) {
    $workspaceRoot = ConvertTo-WorkspaceAbsolutePath $processWorkspaceRoot
  } elseif (-not [string]::IsNullOrWhiteSpace($userWorkspaceRoot)) {
    $workspaceRoot = ConvertTo-WorkspaceAbsolutePath $userWorkspaceRoot
  } else {
    $candidate = [System.IO.Directory]::GetParent($canonicalServerRoot).FullName
    $candidateServer = ConvertTo-WorkspaceAbsolutePath (Join-Path $candidate $serverRelativePath)
    if (Test-WorkspaceSamePath $candidateServer $canonicalServerRoot) {
      $workspaceRoot = ConvertTo-WorkspaceAbsolutePath $candidate
    }
  }

  if (-not $workspaceRoot) {
    throw 'Nao foi possivel comprovar workspaceRoot por variavel ou manifesto local validado.'
  }

  $expectedServerRoot = ConvertTo-WorkspaceAbsolutePath (Join-Path $workspaceRoot $serverRelativePath)
  if (-not (Test-WorkspaceSamePath $expectedServerRoot $canonicalServerRoot)) {
    throw "workspaceRoot nao corresponde ao clone canonico. Esperado: $expectedServerRoot; encontrado: $canonicalServerRoot"
  }

  if (-not (Test-WorkspaceSamePath $checkoutRoot $canonicalServerRoot)) {
    $registered = @(Get-WorkspaceRegisteredWorktreePaths)
    if (-not ($registered | Where-Object { Test-WorkspaceSamePath $_ $checkoutRoot })) {
      throw "checkoutRoot nao esta registrado pelo Git como worktree: $checkoutRoot"
    }
  }

  $origin = Invoke-WorkspaceGit @('config', '--get', 'remote.origin.url')
  $upstream = Invoke-WorkspaceGit @('config', '--get', 'remote.upstream.url')
  if ((ConvertTo-WorkspaceRepositorySlug $origin) -ne 'tadashiyukoyama/centraldeatendimentochat') {
    throw "origin inesperado: $origin"
  }
  if ((ConvertTo-WorkspaceRepositorySlug $upstream) -ne 'chatwoot/chatwoot') {
    throw "upstream inesperado: $upstream"
  }

  $mobileRoot = ConvertTo-WorkspaceAbsolutePath (Join-Path $workspaceRoot (Get-WorkspaceManifestValue $portableManifest 'mobileRelativePath'))
  $runtimeRoot = ConvertTo-WorkspaceAbsolutePath (Join-Path $workspaceRoot (Get-WorkspaceManifestValue $portableManifest 'runtimeRelativePath'))
  $privateRoot = ConvertTo-WorkspaceAbsolutePath (Join-Path $workspaceRoot (Get-WorkspaceManifestValue $portableManifest 'privateRelativePath'))
  $credentialsRoot = ConvertTo-WorkspaceAbsolutePath (Join-Path $workspaceRoot (Get-WorkspaceManifestValue $portableManifest 'credentialsRelativePath'))
  $artifactsRoot = ConvertTo-WorkspaceAbsolutePath (Join-Path $workspaceRoot (Get-WorkspaceManifestValue $portableManifest 'artifactsRelativePath'))
  $worktreesRoot = ConvertTo-WorkspaceAbsolutePath (Join-Path $workspaceRoot (Get-WorkspaceManifestValue $portableManifest 'worktreesRelativePath'))

  return [pscustomobject]@{
    workspaceRoot = $workspaceRoot
    canonicalServerRoot = $canonicalServerRoot
    checkoutRoot = $checkoutRoot
    gitCommonDir = $gitCommonDir
    worktreesRoot = $worktreesRoot
    mobileRoot = $mobileRoot
    runtimeRoot = $runtimeRoot
    privateRoot = $privateRoot
    credentialsRoot = $credentialsRoot
    artifactsRoot = $artifactsRoot
    isLinkedWorktree = (-not (Test-WorkspaceSamePath $checkoutRoot $canonicalServerRoot))
    origin = $origin
    upstream = $upstream
    projectId = Get-WorkspaceManifestValue $portableManifest 'projectId'
    maxAdditionalWorktrees = [int]$portableManifest.maxAdditionalWorktrees
    portableManifestPath = $portableManifestPath
    portableManifest = $portableManifest
  }
}
