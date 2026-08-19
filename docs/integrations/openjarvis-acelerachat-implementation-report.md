# Relatório final — integração nativa AceleraChat/OpenJarvis

Data da validação: 18 de agosto de 2026

## Atualização controlada — 19 de agosto de 2026

- Base: `ce25513cb1ac59d59663974d150114d752bbe6d1`.
- SHA funcional: `5ae823aca23427df49dd3c8d0c8526a1099e258a`.
- Branch: `feat/openjarvis-whatsapp-control`.
- Contrato atualizado: `2026-08-19.2`.
- Política de caixas: `all_account`, dinâmica para todas as caixas atuais e
  futuras da mesma conta, somente com usuário de serviço administrador.
- Operações Evolution adicionadas: reply contextual, reação, recibo de leitura
  e mídia HTTPS protegida contra SSRF.
- Validação: 97 exemplos Rails sem falhas, 4 testes Vitest, ESLint direcionado,
  sintaxe Ruby, YAML/JSON, scanner de segredos e `git diff --check` aprovados.
- Sem migration, envio real, push, deploy ou mudança de credenciais nesta etapa.

Esta atualização preserva o relatório original abaixo como evidência histórica.

## Rastreabilidade

- Repositório alterado: somente AceleraChat.
- Branch: `feat/openjarvis-native-integration`.
- SHA-base solicitado e confirmado: `128d00a1743e198eb370f55fbaf7bffe7a2b01f1`.
- SHA da implementação: `23487c8e7c92ae40d884105ca450809cde118598`.
- Contrato: `2026-08-18.2`.
- Schema de eventos: `1.0`.
- OpenJarvis não foi alterado.
- Não houve push, build de imagem, deploy ou migration em produção nesta entrega.

## Estado da entrega

O lado AceleraChat está concluído e validado para handoff ao projeto OpenJarvis.
A integração completa entre os dois sistemas ainda não está ativada: o consumidor
OpenJarvis deve implementar o contrato publicado, instalar as credenciais fora do
repositório e concluir seus próprios testes contratuais e de reconciliação.

Nenhuma capacidade não implementada é anunciada como disponível. O catálogo e o
health por caixa são a fonte executável de verdade para cada operação.

## Handoff operacional posterior

Os runbooks abaixo foram adicionados depois do SHA de implementação para orientar
o agente OpenJarvis e o futuro release, sem afirmar que houve deploy:

- `docs/integrations/openjarvis-edge-worker-mcp-handoff.md`;
- `docs/integrations/openjarvis-vps-release-runbook.md`.

O manifesto com referências privadas permanece fora do repositório em
`D:\dev\workspaces\centraldeatendimentoCHAT\credenciais\openjarvis\OPENJARVIS_VPS_EDGE_MCP_PRIVATE.md`.

## Contrato entregue

O OpenAPI 3.1 modular está em
`docs/integrations/openjarvis-openapi.yaml` e possui schemas concretos de request,
response, erro e webhook, além de exemplos sanitizados. O catálogo publica 23
operações executáveis:

1. `catalog.get`
2. `openapi.get`
3. `health.get`
4. `diagnostics.get`
5. `operations.list`
6. `sync.backfill`
7. `inboxes.list`
8. `inboxes.health`
9. `agents.list`
10. `teams.list`
11. `labels.list`
12. `contacts.search`
13. `contacts.get`
14. `contacts.create`
15. `contacts.update`
16. `conversations.search`
17. `conversations.get`
18. `conversations.create`
19. `conversations.update`
20. `conversations.mark_read`
21. `messages.search`
22. `messages.list`
23. `messages.create`

Cada operação possui input e output schema no catálogo. A lista de operações, os
operation IDs do OpenAPI e as 23 fixtures de endpoint são comparados por teste.

## Capacidades e limites formais

A matriz cobre 12 `channel_type` conhecidos e 26 capacidades, incluindo conexão,
leitura, busca, criação de conversa, envio, reply, reação, mark-read interno e do
provedor, leitura/envio de mídia, entrega e operações de e-mail.

- `enable_auto_assignment` é apenas uma configuração de roteamento e nunca indica
  conexão.
- O endpoint `/inboxes/{inbox_id}/health` informa evidência de conexão e capacidade
  para a caixa autorizada.
- WhatsApp: leitura, envio AceleraChat e status de entrega são expostos; reply
  contextual nativo do provedor, reação, recibo de leitura do provedor e upload de
  mídia estão formalmente marcados como não suportados.
- E-mail: busca, não lidos, threads, reply, destinatários e leitura de anexos são
  recursos de atendimento AceleraChat; upload de anexos, archive e trash da caixa
  do provedor estão formalmente fora do escopo.
- Mark-read altera somente o estado interno do AceleraChat e retorna
  `provider_receipt_sent: false`.
- Um resultado de envio aceito permanece `unknown_until_message_updated` até que o
  estado assíncrono da mensagem permita reconciliação.

## Associação, busca e sincronização

