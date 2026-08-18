# Handoff de implementação — OpenJarvis Edge Worker e MCP

Status: `REQUISITOS PARA O AGENTE OPENJARVIS`

Data de referência: 18 de agosto de 2026

## 1. Resultado esperado

Finalizar o lado OpenJarvis da arquitetura híbrida sem alterar o contrato público
AceleraChat `2026-08-18.2` e sem executar envios reais.

O resultado deve permitir simultaneamente:

1. OpenJarvis Core na VPS delegar jobs para um Edge Worker no computador por WSS.
2. Edge Worker usar o Codex app-server local para tarefas aprovadas.
3. Codex local consumir ferramentas OpenJarvis por MCP STDIO.
4. ChatGPT remoto consumir um subconjunto seguro por MCP Streamable HTTP, quando
   habilitado.
5. AceleraChat permanecer a autoridade de e-mail, WhatsApp, contatos e
   conversas.

## 2. Estado de entrada comprovado

### AceleraChat

- API base: `https://atendimento.meugerenciador.pro/api/v1/openjarvis`.
- Contrato: `2026-08-18.2`.
- Schema de eventos: `1.0`.
- 23 operações executáveis.
- Bearer para chamadas e HMAC para webhooks.
- Cursores assinados, idempotência, backfill e retenção implementados.
- AceleraChat ainda não implantado com este contrato no momento do handoff.

### OpenJarvis local

- Repositório: `D:\dev\workspaces\openjarvis`.
- Branch observada: `codex/acelerachat-native-adapter`.
- Base: `ec5e22e360943eb77560be3b9e5ea8ab7300b5eb`.
- Backend local: porta `8127`.
- Frontend local: porta `5173`.
- Codex app-server local: `127.0.0.1:8131`.
- Gateway experimental: porta `8140`, não usar como produção.
- Adaptador AceleraChat e testes estavam em working tree ainda não commitado.

Componentes existentes que devem ser reaproveitados:

- `src/openjarvis/server/jarvis_agent/adapters/acelerachat/`;
- `src/openjarvis/server/jarvis_agent/registry/acelerachat.py`;
- `src/openjarvis/server/jarvis_agent/registry/catalog.py`;
- `src/openjarvis/server/jarvis_agent/services/execution.py`;
- `src/openjarvis/server/jarvis_agent/persistence/providers.py`;
- `src/openjarvis/server/jarvis_agent/api/router.py`;
- `src/openjarvis/mcp/server.py`;
- integração existente com o Codex app-server.

O `src/openjarvis/server/ws_bridge.py` atual encaminha EventBus para clientes
WebSocket. Ele não comprova o canal Edge Worker outbound, lease, retomada ou fila
durável exigidos aqui.

## 3. Fronteiras obrigatórias

- Não alterar o repositório AceleraChat nesta entrega OpenJarvis.
- Não criar outro adaptador direto de WhatsApp ou Gmail.
- Não alterar ou remover o fallback preservado sem decisão separada.
- Não expor `127.0.0.1:8131`, terminal, filesystem ou browser local.
- Não criar ferramenta genérica de shell/comando.
- Não expor `codex_delegate_task` ao próprio Codex por MCP.
- Não afirmar capacidade apenas porque existe uma rota ou configuração.
- Não executar mensagem, e-mail, reação, campanha ou broadcast real.
- Não usar Quick Tunnel como endpoint definitivo.
- Não incluir segredos em testes, fixtures, logs, docs ou Git.
- Não instalar na VPS antes de produzir SHA limpo, artefato reproduzível e
  rollback.

## 4. Catálogo canônico

O catálogo atual possui 16 ferramentas:

### Operação local

1. `jarvis.operational_audit` / `jarvis_read_operational_audit`.

### E-mail AceleraChat

2. `email.search` / `email_search_messages`.
3. `email.list_unread` / `email_list_unread`.
4. `email.read_message` / `email_read_message`.
5. `email.read_conversation` / `email_read_conversation`.
6. `email.reply` / `email_reply_conversation`.

### WhatsApp AceleraChat

7. `whatsapp.status` / `whatsapp_get_status`.
8. `whatsapp.search_contacts` / `whatsapp_search_contacts`.
9. `whatsapp.search_chats` / `whatsapp_search_chats`.
10. `whatsapp.read_conversation` / `whatsapp_read_conversation`.
11. `whatsapp.summarize_conversation` /
    `whatsapp_summarize_conversation`.
