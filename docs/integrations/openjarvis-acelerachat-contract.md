# AceleraChat ↔ OpenJarvis integration contract

- Contract version: `2026-08-18`
- AceleraChat baseline: `8e34f761c3a85153954529cf67490d6ac540781e`
- OpenJarvis audited baseline: `ec5e22e360943eb77560be3b9e5ea8ab7300b5eb`

## Authority boundary

AceleraChat is the only authority that reads and writes its WhatsApp, Instagram,
email and website inboxes. OpenJarvis must call this API instead of opening a
second Baileys, Gmail or provider connection for the same channel. This avoids
duplicate sends, split histories and conflicting session state.

The connection is account-scoped and evaluates every request as the configured
service user. It then applies the configured inbox allowlist and the existing
strict team visibility rules. An administrator can see every selected inbox; an
agent can only see the selected inboxes and teams already available to that user.

## Authentication and credentials

All `/api/v1/openjarvis/*` requests require:

```http
Authorization: Bearer <ACELERACHAT_BEARER_TOKEN>
Accept: application/json
```

Mutating `POST` and `PATCH` requests also require a stable idempotency key:

```http
Idempotency-Key: <8-to-128-character-operation-identifier>
Content-Type: application/json
```

Replays return the original status and body plus
`Idempotency-Replayed: true`. Reusing a key with another operation or payload
returns `409 idempotency_conflict`.

The Bearer token and webhook signing secret are separate, encrypted at rest when
Active Record encryption is configured, never returned by ordinary reads and
shown only after creation or explicit rotation. Production refuses an
OpenJarvis configuration without Active Record encryption.

The integration screen exposes separate actions to disable access temporarily,
rotate either credential, or disconnect completely. Disconnecting disables the
API, stops webhook delivery and rotates both credentials in the same operation.

The private handoff report and the actual values belong only in:

`D:\dev\workspaces\centraldeatendimentoCHAT\credenciais\openjarvis`

They must not be committed, pasted into issues, Actions logs or application logs.

## API endpoints

The runtime base URL is shown in the native integration screen. The production
value is expected to be:

`https://atendimento.meugerenciador.pro/api/v1/openjarvis`

| Method | Path                                                           | Scope                 | Purpose                                            |
| ------ | -------------------------------------------------------------- | --------------------- | -------------------------------------------------- |
| GET    | `/catalog`                                                     | authenticated         | Stable contract and granted scopes                 |
| GET    | `/health`                                                      | authenticated         | Integration health without secrets                 |
| GET    | `/diagnostics`                                                 | `diagnostics:read`    | PostgreSQL, Redis, Sidekiq and release diagnostics |
| GET    | `/operations`                                                  | `diagnostics:read`    | Sanitized API and webhook activity                 |
| GET    | `/inboxes`                                                     | `inboxes:read`        | Authorized inboxes                                 |
| GET    | `/contacts?q=&page=&limit=`                                    | `contacts:read`       | Authorized contact search                          |
| GET    | `/contacts/:id`                                                | `contacts:read`       | Contact details                                    |
| POST   | `/contacts`                                                    | `contacts:write`      | Create or reuse a contact                          |
| PATCH  | `/contacts/:id`                                                | `contacts:write`      | Update a contact                                   |
| GET    | `/conversations?inbox_id=&status=&updated_after=&page=&limit=` | `conversations:read`  | Authorized conversations                           |
| GET    | `/conversations/:id`                                           | `conversations:read`  | Conversation details                               |
| POST   | `/conversations`                                               | `conversations:write` | Create a conversation in an authorized inbox       |
| PATCH  | `/conversations/:id`                                           | `conversations:write` | Status, priority, assignment, team and labels      |
| GET    | `/conversations/:id/messages?before_id=&limit=`                | `messages:read`       | Messages newest first                              |
| POST   | `/conversations/:id/messages`                                  | `messages:write`      | Send through the conversation channel              |

The `:id` used by conversation routes is the account-visible `display_id`, not
the internal database ID.

Allowed enum values are explicit: contact `contact_type` is `visitor`, `lead` or
`customer`; conversation `status` is `open`, `resolved`, `pending` or `snoozed`;
and conversation `priority` is `low`, `medium`, `high` or `urgent`. Invalid
values, malformed ISO-8601 timestamps and non-positive message cursors return a
stable `400` error instead of an internal exception.

Errors use one envelope across the API:

```json
{
  "error": {
    "code": "stable_machine_code",
    "message": "Sanitized explanation",
    "details": {}
  }
}
```

### Contact write example

```json
{
  "contact": {
    "name": "Restaurante Exemplo",
    "email": "contato@example.com",
    "phone_number": "+5511999999999",
    "contact_type": "lead",
    "additional_attributes": { "company_name": "Restaurante Exemplo" },
    "custom_attributes": { "origin": "openjarvis" }
  }
}
```

