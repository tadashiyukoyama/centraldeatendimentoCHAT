# Política de worktrees

- Não criar worktree para toda tarefa por padrão.
- Tarefas pequenas podem usar o checkout canônico `server/`.
- Criar worktree somente quando houver necessidade real de isolamento, paralelismo ou reprodução independente.
- Máximo: duas worktrees adicionais ativas além do clone canônico.
- Consultar `git worktree list --porcelain` antes de criar, reutilizar ou remover.
- Alterações não commitadas, PR aberta ou branch útil bloqueiam remoção.
- Não usar `git clean`, `git reset --hard` ou exclusão automática para liberar espaço.
- Não instalar dependências automaticamente em todas as worktrees.
- Executar o disk guard antes de criar worktree, instalar dependências ou compilar.
