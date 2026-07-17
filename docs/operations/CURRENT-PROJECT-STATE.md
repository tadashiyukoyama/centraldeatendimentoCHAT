# Estado atual do projeto

Este é o documento canônico do estado operacional do
`CENTRAL_ATENDIMENTO_CHAT`. O estado observado no Git sempre prevalece sobre
qualquer valor copiado neste documento.

## Identidade e controle de versão

- Repositório canônico: `tadashiyukoyama/centraldeatendimentoCHAT`.
- Upstream: `chatwoot/chatwoot`.
- Base autorizada: `4b195fd4d985377c92d7732040e96913d8c485a6`.
- Branch da correção: `ops/consolidate-workspace-and-mobile-foundation`.
- PR: `#1`, mantida como draft.
- HEAD e status devem ser obtidos por `git rev-parse HEAD` e `git status`.
- O HEAD esperado antes desta correção era
  `c0cbd4bf39eb7f8772c88514b4a3fe1b6aa430de`.

## Cápsula física portátil

```text
centraldeatendimentoCHAT/
├── .workspace/       identidade, manifestos e ledger local
├── artifacts/        relatórios e entregáveis não versionados
├── private/          envs reais, credenciais e recuperação do banco
├── runtime/          dados, cache, logs, temporários e memória curta
├── worktrees/        worktrees adicionais autorizadas
├── server/           clone Git canônico do Chatwoot OSS
└── mobile/           reserva do futuro repositório mobile
```

O caminho absoluto é resolvido por `CENTRAL_ATENDIMENTO_WORKSPACE_ROOT`, na
variável de processo, na variável de usuário ou pelo pai validado do clone
canônico. O manifesto portátil em `.workspace/project.portable.json` contém
somente caminhos relativos e é validado pelo schema em
`.workspace/schemas/project.portable.schema.json`.

O `server/` é o clone canônico. Em uma worktree vinculada, o `checkoutRoot` é
o caminho da worktree, enquanto `canonicalServerRoot` continua sendo derivado
do `git-common-dir`. Os scripts em `scripts/` usam o contexto centralizado em
`scripts/lib/WorkspaceContext.ps1`.

## Worktrees

- O clone canônico não entra na contagem.
- O máximo é de duas worktrees adicionais ativas.
- Antes de criar ou remover uma worktree, executar o disk guard e
  `scripts/check-worktree-budget.ps1`.
- Não há limpeza, prune ou remoção automática.
- Alterações não commitadas, commits úteis, PRs ou processos ativos bloqueiam
  a remoção até inspeção e autorização.

## Dados, banco e credenciais

- Banco oficial: PostgreSQL 16 com `pgvector`; localmente, o caminho reservado
  é `runtime/data/postgres`.
- Redis 7 para cache, pub/sub e filas; localmente, `runtime/data/redis`.
- Active Storage local em `runtime/data/storage`; produção usa volume do host
  ou armazenamento S3 compatível.
- Segredos reais: `private/env` e `private/credentials`, ou secret store do
  provedor.
- Dumps e recuperação: `private/recovery/database`.
- Nenhum desses valores é versionado ou impresso pelo Codex.

## Mobile

`mobile/` é somente uma reserva com marcador. O futuro repositório é
`tadashiyukoyama/centraldeatendimentoCHAT-mobile`, com upstream
`chatwoot/chatwoot-mobile-app`. O mobile não foi baixado, não possui `.git`,
dependências ou build nesta fase.

## Estado de runtime desta fase

Docker não está instalado e não foi instalado. Não foram executados Compose,
containers locais, migrations, banco local, healthchecks, acesso a VPS ou
deploy. A infraestrutura versionada continua sendo contrato, não evidência de
execução.

## Diagnóstico frontend

O run remoto anterior da PR, `29563348750`, terminou com `frontend-tests`
falhando no job `87830390554`. A falha é determinística no mock de
`dashboard/composables/store`: o teste fornece `useMapGetter`, mas
`useAccount.js` importa `useStore` pela cadeia usada por
`useChannelConfig.js`. O resultado observado foi 2 testes falhos, 376 de 377
arquivos aprovados e 3738 de 3740 testes aprovados. `lint-frontend` passou.

Os arquivos do produto envolvidos não foram alterados nesta correção e não
tinham diff em relação à base autorizada; o diagnóstico não inclui conserto de
produto. O CI será observado após o novo commit, sem reexecução manual antes
dele.

## Evidência operacional

As validações locais previstas para a fundação são `verify-capsule.ps1`,
`check-worktree-budget.ps1`, `rehydrate-workspace.ps1 -ReadOnly`,
`project-status.ps1`, `disk-guard.ps1 -ReadOnly` e
`validate-local-boundaries.ps1`. Elas devem comprovar separadamente
`checkoutRoot`, `canonicalServerRoot` e `workspaceRoot`, além de origem,
upstream, limites de worktree e fronteiras privadas.
