[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$sourceRepoRoot = [System.IO.Directory]::GetParent([System.IO.Directory]::GetParent($PSScriptRoot).FullName).FullName
$script:PowerShellExecutable = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell.exe' }
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("centraldeatendimentochat-workspace-tests-" + [guid]::NewGuid().ToString('N'))
$capsuleRoot = Join-Path $testRoot 'capsule'
$serverRoot = Join-Path $capsuleRoot 'server'
$mobileRoot = Join-Path $capsuleRoot 'mobile'
$runtimeRoot = Join-Path $capsuleRoot 'runtime'
$credentialsRoot = Join-Path $capsuleRoot 'credenciais'
$worktreesRoot = Join-Path $capsuleRoot 'worktrees'
$linkedRoot = Join-Path $worktreesRoot 'context-validation'
$previousWorkspaceRoot = [Environment]::GetEnvironmentVariable('CENTRAL_ATENDIMENTO_WORKSPACE_ROOT', 'Process')
$results = New-Object System.Collections.Generic.List[object]

function Invoke-LocalGit {
  param(
    [Parameter(Mandatory = $true)] [string]$WorkingDirectory,
    [Parameter(Mandatory = $true)] [string[]]$Arguments
  )

  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $output = & git -C $WorkingDirectory @Arguments 2>&1
  $ErrorActionPreference = $oldPreference
  if ($LASTEXITCODE -ne 0) {
    throw (($output | Out-String).Trim())
  }
  return (($output | Out-String).Trim())
}

function Set-TextFile {
  param(
    [Parameter(Mandatory = $true)] [string]$Path,
    [Parameter(Mandatory = $true)] [string]$Text
  )
  [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-WorkspaceScriptJson {
  param(
    [Parameter(Mandatory = $true)] [string]$ScriptPath,
    [Parameter(Mandatory = $true)] [string]$WorkingDirectory,
    [string[]]$Arguments = @()
  )

  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $output = & $script:PowerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
  $ErrorActionPreference = $oldPreference
  if ($LASTEXITCODE -ne 0) {
    throw (($output | Out-String).Trim())
  }
  return (($output | Out-String).Trim() | ConvertFrom-Json)
}

function Assert-True {
  param(
    [Parameter(Mandatory = $true)] [bool]$Condition,
    [Parameter(Mandatory = $true)] [string]$Message
  )
  if (-not $Condition) { throw $Message }
}

function Assert-SamePath {
  param(
    [Parameter(Mandatory = $true)] [string]$Left,
    [Parameter(Mandatory = $true)] [string]$Right,
    [Parameter(Mandatory = $true)] [string]$Message
  )
  $leftPath = [System.IO.Path]::GetFullPath($Left)
  $rightPath = [System.IO.Path]::GetFullPath($Right)
  Assert-True ([System.String]::Equals($leftPath, $rightPath, [System.StringComparison]::OrdinalIgnoreCase)) $Message
}

function Assert-Throws {
  param(
    [Parameter(Mandatory = $true)] [scriptblock]$Action,
    [Parameter(Mandatory = $true)] [string]$MessageFragment
  )

  $thrown = $false
  $message = ''
  try {
    $output = & $Action 2>&1
    if ($LASTEXITCODE -ne 0) {
      $thrown = $true
      $message = ($output | Out-String).Trim()
    }
  } catch {
    $thrown = $true
    $message = $_.Exception.Message
  }
  Assert-True $thrown "Esperava falha contendo '$MessageFragment'."
  Assert-True ($message -like "*$MessageFragment*") "Falha inesperada: $message"
}

function Run-Test {
  param(
    [Parameter(Mandatory = $true)] [string]$Name,
    [Parameter(Mandatory = $true)] [scriptblock]$Action
  )

  try {
    & $Action
    $results.Add([pscustomobject]@{ name = $Name; status = 'passed' })
    Write-Output "PASS $Name"
  } catch {
    $results.Add([pscustomobject]@{ name = $Name; status = 'failed'; error = $_.Exception.Message })
    Write-Output "FAIL ${Name}: $($_.Exception.Message)"
  }
}

function Copy-ContractFile {
  param(
    [Parameter(Mandatory = $true)] [string]$RelativePath
  )

  $source = Join-Path $sourceRepoRoot $RelativePath
  $destination = Join-Path $serverRoot $RelativePath
  New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($destination)) | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Force
}

function Get-PortableObject {
  return Get-Content -LiteralPath (Join-Path $serverRoot '.workspace\project.portable.json') -Raw | ConvertFrom-Json
}

function Write-PortableObject {
  param([Parameter(Mandatory = $true)] [object]$Manifest)
  $path = Join-Path $serverRoot '.workspace\project.portable.json'
  $Manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding UTF8
}

$canonicalContext = $null
$linkedContext = $null
$helperPath = Join-Path $serverRoot 'scripts\lib\WorkspaceContext.ps1'
$validatorPath = Join-Path $serverRoot 'scripts\validate-workspace-contracts.ps1'
$verifyPath = Join-Path $serverRoot 'scripts\verify-capsule.ps1'
$rehydratePath = Join-Path $serverRoot 'scripts\rehydrate-workspace.ps1'
$checkBudgetPath = Join-Path $serverRoot 'scripts\check-worktree-budget.ps1'
$diskGuardPath = Join-Path $serverRoot 'scripts\disk-guard.ps1'

try {
  $requiredDirectories = @(
    $serverRoot,
    $mobileRoot,
    $credentialsRoot,
    (Join-Path $capsuleRoot 'artifacts'),
    (Join-Path $capsuleRoot 'private\recovery\database'),
    (Join-Path $runtimeRoot 'data\postgres'),
    (Join-Path $runtimeRoot 'data\redis'),
    (Join-Path $runtimeRoot 'data\storage'),
    (Join-Path $runtimeRoot 'cache'),
    (Join-Path $runtimeRoot 'logs'),
    (Join-Path $runtimeRoot 'memory\short-term'),
    (Join-Path $runtimeRoot 'temp'),
    $worktreesRoot
  )
  foreach ($directory in $requiredDirectories) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  Set-TextFile (Join-Path $mobileRoot 'README.md') 'Temporary mobile reservation for workspace foundation tests.'

  foreach ($relativePath in @(
    '.workspace\project.portable.json',
    '.workspace\schemas\project.portable.schema.json',
    '.workspace\schemas\project.local.schema.json',
    '.workspace\schemas\worktree-ledger.schema.json',
    '.workspace\templates\project.local.example.json',
    '.workspace\templates\worktrees.local.example.json',
    'scripts\lib\WorkspaceContext.ps1',
    'scripts\validate-workspace-contracts.ps1',
    'scripts\verify-capsule.ps1',
    'scripts\rehydrate-workspace.ps1',
    'scripts\project-status.ps1',
    'scripts\check-worktree-budget.ps1',
    'scripts\disk-guard.ps1',
    'scripts\validate-local-boundaries.ps1'
  )) {
    Copy-ContractFile $relativePath
  }

  $null = Invoke-LocalGit $serverRoot @('init', '-b', 'main')
  $null = Invoke-LocalGit $serverRoot @('config', 'user.name', 'Workspace Foundation Tests')
  $null = Invoke-LocalGit $serverRoot @('config', 'user.email', 'workspace-foundation-tests@example.invalid')
  $null = Invoke-LocalGit $serverRoot @('add', '.')
  $null = Invoke-LocalGit $serverRoot @('commit', '-m', 'test fixture')
  $null = Invoke-LocalGit $serverRoot @('remote', 'add', 'origin', 'https://github.com/tadashiyukoyama/centraldeatendimentoCHAT.git')
  $null = Invoke-LocalGit $serverRoot @('remote', 'add', 'upstream', 'https://github.com/chatwoot/chatwoot.git')

  $env:CENTRAL_ATENDIMENTO_WORKSPACE_ROOT = $capsuleRoot
  Push-Location $serverRoot
  . $helperPath

  Run-Test 'canonical checkout with workspace variable' {
    $script:canonicalContext = Get-WorkspaceContext
    Assert-SamePath $script:canonicalContext.checkoutRoot $serverRoot 'checkoutRoot canonico incorreto.'
    Assert-SamePath $script:canonicalContext.canonicalServerRoot $serverRoot 'canonicalServerRoot incorreto.'
    Assert-SamePath $script:canonicalContext.workspaceRoot $capsuleRoot 'workspaceRoot incorreto.'
    Assert-SamePath $script:canonicalContext.credentialsRoot $credentialsRoot 'credentialsRoot incorreto.'
    Assert-True (-not $script:canonicalContext.isLinkedWorktree) 'Checkout canonico nao pode ser linked.'
  }

  Run-Test 'canonical checkout without workspace variable' {
    $old = [Environment]::GetEnvironmentVariable('CENTRAL_ATENDIMENTO_WORKSPACE_ROOT', 'Process')
    try {
      Remove-Item Env:CENTRAL_ATENDIMENTO_WORKSPACE_ROOT -ErrorAction SilentlyContinue
      $context = Get-WorkspaceContext -IgnoreWorkspaceEnvironment
      Assert-SamePath $context.workspaceRoot $capsuleRoot 'Fallback do workspaceRoot incorreto.'
    } finally {
      $env:CENTRAL_ATENDIMENTO_WORKSPACE_ROOT = $old
    }
  }

  $null = Invoke-LocalGit $serverRoot @('worktree', 'add', '--detach', $linkedRoot, 'HEAD')

  Run-Test 'linked worktree with workspace variable' {
    Push-Location $linkedRoot
    try {
      $context = Get-WorkspaceContext
      Assert-SamePath $context.checkoutRoot $linkedRoot 'checkoutRoot da linked incorreto.'
      Assert-SamePath $context.canonicalServerRoot $serverRoot 'canonicalServerRoot da linked incorreto.'
      Assert-True $context.isLinkedWorktree 'Linked worktree nao identificada.'
    } finally {
      Pop-Location
    }
  }

  Run-Test 'linked worktree without workspace variable' {
    Push-Location $linkedRoot
    try {
      $context = Get-WorkspaceContext -IgnoreWorkspaceEnvironment
      Assert-SamePath $context.workspaceRoot $capsuleRoot 'Fallback da linked nao usa o pai da worktree.'
      Assert-SamePath $context.canonicalServerRoot $serverRoot 'Common Git dir da linked incorreto.'
    } finally {
      Pop-Location
    }
  }

  Run-Test 'incorrect origin is rejected' {
    $original = Invoke-LocalGit $serverRoot @('config', '--get', 'remote.origin.url')
    try {
      $null = Invoke-LocalGit $serverRoot @('config', 'remote.origin.url', 'https://github.com/example/wrong.git')
      Assert-Throws { Get-WorkspaceContext } 'origin inesperado'
    } finally {
      $null = Invoke-LocalGit $serverRoot @('config', 'remote.origin.url', $original)
    }
  }

  Run-Test 'incorrect upstream is rejected' {
    $original = Invoke-LocalGit $serverRoot @('config', '--get', 'remote.upstream.url')
    try {
      $null = Invoke-LocalGit $serverRoot @('config', 'remote.upstream.url', 'https://github.com/example/wrong.git')
      Assert-Throws { Get-WorkspaceContext } 'upstream inesperado'
    } finally {
      $null = Invoke-LocalGit $serverRoot @('config', 'remote.upstream.url', $original)
    }
  }

  Run-Test 'incorrect projectId is rejected' {
    $path = Join-Path $serverRoot '.workspace\project.portable.json'
    $original = Get-Content -LiteralPath $path -Raw
    try {
      $manifest = $original | ConvertFrom-Json
      $manifest.projectId = 'WRONG_PROJECT'
      Write-PortableObject $manifest
      Assert-Throws { & $script:PowerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $validatorPath } 'projectId'
    } finally {
      Set-TextFile $path $original
    }
  }

  Run-Test 'worktree limit is rejected when exceeded' {
    $extraPaths = @(
      (Join-Path $worktreesRoot 'extra-one'),
      (Join-Path $worktreesRoot 'extra-two')
    )
    try {
      foreach ($extraPath in $extraPaths) {
        $null = Invoke-LocalGit $serverRoot @('worktree', 'add', '--detach', $extraPath, 'HEAD')
      }
      Assert-Throws { & $script:PowerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $checkBudgetPath } 'Orcamento excedido'
    } finally {
      foreach ($extraPath in @($extraPaths | Sort-Object -Descending)) {
        if (Test-Path -LiteralPath $extraPath) {
          $null = Invoke-LocalGit $serverRoot @('worktree', 'remove', $extraPath)
        }
      }
    }
  }

  Run-Test 'absolute portable path is rejected' {
    $path = Join-Path $serverRoot '.workspace\project.portable.json'
    $original = Get-Content -LiteralPath $path -Raw
    try {
      $manifest = $original | ConvertFrom-Json
      $manifest.serverRelativePath = 'D:\absolute-server'
      Write-PortableObject $manifest
      Assert-Throws { & $script:PowerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $validatorPath } 'portable'
    } finally {
      Set-TextFile $path $original
    }
  }

  Run-Test 'mobile git directory is rejected' {
    $mobileGit = Join-Path $mobileRoot '.git'
    New-Item -ItemType Directory -Force -Path $mobileGit | Out-Null
    try {
      Assert-Throws { & $script:PowerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $verifyPath } 'mobile deve conter'
    } finally {
      Remove-Item -LiteralPath $mobileGit -Recurse -Force
    }
  }

  Run-Test 'read-only rehydration does not write' {
    $missingPath = Join-Path $runtimeRoot 'data\redis'
    Remove-Item -LiteralPath $missingPath -Recurse -Force
    try {
      Assert-Throws { & $script:PowerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $rehydratePath -ReadOnly } 'diretorios ausentes'
      Assert-True (-not (Test-Path -LiteralPath $missingPath)) 'Reidratação read-only escreveu no workspace.'
    } finally {
      New-Item -ItemType Directory -Force -Path $missingPath | Out-Null
    }
  }

  Run-Test 'disk guard does not depend on drive D' {
    $scriptText = Get-Content -LiteralPath $diskGuardPath -Raw
    Assert-True ($scriptText -notmatch 'Get-PSDrive\s+C,D') 'Disk guard ainda referencia C,D literalmente.'
    $disk = & $script:PowerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $diskGuardPath -ReadOnly | Out-String | ConvertFrom-Json
    $expectedDrive = ([System.IO.Path]::GetPathRoot($capsuleRoot)).Substring(0, 1).ToUpperInvariant()
    Assert-True (@($disk.observedDriveRoots) -contains $expectedDrive) 'Disk guard nao observou o drive do workspace.'
  }

  Run-Test 'server and linked worktree report the same count' {
    $serverBudget = & $script:PowerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $checkBudgetPath | Out-String | ConvertFrom-Json
    Push-Location $linkedRoot
    try {
      $linkedBudget = & $script:PowerShellExecutable -NoProfile -ExecutionPolicy Bypass -File (Join-Path $linkedRoot 'scripts\check-worktree-budget.ps1') | Out-String | ConvertFrom-Json
    } finally {
      Pop-Location
    }
    Assert-True ($serverBudget.additionalActiveWorktrees -eq 1) 'Contagem canonica esperada era 1.'
    Assert-True ($linkedBudget.additionalActiveWorktrees -eq $serverBudget.additionalActiveWorktrees) 'Server e linked divergem na contagem.'
  }

  Run-Test 'checkoutRoot and canonicalServerRoot remain distinct' {
    $canonical = Get-WorkspaceContext
    Push-Location $linkedRoot
    try {
      $linked = Get-WorkspaceContext
    } finally {
      Pop-Location
    }
    Assert-True (-not ([System.String]::Equals($linked.checkoutRoot, $linked.canonicalServerRoot, [System.StringComparison]::OrdinalIgnoreCase))) 'A linked perdeu a distinção de raízes.'
    Assert-SamePath $canonical.checkoutRoot $serverRoot 'Raiz canonica alterada.'
    Assert-SamePath $linked.canonicalServerRoot $serverRoot 'Raiz canonica da linked alterada.'
  }

  $failures = @($results | Where-Object status -eq 'failed')
  [pscustomobject]@{
    testCount = $results.Count
    passed = @($results | Where-Object status -eq 'passed').Count
    failed = $failures.Count
    results = $results
  } | ConvertTo-Json -Depth 6
  if ($failures.Count -gt 0) {
    throw (($failures | ConvertTo-Json -Depth 4))
  }
} finally {
  if ((Get-Location).Path -ne $sourceRepoRoot) {
    while ((Get-Location).Path -ne $sourceRepoRoot) { Pop-Location }
  }

  if ($null -eq $previousWorkspaceRoot) {
    Remove-Item Env:CENTRAL_ATENDIMENTO_WORKSPACE_ROOT -ErrorAction SilentlyContinue
  } else {
    $env:CENTRAL_ATENDIMENTO_WORKSPACE_ROOT = $previousWorkspaceRoot
  }

  if (Test-Path -LiteralPath $serverRoot) {
    $worktreeLines = (& git -C $serverRoot worktree list --porcelain 2>$null) -split "`r?`n"
    $registered = @($worktreeLines | Where-Object { $_ -like 'worktree *' } | ForEach-Object {
      [System.IO.Path]::GetFullPath($_.Substring(9).Trim())
    })
    foreach ($path in @($registered | Where-Object { $_ -ne [System.IO.Path]::GetFullPath($serverRoot) })) {
      $status = (& git -C $path status --porcelain 2>$null | Out-String).Trim()
      if (-not $status) {
        & git -C $serverRoot worktree remove $path 2>$null | Out-Null
      } else {
        Write-Warning "Worktree de teste com alterações não nulas não foi removida: $path"
      }
    }
    $remainingStatus = (& git -C $serverRoot status --porcelain 2>$null | Out-String).Trim()
    if (-not $remainingStatus) {
      $pathsToNormalize = @(
        Get-Item -LiteralPath $testRoot -Force -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $testRoot -Force -Recurse -ErrorAction SilentlyContinue
      )
      foreach ($pathToNormalize in $pathsToNormalize) {
        $pathToNormalize.Attributes = [System.IO.FileAttributes]::Normal
      }
      Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    } else {
      Write-Warning "Capsula de teste preservada para inspeção por conter alterações: $testRoot"
    }
  }
}
