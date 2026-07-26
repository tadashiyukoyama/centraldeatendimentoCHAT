# Ferramentas operacionais dos agentes

## Contrato

As ferramentas fazem parte do catálogo global de `Captain::Assistant`, mas só
entram em um agente quando as flags `feature_contact_attributes`,
`feature_demo_scheduling` e `feature_payment_notices` correspondentes estão
ativas. Toda execução é limitada à conta, conversa e contato autoritativo da
conversa. Uma resposta do modelo nunca substitui o resultado da ferramenta.

Cada execução das ferramentas mutáveis gera um `Captain::ToolExecution` sem
copiar dados pessoais para o resumo de auditoria. Os registros de agenda e
financeiro possuem chave de idempotência e campos `external_provider` e
`external_id` para futura sincronização com CRM/ERP.

## Perfil do contato

`capture_contact_profile` grava nome, telefone, e-mail e empresa. Um valor novo
só é aceito se aparecer explicitamente nas mensagens recebidas do contato no
episódio atual. Telefones brasileiros locais podem ser normalizados para E.164
quando o país `BR` é conhecido; nos demais casos o código internacional é
obrigatório.

O contato passa a `lead` ou `customer` conforme a classificação canônica da
conversa. A ferramenta não mescla contatos automaticamente quando telefone ou
e-mail já pertencem a outro registro.

## Demonstração

`schedule_demo` exige:

- confirmação explícita do horário exato repetido pelo agente;
- nome, telefone e empresa já gravados;
- data futura em ISO 8601 com fuso;
- duração entre 10 e 120 minutos;
- especialista configurado ou administrador da conta;
- ausência de conflito na agenda.

O sucesso cria um compromisso real na agenda interna `Captain::Appointment`,
aplica `demo_agendada`, classifica como `lead_quente` por sinal confiável da
ferramenta e transfere a conversa ao especialista configurado. A mensagem
pública é resolvida a partir do registro criado. Até existir provedor externo,
essa agenda é interna e auditável; ela não deve ser apresentada como Google
Calendar, Outlook ou ERPNext.

## Financeiro

`record_payment_notice` registra apenas a declaração explícita da última
mensagem do cliente e sempre começa como `pending_verification`. Valor, moeda
não padrão e referência também precisam aparecer nessa mesma mensagem. Ele
aplica `pagamento_informado` e transfere para o time `financeiro`, ou para o
administrador quando o time não existe.

`lookup_payment_status` consulta o registro interno. O estado interno não é
confirmação bancária. Integrações futuras com ERPNext ou outro provedor devem
preencher `external_provider`, `external_id` e alterar o estado somente após uma
resposta autenticada e auditável.

## CRM recomendado

O alvo recomendado é Frappe CRM com ERPNext. A integração deve usar um usuário
de API dedicado, permissões mínimas, token armazenado de forma criptografada e
sincronização idempotente:

```text
Contato/conversa no AceleraChat
  -> lead/deal no Frappe CRM
  -> appointment no ERPNext
  -> consulta de fatura/pagamento no ERPNext
  -> resultado normalizado para a ferramenta do agente
```

Nenhuma ferramenta deve afirmar sincronização externa enquanto o provedor não
estiver configurado e não tiver retornado sucesso.
