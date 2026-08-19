# AceleraChat native OpenJarvis contract

- Contract version: `2026-08-19.2`.
- Schema version: `1.0`.
- Audited implementation base SHA: `128d00a1743e198eb370f55fbaf7bffe7a2b01f1`.
- The final implementation SHA is recorded in the release report because changing
  this contract necessarily creates a new Git object.
- OpenAPI root: `docs/integrations/openjarvis-openapi.yaml`.
- Sanitized fixtures: `spec/fixtures/openjarvis/endpoints.json` and
  `spec/fixtures/openjarvis/webhooks.json`.

This delivery changes only AceleraChat. It does not modify OpenJarvis and it does
not authorize a parallel WhatsApp, Instagram or email provider connection.

## Authority and isolation

AceleraChat is the sole authority for its configured inboxes. Every API request
is evaluated as the configured service user, then restricted by the integration
inbox allowlist and the existing strict-team permission filter. A resource that
exists outside that boundary is returned as not found.

The inbox boundary has two explicit modes:

- `selected`: only the persisted inbox IDs are authorized;
- `all_account`: all current and future inboxes belonging to the same account
  are resolved dynamically. This mode requires an administrator service user
  and never grants access to another account.

Connection and per-inbox capability checks still apply in both modes. Dynamic
authorization does not turn a disconnected or unsupported channel into an
executable capability.

The service user is not a permission bypass. Agents, teams and labels used by a
mutation must first be returned by `/agents`, `/teams` or `/labels`. Conversation
assignment additionally verifies that the agent is assignable to the target
inbox.

## Authentication, rotation and secrets

All `/api/v1/openjarvis/*` requests require an opaque Bearer credential. POST and
PATCH mutations also require `Idempotency-Key` with 8 to 128 permitted
characters.

Bearer and HMAC rotation preserve the previous credential for 24 hours. During
that overlap:

- both current and previous Bearer tokens authenticate;
- outbound webhooks carry the current signature in
  `X-AceleraChat-Signature` and the previous signature, when present, in
  `X-AceleraChat-Signature-Previous`;
- ordinary configuration reads expose only suffix and expiry metadata;
- the new secret is displayed only by the explicit rotation response.

Expired overlap values are removed by `Openjarvis::RetentionJob`. Disconnecting
disables API access and webhooks immediately. No credential belongs in this
contract, fixtures, logs, tests or the release report.

## Executable catalog and OpenAPI

`GET /catalog` returns:

- the implementation base SHA and running release;
- granted scopes;
- JSON Schema input and output contracts for every executable operation;
- the public error taxonomy;
- rate limits, retention and idempotency policy;
- webhook delivery semantics;
- the static capability matrix for every known `channel_type`.

`GET /openapi` returns the OpenAPI 3.1 root document. The repository package
contains its relative schema, path, response, webhook and example files.

## Inbox health and capability truth

`GET /inboxes` and `GET /inboxes/:inbox_id/health` return connection and
capability data. `enable_auto_assignment` is exposed only as
`auto_assignment_enabled`; it never represents provider connection.

Connection evidence is deliberately qualified:

- WhatsApp Evolution: state comes from the real
  `Whatsapp::EvolutionProvisioning` state machine. Only `connected` is reported
  as connected.
- WhatsApp Cloud/default: local provider configuration and reauthorization state
  are reported as `configured_not_probed`; no remote probe is fabricated.
- Email: IMAP and outbound SMTP/OAuth configuration are reported separately as
  `configured_not_probed`.
- Instagram/Facebook: local authorization state is reported as
  `configured_not_probed` or `authorization_required`.
- Web widget: a persisted website token is sufficient for local `active` state.

The per-inbox response is authoritative because provider and channel-specific
details can change the static matrix.

## Capability declarations

Every capability is an object with `supported`, `mode`, optional `endpoint` and
an explicit reason when unsupported. The complete machine-readable matrix is in
`Openjarvis::CapabilityResolver` and `/catalog`.

### WhatsApp

- Read/search conversations and messages: supported.
- Send text through an existing conversation: supported; delivery is asynchronous.
- Create or reuse a WhatsApp association from an exact E.164 contact number:
  supported by the server-side contact and conversation builders. OpenJarvis never
  supplies `source_id`.
- Evolution provider-native contextual reply: supported by `reply_to_message_id`.
- Evolution reactions: supported by the dedicated reaction endpoint; an empty
  reaction removes the current reaction.
- Mark read inside AceleraChat: supported by `/conversations/:id/read`.
- Evolution provider read receipt: supported by the dedicated provider-read
  endpoint for up to 100 provider-backed incoming messages.
- Read attachment metadata: supported.
- Evolution media from a public HTTPS URL: supported through SSRF-protected fetch,
  an allowlist of content types and a 20 MB limit. Direct local-file transfer is
  not part of this HTTP contract.
- Delivery status: supported from `Message.status`, `source_id` and
  `message.updated` events. A successful create response is not delivery proof.
- Evolution session-window templates: not applicable; the existing Evolution
  adapter sends session text without the official-template gate.
- Group administration, profile changes, status/broadcast and provider privacy
  settings are deliberately not exposed by this integration token.

### Email

This is an AceleraChat customer-service integration, not a generic IMAP mailbox
client.

