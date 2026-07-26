# Captain response contract

Este documento define o comportamento operacional do Captain no AI Food Manager
Pro. A regra é implementada no runtime e complementada pelo estado estruturado
entregue ao agente; não depende de o modelo inferir regras a partir de exemplos.

## Mensagem respondível

O Captain só pode ser acionado quando a conversa está `pending` e o evento é uma
mensagem pública recebida de um `Contact`. Mensagens privadas, atividades,
resumos, templates e mensagens enviadas por um atendente ou pelo próprio Captain
são contexto, não são solicitações do cliente.

O assistente canônico deve estar associado a cada inbox da conta por
`CaptainInbox`. A configuração falha se um inbox já estiver associado a outro
assistente; não há fallback silencioso para um agente diferente.

O histórico usado pelo Captain começa depois da última atividade de resolução da
conversa. Isso impede que um pedido de atendimento humano de um episódio antigo
seja reutilizado quando o cliente inicia um novo episódio apenas com uma
saudação.

## Origem do lead

A origem é calculada por `Captain::Conversation::OriginResolver` e persistida em
`conversation.additional_attributes['captain_origin']` antes da geração da
resposta. O modelo recebe o valor já calculado, mas nunca é responsável por
deduzi-lo ou alterá-lo.

| Valor | Regra determinística |
| --- | --- |
| `campaign` | A conversa tem `campaign_id` ou uma mensagem de saída com `campaign_id`. |
| `link` | A conversa nasceu em um inbox `Website` do widget do site. |
| `spontaneous` | Qualquer conversa sem evidência das duas origens acima. |

O valor é persistido na conversa para manter o roteamento estável; a precedência
determinística evita que uma resposta posterior altere a origem registrada. O
referer continua disponível para diagnóstico, mas não é interpretado
semanticamente pelo prompt. Essa separação permite auditar a origem sem depender
do texto do cliente.

## Saudação

`Captain::Conversation::GreetingPolicy` identifica, no código, quando a última
mensagem do contato é apenas uma saudação. Nessa situação:

- uma conversa espontânea recebe uma saudação neutra e uma pergunta aberta sobre
  como o atendimento pode ajudar;
- uma conversa de campanha reconhece a campanha e pergunta sobre o interesse do
  contato;
- uma conversa originada pelo site reconhece o contato pelo site e pergunta o
  que ele procura;
- o Captain não começa perguntando se a pessoa possui restaurante, bar ou
  pizzaria.

Se a mensagem já contém uma intenção, a política de saudação não se aplica e o
agente segue o fluxo de entendimento da intenção.

## Base de conhecimento e limite do produto

A fonte revisável dos FAQs é:

```text
config/captain/knowledge/aifood_manager_faqs.yml
```

A aplicação da curadoria é reproduzível por:

```text
scripts/revise_captain_knowledge_base.rb
```

Somente respostas `approved` dessa fonte participam do `faq_lookup`. O dossiê do
AI Food Manager confirma atendimento multicanal, reservas, mesas, fila,
clientes/CRM, eventos, conteúdo do site, Instagram, WhatsApp Meta, Telegram e
chat do site. O mesmo dossiê classifica estoque, compras, caixa, cozinha,
delivery e PDV como customização ou integração a avaliar, não como módulos
transacionais que possam ser prometidos pelo Captain.

Quando a base não confirmar uma capacidade, o agente deve dizer que não pode
confirmá-la e encaminhar para uma pessoa quando o contato estiver bloqueado. É
proibido inventar preço, prazo, estoque, integração, disponibilidade ou
funcionalidade.

## Classificação do lead

As únicas etiquetas de ciclo comercial são:

- `cliente`: cliente existente ou solicitação de suporte de uma operação ativa;
- `lead_morno`: descoberta, dúvidas ou interesse sem sinal claro de compra;
- `lead_quente`: preço, plano, proposta, contratação, demonstração ou aceitação
  de uma oferta de especialista.

`Captain::Conversation::LeadClassificationService` valida sinais do último
contato no servidor. A classificação é monotônica dentro do episódio: um
`lead_quente` não volta para `lead_morno` por uma resposta posterior do modelo.
Um agendamento concluído pela ferramenta é um sinal confiável de `lead_quente`,
mesmo quando a última mensagem do contato é apenas a aceitação de uma oferta.

## Perfil, agenda e financeiro

As ferramentas operacionais são documentadas em
`docs/operations/CAPTAIN-OPERATIONAL-TOOLS.md`.

Dados de perfil só podem ser gravados quando aparecem explicitamente no episódio
atual. A agenda exige aceite, perfil completo, data com fuso e ausência de
conflito. Um aviso de pagamento nunca equivale a confirmação bancária: começa
como pendente e deve ser validado pelo financeiro ou por uma fonte integrada.

## Handoff

O handoff é fail-closed. A ferramenta conclui a transferência quando a última
mensagem:

- pede atendimento humano, especialista ou um setor;
- apresenta um sinal comercial explícito; ou
- aceita uma oferta de handoff feita na mensagem pública anterior do Captain,
  como “ok”, “sim” ou “pode ser”.

Uma saudação isolada ou um “ok” sem oferta anterior nunca causa transferência.
Uma tentativa recusada pela validação não é registrada como handoff concluído e
não aciona fallback de transferência.

Destinos suportados: `owner`, `financeiro`, `contas_a_pagar`, `rh`, `gerencia`,
`representante` e `suporte`. Depois que a ferramenta conclui o handoff, a
conversa passa a ser responsabilidade humana e o Captain não envia nova
resposta até que o episódio seja reaberto para a automação.

## Conversas iniciadas por template

O job de resolução por inatividade só considera uma conversa quando a última
mensagem pública do episódio é recebida do contato. Se o último evento público é
um template ou outra mensagem de saída, a conversa permanece aguardando o
cliente e não é avaliada pelo Captain.

## Alterações obrigatórias

Qualquer mudança no prompt, FAQ, origem, classificação, handoff ou critério de
mensagem respondível exige:

1. atualização deste contrato ou do documento de conhecimento correspondente;
2. teste automatizado do comportamento alterado;
3. validação de `git diff --check` e dos checks do workspace;
4. smoke controlado em cada canal afetado antes de considerar a mudança ativa.
