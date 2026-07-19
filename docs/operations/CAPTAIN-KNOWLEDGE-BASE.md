# Captain knowledge base

## Fonte analisada

A curadoria foi feita a partir do documento `AIFOODMANAGER Dossiê completo de
funcionalidades`, armazenado como documento do Captain. O dossiê tem 25 páginas
e descreve a operação de atendimento, reservas, mesas, fila, clientes, eventos,
conteúdo público, Meta, Telegram e personalizações.

O documento também diferencia três estados importantes:

- disponível no produto;
- configurável ou dependente de credenciais e permissões externas;
- customização ou integração a ser desenhada.

Essa distinção é obrigatória para evitar que uma descrição comercial vire uma
promessa de funcionalidade ativa.

## Conteúdo aprovado

O arquivo versionado
`config/captain/knowledge/aifood_manager_faqs.yml` contém a fonte de revisão
dos FAQs. Ele cobre:

- posicionamento e benefícios operacionais;
- mesas, reservas e regras de capacidade;
- central multicanal e assistente de IA;
- chat do site;
- Instagram, campanhas de comentários e DM;
- WhatsApp Meta e requisitos de ativação;
- Telegram do gerente;
- setores, handoff e implantação;
- personalização e limites do escopo.

Foi incluída uma resposta explícita para estoque, compras, caixa, cozinha,
delivery e PDV. Esses itens aparecem no dossiê como customização ou integração,
portanto permanecem fora das promessas de módulo transacional pronto.

## Conteúdo deliberadamente não aprovado

Não participam do `faq_lookup` as descrições que poderiam induzir o Captain a
afirmar, sem validação local:

- capacidades transacionais não confirmadas;
- capacidades mobile não validadas no ambiente atual;
- Agent SDK e ferramentas de mutação que não estejam instaladas no Captain;
- critérios de aceite, checklist interno e detalhes de infraestrutura;
- capacidades futuras ou dependentes de contrato ainda não fechado.

## Processo de atualização

1. Atualizar a fonte YAML e registrar a origem da afirmação.
2. Revisar a resposta para limitar escopo, pré-requisitos e condição de ativação.
3. Aplicar a curadoria com `scripts/revise_captain_knowledge_base.rb` em ambiente
   controlado.
4. Validar semanticamente as respostas aprovadas e confirmar que conteúdo antigo
   não aprovado está `pending`.
5. Executar smoke de uma pergunta de produto, uma pergunta fora do escopo, uma
   pergunta de canal e um handoff.

Nenhuma alteração de FAQ deve ser feita diretamente na produção sem passar por
esse fluxo versionado.
