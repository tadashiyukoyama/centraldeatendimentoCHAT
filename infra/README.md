# Infraestrutura do centraldeatendimentoCHAT

- `compose/docker-compose.local.yaml`: desenvolvimento completo com dados fora do Git.
- `compose/docker-compose.production.yaml`: execução de imagem imutável em host privado.
- `env/*.example`: nomes e valores de exemplo, sem segredos reais.
- `proxy/openresty.conf.example`: referência de proxy para o Rails local do host.

Use os arquivos próprios com o runbook em `docs/operations/RUNBOOK.md`. O
`docker-compose.yaml` na raiz é a referência oficial do Chatwoot e não deve ser
misturado com estes serviços na mesma porta.
