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
- Dumps locais e recuperação: `private/recovery/database`; no host de produção,
  o gate usa `/opt/central-atendimento/shared/backups/postgres/`, fora do clone
  e dos volumes Docker.
- Nenhum desses valores é versionado ou impresso pelo Codex.

## Mobile

`mobile/` é somente uma reserva com marcador. O futuro repositório é
`tadashiyukoyama/centraldeatendimentoCHAT-mobile`, com upstream
`chatwoot/chatwoot-mobile-app`. O mobile não foi baixado, não possui `.git`,
dependências ou build nesta fase.

## Estado de runtime atual

O runtime de produção foi reconciliado com a VPS e está documentado em
[`docs/operations/PRODUCTION-RUNTIME-STATE.md`](PRODUCTION-RUNTIME-STATE.md).
O release implantado é o commit `c1862b9e18a46490cb1911cd071dc2c33d75b161`,
referenciado no GHCR pela tag imutável do mesmo SHA. O modo Enterprise
self-hosted está ativo na configuração persistida da VPS.

## WhatsApp nativo por QR Code

A integração nativa com Evolution API está em implementação na branch
`feat/native-evolution-whatsapp-channel`, baseada em
`b0366a92dbe5c8176a4c03f7cab05d2fd2ce9ae0`. O contrato prevê uma instalação
multi-instância em domínio HTTPS dedicado, com PostgreSQL e Redis exclusivos da
Evolution e criação integral da caixa pelo Chatwoot.

Neste estado documental, a mudança ainda não prova merge, migration, instalação
da Evolution, alteração da VPS ou deploy. A arquitetura e o futuro gate
operacional estão em:

- [`docs/architecture/NATIVE-EVOLUTION-WHATSAPP.md`](../architecture/NATIVE-EVOLUTION-WHATSAPP.md);
- [`docs/operations/EVOLUTION-NATIVE-WHATSAPP.md`](EVOLUTION-NATIVE-WHATSAPP.md).

## Privacidade rígida por setor

A frente `agent/strict-team-conversation-privacy` implementa uma feature
opt-in por conta para transformar a equipe atribuída em fronteira de
autorização, mesmo quando vários setores usam o mesmo número e a mesma caixa.
O trabalho está publicado na branch remota de mesmo nome e não foi promovido
para `main` nem para produção. O primeiro SHA remoto é
`74c9f609c1b28603c2512376ba43489321f2b9be`.

A regra, as superfícies protegidas, os pré-requisitos, a ativação e o rollback
estão em
[`docs/architecture/STRICT-TEAM-CONVERSATION-VISIBILITY.md`](../architecture/STRICT-TEAM-CONVERSATION-VISIBILITY.md).

O bloco histórico abaixo descreve a fase de fundação anterior e não deve ser
interpretado como o estado atual da produção.

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

O run automático mais recente da PR, `29567520103`, reproduziu exatamente os
mesmos 2 testes falhos, com 376 de 377 arquivos e 3738 de 3740 testes
aprovados. O erro terminal continua sendo a ausência de `useStore` no mock de
`dashboard/composables/store`; o sourcemap ausente de
`@chatwoot/prosemirror-schema` permanece ancillary. Nenhum arquivo de produto
foi alterado para obter essa evidência.

O mock foi corrigido na branch de privacidade e os dois arquivos frontend
diretamente envolvidos foram revalidados localmente: 16 testes passaram e o
lint direcionado ficou verde.

## CI da privacidade rígida

O workflow manual `Run Chatwoot CE spec` foi executado uma única vez contra o
SHA `74c9f609c1b28603c2512376ba43489321f2b9be`, no run
[`30107312407`](https://github.com/tadashiyukoyama/centraldeatendimentoCHAT/actions/runs/30107312407).
Doze dos 19 jobs passaram. As falhas expuseram regressões de compatibilidade
com a feature desativada em busca, ações em lote e integrações, o contrato do
novo bit de feature flag, métricas do RuboCop e o mock frontend já
diagnosticado.

O commit corretivo
`59f6fefac7bde542ca67516b25bb1e1b7d220287` foi validado pelo run
[`30108403737`](https://github.com/tadashiyukoyama/centraldeatendimentoCHAT/actions/runs/30108403737):
os 19 jobs passaram, incluindo os 16 shards do backend, RuboCop, ESLint e a
suíte frontend completa com 378 arquivos e 3.742 testes aprovados. Esse gate
prova o estado da branch, mas não equivale a merge, ativação da feature, deploy
ou teste de aceitação com agentes reais.

## Evidência operacional

As validações locais previstas para a fundação são `verify-capsule.ps1`,
`check-worktree-budget.ps1`, `rehydrate-workspace.ps1 -ReadOnly`,
`project-status.ps1`, `disk-guard.ps1 -ReadOnly` e
`validate-local-boundaries.ps1`. Elas devem comprovar separadamente
`checkoutRoot`, `canonicalServerRoot` e `workspaceRoot`, além de origem,
upstream, limites de worktree e fronteiras privadas.

O gate versionado acrescenta os schemas Draft 2020-12 portátil, local e ledger,
`scripts/validate-workspace-contracts.ps1` e 14 testes PowerShell
autocontidos. O workflow Windows executa esses contratos, constrói uma cápsula
temporária, cria uma linked worktree real, repete as verificações em `server` e
na linked e só remove a linked após confirmar status limpo.
