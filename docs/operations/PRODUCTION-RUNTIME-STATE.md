# Estado versionado do runtime de produção

Este documento registra o estado observado na VPS e a referência imutável do
artefato atualmente em execução. Ele não contém credenciais.

## Fonte de verdade atual

Durante a reconciliação de 18 de julho de 2026, a VPS foi tratada como fonte
de verdade operacional. A imagem em execução foi confirmada contra o SHA que o
Rails expõe internamente e contra o digest local do container.

O estado não deve ser obtido por `latest`, por uma tag mutável ou por um
checkout posterior. A referência exata está em
[`infra/production/enterprise-runtime.yml`](../../infra/production/enterprise-runtime.yml).

| Item | Valor observado |
| --- | --- |
| Repositório | `tadashiyukoyama/centraldeatendimentoCHAT` |
| Commit da aplicação | `6e6027945f37461751603b9e80f5d43beb233774` |
| Tag da imagem | `6e6027945f37461751603b9e80f5d43beb233774` |
| Digest da imagem | `sha256:aee2dbf1c42c85cc3118a559dbf9b54723667f5aab8ff5b965f8618880759ec0` |
| Chatwoot | `4.15.1` |
| Estado do bootstrap | `completed` |

O commit implantado já existe no GitHub e é ancestral de `main`. A `main`
continua sem reescrita: ela contém correções posteriores de infraestrutura que
ainda não fazem parte da imagem implantada. A referência do release da VPS é
o commit acima, não o ponteiro móvel de `main`.

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
