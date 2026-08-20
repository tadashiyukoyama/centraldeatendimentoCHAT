# Transferência do repositório — 2026-08-20

## Escopo

- Origem: `tadashiyukoyama/centraldeatendimentoCHAT`.
- Destino: `cesaryukoyama28-eng/centraldeatendimentoCHAT`.
- Visibilidade preservada: pública.
- Branch padrão preservada: `main`.
- SHA anterior e imediatamente posterior à transferência:
  `afa6f92f59c0a428b63d5c3c1e18a824064aa194`.

## Evidências

- O GitHub preservou o histórico Git e redireciona a URL anterior.
- O environment `production`, seus cinco secrets e suas sete variables foram
  preservados. Somente os nomes foram auditados; nenhum valor foi exposto.
- O runner `vps10056-acelerachat` permaneceu online e executou com sucesso o
  smoke isolado `32339747299` após a transferência.
- O contrato do runner aceita o nome `systemd` legado preservado pela
  transferência e usa o nome do novo proprietário em instalações futuras.
- Nenhum deploy, migration ou alteração de produção foi executado.

## Gate GHCR

O pacote público existente continua em
`ghcr.io/tadashiyukoyama/centraldeatendimentochat`. O GitHub Container Registry
usa escopo próprio e não migra automaticamente esse namespace junto com o
repositório. Por isso, as referências da imagem e os contratos de
deploy/rollback permanecem deliberadamente no namespace antigo até uma
migração de imagem separada, com nova publicação, validação de pull e janela de
rollback. A transferência do código não autoriza esse corte.

## Rollback

Uma transferência aceita não possui rollback automático. A reversão de
proprietário exige uma nova transferência. O código e a imagem atualmente ativa
permanecem recuperáveis pelos SHAs e pelo namespace GHCR registrados acima.
