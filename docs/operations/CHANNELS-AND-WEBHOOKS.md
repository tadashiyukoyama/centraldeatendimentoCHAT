# Channels and webhook contract

This document describes the production boundary for the requested channels. It does not contain provider credentials and does not activate integrations by itself.

## Shared ingress

All public traffic uses the dedicated Chatwoot HTTPS hostname created in the ICP panel. The ICP/OpenResty proxy forwards to `http://127.0.0.1:3000`; no channel gets a direct public port.

## Channel matrix

| Channel              | Configuration location                             | Public callback or transport                                                  | Required secret material                                                             |
| -------------------- | -------------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Website chat         | Chatwoot Website inbox and widget settings         | Browser requests to `FRONTEND_URL`                                            | Widget token is managed by Chatwoot; do not copy it into Git                         |
| Meta WhatsApp        | Chatwoot WhatsApp inbox plus Meta app              | `GET/POST /webhooks/whatsapp/:phone_number`                                   | Meta verify token, app secret and access token                                       |
| WhatsApp via QR Code | Native Chatwoot inbox backed by Evolution API      | Signed `POST /webhooks/evolution/:public_id`; outbound server-to-server HTTPS | Global Evolution key in private env; encrypted per-instance token and webhook secret |
| Meta Instagram       | Chatwoot Instagram inbox plus Meta app             | `GET /webhooks/instagram` and `POST /webhooks/instagram`                      | Meta verify token, app secret and access token                                       |
| Telegram             | Chatwoot Telegram inbox                            | `POST /webhooks/telegram/:bot_token`                                          | Telegram bot token                                                                   |
| Email                | SMTP environment and Chatwoot email inbox settings | Outbound SMTP; inbound messages retrieved through IMAP polling                | SMTP and IMAP credentials                                                            |

## ICP proxy requirements

The ICP route must preserve:

- HTTPS and the original host;
- `GET` verification requests and their query strings;
- `POST` methods, headers and request bodies;
- normal request size and timeout limits for provider callbacks;
- the same route on renewal of the TLS certificate.

The proxy target is `127.0.0.1:3000`. Do not put webhook tokens in the hostname, ICP notes, shell history, workflow output or committed documentation. The Telegram path shown above is the Chatwoot route shape only; the real token is supplied by the inbox integration and remains secret. Evolution callbacks must retain the `Authorization` header used by the short-lived signed JWT.

## Activation checklist

1. Confirm the final Chatwoot subdomain and TLS contact e-mail.
2. Create the subdomain and TLS through the ICP panel's persistent proxy flow.
3. Set `FRONTEND_URL` and `CHATWOOT_DOMAIN` to that HTTPS hostname.
4. Create the Website, Meta WhatsApp, Instagram and Telegram inboxes in Chatwoot using provider credentials stored outside GitHub source files.
5. Configure Meta callback verification and subscribe the required webhook fields.
6. Configure the Telegram webhook through the Chatwoot integration.
7. Configure SMTP for system messages and IMAP for any email inbox; keep provider ports outbound-only.
8. When WhatsApp via QR Code is enabled, follow
   [`EVOLUTION-NATIVE-WHATSAPP.md`](EVOLUTION-NATIVE-WHATSAPP.md); the Evolution
   service, PostgreSQL and Redis remain dedicated and its built-in Chatwoot
   integration remains disabled.
9. Test `/health`, website widget loading, provider verification, one inbound message per channel and one outbound reply.

## Network rule

The only Chatwoot application listener is Rails on `127.0.0.1:3000`. PostgreSQL, Redis and Sidekiq remain on the private Docker network. Evolution uses its own private database and Redis and is exposed only through its authorized HTTPS proxy. No SMTP, IMAP, Meta, Telegram or website-specific host port is published by the production Compose file.
