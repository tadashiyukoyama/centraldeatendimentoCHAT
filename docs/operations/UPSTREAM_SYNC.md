# Sincronização com o Chatwoot OSS

O projeto mantém duas origens Git:

- `upstream`: `https://github.com/chatwoot/chatwoot.git`, branch `develop`;
- `origin`: `https://github.com/tadashiyukoyama/centraldeatendimentoCHAT.git`, branch `main`.

## Procedimento

1. confirmar `git status` limpo ou registrar mudanças locais;
2. consultar este `AGENTS.md` e o estado atual;
3. executar `git fetch upstream --prune`;
4. abrir branch de reconciliação e comparar `upstream/develop` com `main`;
5. revisar conflitos em `AGENTS.md`, `docs/`, `infra/` e configurações de segurança;
6. testar a aplicação e o Compose antes do merge;
7. atualizar `docs/PROJECT_STATE.md` e decisões afetadas;
8. publicar somente depois de revisar o diff completo.

Não fazer merge automático de mudanças upstream que alterem banco, env,
Dockerfiles, autenticação ou filas sem revisar o impacto na arquitetura própria.
O histórico do upstream permanece uma fonte de contexto, mas os contratos
versionados deste projeto são a referência operacional.