- A criação de conversa rejeita `source_id` fornecido pelo cliente.
- O servidor localiza ou cria a associação contato–caixa usando os builders nativos
  para canais deriváveis; canais com identidade exclusiva do provedor exigem uma
  associação previamente recebida pelo AceleraChat.
- Conversas podem ser buscadas por contato, caixa, status e data de atualização.
- Mensagens podem ser buscadas por texto, caixa, contato, conversa e estado não
  lido.
- A paginação usa cursor assinado e vinculado à coleção/filtros, timestamp em
  microssegundos e ID como desempate determinístico.
- Todas as listas retornam `has_more` e `next_cursor`.
- O backfill cobre contatos, conversas e mensagens em ordem ascendente e emite
  snapshots no mesmo envelope versionado usado pelos webhooks.

## Webhooks, reconciliação e retenção

Foram publicados schemas e fixtures para oito eventos: sete eventos de recurso e
`integration.test`. Cada envelope inclui `schema_version`, `event_id`, data do
evento, identidade do recurso, versão e sequência monotônica por recurso.

- Semântica: at-least-once; duplicatas são possíveis.
- Não existe ordenação global; a sequência por recurso permite reordenação local.
- Retries: erro de transporte, HTTP 408, 409, 425, 429 e 5xx são temporários; os
  demais 4xx são permanentes.
- Tentativas temporárias são limitadas a cinco com backoff; erros permanentes não
  são reenfileirados.
- Reconciliação inicial ou após perda de eventos usa `/backfill`.
- Respostas idempotentes e metadados de entrega permanecem por 30 dias.
- Payloads de webhook não são persistidos no ledger de entrega.
- O job diário remove ledgers vencidos e credenciais anteriores cujo período de
  sobreposição terminou.

## Segurança e credenciais

- Bearer e HMAC possuem rotação sem interrupção com sobreposição de 24 horas.
- Durante a rotação HMAC, o emissor envia assinaturas atual e anterior em headers
  distintos.
- Segredos completos aparecem somente na criação ou rotação e permanecem
  criptografados quando a criptografia Active Record está configurada.
- O endpoint de webhook exige HTTPS, rejeita credenciais embutidas, query string,
  fragmento e domínios antigos bloqueados.
- Componentes OpenAPI são servidos por uma whitelist fechada; nomes arbitrários não
  chegam a `File.read`.
- Rate limits: 120 leituras e 30 mutações por minuto, por integração. HTTP 429 usa
  envelope estável e `Retry-After`.
- A taxonomia pública diferencia falhas temporárias, permanentes e resultados
  desconhecidos.
- Nenhum segredo ou dado pessoal de produção foi incluído no contrato, fixtures,
  testes ou neste relatório.

## Migrations

1. `20260818120300_harden_openjarvis_contract.rb`
   - adiciona sobreposição de Bearer/HMAC;
   - adiciona expiração aos ledgers;
   - adiciona identidade, versão, sequência e classificação das entregas;
   - cria `openjarvis_resource_sequences`;
   - preenche registros anteriores de forma aditiva.
2. `20260818120400_add_openjarvis_contract_scopes.rb`
   - adiciona `resources:read` e `sync:read` às conexões OpenJarvis existentes.

O schema foi carregado do zero, migrado até `20260818120400` e validado em
PostgreSQL e Redis descartáveis.

## Evidências de teste

- RSpec isolado: 75 exemplos, 0 falhas.
- Respostas reais dos endpoints comparadas aos schemas OpenAPI publicados.
- Cursores: desempate por ID, adulteração e reutilização com filtros diferentes.
- Idempotência: replay, conflito, chave inválida e resultado em processamento.
- Isolamento: allowlist de caixas, conta, equipe e privacidade rígida.
- Webhooks: duplicata, execução fora de ordem, falha temporária, falha permanente e
  assinatura dupla durante rotação.
- Retenção: API requests, entregas e credenciais anteriores.
- Zeitwerk: aplicação carregada integralmente, sem erros.
- RuboCop: 76 arquivos inspecionados, 0 ofensas.
- ESLint: componente da integração aprovado.
- Prettier: Vue, JSON, fixtures e YAML aprovados.
- Redocly: OpenAPI 3.1 válido, 0 erros e 0 avisos.
- Brakeman diferencial: 34 alertas no baseline, 34 no resultado, 0 alertas novos e
  0 erros do scanner.
- `git diff --check`: aprovado.

Os avisos de depreciação emitidos pela suíte pertencem ao baseline do projeto
(Rails fixture path, alias antigo de User e status Rack) e não causaram falhas.

## Confirmação de não envio

Nenhuma mensagem, e-mail ou webhook real foi enviado. Os testes de escrita de
mensagem usaram somente nota privada em banco descartável; webhooks usaram doubles
ou endpoint simulado. O laboratório não recebeu credenciais de canais de produção.

## Rollback

Rollback principal de código: retornar para
`128d00a1743e198eb370f55fbaf7bffe7a2b01f1`.

