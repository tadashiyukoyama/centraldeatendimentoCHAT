# Production application rollback

Rollback is image-only in the initial deployment phase. It restores only a previously recorded application image; it does not revert migrations or PostgreSQL schema changes. The first deployment has no previous application image for rollback. Database backup and database restoration are intentionally not configured because the first deployment creates an empty database and production has no real data yet.

## Procedure

1. Identify a previously successful full-SHA image from the deployment record. The first deployment cannot use this procedure because it has no previous image.
2. Supply exactly four arguments to the restricted rollback command: image SHA, Chatwoot domain, ICP panel domain and the `PROD_EXPECTED_IP` IPv4 value from the production environment.
3. Before changing Rails or Sidekiq, validate the expected IPv4, public DNS, strict HTTPS, ICP panel, ICP container, private network and Compose configuration.
4. Pull the previous immutable image from GHCR and log out on success or failure.
5. Recreate only Chatwoot Rails and Sidekiq using the existing database, Redis and storage paths.
6. Verify internal `/health`, the public Chatwoot domain, the ICP panel and the ICP container.
7. Keep PostgreSQL, Redis, storage, `icontainer-network`, OpenResty and the ICP panel untouched.

## Limits

This procedure does not revert schema changes. A failed first bootstrap is not an image rollback: it preserves `bootstrap-attempt`, database and storage, stops project services, and requires manual audit plus explicit authorization before retry. Before real operations, database backup, migration compatibility, restore testing and a separate data-recovery runbook are mandatory.

There is no permanent authorization to operate without backups. The first-deploy empty-database exception is the only exception documented for this phase.

BACKUP DE BANCO: NÃO CONFIGURADO
MOTIVO: PRIMEIRA IMPLANTAÇÃO SEM DADOS REAIS
OBRIGATÓRIO ANTES DA OPERAÇÃO REAL: SIM
