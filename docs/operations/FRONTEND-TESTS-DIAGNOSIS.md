# Diagnóstico do frontend-tests

## Evidência observada

- Run remoto da PR: `29563348750`.
- Job: `frontend-tests`, ID `87830390554`.
- Workflow: `Run Chatwoot CE spec`.
- `lint-frontend`: sucesso.
- `frontend-tests`: falha no passo `Run frontend tests`.
- Resultado: 2 testes falhos, 376/377 arquivos aprovados e 3738/3740 testes
  aprovados.

## Causa técnica observada

O teste
`app/javascript/dashboard/routes/dashboard/onboarding/specs/inbox-setup/InboxChannelsDialog.spec.js`
mocka `dashboard/composables/store` com apenas `useMapGetter`. A montagem do
componente percorre `useChannelConfig.js` e `useAccount.js`; `useAccount.js`
importa e chama `useStore`. O Vitest encerra a montagem com:

```text
[vitest] No "useStore" export is defined on the "dashboard/composables/store" mock.
```

Os dois casos afetados são a abertura do picker do Facebook com `fbAppId` e a
exibição do grid sem `fbAppId`.

## Escopo e decisão

Os arquivos de produto envolvidos não foram modificados nesta correção e não
possuem diff contra a base autorizada. Portanto este documento registra um
diagnóstico, não uma correção de frontend. A correção futura deve ajustar o
mock do teste ou usar mock parcial preservando `useStore`, em tarefa de produto
separada e com validação própria.

O CI não foi reexecutado manualmente antes do novo commit. O novo commit deve
gerar a execução automática normal da PR.
