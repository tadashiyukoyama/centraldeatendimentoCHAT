# Central de Atendimento CHAT — Contrato de trabalho do Codex

Este bloco é a política específica do repositório `tadashiyukoyama/centraldeatendimentoCHAT` e complementa as diretrizes upstream do Chatwoot abaixo. O código foi originado de `chatwoot/chatwoot`; o remote `upstream` permanece apontando para a origem oficial e o remote `origin` aponta para o repositório deste projeto.

**Precedência:** quando houver conflito, as regras específicas de
`CENTRAL_ATENDIMENTO_CHAT` prevalecem sobre instruções herdadas do upstream
Chatwoot. As regras de sistema, segurança e autorização continuam superiores a
ambas.

## 1. Escopo, identidade e fontes da verdade

- Projeto: `CENTRAL_ATENDIMENTO_CHAT`.
- Repositório canônico: `tadashiyukoyama/centraldeatendimentoCHAT`.
- Origem upstream: `chatwoot/chatwoot`, branch `develop`.
- Branch canônica deste projeto: `main`.
- Stack preservada do Chatwoot: Rails, Vue/Vite, PostgreSQL com `pgvector`, Redis, Sidekiq e Active Storage.
- Produção planejada: Docker Compose em host privado, OpenResty/Nginx na borda com TLS e app publicado apenas em `127.0.0.1:3000`.

O clone canônico pode estar fora da cápsula local. Quando
`CENTRAL_ATENDIMENTO_WORKSPACE_ROOT` estiver definida, consultar os manifests
em `.workspace/` sob essa raiz. Sem a variável, operar apenas no repositório
atual e não inventar caminhos externos.

Fontes de verdade, nesta ordem:

1. estado real do Git (`git status`, `git worktree list --porcelain`, SHA e remotes);
2. código e migrations do clone canônico;
3. Compose e runbooks versionados em `infra/` e `docs/`;
4. estado atual canônico em `docs/operations/CURRENT-PROJECT-STATE.md`;
5. manifestos locais em `.workspace/`, somente para identidade e política de armazenamento;
6. estado efetivamente observado nos containers e no banco;
7. memória curta e artifacts, que são auxiliares e nunca substituem documentação versionada.

Merge no GitHub não prova deploy, documentação não prova execução e um nome de
branch não substitui o SHA completo.

## 2. Arquitetura que não pode ser alterada silenciosamente

O núcleo deve continuar sendo o Chatwoot OSS. A topologia operacional é:

- Rails web/Puma para HTTP, API, webhooks e interface;
- Sidekiq para jobs assíncronos e filas;
- PostgreSQL 16 com `pgvector` como banco oficial e fonte persistente;
- Redis 7 como cache, pub/sub e backend de filas;
- Active Storage em volume local no desenvolvimento e caminho persistente ou S3 compatível em produção;
- OpenResty/Nginx externo como terminador TLS e proxy público;
- Docker Compose para o ambiente local e para a instalação inicial de produção.

Não introduzir MariaDB, MySQL, segundo banco, segundo proxy público ou outro
runtime paralelo sem ADR aprovada e autorização do proprietário. O Compose
oficial na raiz continua útil como referência upstream; os contratos do projeto
ficam em `infra/compose/`.

## 3. Cápsula local e limite de worktrees

A cápsula local é externa ao Git e segue a estrutura:

```text
centraldeatendimentoCHAT/
├── .workspace/       identidade, política e ledger local
├── artifacts/        relatórios e entregáveis temporários
├── private/          credenciais, envs reais e recuperação do banco
├── runtime/          dados, storage, cache, logs, temp e memória curta
├── worktrees/        worktrees adicionais autorizados
└── <clone canônico>  código Git do projeto
```

O clone canônico não entra na contagem. O limite é de **2 worktrees adicionais
ativos**. Antes de criar ou remover um worktree, executar
`git worktree list --porcelain` e `pwsh -File scripts/check-worktree-budget.ps1`.