12. `whatsapp.send_text` / `whatsapp_send_text`.
13. `whatsapp.mark_read_internal` / `whatsapp_mark_acelerachat_read`.

### Codex

14. `codex.status` / `codex_get_status`.
15. `codex.history` / `codex_read_recent_history`.
16. `codex.delegate` / `codex_delegate_task`.

O MCP apresentado ao Codex local deve filtrar todas as ferramentas cujo
`source/provider` seja Codex. Portanto, o máximo inicial elegível é 13
ferramentas, ainda sujeito a capacidades reais e permissões. O catálogo global
continua com 16.

O MCP remoto do ChatGPT pode oferecer delegação ao Codex somente depois que Edge
Worker, aprovação, identidade e auditoria estiverem ativos. Essa ferramenta deve
ser omitida quando nenhum worker autorizado estiver conectado.

## 5. Edge Worker outbound

### 5.1 Transporte

- URL: `wss://openjarvis.meugerenciador.pro/edge`.
- Conexão sempre iniciada pelo computador local.
- Nenhum listener público no Windows.
- TLS obrigatório.
- Autenticação de dispositivo separada de Bearer AceleraChat, HMAC e MCP.
- Heartbeat com timeout e estado offline real.
- Backoff exponencial com jitter e limite.
- Retomada após reconexão usando cursor/sequence persistido.
- Limite de payload e fila local.

### 5.2 Envelope mínimo

Todo frame de aplicação deve conter:

```json
{
  "schema_version": "1.0",
  "event_id": "uuid",
  "type": "job.offer",
  "device_id": "opaque-device-id",
  "occurred_at": "2026-08-18T12:00:00Z",
  "sequence": 42,
  "job_id": "opaque-job-id",
  "payload": {}
}
```

Requisitos:

- `event_id` globalmente único para deduplicação;
- `sequence` monotônica por dispositivo/conexão;
- `job_id` estável durante retries e retomada;
- timestamps UTC;
- payload com schema fechado e `additionalProperties: false` onde aplicável;
- conteúdo do usuário tratado como não confiável;
- nenhuma credencial no payload.

### 5.3 Tipos obrigatórios

Cliente → Core:

- `edge.register`;
- `edge.heartbeat`;
- `edge.resume`;
- `job.accepted`;
- `job.rejected`;
- `job.progress`;
- `approval.required`;
- `job.succeeded`;
- `job.failed`;
- `job.cancelled`;
- `edge.goodbye`.

Core → Cliente:

- `edge.registered`;
- `edge.heartbeat_ack`;
- `job.offer`;
- `job.cancel`;
- `approval.resolved`;
- `edge.rotate_credentials`;
- `edge.error`.

### 5.4 Estados de job

```text
queued
  -> offered
  -> accepted
  -> running
  -> waiting_approval
  -> running
  -> succeeded | failed | cancelled | expired
```

Regras:

- somente estados terminais encerram o lease;
- perda de conexão não significa falha automática;
- Core não oferece o mesmo job simultaneamente a dois workers, salvo política
  explícita de reentrega após lease expirado;
- reentrega mantém o `job_id` e uma attempt separada;
- worker deduplica jobs terminais;
- resultado desconhecido não pode ser convertido em sucesso;
- cancelamento deve interromper o turno quando suportado e reconciliar o estado.

### 5.5 Codex app-server

Reaproveitar a integração local já existente:

- retomar thread com `thread/resume` quando houver mapeamento válido;
- criar thread somente quando não existir associação;
- iniciar trabalho com `turn/start`;
- persistir apenas IDs e metadados necessários;
- retransmitir progresso limitado, sem vazar raciocínio interno ou segredos;
- tratar approval como estado explícito;
- suportar `turn/interrupt` para cancelamento quando seguro;
- não assumir espelhamento token a token com outro processo Codex Desktop;
- manter `8131` em loopback.

## 6. Core na VPS

Implementar uma fronteira separada do frontend local:

- registry de dispositivos;
- credenciais atuais e anteriores com expiração;
- fila persistente de jobs;
- leases e attempts;
- ledger de eventos/deduplicação;
- sequência por job/dispositivo;
- backfill de eventos;
- API de status sanitizada;
- auditoria de aprovação;
- revogação imediata de dispositivo;
- retenção e limpeza programada;
- health independente de worker conectado;
- capability snapshot por worker.

O Core não deve montar Docker socket, diretório AceleraChat, credenciais SSH ou
filesystem do host. A comunicação com AceleraChat ocorre apenas pela API HTTPS
publicada.

