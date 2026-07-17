# Estado inicial do centraldeatendimentoCHAT

- Base: clone raso de `chatwoot/chatwoot`, branch upstream `develop`.
- Branch local do projeto: `main`.
- Remote upstream: `https://github.com/chatwoot/chatwoot.git`.
- Remote origin: será configurado para `tadashiyukoyama/centraldeatendimentoCHAT` na publicação final.
- Infraestrutura própria: `infra/compose/`, `infra/env/` e `infra/proxy/`.
- Banco oficial: PostgreSQL 16 com `pgvector`.
- Cache e filas: Redis 7; jobs processados por Sidekiq.
- Limite: 3 worktrees adicionais ativos, sem limpeza automática.

Este arquivo descreve o estado do bootstrap. Após a primeira validação de
containers, atualizar com SHA, imagens, portas, healthchecks e pendências reais.