- Search AceleraChat email messages and unread incoming messages: supported.
- AceleraChat conversations are the thread boundary: supported.
- Reply with `to_emails`, `cc_emails`, `bcc_emails` and optional HTML body:
  supported.
- Read attachment metadata: supported.
- Upload/send new attachments: not supported until a dedicated binary-upload
  contract exists.
- Provider mailbox archive and trash: formally outside scope and not supported.

### Website, API and Instagram

Website/API text reads and sends are supported. Contextual AceleraChat reply is
supported for website/API conversations. Instagram text reads and sends are
supported, while provider-native contextual reply, reaction, read receipt and
binary upload remain explicitly unsupported.

## Conversation creation and contact-inbox association

OpenJarvis never supplies or invents `source_id`.

`POST /conversations` accepts `inbox_id` and `contact_id`. The server:

1. reuses an existing `ContactInbox` association;
2. otherwise derives a safe association for API, website, email, SMS, Twilio or
   WhatsApp using the contact's existing routing attributes;
3. rejects provider-only channels such as Instagram with
   `contact_inbox_missing` until a real inbound/provider association exists;
4. rejects a missing email or phone with
   `contact_routing_attribute_missing`.

This prevents guessed provider identities and cross-contact routing.

## Search and stable cursors

Contacts and conversations are ordered by `updated_at DESC, id DESC`. Messages
are ordered by `created_at DESC, id DESC`. Backfill is ordered by
`updated_at ASC, id ASC`.

All paged responses include:

```json
{
  "meta": {
    "limit": 25,
    "returned": 25,
    "has_more": true,
    "next_cursor": "opaque-signed-value"
  }
}
```

Cursors are signed, bind the operation, direction and normalized filters, and
use the database ID as deterministic tie-breaker. Tampered cursors return
`invalid_cursor`; reuse with another collection/filter returns
`cursor_mismatch`. Cursor pagination is stable in ordering but not a database
snapshot: concurrent updates are reconciled through backfill.

Conversation search accepts `contact_id`, `inbox_id`, `status` and
`updated_after`. Global message search accepts `q`, `contact_id`, `inbox_id`,
account-visible `conversation_id` and `unread`.

## Backfill and reconciliation

`GET /backfill?resource=contacts|conversations|messages` returns current
`resource.snapshot` envelopes and an ascending signed cursor. It is used for:

- initial synchronization;
- recovery after lost webhook delivery;
- resolution of duplicate or out-of-order events;
- reconciliation of `unknown` mutation results.

Backfill covers current resources. Deletion tombstones are not part of this
contract version and are not advertised.

## Webhook schema and delivery guarantees

Every webhook contains:

- `schema_version`;
- globally unique `event_id`;
- event name and microsecond `occurred_at`;
- resource type, public ID, internal ID, deterministic version and monotonic
  per-resource sequence;
- the complete resource presenter;
- changed attributes when available.

The event schemas are defined individually in
`docs/integrations/openjarvis-openapi/webhooks.yaml`.

Delivery guarantees:

- at-least-once, therefore duplicates are possible;
- no global ordering guarantee;
- a monotonic sequence per integration/resource permits local reordering;
- the receiver must durably persist `event_id`/delivery ID before returning 2xx;
- transport errors, 408, 409, 425, 429 and 5xx are temporary and retried with
  bounded polynomial backoff, at most five attempts;
- other 4xx responses are permanent and are not retried;
- delivery metadata records `temporary` or `permanent` failure class;
- reconciliation uses the backfill endpoint.

The signature input is exactly `timestamp + "." + raw_body`, HMAC-SHA256. The
receiver URL must be HTTPS, cannot contain credentials/query/fragment and is
subject to SSRF controls. Sensitive signature headers are stripped on
cross-origin redirects.

## Idempotency, unknown results and retention

Idempotent replay returns the original status/body and
`Idempotency-Replayed: true`. Reusing a key with another operation/payload
returns `idempotency_conflict`.

A processing row after an interrupted request returns `request_in_progress`
with `result_state: unknown`. OpenJarvis must reconcile using operation history,
resource search or backfill before choosing a new key. Unexpected mutation
errors also use `result_state: unknown`; the API never claims a write was not
applied when that cannot be proven.

- Idempotency response retention: 30 days.
- Webhook delivery metadata retention: 30 days.
- Webhook bodies are not retained in the delivery ledger.
- Resource sequence counters contain only integration/resource identifiers and
  remain until integration deletion.

## Rate limits

- Reads: 120 requests per 60 seconds per integration.
- Writes: 30 requests per 60 seconds per integration.

Every response includes limit, remaining and reset headers. A limit breach
returns HTTP 429, `Retry-After`, and the same stable JSON error envelope as the
rest of the API.

## Public errors

Errors use:

```json
{
  "error": {
    "code": "stable_machine_code",
    "message": "Sanitized explanation",
    "details": {},
    "retryable": false,
    "result_state": "not_applied",
    "request_id": "sanitized-request-id"
  }
}
```

The complete taxonomy is returned by `/catalog` and represented in OpenAPI.
Provider secrets, raw Rails errors, environment variables, shell access, raw
logs and arbitrary database queries are never part of this contract.
