# Campanhas WhatsApp por QR Code/Evolution

## Contrato do canal

Campanhas de caixas `Channel::Whatsapp` com `provider=evolution` usam mensagens
comuns do WhatsApp Web. Não usam templates Meta e não aplicam a janela oficial
de 24 horas. As caixas `whatsapp_cloud` continuam seguindo integralmente as
regras da API oficial e o fluxo de templates existente.

O sistema não tenta disfarçar automação nem contornar mecanismos de proteção do
provedor. O administrador escolhe um intervalo fixo entre 4 e 45 minutos. Essa
cadência existe para controle operacional, capacidade e auditoria; não é uma
garantia contra bloqueios do WhatsApp.

## Público e importação

Os leads são contatos nativos da conta. A importação fica em **Contatos >
Importar** e aceita o CSV padrão do produto. A coluna `labels` deve usar uma
etiqueta previamente criada na conta; essa etiqueta seleciona o público da
campanha.

Cada destinatário precisa ter:

- nome;
- telefone em formato internacional;
- uma das etiquetas selecionadas;
- consentimento ou outra base legal aplicável, cuja confirmação é obrigatória
  no agendamento.

Contatos bloqueados, sem nome, sem telefone ou com
`whatsapp_marketing_unsubscribed=true` entram no snapshot, mas são marcados
como `skipped` com o motivo. Assim, a contagem permanece auditável.

## Personalização e variações

A mensagem principal e cada variação precisam conter `{{contact.name}}`. É
possível cadastrar até três versões. A distribuição A/B é determinística pelo
par campanha-contato, de modo que reprocessamentos escolhem sempre a mesma
versão. Não há geração automática de saudações nem sorteio de conteúdo.

Toda mensagem recebe a orientação para responder `SAIR`. Uma resposta cujo
texto seja exatamente `SAIR` (com variação de maiúsculas, espaços e pontuação
final simples) grava o descadastro no contato. Frases normais de suporte, como
“quero cancelar minha reserva”, não são interpretadas como descadastro.

## Filas e rastreabilidade

Ao disparar, o serviço cria um snapshot idempotente em `campaign_deliveries`.
Cada entrega possui contato, campanha, horário programado, status, erro,
horário de processamento e conversa. A chave única
`(campaign_id, contact_id)` impede duplicação.

Um job independente é agendado por entrega na fila `low`; nenhum worker fica
bloqueado com `sleep`. O serviço cria uma conversa e uma mensagem individual,
que seguem pelo pipeline nativo da Evolution. O estado `queued` significa que
a mensagem entrou nesse pipeline, não que o destinatário a recebeu. Os estados
reais de `Message` (`sent`, `delivered`, `read` ou `failed`) continuam vindo dos
webhooks da Evolution.

## Deploy, rollback e smoke

A coluna `campaign_deliveries.scheduled_for` é aditiva. O deploy exige backup
PostgreSQL validado e imagem identificada pelo SHA completo. O rollback de
código pode manter a coluna sem uso; sua remoção é uma operação de banco
separada.

O smoke usa uma etiqueta exclusiva com um único número controlado. Deve
comprovar:

1. caixa Evolution disponível no formulário;
2. ausência de seletor de template para essa caixa;
3. rejeição de intervalo fora de 4–45 minutos e de mensagem sem
   `{{contact.name}}`;
4. criação de uma única entrega, conversa e mensagem personalizada;
5. envio fora da janela Meta de 24 horas;
6. resposta `SAIR` registrando o descadastro;
7. nova campanha marcando o mesmo contato como `skipped`;
8. nenhuma alteração no comportamento de caixas `whatsapp_cloud`.
