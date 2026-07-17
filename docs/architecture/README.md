# Arquitetura do centraldeatendimentoCHAT

Esta é a camada arquitetural própria sobre o Chatwoot OSS. O código de negócio
continua organizado como upstream; decisões de operação, isolamento e
governança ficam aqui e em `infra/`.

- [Infraestrutura](INFRASTRUCTURE.md)
- [Layout da cápsula e do repositório](../operations/REPOSITORY_LAYOUT.md)
- [Segredos e dados](../operations/SECRETS.md)
- [Memória e documentação](../operations/MEMORY_AND_DOCUMENTATION.md)
- [Runbook operacional](../operations/RUNBOOK.md)
- [Arquitetura mobile](MOBILE-ARCHITECTURE.md)
- [Workspace multi-repositório](MULTI-REPOSITORY-WORKSPACE.md)
- [ADR-0001: cápsula e orçamento de worktrees](../decisions/0001-capsula-worktree-budget.md)

## Estado da decisão

Arquitetura inicial aprovada para desenvolvimento local e primeira implantação:
Rails + Sidekiq + PostgreSQL 16/pgvector + Redis 7 + Active Storage, atrás de
OpenResty/Nginx. Não há MariaDB/MySQL nesta base.
