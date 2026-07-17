# Política de armazenamento

- Código: `server/`.
- Mobile reservado: `mobile/`, sem clone nesta fase.
- Dados persistentes locais: `runtime/data/`.
- Credenciais e envs reais: `private/`.
- Backups de banco: `private/recovery/database/`.
- Relatórios temporários: `artifacts/`.
- Worktrees adicionais: `worktrees/`.
- Cache e temporários: `runtime/cache/` e `runtime/temp/`.

Não criar cópia integral do repositório em artifacts, recovery ou worktrees.
Não versionar dados, uploads, dumps, logs crus, segredos ou envs reais.

Antes de qualquer operação que possa consumir espaço relevante, executar
`scripts/disk-guard.ps1 -ReadOnly`.