O limite não bloqueia o Codex: permite o checkout principal mais duas tarefas
isoladas em paralelo. Uma worktree não é obrigatória para toda tarefa; tarefas
pequenas devem usar o checkout canônico. Ao atingir duas, o Codex deve reutilizar
uma worktree limpa ou solicitar autorização para remover uma depois de verificar branch,
commits úteis, PR, alterações não commitadas e processos ativos. Não apagar,
prunar ou limpar automaticamente; alterações não commitadas sempre bloqueiam
remoção.

Não criar `.codex` dentro de `server/`, `mobile/` ou `worktrees/`. A configuração
do Codex permanece no `CODEX_HOME` existente no disco D:. Não instalar
dependências automaticamente em todas as worktrees. Executar o disk guard antes
de criar worktree, fazer Docker build, `pnpm install`, `bundle install` ou build
mobile.

## 4. Segredos, banco e dados privados

- Valores reais ficam na cápsula `private/env/` ou no secret store do provedor;
- chaves e certificados ficam em `private/credentials/` com ACL restrita;
- dumps do PostgreSQL ficam em `private/recovery/database/`, com checksum e retenção;
- dados vivos locais ficam em `runtime/data/postgres`, `runtime/data/redis` e `runtime/data/storage`;
- em produção, os equivalentes ficam em volumes dedicados do host, fora do clone;
- o GitHub recebe somente exemplos sanitizados e nomes de variáveis;
- nunca imprimir, versionar, colar em logs, screenshots, testes ou relatórios um segredo.

A existência de uma credencial não autoriza seu uso. Não descriptografar cofres,
materializar chaves privadas, conectar a produção, alterar credenciais ou
restaurar banco sem tarefa e autorização explícitas.

## 5. Memória curta, memória longa e atualização obrigatória

**Memória curta do Codex:** `runtime/memory/short-term/`. Serve para o contexto
temporário da tarefa e pode ser descartada após a reconciliação. Não é fonte de
verdade, tem revisão padrão de 7 dias e não pode conter segredos.

**Memória longa do projeto:** `docs/architecture/`, `docs/operations/`,
`docs/decisions/` e o estado atual versionado. Decisões, contratos, invariantes,
runbooks e fatos que precisam sobreviver à tarefa devem terminar nesses arquivos.

O Codex é obrigado a atualizar a documentação versionada quando alterar:

- arquitetura, topologia, serviços, portas, volumes ou caminhos de runtime;
- banco, migrations, índices, política de backup ou restauração;
- variáveis de ambiente, integração externa, autenticação ou segurança;
- contrato público, comportamento operacional, CI/CD, release ou rollback;
- política do Codex, worktrees, memória, armazenamento ou fontes da verdade;
- estado atual após uma validação, release ou decisão que mude o runbook.

Uma alteração puramente interna que não mude contrato, operação ou decisão pode
ser documentada apenas no commit. Se código, infra e documento divergirem,
registrar a divergência e reconciliar antes de declarar a tarefa concluída.

Integrações de transporte devem permanecer modulares e server-side. Para o
provedor Evolution, a integração Chatwoot embutida na Evolution permanece
desativada; tokens, QR Codes, nomes internos de instância e payloads brutos não
entram no navegador, `provider_config`, logs, artifacts ou memória do Codex.
Mudanças nesse limite exigem revisão de arquitetura e segurança.

## 6. Protocolo de execução

Antes de escrever:

1. ler este `AGENTS.md` e os documentos relevantes em `docs/`;
2. confirmar raiz Git, branch, remotes, SHA e status inicial;
3. consultar o orçamento de worktrees e executar o disk guard em modo somente leitura;
4. buscar `upstream` somente quando a tarefa exigir sincronização;
5. definir arquivos autorizados, riscos e testes antes da mudança;
6. manter mudanças não relacionadas intactas.

Para mudanças de banco, exigir backup válido, migration revisada, checksum,
plano de rollback e autorização operacional. Para deploy, usar apenas o fluxo
versionado e autorização explícita; o Codex não promove produção por SSH local.

