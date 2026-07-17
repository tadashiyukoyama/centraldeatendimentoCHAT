[CmdletBinding()]
param(
  [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\WorkspaceContext.ps1')

if (-not $RepositoryRoot) {
  $RepositoryRoot = [System.IO.Directory]::GetParent($PSScriptRoot).FullName
}
$RepositoryRoot = ConvertTo-WorkspaceAbsolutePath $RepositoryRoot

$portableManifestPath = Join-Path $RepositoryRoot '.workspace\project.portable.json'
$portableSchemaPath = Join-Path $RepositoryRoot '.workspace\schemas\project.portable.schema.json'
$localExamplePath = Join-Path $RepositoryRoot '.workspace\templates\project.local.example.json'
$localSchemaPath = Join-Path $RepositoryRoot '.workspace\schemas\project.local.schema.json'
$ledgerExamplePath = Join-Path $RepositoryRoot '.workspace\templates\worktrees.local.example.json'
$ledgerSchemaPath = Join-Path $RepositoryRoot '.workspace\schemas\worktree-ledger.schema.json'

foreach ($path in @($portableManifestPath, $portableSchemaPath, $localExamplePath, $localSchemaPath, $ledgerExamplePath, $ledgerSchemaPath)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Contrato ou schema ausente: $path"
  }
}

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCommand) {
  throw 'Python e necessario para a validacao Draft 2020-12; o workflow instala apenas jsonschema, sem runtime do projeto.'
}

$pythonValidator = @'
import json
import sys
from pathlib import Path
from jsonschema import Draft202012Validator

schema_path, instance_path, label = sys.argv[1:4]
schema = json.loads(Path(schema_path).read_text(encoding="utf-8"))
instance = json.loads(Path(instance_path).read_text(encoding="utf-8"))
Draft202012Validator.check_schema(schema)
errors = sorted(Draft202012Validator(schema).iter_errors(instance), key=lambda error: list(error.absolute_path))
if errors:
    for error in errors:
        location = ".".join(str(part) for part in error.absolute_path) or "$"
        print(f"{label}: {location}: {error.message}")
    sys.exit(1)
print(f"{label}: OK")
'@

$validationErrorPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$importOutput = & $pythonCommand.Source -c 'import jsonschema' 2>&1
$ErrorActionPreference = $validationErrorPreference
$pythonHasJsonSchema = ($LASTEXITCODE -eq 0)

function Assert-FallbackContract {
  param(
    [Parameter(Mandatory = $true)] [string]$SchemaPath,
    [Parameter(Mandatory = $true)] [string]$InstancePath,
    [Parameter(Mandatory = $true)] [string]$Label
  )

  $schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
  $instance = Get-Content -LiteralPath $InstancePath -Raw | ConvertFrom-Json
  if ($schema.'$schema' -ne 'https://json-schema.org/draft/2020-12/schema') {
    throw "${Label}: schema Draft 2020-12 ausente."
  }
  if ($schema.additionalProperties -ne $false) {
    throw "${Label}: schema deve bloquear propriedades adicionais."
  }

  $properties = @($schema.properties.PSObject.Properties.Name)
  $instanceProperties = @($instance.PSObject.Properties.Name)
  foreach ($required in @($schema.required)) {
    if ($instanceProperties -notcontains [string]$required) {
      throw "${Label}: campo obrigatorio ausente: $required"
    }
  }
  foreach ($property in $instanceProperties) {
    if ($properties -notcontains $property) {
      throw "${Label}: propriedade adicional: $property"
    }
  }

  if ($instance.projectId -ne 'CENTRAL_ATENDIMENTO_CHAT') {
    throw "${Label}: projectId incorreto."
  }
  if ([int]$instance.maxAdditionalWorktrees -ne 2) {
    throw "${Label}: limite de worktrees incorreto."
  }
  if ($Label -eq 'portable') {
    foreach ($field in @('serverRelativePath', 'mobileRelativePath', 'runtimeRelativePath', 'privateRelativePath', 'artifactsRelativePath', 'worktreesRelativePath')) {
      $value = [string]$instance.$field
      if ($value -match '^[A-Za-z]:[\\/]' -or $value.StartsWith('/') -or $value.StartsWith('\')) {
        throw "${Label}: caminho absoluto em $field."
      }
    }
  }
  if ($Label -eq 'ledger-example' -and @($instance.activeAdditionalWorktrees).Count -gt 2) {
    throw "${Label}: mais de duas worktrees."
  }
}

function Assert-JsonSchema {
  param(
    [Parameter(Mandatory = $true)] [string]$SchemaPath,
    [Parameter(Mandatory = $true)] [string]$InstancePath,
    [Parameter(Mandatory = $true)] [string]$Label
  )

  if (-not $pythonHasJsonSchema) {
    Assert-FallbackContract $SchemaPath $InstancePath $Label
    return
  }

  $validationErrorPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $output = & $pythonCommand.Source -c $pythonValidator $SchemaPath $InstancePath $Label 2>&1
  $validationExitCode = $LASTEXITCODE
  $ErrorActionPreference = $validationErrorPreference
  if ($validationExitCode -ne 0) {
    $message = (($output | Out-String).Trim())
    if ($message -match 'No module named .*jsonschema') {
      Assert-FallbackContract $SchemaPath $InstancePath $Label
      return
    }
    throw $message
  }
}

Assert-JsonSchema $portableSchemaPath $portableManifestPath 'portable'
Assert-JsonSchema $localSchemaPath $localExamplePath 'local-example'
Assert-JsonSchema $ledgerSchemaPath $ledgerExamplePath 'ledger-example'

$portable = Get-Content -LiteralPath $portableManifestPath -Raw | ConvertFrom-Json
if ($portable.projectId -ne 'CENTRAL_ATENDIMENTO_CHAT') {
  throw 'projectId inesperado no manifesto portatil.'
}
if ([int]$portable.maxAdditionalWorktrees -ne 2) {
  throw 'O limite do manifesto portatil deve ser duas worktrees adicionais.'
}

foreach ($field in @('serverRelativePath', 'mobileRelativePath', 'runtimeRelativePath', 'privateRelativePath', 'artifactsRelativePath', 'worktreesRelativePath')) {
  $value = [string]$portable.$field
  if ($value -match '^[A-Za-z]:[\\/]' -or $value.StartsWith('/') -or $value.StartsWith('\')) {
    throw "Caminho absoluto no manifesto portatil: $field"
  }
}

$origin = (Invoke-WorkspaceGit @('config', '--get', 'remote.origin.url')).Trim()
$upstream = (Invoke-WorkspaceGit @('config', '--get', 'remote.upstream.url')).Trim()
if ((ConvertTo-WorkspaceRepositorySlug $origin) -ne 'tadashiyukoyama/centraldeatendimentochat') {
  throw "origin inesperado: $origin"
}
if ((ConvertTo-WorkspaceRepositorySlug $upstream) -ne 'chatwoot/chatwoot') {
  throw "upstream inesperado: $upstream"
}

[pscustomobject]@{
  repositoryRoot = $RepositoryRoot
  portableSchema = $portableSchemaPath
  localSchema = $localSchemaPath
  ledgerSchema = $ledgerSchemaPath
  projectId = $portable.projectId
  maxAdditionalWorktrees = [int]$portable.maxAdditionalWorktrees
  origin = $origin
  upstream = $upstream
  valid = $true
} | ConvertTo-Json -Depth 4
