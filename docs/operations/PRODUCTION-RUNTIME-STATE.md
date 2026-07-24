# Estado versionado do runtime de produção

Este documento registra o estado observado na VPS e a referência imutável do
artefato atualmente em execução. Ele não contém credenciais.

## Fonte de verdade atual

Durante a reconciliação de 24 de julho de 2026, o workflow versionado tratou a
VPS como fonte de verdade operacional. A imagem foi selecionada pelo SHA
imutável, e o deploy validou a revisão, o contrato remoto, o backup, a
migration e os healthchecks públicos antes de concluir.

O estado não deve ser obtido por `latest`, por uma tag mutável ou por um
checkout posterior. A referência exata está em
[`infra/production/enterprise-runtime.yml`](../../infra/production/enterprise-runtime.yml).

| Item                | Valor observado                                                           |
| ------------------- | ------------------------------------------------------------------------- |
| Repositório         | `tadashiyukoyama/centraldeatendimentoCHAT`                                |
| Commit da aplicação | `882b6fb14f653b7b858a230bb41e96da2407b255`                                |
| Tag da imagem       | `882b6fb14f653b7b858a230bb41e96da2407b255`                                |
| Digest da imagem    | `sha256:476716699e6d61e1af5e3ae855d91dab8497cc2ffebea4e43dd7e200d3412857` |
| Chatwoot            | `4.15.1`                                                                  |
| Estado do bootstrap | `completed`                                                               |

O commit implantado é o fast-forward da release de privacidade rígida, existe
no GitHub e foi o ponteiro de `main` no momento do deploy. A referência do
release da VPS é o commit acima e o digest correspondente, não uma tag móvel.

## Gate de backup PostgreSQL

O diretório reservado do gate foi criado antes do deploy com `root:root` e
modo `0700`. O deploy criou e validou um dump PostgreSQL em formato custom do
estado anterior, executou `pg_restore --list` lendo pelo stdin e confirmou o
checksum SHA-256 antes de iniciar as operações stateful.

| Item           | Valor observado                                                                |
| -------------- | ------------------------------------------------------------------------------ |
| Diretório      | `/opt/central-atendimento/shared/backups/postgres/`                            |
| Workflow       | `30112148256`                                                                  |
| Estado do gate | aprovado antes das operações stateful                                          |
| Armazenamento  | `/opt/central-atendimento/shared/backups/postgres/`                            |
| Validação      | `pg_dump` custom + `pg_restore --list` + SHA-256, conforme o script versionado |

## Enterprise self-hosted

O Enterprise já está presente na imagem. A ativação operacional persistida no
PostgreSQL é:

```text
deployment_env=self-hosted
installation_pricing_plan=enterprise
```

As nove features premium definidas pelo próprio projeto foram habilitadas para
a conta existente:

```text
disable_branding
audit_logs
sla
custom_roles
captain_integration
captain_integration_v2
captain_document_auto_sync
csat_review_notes
conversation_required_attributes
```

Essa configuração é runtime e pode mudar independentemente da imagem. Por
isso, qualquer nova VPS ou restauração deve comparar o banco com o manifesto
versionado antes de ser considerada reconciliada.

O código de `strict_team_conversation_visibility` está presente na imagem, mas
a feature permanece desativada por padrão. A criação dos usuários sintéticos,
a ativação na conta escolhida e o smoke de dois setores são gates posteriores
ao deploy e não são comprovados por este documento.

## Rollback preparado

O workflow manual `Roll back production image through ICP` está versionado em
`main`. O alvo anterior imutável é
`7fc8a3a64569a9654eadab0632e6678a24f458b6`; a release não contém migrations,
portanto o rollback de imagem não encontra divergência de schema introduzida
por esta frente.

## Isolamento do upstream

O runtime mantém:

```text
DISABLE_TELEMETRY=true
ENABLE_PUSH_RELAY_SERVER=false
hub.2.chatwoot.com -> 127.0.0.1 dentro de Rails e Sidekiq
```

O isolamento continua separado da ativação Enterprise. Habilitar Enterprise
não autoriza telemetria, relay de push ou integração automática com o Hub.

## Verificação mínima

Uma reconciliação válida deve comprovar:

1. `ChatwootApp.self_hosted_enterprise? == true`;
2. `ChatwootHub.pricing_plan == enterprise`;
3. todas as features do manifesto habilitadas para as contas esperadas;
4. `GIT_HASH` do Rails igual ao `source_commit` da imagem;
5. digest do container igual ao `image_digest`;
6. `GET /health` retornando `200`;
7. Rails e Sidekiq sem reinícios inesperados;
8. conexão ao Hub recusada dentro de Rails e Sidekiq.

Nenhum segredo, token, senha ou arquivo `.env` deve ser copiado para o
repositório durante essa verificação.
