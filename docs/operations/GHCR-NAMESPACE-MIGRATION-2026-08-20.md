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

Publicação concluída:

- SHA: `392b78d65b103171c3e4b8d9a823e159af092376`.
- Digest OCI: `sha256:672e739e6f621f833fff835a0af47d42d3b720590c8832bc91d45c737dc14140`.
- Run: `32343503639`.
- Pacote público, associado ao repositório novo, com manifesto e 15 blobs
  validados anonimamente.

## Gate posterior de produção

A troca do marcador ativo usa um repositório GHCR explícito e limitado aos
namespaces novo e legado. O marcador antigo continua válido durante o corte;
deploys novos apontam para o namespace AceleraChat e o workflow de rollback
exige a escolha explícita do namespace. Ambos os pulls são anonimamente
validados antes de qualquer operação stateful. O gate também observa o marcador
real da VPS, valida backup PostgreSQL e mantém a imagem anterior como rollback.
Falha em qualquer preflight encerra o corte sem alterar produção.
