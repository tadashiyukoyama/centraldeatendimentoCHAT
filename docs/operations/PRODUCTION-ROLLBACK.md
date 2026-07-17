# Production application rollback

Rollback is image-only in the initial deployment phase. Database backup and database restoration are intentionally not configured because production has no real data yet.

## Procedure

1. Identify the previous full-SHA image from `/opt/central-atendimento/shared/previous-image` or the deployment record.
2. Dispatch `deploy-production.yml` with the explicit previous image SHA, or use the restricted rollback command.
3. Pull the previous immutable image from GHCR.
4. Recreate only Chatwoot Rails and Sidekiq using the existing database, Redis and storage paths.
5. Verify internal `/health`, the public Chatwoot domain, the ICP panel and the ICP container.
6. Keep PostgreSQL, Redis, storage, `icontainer-network`, OpenResty and the ICP panel untouched.

## Limits

This procedure does not revert schema changes. Before real operations, database backup, migration compatibility, restore testing and a separate data-recovery runbook are mandatory.

BACKUP DE BANCO: NÃO CONFIGURADO
MOTIVO: PRIMEIRA IMPLANTAÇÃO SEM DADOS REAIS
OBRIGATÓRIO ANTES DA OPERAÇÃO REAL: SIM