Como não houve deploy nesta entrega, produção permanece nesse SHA e não requer
rollback agora. Em uma implantação futura, o rollback preferencial é restaurar a
imagem desse SHA e manter as estruturas aditivas inativas. Caso seja necessária
reversão física do banco, fazer backup validado e executar, nesta ordem:

1. `rails db:migrate:down VERSION=20260818120400`
2. `rails db:migrate:down VERSION=20260818120300`

A segunda reversão remove sequências e metadados novos; por isso só deve ser usada
sem tráfego OpenJarvis ativo e após confirmar que os ledgers não são necessários
para reconciliação.

## Manifesto de arquivos da implementação

O commit de implementação altera 77 arquivos:

```text
app/controllers/api/v1/accounts/integrations/openjarvis_controller.rb
app/controllers/api/v1/openjarvis/agents_controller.rb
app/controllers/api/v1/openjarvis/backfill_controller.rb
app/controllers/api/v1/openjarvis/base_controller.rb
app/controllers/api/v1/openjarvis/contacts_controller.rb
app/controllers/api/v1/openjarvis/conversations_controller.rb
app/controllers/api/v1/openjarvis/health_controller.rb
app/controllers/api/v1/openjarvis/inbox_health_controller.rb
app/controllers/api/v1/openjarvis/labels_controller.rb
app/controllers/api/v1/openjarvis/messages_controller.rb
app/controllers/api/v1/openjarvis/openapi_controller.rb
app/controllers/api/v1/openjarvis/operations_controller.rb
app/controllers/api/v1/openjarvis/teams_controller.rb
app/javascript/dashboard/i18n/locale/en/integrationApps.json
app/javascript/dashboard/i18n/locale/pt_BR/integrationApps.json
app/javascript/dashboard/routes/dashboard/settings/integrations/OpenJarvis.vue
app/jobs/openjarvis/retention_job.rb
app/jobs/openjarvis/webhook_delivery_job.rb
app/models/integrations/hook.rb
app/models/openjarvis/api_request.rb
app/models/openjarvis/resource_sequence.rb
app/models/openjarvis/webhook_delivery.rb
app/presenters/openjarvis/inbox_presenter.rb
app/presenters/openjarvis/message_presenter.rb
app/services/openjarvis/access_scope.rb
app/services/openjarvis/api_error.rb
app/services/openjarvis/backfill.rb
app/services/openjarvis/capability_definition.rb
app/services/openjarvis/capability_resolver.rb
app/services/openjarvis/catalog.rb
app/services/openjarvis/catalog_operations.rb
app/services/openjarvis/catalog_policies.rb
app/services/openjarvis/catalog_schemas.rb
app/services/openjarvis/configuration.rb
app/services/openjarvis/contact_inbox_resolver.rb
app/services/openjarvis/cursor.rb
app/services/openjarvis/cursor_page.rb
app/services/openjarvis/idempotency/executor.rb
app/services/openjarvis/integration_test_payload.rb
app/services/openjarvis/rate_limiter.rb
app/services/openjarvis/resource_identity.rb
app/services/openjarvis/resource_resolver.rb
app/services/openjarvis/webhook_client.rb
app/services/openjarvis/webhook_enqueuer.rb
app/services/openjarvis/webhook_payload_builder.rb
config/routes.rb
config/schedule.yml
db/migrate/20260818120300_harden_openjarvis_contract.rb
db/migrate/20260818120400_add_openjarvis_contract_scopes.rb
db/schema.rb
docs/integrations/openjarvis-acelerachat-contract.md
docs/integrations/openjarvis-openapi.yaml
docs/integrations/openjarvis-openapi/examples.yaml
docs/integrations/openjarvis-openapi/parameters.yaml
docs/integrations/openjarvis-openapi/paths.yaml
docs/integrations/openjarvis-openapi/responses.yaml
docs/integrations/openjarvis-openapi/schemas.yaml
docs/integrations/openjarvis-openapi/webhook-examples.yaml
docs/integrations/openjarvis-openapi/webhooks.yaml
spec/contracts/openjarvis/catalog_spec.rb
spec/factories/openjarvis.rb
spec/fixtures/openjarvis/endpoints.json
spec/fixtures/openjarvis/webhooks.json
spec/jobs/openjarvis/retention_job_spec.rb
spec/jobs/openjarvis/webhook_delivery_job_spec.rb
spec/requests/api/v1/accounts/integrations/openjarvis_controller_spec.rb
spec/requests/api/v1/openjarvis_api_spec.rb
spec/requests/api/v1/openjarvis_contract_api_spec.rb
spec/services/openjarvis/capability_resolver_spec.rb
spec/services/openjarvis/contact_inbox_resolver_spec.rb
spec/services/openjarvis/cursor_page_spec.rb
spec/services/openjarvis/idempotency/executor_spec.rb
spec/services/openjarvis/rate_limiter_spec.rb
spec/services/openjarvis/webhook_client_spec.rb
spec/services/openjarvis/webhook_enqueuer_spec.rb
spec/support/openjarvis_contract_reference_validator.rb
spec/support/openjarvis_contract_schema_validator.rb
```
