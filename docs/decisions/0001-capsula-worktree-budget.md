# ADR-0001 — Cápsula local e orçamento de worktrees

- Status: aprovado para a arquitetura inicial
- Data: 2026-07-17
- Escopo: organização local e governança do Codex

## Decisão

Adotar uma cápsula local externa ao clone Git, inspirada na estrutura do OZ3D,
com `.workspace`, `artifacts`, `private`, `runtime` e `worktrees`. O clone
canônico permanece separado; nenhum dado privado ou runtime é publicado.

O orçamento máximo é de **3 worktrees adicionais ativos**, além do clone
canônico. O estado real é obtido do Git; o ledger local registra apenas a
finalidade e o ciclo de vida. Não há exclusão automática.

## Motivo

Separar código, dados, segredos, entregáveis e worktrees reduz o risco de
publicar informações sensíveis e evita acumular versões antigas no disco. Três
isolamentos adicionais atendem paralelismo normal sem tornar a limpeza um
processo destrutivo ou bloquear o checkout principal.

## Consequências

- O Codex pode trabalhar no checkout principal e em três tarefas isoladas.
- A quarta tarefa paralela precisa reutilizar um worktree limpo ou de decisão explícita.
- Um worktree com mudanças não commitadas, PR aberta ou branch útil não pode ser removido.
- O limite é operacional, não um limite de branches remotas ou commits históricos.
