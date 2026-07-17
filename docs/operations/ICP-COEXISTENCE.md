# ICP/OpenResty coexistence contract

The ICP remains the public ingress for the VPS. Chatwoot must not replace the ICP, its OpenResty container, its panel, or its network.

## Current verified topology

```text
Internet
  -> ICP/OpenResty (80/443, provider-managed)
     -> ICP domain proxy for CHATWOOT_DOMAIN
        -> http://127.0.0.1:3000 on the VPS
           -> Rails container
              -> private Docker network
                 -> PostgreSQL, Redis, Sidekiq
```

The installed ICP container `ic-openresty-tATe` runs with Docker `host` networking. Its persistent configuration is mounted from `/etc/icontainer/apps/openresty/openresty`, including the provider-managed `conf/conf.d` directory. The ICP panel bundle exposes the supported “Proxying Existing Service” flow and documents a proxy address such as `127.0.0.1:8080`; the production target for Chatwoot is `127.0.0.1:3000`.

The chosen coexistence mode is therefore the host-loopback mode. Chatwoot Rails publishes only `127.0.0.1:3000:3000`. It does not join `icontainer-network`; that provider network remains untouched. PostgreSQL, Redis and Sidekiq remain on the private application network.

Do not edit generated OpenResty files over SSH. Create the domain and proxy through the ICP panel's persistent domain/proxy workflow, then verify the generated result through the panel and by public HTTPS tests.

Before the first application state is changed, the deployment gate resolves the Chatwoot domain to the expected VPS IP (`216.22.27.48` unless an explicit infrastructure override is supplied), performs a normal certificate-validated HTTPS request, and records the observed HTTP status. Status 200-599 is accepted because the Rails service may not be active yet; status 000, DNS mismatch or invalid TLS blocks the deployment. This check does not modify ICP/OpenResty and runs before PostgreSQL, Redis or migrations.

## Public channels

All inbound webhooks use the Chatwoot HTTPS domain and the ICP proxy. No channel opens a new host port.

| Channel | Public flow | Chatwoot endpoint/contract | Additional host port |
| --- | --- | --- | --- |
| Website chat | Browser loads the widget from `FRONTEND_URL` | Widget endpoints on the Chatwoot HTTPS domain | None |
| Meta WhatsApp | Meta verification and event delivery through ICP | `GET/POST /webhooks/whatsapp/:phone_number` | None |
| Meta Instagram | Meta verification and event delivery through ICP | `GET /webhooks/instagram` and `POST /webhooks/instagram` | None |
| Telegram | Telegram sends the bot callback through ICP | `POST /webhooks/telegram/:bot_token` | None |
| Email | Rails/Sidekiq connects outbound to the mail provider | SMTP for delivery and IMAP polling for email inboxes | None |

For Meta, the proxy must preserve the HTTP method, query string, headers and request body. The Meta callback URL and verify token are configured in Meta and in the Chatwoot inbox; they are not committed to Git. Telegram bot tokens are secrets and must never be written to this document, shell history, workflow logs or URLs shared publicly. Email provider credentials are kept in the production secret file and inbox configuration.

The website chat, Telegram and Meta channels are application-level integrations. They do not require a second reverse proxy, a public Rails port or a separate webhook service. Email does not require an inbound SMTP/IMAP listener in this Compose contract: the application uses the configured provider, with Sidekiq handling scheduled IMAP retrieval when an email inbox is configured.

The activation checklist and provider-specific secret boundaries are maintained in [CHANNELS-AND-WEBHOOKS.md](CHANNELS-AND-WEBHOOKS.md).

The final domain must be a dedicated subdomain, for example `chatwoot.vps10054.panel.icontainer.cloud`, and must not replace `vps10054.panel.icontainer.cloud`, which remains reserved for the ICP panel.

## Invariants

- Do not stop, recreate, update or remove `ic-openresty-tATe`.
- Do not modify `icontainer-network`.
- Do not expose ports 3000, 3036, 5432, 6379 or 8025.
- Do not install a second Nginx/OpenResty.
- Verify the ICP panel and its domain before and after each application deployment.
- Abort if the ICP container, OpenResty, port 2090, ports 80/443 or an existing route changes unexpectedly.

## Backup decision

BACKUP DE BANCO: NÃO CONFIGURADO
MOTIVO: PRIMEIRA IMPLANTAÇÃO SEM DADOS REAIS
OBRIGATÓRIO ANTES DA OPERAÇÃO REAL: SIM
