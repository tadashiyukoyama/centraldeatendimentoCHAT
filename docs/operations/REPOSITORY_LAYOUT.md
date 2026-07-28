# Layout portátil do projeto e da cápsula

O workspace físico é resolvido por `CENTRAL_ATENDIMENTO_WORKSPACE_ROOT`. A
estrutura abaixo é relativa e não depende de uma letra de disco:

```text
<workspace-root>/
├── .workspace/       identidade local, políticas e ledger
├── artifacts/        relatórios e entregáveis temporários
├── credenciais/      senhas, tokens, DSNs e chaves; fora do Git
├── private/          recuperação e dados privados sem credenciais de acesso
├── runtime/          dados locais, storage, cache, logs, temp e memória curta
├── worktrees/        até 2 worktrees adicionais ativas
├── server/           repositório Git do Chatwoot/projeto
└── mobile/           reserva do futuro fork, sem clone nesta fase
```

O servidor e o mobile são repositórios diferentes no mesmo workspace. O
checkout canônico do servidor é `server/`; ele não entra na contagem de
worktrees. `mobile/` contém somente um marcador e não possui `.git`.

## Dentro de `server/`

```text
.workspace/           contrato portátil, políticas e templates locais
AGENTS.md              contrato de trabalho do Codex
app/ config/ lib/      código Rails e configurações upstream
app/javascript/       frontend Vue/Vite
db/                    migrations e seeds
docs/architecture/     arquitetura, mobile e decisões de alto nível
docs/decisions/        ADRs versionadas
docs/operations/       runbooks, segredos, memória e estado atual
infra/compose/         Compose próprio local e de produção
infra/env/             exemplos sanitizados de ambiente
infra/proxy/           exemplo de proxy reverso
scripts/               verificações operacionais seguras
spec/ tests/            testes upstream e do projeto
```

Não colocar `credenciais/`, `private/`, `runtime/`, `artifacts/` ou `worktrees/` dentro de
`server/`. Não criar `.codex` em `server/`, `mobile/` ou `worktrees/`; a
configuração do Codex permanece no `CODEX_HOME` existente no disco D:.
