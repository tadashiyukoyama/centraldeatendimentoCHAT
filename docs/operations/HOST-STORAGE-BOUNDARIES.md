# Limites de armazenamento do host

Esta política registra o que ainda precisa ser comprovado antes da instalação
de qualquer runtime. Nenhum caminho abaixo é considerado protegido apenas por
estar documentado.

## Pendências de validação

- armazenamento do Docker Desktop;
- virtual disk do WSL2;
- imagens, camadas e volumes Docker;
- cache do pnpm;
- cache do Bundler;
- arquivos temporários e logs;
- artifacts de build do servidor;
- Android SDK, Gradle, AVDs e APKs/AABs.

## Regra operacional

Executar `scripts/disk-guard.ps1 -ReadOnly` antes de criar worktree, instalar
dependências, fazer Docker build, executar `bundle install`, `pnpm install` ou
iniciar build mobile. O script mede somente os caminhos conhecidos, não remove
arquivos e não afirma que o disco C: está protegido.

O resultado deve registrar espaço livre em C: e D:, tamanho das árvores do
projeto e quais fronteiras continuam pendentes. Limpeza exige classificação,
auditoria e autorização explícita; não usar limpeza automática para contornar o
limite de worktrees.
