# Production deployment contract

Production deployment is manual and image-pinned. The first deployment is not authorized by this document; it requires explicit approval after the draft PR and the ICP domain are reviewed.

The first-deploy exception is intentionally narrow: when `/opt/central-atendimento/shared/active-image` does not exist, the empty-database bootstrap may proceed without a backup because the database will be created empty and there are no real production data yet. Once `active-image` exists, normal deployment is refused with `Subsequent deployment blocked: database backup gate is not configured.` No permanent bypass is provided; a future authorization must define and implement the backup gate first.

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

The domain must be created through the ICP panel as a dedicated subdomain. TLS must be enabled there after DNS resolves to the VPS. The panel domain remains separate.

## Pipeline

1. `build-production-image.yml` builds the exact commit on a GitHub-hosted runner.
2. The image is published to GHCR with the full commit SHA as tag.
3. `deploy-production.yml` runs only through `workflow_dispatch` and requires an explicit full SHA.
4. The workflow checks out `inputs.image_tag`, proves that commit is present, proves it is an ancestor of `origin/main`, and verifies the deployment scripts are the blobs from that same commit.
5. The runner verifies the SSH host key and uses the restricted deploy key.
6. The environment file is sent over the authenticated SSH channel and stored with mode 0600; its value is never printed.
7. The deploy script logs in to GHCR only for the pull, pulls the immutable image, and logs out.
8. PostgreSQL and Redis start on the private network; `db:chatwoot_prepare` runs; Rails and Sidekiq start.
9. The internal Rails health endpoint, public Chatwoot domain, ICP panel and ICP container are tested with strict TLS verification.
10. A failure restores the previous application image without deleting database or storage paths.

## Production filesystem

```text
/opt/central-atendimento/compose/
/opt/central-atendimento/releases/
/opt/central-atendimento/shared/env/chatwoot.production.env
/opt/central-atendimento/shared/storage/postgres/
/opt/central-atendimento/shared/storage/redis/
/opt/central-atendimento/shared/storage/ (Active Storage)
/var/log/central-atendimento/
```

There is no backup directory in this phase. The application image is the only rollback artifact.

## Backup gate

The image-only policy is allowed only for the first empty-database bootstrap. It does not authorize later deployments. After the first successful deployment creates `shared/active-image`, the deploy script blocks subsequent deployment until a future decision adds a real database-backup gate. This phase does not create that backup implementation.