## 7. MCP local para Codex

A documentação oficial suporta servidor local STDIO iniciado pelo Codex. Usar
esse transporte como padrão.

Requisitos:

- reaproveitar `JarvisToolCatalog`; não criar segundo catálogo manual;
- filtrar ferramentas pela capability snapshot da sessão;
- remover todas as ferramentas `codex.*` da superfície entregue ao Codex;
- converter `ToolDefinition` para MCP `tools/list` e `tools/call`;
- preservar JSON Schema fechado, limites e descrições;
- adicionar annotations de leitura/mutação/destrutividade;
- incluir `instructions` curtas com aprovação, rate limit e proibição de
  recursão;
- mapear erros estáveis sem stack trace;
- não iniciar frontend, app-server ou outro worker para responder ao MCP;
- stdout reservado ao protocolo; logs somente em stderr ou arquivo redigido;
- encerramento gracioso quando o Codex fecha STDIO.

Configuração esperada no Codex deve ser gerada pelo agente sem inserir segredos no
`config.toml`. Se houver variável privada, usar nome de ambiente e arquivo fora do
Git. Não editar configuração global de outros projetos sem autorização.

Testes mínimos:

- initialize;
- tools/list com 13 ou menos ferramentas elegíveis;
- ausência de `codex_delegate_task`;
- paridade de schemas com `JarvisToolCatalog`;
- leitura AceleraChat simulada;
- mutação produz proposta/aprovação, não execução direta;
- provider indisponível remove a ferramenta;
- erro de configuração não imprime segredo;
- protocolo não é corrompido por logs.

## 8. MCP remoto para ChatGPT

Implementar apenas no Core da VPS e atrás de HTTPS.

- Transporte: Streamable HTTP.
- Endpoint: `/mcp`.
- Autenticação inicial aceitável: Bearer rotacionável; OAuth pode ser adicionado
  antes de multiusuário público.
- Identidade e escopos por usuário/cliente.
- Rate limit e `Retry-After`.
- CORS não substitui autenticação.
- Sessões e streaming não podem depender de memória de um único processo sem
  afinidade ou persistência.
- Ferramentas mutáveis exigem aprovação do Agent Core.
- `codex.delegate` só aparece com Edge Worker elegível e online.
- nenhum segredo em URL, query ou browser storage inseguro.

O MCP remoto não é necessário para o Codex local. Ele é necessário somente para
ChatGPT/consumidor remoto.

## 9. Mapeamento AceleraChat

Não codificar rotas ou capacidades duplicadas. Descobrir o catálogo e health do
AceleraChat.

Configuração privada já prevista:

```text
ACELERACHAT_BASE_URL=https://atendimento.meugerenciador.pro/api/v1/openjarvis
ACELERACHAT_BEARER_TOKEN=<privado>
ACELERACHAT_WEBHOOK_SECRET_CURRENT=<privado>
ACELERACHAT_WEBHOOK_SECRET_PREVIOUS=<privado-ou-vazio>
ACELERACHAT_EMAIL_INBOX_ID=<id-confirmado>
ACELERACHAT_WHATSAPP_INBOX_ID=<id-confirmado>
```

Semântica obrigatória:

- API sem retry automático para mutação aceita/resultado desconhecido;
- `Idempotency-Key` derivada do `action_id` estável;
- resultados assíncronos reconciliados por webhook/backfill;
- cursores tratados como opacos;
- `has_more` e `next_cursor` respeitados;
- duplicatas e eventos fora de ordem tratados por identidade/sequência;
- somente caixas permitidas;
- `enable_auto_assignment` nunca indica conexão;
- WhatsApp conectado somente quando há evidência do provedor;
- e-mail é atendimento AceleraChat, não administração Gmail.

Capacidades formalmente não suportadas não podem aparecer no MCP ou UI:

- WhatsApp: reação, reply contextual nativo, mídia, provider mark-read,
  broadcast e voz;
- e-mail: composição nova, upload de anexos, archive e trash.

## 10. Autenticação e rotação

Quatro fronteiras independentes:

| Fronteira | Credencial | Regra |
| --- | --- | --- |
| OpenJarvis → AceleraChat | Bearer AceleraChat | Escopo/allowlist da integração |
| AceleraChat → OpenJarvis | HMAC AceleraChat | Timestamp, event ID e corpo exato |
| Edge Worker → Core | credencial do dispositivo | Rotação e revogação por dispositivo |
| Cliente → MCP remoto | Bearer/OAuth MCP | Identidade e escopos próprios |