## 7. Critérios de aceite da tarefa

- `git diff --check` sem erro;
- documentação e exemplos de ambiente coerentes com a mudança;
- contratos do workspace validados pelo schema e pelos testes PowerShell quando a fundação for alterada;
- Compose validado com `docker compose config` quando aplicável;
- testes/lint adequados ao escopo, sem alegar sucesso de comandos não executados;
- nenhum segredo ou artefato privado no diff;
- worktree e branch deixados identificáveis, sem limpeza destrutiva.

As instruções oficiais de estilo, testes, Enterprise overlay e frontend do
Chatwoot continuam válidas nas seções seguintes.


## Build / Test / Lint

- **Setup**: `bundle install && pnpm install`
- **Run Dev**: `pnpm dev` or `overmind start -f ./Procfile.dev`
- **Seed Local Test Data**: `bundle exec rails db:seed` (quickly populates minimal data for standard feature verification)
- **Seed Search Test Data**: `bundle exec rails search:setup_test_data` (bulk fixture generation for search/performance/manual load scenarios)
- **Seed Account Sample Data (richer test data)**: `Seeders::AccountSeeder` is available as an internal utility and is exposed through Super Admin `Accounts#seed`, but can be used directly in dev workflows too:
  - UI path: Super Admin → Accounts → Seed (enqueues `Internal::SeedAccountJob`).
  - CLI path: `bundle exec rails runner "Internal::SeedAccountJob.perform_now(Account.find(<id>))"` (or call `Seeders::AccountSeeder.new(account: Account.find(<id>)).perform!` directly).
- **Lint JS/Vue**: `pnpm eslint` / `pnpm eslint:fix`
- **Lint Ruby**: `bundle exec rubocop -a`
- **Test JS**: `pnpm test` or `pnpm test:watch`
- **Test Ruby**: `bundle exec rspec spec/path/to/file_spec.rb`
- **Single Test**: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- **Run Project**: `overmind start -f Procfile.dev`
- **Ruby Version**: Manage Ruby via `rbenv` and install the version listed in `.ruby-version` (e.g., `rbenv install $(cat .ruby-version)`)
- **rbenv setup**: Before running any `bundle` or `rspec` commands, init rbenv in your shell (`eval "$(rbenv init -)"`) so the correct Ruby/Bundler versions are used
- Always prefer `bundle exec` for Ruby CLI tasks (rspec, rake, rubocop, etc.)

## Code Style

- **Ruby**: Follow RuboCop rules (150 character max line length)
- **Vue/JS**: Use ESLint (Airbnb base + Vue 3 recommended)
- **Vue Components**: Use PascalCase
- **Events**: Use camelCase
- **I18n**: No bare strings in templates; use i18n
- **Error Handling**: Use custom exceptions (`lib/custom_exceptions/`)
- **Models**: Validate presence/uniqueness, add proper indexes
- **Type Safety**: Use PropTypes in Vue, strong params in Rails
- **Naming**: Use clear, descriptive names with consistent casing
- **Vue API**: Always use Composition API with `<script setup>` at the top

## Styling

- **Tailwind Only**:  
  - Do not write custom CSS  
  - Do not use scoped CSS  
  - Do not use inline styles  
  - Always use Tailwind utility classes  
- **Colors**: Refer to `tailwind.config.js` for color definitions

## General Guidelines

