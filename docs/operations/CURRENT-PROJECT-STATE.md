# Estado atual do projeto

Este é o documento canônico do estado operacional do
`CENTRAL_ATENDIMENTO_CHAT`. O estado observado no Git sempre prevalece sobre
qualquer valor copiado neste documento.

## Identidade e controle de versão

- Repositório canônico: `tadashiyukoyama/centraldeatendimentoCHAT`.
- Upstream: `chatwoot/chatwoot`.
- Base operacional atual: `main` em `7fc8a3a64569a9654eadab0632e6678a24f458b6`.
- Correção Evolution: branch `agent/evolution-webhook-concurrency-sanitization`;
  PR `#15`, squash merge confirmado.
- Deploy de produção: workflow `30051773036`, com `headSha` igual ao SHA acima.
- HEAD e status devem ser obtidos por `git rev-parse HEAD` e `git status`.
- O HEAD da branch de implementação antes do merge foi
  `c2f669641e736f373e62df31941cb982bfa0b247`.

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
O release implantado é o commit `7fc8a3a64569a9654eadab0632e6678a24f458b6`,
referenciado no GHCR pela tag imutável do mesmo SHA e pelo digest
`sha256:cb1be78ea355453281c9e67589cffcce620c41cd7222d25d50ff5a5db54f7f18`.
O modo Enterprise self-hosted permanece ativo na configuração persistida da
VPS.

## WhatsApp nativo por QR Code

A integração nativa com Evolution API foi incorporada pela PR `#15`, cujo
commit de merge em `main` é `7fc8a3a64569a9654eadab0632e6678a24f458b6`.
O contrato prevê uma instalação multi-instância em domínio HTTPS dedicado, com
PostgreSQL e Redis exclusivos da Evolution e criação integral da caixa pelo
Chatwoot.

O deploy prova a revisão da aplicação, a migration/healthcheck do Chatwoot e a
saúde pública do Chatwoot e do ICP, mas não prova conexão de número, criação de
caixa por QR ou troca de mensagens. A arquitetura e o gate operacional estão
em:

- [`docs/architecture/NATIVE-EVOLUTION-WHATSAPP.md`](../architecture/NATIVE-EVOLUTION-WHATSAPP.md);
- [`docs/operations/EVOLUTION-NATIVE-WHATSAPP.md`](EVOLUTION-NATIVE-WHATSAPP.md).

O bloco histórico abaixo descreve a fase de fundação anterior e não deve ser
interpretado como o estado atual da produção.

## Estado de runtime desta fase

Docker e Ruby/Bundler não estão disponíveis neste Windows workspace. Não foram
executados containers locais nem testes backend locais. O acesso à VPS, o
deploy versionado, as migrations e os healthchecks foram executados pelo
workflow `30051773036`; não houve uso de número real ou cliente no smoke.

## Diagnóstico frontend

O run remoto da PR `30045609092` terminou com `frontend-tests` falhando no job
`89335907435`. A falha é determinística no mock de
`dashboard/composables/store`: o teste fornece `useMapGetter`, mas
`useAccount.js` importa `useStore` pela cadeia usada por
`useChannelConfig.js`. O resultado observado foi 2 testes falhos, 376 de 377
arquivos aprovados e 3738 de 3740 testes aprovados. `lint-frontend` passou.

Esse run reproduziu 2 testes falhos, com 377 arquivos e 3740 testes no total.
O erro terminal continua sendo a ausência de `useStore` no mock de
`dashboard/composables/store`; o sourcemap ausente de
`@chatwoot/prosemirror-schema` permanece ancillary. Nenhum arquivo de produto
foi alterado para obter essa evidência.

Os arquivos do produto envolvidos não foram alterados nesta correção e não
tinham diff em relação à base autorizada; o diagnóstico não inclui conserto de
produto. O CI foi observado após o novo commit, sem reexecução manual antes
dele.

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
