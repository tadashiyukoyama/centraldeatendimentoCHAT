# Production application rollback

Rollback is image-only for the application image. It restores only a previously recorded application image; it does not revert migrations or PostgreSQL schema changes and it does not restore database rows. The first deployment has no previous application image for rollback. Subsequent deployments require the deploy gate to create a validated PostgreSQL backup before changing application state.

## Procedure

1. Identify a previously successful full-SHA image from the deployment record. The first deployment cannot use this procedure because it has no previous image.
2. Run the manual `Roll back production image through ICP` workflow from
   `main`, supplying the previous full SHA and the exact confirmation
   `ROLLBACK`.
3. The workflow validates that the target is an ancestor of `main`, that its
   immutable image exists in GHCR, and that the pinned SSH key, remote
   production contract, DNS, TLS and ICP preflights pass.
4. The restricted gateway then supplies exactly four arguments to the rollback
   command: image SHA, Chatwoot domain, ICP panel domain and the
   `PROD_EXPECTED_IP` IPv4 value from the production environment.
5. Before changing Rails or Sidekiq, validate the expected IPv4, public DNS, strict HTTPS, ICP panel, ICP container, private network and Compose configuration.
6. Pull the previous immutable image from GHCR and log out on success or failure.
7. Recreate only Chatwoot Rails and Sidekiq using the existing database, Redis and storage paths.
8. Verify internal `/health`, the public Chatwoot domain, the ICP panel and the ICP container.
9. Keep PostgreSQL, Redis, storage, `icontainer-network`, OpenResty and the ICP panel untouched.

## Limits

This procedure does not revert schema changes. A failed first bootstrap is not an image rollback: it preserves `bootstrap-attempt`, database and storage, stops project services, and requires manual audit plus explicit authorization before retry. A later application rollback must be evaluated against the schema version because the image-only action cannot undo a migration.

The deploy gate stores validated local recovery artifacts in
`/opt/central-atendimento/shared/backups/postgres/`. Those artifacts are not
automatically restored by rollback and are not an off-site backup. A separate
data-recovery runbook and restore drill are still required before treating the
VPS copy as a complete backup strategy.

BACKUP DE BANCO: GATE CONFIGURADO NO DEPLOY POSTERIOR
VALIDACAO: PG_DUMP CUSTOM + PG_RESTORE LIST + SHA-256
RESTAURACAO AUTOMATICA: NAO
