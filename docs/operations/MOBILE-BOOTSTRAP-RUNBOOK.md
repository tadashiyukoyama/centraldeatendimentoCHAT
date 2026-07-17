# Runbook de bootstrap mobile

Este runbook é apenas preparatório. O mobile não deve ser clonado nesta fase.

Quando houver autorização explícita:

1. executar `scripts/disk-guard.ps1 -ReadOnly`;
2. confirmar que `mobile/` contém somente o marcador e não possui `.git`;
3. abrir uma branch própria no futuro repositório mobile;
4. clonar o upstream autorizado em `mobile/`, sem copiar o servidor;
5. configurar envs e credenciais fora do Git;
6. validar contrato de API com o servidor sem iniciar produção;
7. gerar builds em `artifacts/apk/`, nunca em `mobile/` como armazenamento final;
8. registrar o SHA do mobile, SDK, Gradle, assinatura e compatibilidade da API.

Não instalar dependências, Android SDK, Gradle ou chaves de assinatura como
efeito colateral de uma tarefa no servidor.