### Message write example

```json
{
  "message": {
    "content": "Olá, esta mensagem foi enviada pelo atendimento AceleraChat.",
    "private": false,
    "content_type": "text"
  }
}
```

For email conversations, the same endpoint also accepts `to_emails`,
`cc_emails`, `bcc_emails` and `email_html_content`. Provider restrictions and
delivery errors remain the responsibility of the AceleraChat channel adapter.

## Webhooks sent to OpenJarvis

The administrator configures one exact HTTPS receiver URL. AceleraChat sends
JSON with these headers:

```http
X-AceleraChat-Delivery: <uuid>
X-AceleraChat-Timestamp: <unix-seconds>
X-AceleraChat-Signature: sha256=<hex-hmac>
```

Verification algorithm:

```text
expected = HMAC_SHA256(ACELERACHAT_WEBHOOK_SECRET, timestamp + "." + raw_body)
```

OpenJarvis must compare signatures in constant time, reject timestamps older
than five minutes, and persist delivery IDs long enough to reject duplicates.
It must return any `2xx` only after accepting the event durably. AceleraChat
retries transport and `4xx/5xx` failures with bounded exponential backoff.

Subscriptions:

- `message.created`
- `message.updated`
- `conversation.created`
- `conversation.updated`
- `conversation.status_changed`
- `contact.created`
- `contact.updated`

`integration.test` is sent only by the configuration screen and is not a normal
subscription.

The receiver URL cannot contain embedded credentials, a query string or a
fragment, and cannot use `chatwoot.com`, `chatwoot.help`, `chwt.app` or their
subdomains. Network fetching also blocks private-network SSRF targets by
default. Signature headers are marked sensitive and are removed from
cross-origin redirects.

## Required OpenJarvis implementation

The audited OpenJarvis runtime does not automatically expose generic MCP tools
inside its canonical Gemini Live agent. Implement the native adapter at the
audited SHA instead of relying only on `SystemBuilder._discover_external_mcp`.

Required code locations:

1. Add `src/openjarvis/server/jarvis_agent/adapters/acelerachat/` with a client,
   argument models and an adapter implementing `JarvisAdapter`.
2. Add `src/openjarvis/server/jarvis_agent/registry/acelerachat.py` with immutable
   `ToolDefinition` entries and input schemas.
3. Include those definitions in
   `src/openjarvis/server/jarvis_agent/registry/catalog.py`.
4. Add `AceleraChatAdapter` to the `adapters` map in
   `src/openjarvis/server/jarvis_agent/api/container.py`.
5. Add an authenticated webhook receiver to the FastAPI app, verify the raw
   body signature before parsing, deduplicate `X-AceleraChat-Delivery`, then
   publish accepted events into the canonical event ledger.
6. Add tests for capability discovery, reads, approval-required writes,
   idempotency, signature verification, stale timestamps, duplicate deliveries,
   timeouts and sanitized errors.

Recommended canonical tools:

- `acelerachat.health`
- `acelerachat.diagnostics`
- `acelerachat.list_inboxes`
- `acelerachat.search_contacts`
- `acelerachat.get_contact`
- `acelerachat.save_contact`
- `acelerachat.update_contact`
- `acelerachat.list_conversations`
- `acelerachat.get_conversation`
- `acelerachat.create_conversation`
- `acelerachat.update_conversation`
- `acelerachat.list_messages`
- `acelerachat.send_message`

Read tools use `Effect.READ`. Contact, conversation and message writes use
`Effect.MUTATION`, preserving the existing visual approval flow. Use
`AdapterContext.request_id` as the AceleraChat `Idempotency-Key`; do not invent a
second retry identity.

The adapter provider should be `acelerachat_api`, source `acelerachat`, adapter
ID `acelerachat`, and its capability set should come from the authenticated
`GET /catalog` response. A failed catalog or health call must mark the provider
disconnected; it must never silently fall back to direct WhatsApp or Gmail for
an AceleraChat-managed inbox.

## Operational limits

The diagnostics endpoint deliberately exposes no environment variables, shell,
Docker socket, arbitrary files, raw Rails logs or database queries. Host-level
VPS administration requires a separate, allowlisted operations agent and is not
part of this channel integration.

Version 1 sends text and channel-native message fields. Binary upload is not an
OpenJarvis API capability yet; existing attachment metadata can be read with
messages, but a future upload contract must be added before OpenJarvis can send
new files. This limitation must not be hidden by falling back to direct provider
connections.

The integration screen reports `awaiting_openjarvis` until the receiver exists
and reports `connected` only after OpenJarvis acknowledges a signed test event.
