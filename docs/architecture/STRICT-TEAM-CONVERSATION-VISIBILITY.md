# Visibilidade rígida de conversas por equipe

Este documento define a fronteira de autorização usada quando vários setores
atendem pelo mesmo número e pela mesma caixa de entrada.

## Objetivo

Uma caixa compartilhada continua representando o único número do canal. A
equipe atribuída à conversa passa a ser uma fronteira de autorização no
servidor, e não apenas um filtro da interface.

A regra é ativada por conta pela feature
`strict_team_conversation_visibility`. Ela permanece desativada por padrão
para não mudar silenciosamente o comportamento de outras contas.

## Regra de acesso

Administradores da conta continuam com acesso integral. Um agente precisa ter
acesso à caixa da conversa e satisfazer pelo menos uma destas condições:

- pertencer à equipe atribuída à conversa;
- ser o responsável atribuído diretamente;
- ser participante explícito da conversa.

Uma conversa sem equipe, responsável ou participante fica visível somente
para administradores. A autoatribuição não escolhe um agente para uma conversa
sem equipe enquanto a regra rígida estiver ativa.

Participação explícita é o mecanismo de colaboração entre setores. A remoção
da equipe, do responsável, da participação ou do acesso à caixa revoga o
acesso do agente.

## Superfícies protegidas

A mesma regra é aplicada a:

- política de abertura direta da conversa;
- listagens, filtros, contagens e ações em lote;
- busca de conversas, mensagens e contatos;
- histórico e anexos do contato;
- contagens de não lidas;
- notificações, presença de contatos e eventos Action Cable;
- ferramentas de conversa e contato do Copilot;
- atribuição manual, automações e autoatribuição.

Contatos são visíveis para agentes somente quando existe pelo menos uma
conversa visível associada. Contatos ainda sem conversa ficam disponíveis
somente para administradores. Relatórios e exportações globais permanecem
restritos a administradores quando a regra está ativa.

Webhooks e integrações server-side da conta não são usuários humanos e não são
filtrados por equipe. Eles devem continuar sendo administrados como
credenciais privilegiadas da conta.

A feature `channel_voice` deve permanecer desativada nesta fase. Qualquer
reativação futura de chamadas exige uma revisão específica dos streams de voz
antes de ser considerada compatível com esta fronteira.

## Pré-requisitos operacionais

Antes da ativação:

1. cadastrar cada agente na caixa do número compartilhado;
2. cadastrar cada agente somente nas equipes dos setores que pode atender;
3. garantir que cada conversa aberta destinada a atendimento humano tenha uma
   equipe, um responsável direto ou um participante;
4. manter administradores como fila de triagem das conversas ainda sem setor;
5. validar transferência nos dois sentidos com dois usuários agentes reais.
6. orientar os agentes a recarregar a aplicação imediatamente após a ativação
   ou o rollback da feature.

O handoff do Captain atribui a equipe e deixa o responsável vazio. Portanto,
os agentes do setor precisam pertencer simultaneamente à equipe e à caixa.

## Ativação e rollback

A ativação é feita somente depois do deploy versionado e da validação dos
pré-requisitos:

```bash
STRICT_TEAM_ACCOUNT_ID=1 bundle exec rails runner \
  "Account.find(ENV.fetch('STRICT_TEAM_ACCOUNT_ID')).enable_features!('strict_team_conversation_visibility')"
```

Rollback imediato da regra:

```bash
STRICT_TEAM_ACCOUNT_ID=1 bundle exec rails runner \
  "Account.find(ENV.fetch('STRICT_TEAM_ACCOUNT_ID')).disable_features!('strict_team_conversation_visibility')"
```

O rollback restaura o comportamento anterior de visibilidade por caixa. Ele
não altera equipes, responsáveis, participantes ou mensagens.

## Teste de aceitação

Usar dois agentes, cada um pertencente a apenas uma equipe, e um administrador:

1. encaminhar uma conversa para o primeiro setor;
2. confirmar que o primeiro agente consegue listar, abrir, buscar e responder;
3. confirmar que o segundo agente não encontra a conversa por lista, URL
   direta, busca, contato, anexo, não lidas ou Copilot;
4. transferir a conversa para o segundo setor;
5. confirmar que o primeiro agente perde o acesso e que o segundo passa a
   receber os eventos e responder;
6. adicionar o primeiro agente como participante e confirmar o
   compartilhamento explícito;
7. remover a participação e confirmar a revogação;
8. confirmar que o administrador mantém acesso durante todo o fluxo.
