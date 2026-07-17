# Estado inicial do centraldeatendimentoCHAT

- Base: clone raso de `chatwoot/chatwoot`, branch upstream `develop`.
- Branch local do projeto: `main`.
- Remote upstream: `https://github.com/chatwoot/chatwoot.git`.
- Remote origin: `https://github.com/tadashiyukoyama/centraldeatendimentoCHAT`.
- Infraestrutura própria: `infra/compose/`, `infra/env/` e `infra/proxy/`.
- Banco oficial: PostgreSQL 16 com `pgvector`.
- Cache e filas: Redis 7; jobs processados por Sidekiq.
- Limite: 3 worktrees adicionais ativos, sem limpeza automática.

SHA arquitetural publicado: `0c40a6a4f`; reconciliação documental publicada em
`ae2c46e44514390f702c472705ee3876743ee977` (histórico completo do upstream
preservado). A validação de containers permanece pendente porque o Docker não
está instalado nesta estação; não declarar healthchecks ou imagens executados
até essa validação ocorrer.