- Prefer the smallest production-ready change that solves the current problem.
- Build for the expected production path first. Do not add speculative guards, fallbacks, retries, or edge-case handling unless the caller can actually hit that case or production has proven it necessary.
- When an impossible or misconfigured state would indicate a setup/deployment bug, let it fail loudly instead of silently skipping behavior.
- For locked/internal configs that must exist in production, prefer direct reads (`find`, `find_by!`, required hash keys) over silent fallbacks.
- Do not add validation or response checks unless the code uses the result or the check changes behavior meaningfully.
- Prefer existing repo dependencies/client libraries over hand-rolled protocol code for auth, signing, parsing, or API plumbing.
- Avoid one-use private helpers unless they hide real complexity or make the main flow meaningfully easier to read.
- Prefer minimal, readable code over elaborate abstractions; clarity beats cleverness
- Break down complex tasks into small, testable units
- Iterate after confirmation
- Avoid writing specs unless explicitly asked
- In specs, avoid custom helper methods for setup/data. Prefer `let` values and direct per-example setup; only add a helper when it removes meaningful repeated complexity.
- Remove dead/unreachable/unused code
- Don’t write multiple versions or backups for the same logic — pick the best approach and implement it
- Prefer `with_modified_env` (from spec helpers) over stubbing `ENV` directly in specs
- Specs in parallel/reloading environments: prefer comparing `error.class.name` over constant class equality when asserting raised errors

## Codex Worktree Workflow

- Uma worktree adicional é criada apenas quando houver necessidade real de isolamento, paralelismo ou reprodução independente.
- Tarefas pequenas usam o checkout canônico `server/`.
- A configuração do Codex fica no `CODEX_HOME` existente no disco D:; não criar `.codex/` no projeto, no mobile ou em worktrees.
- O limite operacional é de duas worktrees adicionais, além do checkout canônico.
- Cada worktree isolada deve receber portas, banco lógico e socket próprios apenas quando a tarefa realmente exigir processos concorrentes.

## Commit Messages

- Prefer Conventional Commits: `type(scope): subject` (scope optional)
- Example: `feat(auth): add user authentication`
- Don't reference Claude in commit messages

## PR Description Format

- Start with a short, user-facing paragraph describing the product change.
- Add a `Closes` section with relevant issue links (GitHub, Linear, etc.).
- For feature PRs, add `How to test` from a product/UX standpoint.
- For bugfix PRs, use `How to reproduce` when helpful.
- Optionally add a `What changed` section for implementation highlights.
- Do not add a `How this was tested` section listing specs/commands.

## Project-Specific

- **Translations**:
  - Only update `en.yml` and `en.json`
  - Other languages are handled by the community
  - Backend i18n → `en.yml`, Frontend i18n → `en.json`
- **Frontend**:
  - Use `components-next/` for message bubbles (the rest is being deprecated)

## Ruby Best Practices

- Use compact `module/class` definitions; avoid nested styles

## Enterprise Edition Notes

- Chatwoot has an Enterprise overlay under `enterprise/` that extends/overrides OSS code.
- When you add or modify core functionality, always check for corresponding files in `enterprise/` and keep behavior compatible.
- Follow the Enterprise development practices documented here:
  - https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38

Practical checklist for any change impacting core logic or public APIs
- Search for related files in both trees before editing (e.g., `rg -n "FooService|ControllerName|ModelName" app enterprise`).
- If adding new endpoints, services, or models, consider whether Enterprise needs:
  - An override (e.g., `enterprise/app/...`), or
  - An extension point (e.g., `prepend_mod_with`, hooks, configuration) to avoid hard forks.
- Avoid hardcoding instance- or plan-specific behavior in OSS; prefer configuration, feature flags, or extension points consumed by Enterprise.
- Keep request/response contracts stable across OSS and Enterprise; update both sets of routes/controllers when introducing new APIs.
- When renaming/moving shared code, mirror the change in `enterprise/` to prevent drift.
- Tests: Add Enterprise-specific specs under `spec/enterprise`, mirroring OSS spec layout where applicable.
- When modifying existing OSS features for Enterprise-only behavior, add an Enterprise module (via `prepend_mod_with`/`include_mod_with`) instead of editing OSS files directly—especially for policies, controllers, and services. For Enterprise-exclusive features, place code directly under `enterprise/`.

## Branding / White-labeling note

- For user-facing strings that currently contain "Chatwoot" but should adapt to branded/self-hosted installs, prefer applying `replaceInstallationName` from `shared/composables/useBranding` in the UI layer (for example tooltip and suggestion labels) instead of adding hardcoded brand-specific copy.
