# Contrato portátil do workspace

Este diretório é versionado no repositório do servidor e não contém segredos
nem caminhos absolutos. Ele descreve como reidratar o projeto em outra estação.

O workspace físico é resolvido por `CENTRAL_ATENDIMENTO_WORKSPACE_ROOT`. O
servidor e o mobile são repositórios separados no mesmo workspace; o mobile
está apenas reservado nesta fase e não foi clonado.

Leia `project.portable.json` e as políticas antes de qualquer movimentação,
criação de worktree, instalação de dependência ou build. Os exemplos locais são
modelos: não substituem os manifestos privados da estação.

## Limite de worktrees

O clone canônico do servidor não entra na contagem. O máximo é de duas
worktrees adicionais ativas. O estado real é sempre
`git worktree list --porcelain`; o ledger é apenas finalidade e ciclo de vida.
