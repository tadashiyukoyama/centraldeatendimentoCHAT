# Estado atual do projeto

Este é o documento canônico do estado operacional do
`CENTRAL_ATENDIMENTO_CHAT`. O estado observado no Git sempre prevalece sobre
qualquer valor copiado neste documento.

## Frente ativa: rebranding AceleraChat

- SHA-base fixado: `901a23fbed68b0e0cf2a2c8e850eab6ab454ad5f`.
- Branch: `release/strict-team-conversation-privacy`.
- Marca pública: AceleraChat; assistente: Nemmo; camada comercial: PRO.
- Implementação local concluída em código, assets, ajuda, jurídico, e-mails,
  SuperAdmin e fluxo LGPD; ainda sem push ou deploy.
- Rollback de produção fixado em `b8932617338a4cd3762fa5cf89540fc68cdae5eb`.
- Gates Ruby/Docker, fatos jurídicos, DNS de e-mail, sync conectado e smoke de
  produção continuam obrigatórios antes do corte.
- Runbook canônico:
  [`ACELERACHAT-REBRAND-RELEASE-RUNBOOK.md`](ACELERACHAT-REBRAND-RELEASE-RUNBOOK.md).

O Acelera Control permanece desativado e não tem autoridade sobre a marca.
Nomes internos `Chatwoot`, `Captain` e `enterprise` permanecem por
compatibilidade.

## Identidade e controle de versão

- Repositório canônico: `tadashiyukoyama/centraldeatendimentoCHAT`.
- Upstream: `chatwoot/chatwoot`.
- Base operacional atual: `main`; release da aplicação em
  `882b6fb14f653b7b858a230bb41e96da2407b255`.
- Correção Evolution: branch `agent/evolution-webhook-concurrency-sanitization`;
  PR `#15`, squash merge confirmado.
- Deploy de produção: workflow `30112148256`, com `headSha` igual ao SHA acima.
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
O release implantado é o commit `882b6fb14f653b7b858a230bb41e96da2407b255`,
referenciado no GHCR pela tag imutável do mesmo SHA e pelo digest
`sha256:476716699e6d61e1af5e3ae855d91dab8497cc2ffebea4e43dd7e200d3412857`.
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

## Privacidade rígida por setor

A frente `agent/strict-team-conversation-privacy` implementa uma feature
opt-in por conta para transformar a equipe atribuída em fronteira de
autorização, mesmo quando vários setores usam o mesmo número e a mesma caixa.
O código foi promovido por fast-forward para `main` e implantado em produção
no SHA `882b6fb14f653b7b858a230bb41e96da2407b255`. A feature permanece
desativada por padrão. A criação dos usuários sintéticos, a ativação na conta
escolhida e o smoke controlado ainda não foram executados.

A regra, as superfícies protegidas, os pré-requisitos, a ativação e o rollback
estão em
[`docs/architecture/STRICT-TEAM-CONVERSATION-VISIBILITY.md`](../architecture/STRICT-TEAM-CONVERSATION-VISIBILITY.md).

O bloco histórico abaixo descreve a fase de fundação anterior e não deve ser
interpretado como o estado atual da produção.

## Estado de runtime desta fase

Docker e Ruby/Bundler não estão disponíveis neste Windows workspace. Não foram
executados containers locais nem testes backend locais. O acesso à VPS, o
backup, o deploy versionado, a preparação do banco e os healthchecks foram
executados pelo workflow `30112148256`; não houve uso de número real ou
cliente no smoke.

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
suíte frontend completa com 378 arquivos e 3.742 testes aprovados. O mesmo
código de produto foi rebased sobre `main`, promovido e implantado; esse gate
continua não equivalendo à ativação da feature nem ao teste de aceitação com
agentes reais.

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
