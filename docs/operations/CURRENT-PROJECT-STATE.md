# Estado atual do projeto

Snapshot da consolidação: 2026-07-17.

## Identidade

- Repositório: `tadashiyukoyama/centraldeatendimentoCHAT`.
- Upstream: `chatwoot/chatwoot`.
- Base autorizada: `4b195fd4d985377c92d7732040e96913d8c485a6`.
- Branch de correção: `ops/consolidate-workspace-and-mobile-foundation`.
- Git root definitivo: `server/` dentro do workspace.
- Mobile: reservado, não baixado e sem `.git`.

## Estado físico observado

- O clone foi movido integralmente para `server/`, incluindo `.git`.
- A pasta antiga `chatwoot` ficou vazia; o Windows ainda impede sua remoção por handle externo.
- Não existem worktrees adicionais.
- O limite é de duas worktrees adicionais.
- A variável de usuário `CENTRAL_ATENDIMENTO_WORKSPACE_ROOT` aponta para o workspace.

## Restrições desta fase

- Docker não instalado e não deve ser instalado nesta tarefa.
- Containers, banco, migrations, healthchecks, VPS e deploy não foram executados.
- Configuração do Codex permanece no `CODEX_HOME` do disco D:.
- Nenhuma credencial foi aberta, copiada ou materializada.

## Próxima evidência necessária

Executar as validações portáteis e de fronteira. A instalação de runtime e o
bootstrap mobile exigem novas tarefas autorizadas e novo preflight.
