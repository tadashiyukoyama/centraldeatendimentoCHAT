# Captain response contract

## Mensagem respondível

O Captain só pode ser acionado quando a conversa está `pending` e o evento é uma
mensagem pública recebida de um `Contact`. Mensagens privadas, atividades,
resumos, templates e mensagens enviadas por um atendente ou pelo próprio Captain
são contexto, não são solicitações do cliente.

## Limite de contexto

O histórico usado pelo Captain começa depois da última atividade de resolução da
conversa. Isso impede que um pedido de atendimento humano de um episódio antigo
seja reutilizado quando o cliente inicia um novo episódio apenas com “olá”.

## Handoff

O handoff é fail-closed. A ferramenta só conclui a transferência quando a última
mensagem recebida contém um pedido explícito de atendimento humano, setor ou
especialista, ou um sinal comercial explícito como preço, proposta, contratação
ou demonstração. Uma saudação curta nunca pode causar transferência.

Uma tentativa recusada pela validação não é registrada como handoff concluído e
não pode acionar o fallback de transferência do job.

## Conversas iniciadas por template

O job de resolução por inatividade só considera uma conversa quando a última
mensagem pública do episódio é recebida do contato. Se o último evento público é
um template ou outra mensagem de saída, a conversa permanece aguardando o
cliente e não é avaliada pelo Captain.

## Base de conhecimento

As respostas derivadas do dossiê são aprovadas somente quando são úteis e
compatíveis com o runtime atual. Conteúdo interno, mobile não validado,
capacidades futuras, contratos técnicos e critérios de QA permanecem pendentes e
não participam do FAQ lookup.

A curadoria é reproduzível por:

```text
scripts/revise_captain_knowledge_base.rb
```
