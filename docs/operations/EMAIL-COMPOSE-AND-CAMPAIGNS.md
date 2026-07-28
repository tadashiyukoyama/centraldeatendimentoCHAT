# E-mail: composição e campanhas individualizadas

Este documento define o contrato operacional das funções de e-mail do
AceleraChat. O transporte continua sendo a caixa `Channel::Email` e o SMTP
global já configurado; esta frente não cria um segundo serviço de e-mail.

## Novo e-mail

Em uma caixa de entrada de e-mail, a ação **Novo e-mail** abre o compositor
nativo com a própria caixa previamente selecionada. O operador escolhe o
contato principal e pode informar:

- destinatários adicionais em `Para`;
- assunto, cópia e cópia oculta;
- corpo da mensagem;
- anexos pelo fluxo de upload já existente.

Os endereços em `Para` são normalizados e deduplicados sem diferenciar
maiúsculas de minúsculas. A conversa fica vinculada ao contato principal e
cada envio gera uma mensagem rastreável dentro dessa conversa.

## Campanhas de e-mail

Campanhas são administradas em **Campanhas > E-mail** e são restritas a
administradores da conta. Não existe uma operação literal e irrestrita de
“enviar para todos”. O público é selecionado por uma ou mais etiquetas da
própria conta, e o administrador precisa confirmar a base legítima/permissão
antes de agendar.

O agendador cria um snapshot idempotente em `campaign_deliveries`. Cada
contato elegível recebe:

- uma entrega própria;
- uma conversa própria;
- uma mensagem própria, processada com Liquid;
- um link assinado de descadastro.

Contatos bloqueados, sem e-mail ou já descadastrados não recebem a mensagem.
O processamento usa a fila `low`, com intervalo de dois segundos entre
entregas, e a chave única `(campaign_id, contact_id)` impede duplicação.

Os estados expostos são `pending`, `processing`, `queued`, `skipped` e
`failed`. **Queued significa que a mensagem foi criada e entregue ao pipeline
assíncrono; não é confirmação de entrega pelo servidor do destinatário.**

Campanhas não aceitam anexos nesta versão. Para um envio com anexo, deve-se
usar **Novo e-mail**. A inclusão segura de anexos em campanhas exige um
contrato separado de retenção, tamanho e reutilização de blobs.

## Descadastro

Cada mensagem de campanha contém uma URL assinada em
`/email/unsubscribe/:token`. O link abre uma confirmação e somente o `POST`
registra:

- `email_unsubscribed=true`;
- `email_unsubscribed_at=<timestamp ISO 8601>`.

O token não contém uma credencial de acesso à conta e só resolve o contato
assinado. Tokens inválidos retornam `404`. O descadastro afeta campanhas de
e-mail posteriores daquela conta; mensagens operacionais individuais
continuam disponíveis ao agente.

## Banco, deploy e rollback

A migration `20260728120000_create_campaign_deliveries.rb` é aditiva. O deploy
deve seguir `PRODUCTION-DEPLOYMENT.md`, incluindo backup PostgreSQL validado
antes de `db:chatwoot_prepare`.

O rollback normal troca Rails e Sidekiq para a imagem anterior, conforme
`PRODUCTION-ROLLBACK.md`. A tabela aditiva pode permanecer sem uso pela imagem
anterior. Ela não deve ser removida durante a janela de rollback. Restaurar ou
reverter schema exige uma operação de banco separada e autorização explícita.

## Smoke controlado

Após o deploy:

1. confirmar `/health` e a revisão ativa;
2. abrir uma caixa de e-mail e validar **Novo e-mail**;
3. validar assunto, destinatários adicionais e seleção de anexo sem enviar a
   terceiros;
4. abrir **Campanhas > E-mail**;
5. criar, quando houver um contato de teste autorizado, uma etiqueta exclusiva
   com um único destinatário controlado;
6. confirmar uma única `campaign_delivery`, uma conversa, uma mensagem e o
   estado `queued`;
7. validar o link de descadastro e que uma nova campanha marca o contato como
   `skipped`;
8. verificar filas, logs e Sentry sem expor conteúdo ou credenciais.

Nenhum smoke pode usar uma etiqueta de clientes reais ou disparar envio em
massa.
