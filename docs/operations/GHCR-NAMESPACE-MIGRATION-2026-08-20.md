# Migração do namespace GHCR — 2026-08-20

## Escopo

- Repositório: `cesaryukoyama28-eng/centraldeatendimentoCHAT`.
- Namespace legado: `ghcr.io/tadashiyukoyama/centraldeatendimentochat`.
- Namespace candidato: `ghcr.io/cesaryukoyama28-eng/centraldeatendimentochat`.
- Tags continuam sendo exclusivamente SHAs Git completos de 40 caracteres.

## Estado seguro durante a migração

- A imagem ativa e o marcador de produção permanecem no namespace legado.
- O pacote legado permanece disponível para rollback.
- O workflow de build usa `GITHUB_TOKEN`, com `packages: write`, e publica a
  imagem candidata vinculada ao repositório pelo rótulo
  `org.opencontainers.image.source`.
- Builds de produção são manuais. Pull requests continuam validando a imagem
  sem publicá-la.
- Nenhum deploy, migration de banco ou reinício de serviço faz parte deste
  gate.

## Gate de publicação

1. Validar workflow, Dockerfile, contratos e ausência de credenciais.
2. Publicar uma única imagem para o SHA aprovado por `workflow_dispatch`.
3. Registrar run ID, SHA e digest retornado pelo Buildx.
4. Preservar a visibilidade pública usada pelo pacote anterior.
5. Validar manifesto e pull sem alterar o container ativo.

## Gate posterior de produção

A troca do marcador ativo exige uma entrega separada. Ela deve adaptar os
contratos de deploy e rollback para aceitar explicitamente os namespaces novo e
legado, observar o marcador real da VPS, validar backup PostgreSQL e manter a
imagem anterior como rollback. Falha em qualquer preflight encerra o corte sem
alterar produção.
