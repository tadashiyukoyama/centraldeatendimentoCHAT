# Arquitetura mobile

## Estado atual

O mobile ainda não foi baixado. A pasta `mobile/` está reservada para o futuro
fork `cesaryukoyama28-eng/centraldeatendimentoCHAT-mobile`, que terá como upstream
`chatwoot/chatwoot-mobile-app`.

O servidor e o mobile serão repositórios Git diferentes no mesmo workspace. O
mobile não terá banco próprio nem cópia das conversas: consumirá a API do
servidor usando contratos compatíveis, autenticação apropriada e versionamento
de endpoints.

## Relações de contrato

- Dados de contas, contatos, conversas e mensagens permanecem no PostgreSQL do servidor.
- Filas, cache e jobs continuam no runtime do servidor.
- Alterações no frontend Vue não alteram automaticamente o React Native.
- Mudanças de API precisam manter compatibilidade ou incluir versionamento e migração coordenada.
- Uma funcionalidade mobile pode exigir mudanças no servidor e no mobile.
- Push notifications, uploads, autenticação e deep links devem ser tratados como contratos explícitos.
- Android gera APK/AAB somente em `artifacts/apk/`, fora do Git e após o disk guard.
- Chaves de assinatura nunca entram no Git, artifacts públicos ou logs.

## Invariantes

Não duplicar regra de negócio crítica no mobile. O servidor é a fonte de
verdade para autorização, estado de conversa, mensagens e integrações externas.
O mobile deve degradar de forma observável quando uma capacidade da API não
estiver disponível, sem inventar estado local como se fosse persistente.
