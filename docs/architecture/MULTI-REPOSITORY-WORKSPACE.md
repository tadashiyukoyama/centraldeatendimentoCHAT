# Workspace multi-repositório

```text
<workspace-root>/
├── server/  -> tadashiyukoyama/centraldeatendimentoCHAT
└── mobile/  -> reservado para tadashiyukoyama/centraldeatendimentoCHAT-mobile
```

O upstream do servidor é `chatwoot/chatwoot`; o upstream futuro do mobile é
`chatwoot/chatwoot-mobile-app`. Cada diretório terá seu próprio `.git` quando
o mobile for autorizado e clonado. O diretório `mobile/` atual não possui `.git`.

## Coordenação

- Alterações de API devem ser revisadas nos dois contratos antes do merge.
- O servidor e o mobile podem ter ciclos de release diferentes, mas a API deve preservar compatibilidade durante a janela acordada.
- CI do servidor não deve baixar ou instalar o mobile automaticamente.
- Builds mobile e seus APKs/AABs ficam fora do clone em `artifacts/apk/`.
- Segredos de assinatura, tokens de push e envs ficam em `private/` ou secret store.
- O Codex deve documentar qualquer mudança cross-repository em ADR ou runbook.
