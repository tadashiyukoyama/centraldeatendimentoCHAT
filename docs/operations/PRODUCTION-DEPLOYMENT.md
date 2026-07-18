# Production deployment contract

Production deployment is manual and image-pinned. The first deployment is not authorized by this document; it requires explicit approval after the draft PR and the ICP domain are reviewed.

The first-deploy exception is intentionally narrow: when `/opt/central-atendimento/shared/active-image` does not exist and `/opt/central-atendimento/shared/bootstrap-attempt` does not exist, the empty-database bootstrap may proceed without a backup because the database will be created empty and there are no real production data yet. Once `active-image` exists, normal deployment is refused with `Subsequent deployment blocked: database backup gate is not configured.` If a first bootstrap has already started without completing, `bootstrap-attempt` blocks retry with `Incomplete first deployment detected: manual audit is required before retry.` No permanent bypass is provided; a future authorization must define and implement the backup gate first.

## Required GitHub configuration

Secrets:

- `PROD_SSH_KEY`: private key for the restricted `centraldeploy` account;
- `GHCR_PULL_TOKEN`: least-privilege token that can pull the package;
- `PROD_ENV_FILE`: complete production environment file, without committing its values.

Variables:

- `PROD_HOST`
- `PROD_PORT`
- `PROD_USER` (expected: `centraldeploy`)
- `PROD_DOMAIN`
- `PROD_SSH_HOST_KEY` (SHA-256 SSH host-key fingerprint)
- `ICP_PANEL_DOMAIN`
- `PROD_EXPECTED_IP` (required IPv4 variable in the `production` environment; documentation placeholder: `192.0.2.44`)

The domain must be created through the ICP panel as a dedicated subdomain. TLS must be enabled there after DNS resolves to the VPS. The panel domain remains separate.

## Pipeline

1. `build-production-image.yml` builds the exact commit on a GitHub-hosted runner.
2. The image is published to GHCR with the full commit SHA as tag.
3. `deploy-production.yml` runs only through `workflow_dispatch` and requires an explicit full SHA.
4. The workflow checks out `inputs.image_tag`, proves that commit is present, proves it is an ancestor of `origin/main`, and verifies the deployment scripts are the blobs from that same commit.
5. Before sending the environment file or token, the runner calculates the five contract hashes from the selected commit and calls the restricted `verify-contract` action. A mismatch aborts with `Production contract mismatch: remote root-owned files do not match the selected commit.` The workflow never updates root-owned files automatically.
6. The runner pins the audited ED25519 SSH host key with `ssh-keyscan -t
   ed25519`. It requires exactly one unique fingerprint, places only the
   validated ED25519 line in `known_hosts`, and uses the restricted deploy key.
7. Before any mutating SSH command, the runner validates the immutable image exists in GHCR, validates `PROD_EXPECTED_IP`, checks that `PROD_DOMAIN` resolves exclusively to it, and performs strict HTTPS checks for the Chatwoot and ICP panel domains. HTTP 200-599 is accepted because the application may not be active yet; status 000 or invalid TLS blocks the operation.
8. The environment file is sent over the authenticated SSH channel and stored with mode 0600; its value is never printed.
9. The deploy command receives exactly four arguments: image SHA, Chatwoot domain, ICP panel domain and expected IPv4. The gateway rejects missing or extra arguments.
10. The deploy script repeats the DNS, strict TLS and ICP checks before changing application state, validates Compose, authenticates to GHCR, pulls the immutable image, and logs out before creating any bootstrap marker.
11. A successful image pull is followed immediately by the atomic `shared/bootstrap-attempt` marker with the image, UTC start time and `state=started`, before stateful Compose operations.
12. PostgreSQL and Redis start on the private network; `db:chatwoot_prepare` runs; Rails and Sidekiq start.
13. The internal Rails health endpoint, public Chatwoot domain, ICP panel and ICP container are tested with strict TLS verification. Only after all healthchecks does the script atomically write `active-image` and mark the bootstrap `completed`.
14. A first-deploy failure preserves PostgreSQL, Redis, storage and `bootstrap-attempt`, stops project services, and does not create `active-image`. It does not restore a previous application image because the first deploy has no previous image.

## Production filesystem

```text
/opt/central-atendimento/compose/
/opt/central-atendimento/releases/
/opt/central-atendimento/shared/env/chatwoot.production.env
/opt/central-atendimento/shared/bootstrap-attempt
/opt/central-atendimento/shared/active-image
/opt/central-atendimento/shared/storage/postgres/
/opt/central-atendimento/shared/storage/redis/
/opt/central-atendimento/shared/storage/ (Active Storage)
/var/log/central-atendimento/
```

There is no backup directory in this phase. The application image is the only rollback artifact.

## Backup gate

The image-only policy is allowed only for the first empty-database bootstrap. It does not authorize later deployments. After the first successful deployment creates `shared/active-image`, the deploy script blocks subsequent deployment until a future decision adds a real database-backup gate. This phase does not create that backup implementation.

## Remote contract pinning

The restricted SSH gateway exposes only the fixed-path `verify-contract` read action for contract inspection. It hashes the deployed root-owned deploy, rollback, environment-install, Compose and gateway files and accepts no user-supplied path, glob or shell. The workflow compares all five values with the selected commit before it sends any environment file or registry token. Installing the exact root-owned blobs is a separate administrative gate after merge; this workflow never performs that installation.

## SSH host-key pinning

The production workflow validates only the audited ED25519 host key. It calls
`ssh-keyscan -t ed25519`, requires exactly one unique SHA-256 fingerprint, and
compares it with `PROD_SSH_HOST_KEY`. The resulting `known_hosts` file contains
only the validated `ssh-ed25519` line. The workflow does not depend on the
order in which RSA, ECDSA, or ED25519 keys might otherwise be returned, and a
mismatch stops the job before remote SSH, environment transfer, or registry
token handling.

The variable is not changed to accommodate a scan result. Any mismatch must
be independently audited; no fallback accepts an arbitrary or unvalidated
fingerprint.

The incident recorded for this contract is:

```text
Run: 29632260934
Failure: Prepare pinned SSH host key
Persistent state started: NO
VPS altered: NO
Rerun: NO
```

## Failed first bootstrap

The first deploy has no previous application image for rollback. A failure after `bootstrap-attempt` is created must leave the marker in place, preserve database and storage paths, stop `rails`, `sidekiq`, `postgres` and `redis` when present, and leave `active-image` absent. Retrying is prohibited until a manual audit and explicit owner authorization remove the marker through a separate administrative command. Error handling never deletes volumes, containers or the marker and never touches ICP/OpenResty.

## Preflight and secret handling

The GHCR pull token is supplied only to the runner through the protected secret, used through `docker login --password-stdin` for `buildx imagetools inspect`, and cleaned up with `docker logout` on both success and failure. It is never sent to the VPS during preflight, stored in a file, placed in arguments, written to the bootstrap marker or printed in logs. The preflight must pass before `install-env` is allowed.

`PROD_EXPECTED_IP` is an environment variable, not a secret and not a repository fallback. The repository contains only documentation placeholders; the production environment supplies the actual IPv4 value.