Nunca reutilizar uma credencial em outra fronteira. Implementar sobreposição de
credencial anterior por período limitado, revogação imediata e auditoria sem
valor completo.

## 11. Persistência e retenção

Definir migrations/versionamento para:

- devices;
- device credentials metadata;
- jobs;
- attempts/leases;
- event deduplication;
- per-job/device sequences;
- approvals;
- provider operations já existentes.

Valores recomendados a validar:

- deduplicação Edge: pelo menos 30 dias;
- jobs terminais: 30 dias com payload sensível expurgado antes, quando possível;
- audit metadata: 90 dias ou política formal do produto;
- heartbeat efêmero: não persistir indefinidamente;
- credencial anterior: expiração explícita, preferencialmente 24 horas.

## 12. Segurança

- schemas fechados e limites de tamanho;
- allowlist de ferramentas por identidade;
- zero shell genérico;
- zero eval/import dinâmico vindo de payload;
- proteção contra prompt injection em mensagens/e-mails;
- não retornar filesystem paths privados ao MCP remoto;
- sanitizar logs, exceções e traces;
- validar URL HTTPS e bloquear credenciais em host/query;
- rate limit por usuário, dispositivo e integração;
- timeouts por ferramenta;
- circuit breaker apenas para leituras seguras;
- nenhuma tentativa automática cega de mutação;
- approvals persistidas e vinculadas ao conteúdo exato;
- testes de isolamento entre contas, caixas, sessões e dispositivos.

## 13. Testes obrigatórios

### Unitários/contratuais

- catálogo global 16 e MCP local sem ferramentas Codex;
- schemas e additionalProperties;
- autenticação/rotação/revogação;
- state machine de jobs;
- lease e reentrega;
- duplicata e fora de ordem;
- reconexão e resume;
- cancelamento;
- approval;
- provider offline;
- cursor/backfill AceleraChat;
- unknown result;
- rate limit;
- body limit;
- redaction;
- retenção.

### Integração sem mutação

- Core e worker em processos distintos;
- queda de rede simulada;
- reinício do Core;
- reinício do worker;
- Codex app-server fake e real somente com status/read;
- MCP STDIO real com Codex em projeto de teste;
- MCP HTTP autenticado;
- webhook AceleraChat assinado usando fixture sanitizada;
- nenhum envio externo.

### Build

- Python lint/format/typecheck;
- frontend tests e build;
- contrato gerado sem diff inesperado;
- container build;
- container como usuário não root;
- scanner de segredos;
- `git diff --check`;
- instalação limpa reproduzida sem `node_modules` copiado.

## 14. Entregáveis do agente OpenJarvis

1. Branch limpa e SHA final.
2. Lista de arquivos alterados.
3. Edge Worker implementado.
4. Core WSS implementado.
5. MCP local conectado ao catálogo.
6. MCP remoto, se incluído, com auth e streaming.
7. Schemas e fixtures dos frames Edge.
8. Migrations e retenção.
9. Compose/Dockerfile de produção.
10. Arquivo `.env.example` sem segredos.
11. Runbook de instalação e atualização.
12. Runbook de rotação/revogação.
13. Testes e resultados.
14. Rollback para SHA anterior.
15. Confirmação de nenhum envio real.
16. Lista explícita de bloqueadores restantes.

Não declarar “pronto para produção” enquanto Edge Worker, Core, MCP local,
artefato reproduzível, rollback e testes de reconexão não estiverem concluídos.

## 15. Gate para a instalação na VPS

O lado OpenJarvis será aceito para instalação somente quando:

- `git status` estiver limpo;
- SHA final estiver publicado/reproduzível;
- testes direcionados estiverem verdes;
- imagem e digest existirem;
- Compose não tocar serviços ICP/AceleraChat;
- variáveis privadas estiverem documentadas sem valores;
- nenhum segredo estiver no Git;
- endpoints, portas e health estiverem definidos;
- rollback tiver sido ensaiado localmente;
- o relatório confirmar zero mutações externas.

Depois disso, seguir
`docs/integrations/openjarvis-vps-release-runbook.md`.

## 16. Manifesto privado

O agente deve consultar, sem imprimir, o arquivo:

`D:\dev\workspaces\centraldeatendimentoCHAT\credenciais\openjarvis\OPENJARVIS_VPS_EDGE_MCP_PRIVATE.md`

Esse manifesto aponta para as credenciais existentes e separa os valores que só
serão gerados durante a ativação.
