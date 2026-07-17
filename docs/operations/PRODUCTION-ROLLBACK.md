# Production application rollback

Rollback is image-only in the initial deployment phase. It restores only a previously recorded application image; it does not revert migrations or PostgreSQL schema changes. The first deployment has no previous application image for rollback. Database backup and database restoration are intentionally not configured because the first deployment creates an empty database and production has no real data yet.

## Procedure

1. Identify a previously successful full-SHA image from the deployment record. The first deployment cannot use this procedure because it has no previous image.
2. Use the restricted rollback command with the explicit previous image SHA. The normal deployment command is blocked after `shared/active-image` exists until a future backup gate is implemented.
3. Pull the previous immutable image from GHCR.
4. Recreate only Chatwoot Rails and Sidekiq using the existing database, Redis and storage paths.
5. Verify internal `/health`, the public Chatwoot domain, the ICP panel and the ICP container.
6. Keep PostgreSQL, Redis, storage, `icontainer-network`, OpenResty and the ICP panel untouched.

## Limits

This procedure does not revert schema changes. A failed first bootstrap is not an image rollback: it preserves `bootstrap-attempt`, database and storage, stops project services, and requires manual audit plus explicit authorization before retry. Before real operations, database backup, migration compatibility, restore testing and a separate data-recovery runbook are mandatory.

There is no permanent authorization to operate without backups. The first-deploy empty-database exception is the only exception documented for this phase.

BACKUP DE BANCO: NÃO CONFIGURADO
MOTIVO: PRIMEIRA IMPLANTAÇÃO SEM DADOS REAIS
OBRIGATÓRIO ANTES DA OPERAÇÃO REAL: SIM
