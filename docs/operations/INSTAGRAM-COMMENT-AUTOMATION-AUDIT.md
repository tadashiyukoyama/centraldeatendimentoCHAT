# Instagram comment automation audit

## Traceability

- Audit date: 2026-07-27
- Baseline SHA: `ea18fe7fa160c5df4d89f2d823d7ab19b7aa409d`
- Production inbox: `aifoodpro` (`inbox_id=5`)
- Production channel: `Channel::Instagram`
- Instagram professional account ID: recorded in the runtime database; intentionally omitted here
- Production inspection: read-only, over SSH with the pinned host fingerprint
- Secrets: no access token, app secret, mailbox password, or webhook payload is stored in this document

## Scope

This audit covers keyword-triggered automations for comments on Instagram
professional media:

1. receive `comments` and `live_comments` webhook notifications;
2. select one deterministic automation;
3. optionally reply publicly;
4. optionally send the single private reply allowed by Meta;
5. associate the resulting Direct conversation with the campaign;
6. make that context available to Nemmo;
7. retain an auditable, idempotent delivery ledger.

Comment deletion, hiding, moderation, bulk historical import, and unsolicited
Direct campaigns are outside this delivery.

## Official platform contracts

The implementation follows the current Meta Instagram API contracts:

- [Comment webhook payload](https://www.postman.com/meta/instagram/request/23987686-db99ce99-bf76-475c-8b76-718576c11cae)
- [Private replies](https://www.postman.com/meta/instagram/request/23987686-189d7215-22b3-403f-b2f5-a46c7e66a514)
- [Public comment replies](https://www.postman.com/meta/instagram/request/23987686-59e5000b-326c-42a1-8545-b984c7fd0e40)
- [Webhook subscription](https://www.postman.com/meta/instagram/request/23987686-0223707a-7035-46a2-8015-1fdf7249278f)

Material constraints:

- Instagram Login requires `instagram_business_manage_comments`.
- The professional account must subscribe to `comments` and `live_comments`.
- A private reply uses the comment ID, can be sent only once, and must be sent
  within seven days. Live-comment replies are limited to the live broadcast.
- Follow-up messages are allowed only after the person responds, under the
  platform messaging window.

## Findings before implementation

### Critical

1. The production account was subscribed only to `messages`,
   `message_reactions`, and `messaging_seen`. Comment events could not arrive.
2. `Webhooks::InstagramEventsJob` treated every payload containing `changes` as
   a dashboard test event. Comment notifications can use either a Page-style
   `changes` collection or the Instagram Login `entry.field/value` shape;
   neither shape had a production comment-processing path.
3. The OAuth flow requested only basic and messaging permissions. Reconnecting
   the inbox could not grant the comment permission.
4. There was no durable idempotency boundary. Retried webhooks could have
   produced duplicate public or private replies if comment handling were added
   directly to the existing message job.

### High

1. No account-scoped model existed for keyword, publication, reply templates,
   activation window, or precedence.
2. No delivery ledger existed for matched, ignored, successful, partial, or
   failed events.
3. There was no way to pass campaign context to Nemmo after the commenter
   answered the private reply.
4. Subscription errors were swallowed by `Channel::Instagram#subscribe`, and
   reauthorization did not explicitly refresh subscriptions.
5. Direct-message and comment flows were coupled at the webhook endpoint but
   had different payloads, rate limits, idempotency rules, and failure modes.

### Medium

1. Instagram API versions were repeated in code. The new module consumes the
   existing `INSTAGRAM_API_VERSION` runtime setting.
2. Existing Instagram calls often passed tokens in query parameters. The new
   module sends tokens only in the authorization header.
3. Comment and username retention had no explicit limit because the data model
   did not exist.
4. There was no administrator-facing health view for comment subscriptions or
   event outcomes.

## Architecture decision

Comment automation is implemented as a separate first-class domain instead of
being forced into `AutomationRule` or `Campaign`:

- comments are not Chatwoot messages;
- Meta permits only one private reply per comment;
- webhook retries require a unique `(inbox_id, comment_id)` boundary;
- a public reply and a private reply can succeed or fail independently;
- the Direct conversation may be created later by an echo or customer reply.

The existing Instagram Direct path remains unchanged except for a small,
idempotent conversation-linking hook.

## Data model

### `instagram_comment_automations`

Account- and inbox-scoped configuration with:

- enabled/draft state;
- exact, whole-word, or contains matching;
- one to twenty normalized keywords;
- optional media ID;
- deterministic priority;
- optional nested-reply handling;
- public and private reply templates;
- Nemmo context and conversation label;
- optional activation window;
- optimistic locking and administrator audit history.

### `instagram_comment_events`

Minimal normalized delivery ledger with:

- unique comment ID per inbox;
- commenter, media, text, and webhook field;
- match and ignore reason;
- independent public/private delivery states and external IDs;
- retry state, timestamps, and optional conversation link.

Raw webhook payloads and credentials are never persisted. Comment text and
username use application encryption when encryption keys are configured. The
ledger is deleted after 90 days.

## Processing and failure isolation

1. The controller validates the Meta HMAC signature before acknowledging.
2. It normalizes both supported comment webhook shapes (`changes` and direct
   `entry.field/value`) and separates them from Direct messaging events.
3. A comment ingestion job normalizes supported fields and inserts the unique
   event.
4. A deterministic matcher selects at most one enabled automation.
5. A processing job claims the event with optimistic locking.
6. Public and private API calls are recorded independently.
7. HTTP 429, 5xx, and network failures use bounded delayed retries.
8. Permanent failures are recorded without retry storms.
9. The Direct echo or first customer reply links the conversation before the
   new message is dispatched, adds the configured label, and writes structured
   campaign context into conversation attributes consumed by Nemmo.

## Security controls

- HMAC verification remains mandatory.
- Every API route is account-scoped and administrator-only.
- The inbox must be an Instagram inbox owned by the current account.
- Object IDs are numeric and validated before URL construction.
- Tokens are sent in the authorization header and are not logged.
- Templates permit only approved variables and reject Liquid control tags.
- Rules cannot be enabled until comment webhook health is confirmed.
- Subscription activation preserves any pre-existing webhook fields and
  verifies the resulting field set with a read-after-write.
- Multiple workers cannot deliver the same new comment concurrently.
- Retries are bounded and endpoint-specific success is never resent.
- Destructive comment moderation is not implemented.

## Activation gate

Code deployment does not activate replies by itself. Production activation
requires:

1. deploy and migrate by full SHA;
2. reauthorize the Instagram inbox so its token grants
   `instagram_business_manage_comments`;
3. activate `comments` and `live_comments` subscriptions;
4. verify health in the inbox tab;
5. create a disabled rule and review its templates;
6. enable it for one controlled publication;
7. post one controlled keyword comment;
8. verify the public reply, private reply, event ledger, Direct conversation,
   label, and Nemmo context;
9. only then broaden the publication scope.

## Rollback

- Application rollback: deploy the previously recorded full image SHA.
- Schema rollback is not required for application rollback; both new tables are
  additive and unreferenced by the previous image.
- Disable all rules before rollback to stop sends immediately.
- If a public cut-off is required, remove `comments` and `live_comments` from
  the account subscription through the controlled administration action.
- Existing Instagram Direct messages remain independent of comment rules.
