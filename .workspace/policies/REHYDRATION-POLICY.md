# Política de reidratação

`scripts/rehydrate-workspace.ps1 -ReadOnly` deve:

1. usar `CENTRAL_ATENDIMENTO_WORKSPACE_ROOT` quando definida;
2. sem a variável, resolver somente pelo `project.portable.json` e pelo diretório atual;
3. validar `projectId`, `origin`, `upstream` e a estrutura esperada;
4. não criar pastas, clonar repositórios, abrir credenciais ou instalar dependências em modo somente leitura;
5. falhar de forma segura em qualquer divergência de identidade;
6. respeitar o limite de duas worktrees adicionais.

Criação de diretórios, clone do mobile, instalação ou alteração de env exigem
parâmetro explícito e uma tarefa autorizada.
