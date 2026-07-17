# Layout do projeto e da cápsula

## Cápsula local, fora do Git

```text
D:/dev/workspaces/centraldeatendimentoCHAT/
├── .workspace/
│   ├── project.json          identidade e caminhos locais
│   ├── storage-policy.json   política de retenção e segredos
│   └── worktrees.json        ledger de finalidade/ciclo de vida
├── artifacts/                relatórios e entregáveis temporários
├── private/
│   ├── credentials/          chaves e certificados com ACL restrita
│   ├── env/                  .env reais não versionados
│   └── recovery/database/    dumps e checksums protegidos
├── runtime/
│   ├── data/postgres/        dados vivos do PostgreSQL local
│   ├── data/redis/           dados vivos do Redis local
│   ├── data/storage/         anexos do Active Storage local
│   ├── cache/                cache descartável
│   ├── logs/                 logs sanitizados
│   ├── memory/short-term/    memória curta do Codex
│   └── temp/                 temporários
├── worktrees/                até 3 worktrees adicionais ativos
└── <clone canônico>/         o Git do projeto
```

Nesta estação o clone canônico está em `D:/dev/workspaces/chatwoot`, conforme o
manifesto local. A cápsula não precisa ser um subdiretório do Git. Isso evita
que dados, segredos e worktrees sejam confundidos com código ou publicados no
GitHub.

## Dentro do clone Git

```text
AGENTS.md                contrato de execução do Codex
app/ config/ lib/        código Rails e configurações upstream
app/javascript/          frontend Vue/Vite
db/                      migrations e seeds
docs/architecture/       arquitetura e decisões de alto nível
docs/decisions/          ADRs versionadas
docs/operations/         segredos, memória, runbook e estado operacional
infra/compose/           Compose próprio local e de produção
infra/env/               exemplos sanitizados de ambiente
infra/proxy/             exemplo de proxy reverso
scripts/                 verificações operacionais seguras
spec/ tests/              testes upstream e do projeto
```

Nunca colocar `private/`, `runtime/`, `artifacts/` ou `worktrees/` dentro do
clone. Se a organização física mudar, atualizar o manifesto local, este
documento e o contrato do `AGENTS.md` na mesma tarefa.
