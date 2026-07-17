# Memória do Codex e disciplina documental

## Memória curta

Fica fora do Git em `runtime/memory/short-term/`. Contém somente o estado da
tarefa atual: hipóteses, decisões ainda não consolidadas, comandos pendentes e
links para evidências. Tem retenção de revisão de sete dias e pode ser apagada
depois que a tarefa estiver reconciliada.

Não colocar senha, token, dump, transcript cru ou dado pessoal. Memória curta
nunca vence uma fonte de verdade versionada.

## Memória longa

Fica no Git, em documentos pequenos e específicos:

- `docs/architecture/`: topologia, componentes e invariantes;
- `docs/decisions/`: decisões irreversíveis ou com trade-off relevante;
- `docs/operations/`: runbooks, segredos, banco, recuperação e estado operacional;
- `AGENTS.md`: contrato de trabalho e limites do Codex.

O estado atual deve registrar SHA, imagem, serviços, banco, migrations, riscos e
pendências, sem segredos. Uma conclusão deve apontar para evidência observável.

## Quando atualizar obrigatoriamente

Atualizar no mesmo change set quando houver alteração de arquitetura,
infraestrutura, banco/migration, env, segurança, integração externa, release,
rollback, layout da cápsula, orçamento de worktrees ou contrato do Codex.

Para código sem mudança de comportamento operacional, a atualização documental
pode ser dispensada, mas o commit deve deixar claro por que não há contrato novo.

## Reconciliação

Antes de encerrar uma tarefa, comparar código, Compose, docs e estado Git. Se um
documento estiver atrasado, corrigir ou registrar a divergência como pendência;
nunca preencher o relatório com uma suposição apresentada como fato.
