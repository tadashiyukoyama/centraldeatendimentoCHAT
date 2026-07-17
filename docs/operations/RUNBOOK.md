# Runbook operacional inicial

## Verificações seguras

```powershell
git status --short --branch
git worktree list --porcelain
pwsh -File scripts/check-worktree-budget.ps1
docker compose --env-file "$env:CHATWOOT_ENV_FILE" -f infra/compose/docker-compose.production.yaml config
```

O último comando valida a interpolação sem iniciar ou alterar serviços. Não
executar operações contra produção apenas para confirmar conectividade.

## Desenvolvimento local

1. Copiar `infra/env/chatwoot.local.env.example` para a cápsula como `private/env/chatwoot.local.env`.
2. Ajustar `CHATWOOT_ENV_FILE`, `CHATWOOT_POSTGRES_DATA_DIR`, `CHATWOOT_REDIS_DATA_DIR` e `CHATWOOT_STORAGE_DIR` no ambiente do shell.
3. Executar `docker compose --env-file $env:CHATWOOT_ENV_FILE -f infra/compose/docker-compose.local.yaml up -d --build`.
4. Executar migrations/seeds pelos comandos oficiais do Chatwoot dentro do serviço Rails.
5. Validar `http://127.0.0.1:3000/health` e o painel do MailHog quando necessário.

## Produção

1. Publicar imagem imutável por SHA em registry autorizado.
2. Criar/validar o env privado no host e o backup do PostgreSQL.
3. Conferir `CHATWOOT_IMAGE`, SHA e migrations esperadas.
4. Rodar `docker compose ... config` e revisar o diff do Compose.
5. Subir Rails/Sidekiq e aguardar healthchecks.
6. Validar `/health`, login administrativo controlado, jobs e uma operação funcional.
7. Registrar evidências sem dados pessoais e sem segredos.

Deploy, migration e rollback de produção exigem autorização explícita. O
rollback de aplicação deve preservar o volume do banco; alteração incompatível
de schema exige runbook específico e restauração ensaiada.

O workflow `Central de Atendimento CHAT infrastructure contract` valida a
estrutura do Compose e impede que a cápsula privada seja confundida com o Git.
Os workflows upstream continuam responsáveis pelos testes e build do Chatwoot.

## Worktrees

O máximo é de três worktrees adicionais além do clone canônico. Quando o
orçamento estiver cheio, reutilizar um worktree limpo ou parar e pedir
autorização para remoção. Não usar `git clean`, `git reset --hard` ou exclusão
recursiva como limpeza de rotina.
