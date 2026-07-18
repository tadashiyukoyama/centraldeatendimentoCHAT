# Captain — fluxo padrão de atendimento e qualificação

Este documento define o comportamento padrão do Captain para o AI Food Manager
Pro nos canais conectados à conta. A configuração de produção é aplicada de
forma idempotente por `scripts/configure_captain_lead_routing.rb`.

## Modelo e esforço

- Modelo padrão do assistente: `gpt-5.4-mini`.
- Esforço de raciocínio: `low`.
- O identificador é o ID oficial da API; “GPT-5.4 Mini” é apenas o nome de
  exibição.
- O parâmetro é enviado pelo Agents SDK como `reasoning_effort: low` nas
  execuções do Captain V2.

## Fluxo de uma mensagem

1. Uma mensagem recebida em um inbox vinculado ao Captain mantém a conversa
   sob responsabilidade do Captain enquanto o status for `pending`.
2. O Captain responde em português do Brasil, consulta a base de conhecimento
   antes de afirmar fatos sobre o produto e faz perguntas curtas para entender
   a necessidade.
3. O Captain classifica a conversa com exatamente uma etiqueta de negócio:

   - `cliente`: cliente que já usa o produto ou solicita suporte sobre uma
     operação existente;
   - `lead_morno`: pessoa conhecendo a solução ou tirando dúvidas sem sinal
     claro de compra;
   - `lead_quente`: pergunta por preço, plano, proposta, contratação ou aceita
     uma demonstração.

4. Para `lead_quente`, o Captain chama o handoff com destino `owner`. A
   conversa fica aberta e atribuída ao primeiro administrador da conta.
5. Quando a pessoa pede um setor, o Captain chama o handoff com um destes
   destinos: `financeiro`, `contas_a_pagar`, `rh`, `gerencia`, `representante`
   ou `suporte`. A conversa fica aberta na equipe correspondente.
6. Depois de o handoff ser executado, o Captain não responde mais nessa
   conversa. Uma resposta humana ou a resolução da conversa encerra o silêncio
   do bot conforme o comportamento nativo do Chatwoot.

## Estado e roteamento

O handoff atribui o `owner` ao administrador da conta ou atribui a equipe
correspondente. A configuração das equipes é criada pelo script idempotente e
os administradores existentes são adicionados como membros para que possam
visualizar as conversas roteadas.

Os cenários antigos são preservados para auditoria, mas desativados durante a
configuração porque havia duplicidade de “Prospective Buyer”. A classificação e
o roteamento passam a ter uma única política no assistente principal.

## Aplicação

O código precisa ser incluído em uma imagem versionada e promovido pelo fluxo
de release autorizado. Depois que essa imagem estiver ativa, executar:

```bash
CAPTAIN_ACCOUNT_ID=1 bundle exec rails runner scripts/configure_captain_lead_routing.rb
```

A execução deve informar somente IDs, nomes de equipes/etiquetas e o modelo;
nenhuma chave, token ou valor de segredo deve aparecer no terminal ou em
relatórios.

## Teste de aceitação

Testar, em cada inbox ativo:

1. Saudação: o Captain responde e não transfere.
2. Dúvida sobre produto: responde após consultar a base e aplica `lead_morno`.
3. Pedido de preço ou demonstração: aplica `lead_quente`, envia o handoff e
   não responde à mensagem seguinte até a intervenção humana.
4. Pedido por financeiro ou suporte: atribui a equipe correspondente e deixa a
   conversa aberta.
5. Cliente existente: aplica `cliente` e continua respondendo enquanto não
   houver handoff.

Conversas já abertas antes da configuração não devem ser usadas como teste do
gatilho automático: elas precisam ser resolvidas ou devolvidas ao estado
`pending` pela interface antes de uma nova mensagem de teste.
