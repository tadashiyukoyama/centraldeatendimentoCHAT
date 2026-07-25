# Auditoria de transição completa para AceleraChat

## 1. Identificação e rastreabilidade

- Data da auditoria: 25 de julho de 2026.
- Repositório: `D:\dev\workspaces\centraldeatendimentoCHAT\server`.
- Branch auditada: `release/strict-team-conversation-privacy`.
- SHA-base: `2fb8bd4c69160fcd2140bbbb70f24e0b976b9674`.
- Produção inspecionada: `https://atendimento.meugerenciador.pro`.
- Escopo: inventário e plano de migração; nenhuma alteração funcional ou deploy faz parte desta auditoria.

Esta auditoria separa três conceitos:

1. **Marca pública:** AceleraChat.
2. **Assistente público:** Nemmo, substituindo apenas a apresentação de “Capitão”.
3. **Camada pública PRO:** “Enterprise” passa a ser apresentado como “PRO”, mas a pasta `enterprise/`, namespaces, tabelas, chaves e rotas internas permanecem inalterados.

## 2. Resumo executivo

A troca não se limita a logos e textos. O produto ainda contém dependências visíveis e operacionais da marca anterior em:

- configuração padrão de marca;
- interface principal, SuperAdmin, login e onboarding;
- Central de Ajuda e links contextuais;
- e-mails e remetentes;
- PWA, favicons, widget e imagens;
- termos, privacidade e exclusão de dados;
- telemetria, versão, changelog, suporte e licenciamento da camada PRO;
- apresentação pública e liberação da camada interna `enterprise/`;
- conteúdo do Captain, que será apresentado como Nemmo.

O caminho recomendado é uma migração em fases, com bloqueio explícito de tráfego para domínios antigos, testes de ausência de marca e um plano próprio de assinaturas e permissões PRO. A produção não deve ser renomeada parcialmente: o corte público deve ocorrer quando marca, links, e-mails, apoio e páginas legais estiverem disponíveis.

## 3. Evidência quantitativa

Inventário aproximado no código de runtime:

| Termo/domínio | `app` | `config` | `enterprise` | `lib` | Observação |
|---|---:|---:|---:|---:|---|
| `Chatwoot` | 1.026 arquivos | 68 | 43 | 17 | Inclui interface, traduções, mailers e classes internas |
| `chatwoot.com` | 187 arquivos | 3 | 3 | 1 | Links, remetentes, APIs e exemplos |
| `chwt.app` | 12 arquivos | 2 | 0 | 1 | Atalhos para documentação e páginas comerciais |
| `chatwoot.help` | 56 arquivos | 0 | 0 | 0 | Links de apoio, principalmente nas traduções |
| `Captain`/`captain` | 203/— | 58/— | 155/— | 15/— | O nome interno aparece milhares de vezes |

Inventário estrutural no repositório:

- referência literal a `enterprise/`: 80 ocorrências em 20 arquivos;
- namespace `Enterprise::`: 244 ocorrências em 148 arquivos;
- método `enterprise?`: 44 ocorrências em 24 arquivos;
- `IS_ENTERPRISE`: 4 ocorrências em 3 arquivos;
- `INSTALLATION_PRICING_PLAN`: 15 ocorrências em 8 arquivos;
- `Captain`: 3.264 ocorrências em 495 arquivos;
- `captain`: 4.840 ocorrências em 659 arquivos.

Conclusão: a varredura deve distinguir referências públicas, integrações operacionais, compatibilidade interna e avisos legais. Uma substituição global de texto quebraria rotas, traduções, tabelas, autoload, APIs e compatibilidade de dados.

## 4. Estado visível confirmado em produção

A inspeção autenticada confirmou:

- título de página “Chatwoot”;
- logo servido por `/brand-assets/logo_thumbnail.svg`;
- item de navegação “Capitão” e rotas `/captain/...`;
- rodapé com `v4.15.1 Build 2fb8bd4`;
- login do SuperAdmin com título `SuperAdmin | Chatwoot`;
- logos `logo.svg` e `logo_dark.svg` com texto alternativo “Chatwoot”.

O nome “AI Food Manager PRO” visto na conta é o nome da conta/cliente, não a marca da plataforma.

## 5. Marca e configuração

### 5.1 Configurações centrais

`config/installation_config.yml` concentra as configurações públicas que precisam receber valores AceleraChat:

- `INSTALLATION_NAME`;
- `LOGO_THUMBNAIL`;
- `LOGO`;
- `LOGO_DARK`;
- `BRAND_URL`;
- `WIDGET_BRAND_URL`;
- `BRAND_NAME`;
- `TERMS_URL`;
- `PRIVACY_URL`;
- `DISPLAY_MANIFEST`;
- `MAILER_SUPPORT_EMAIL`;
- opções de suporte e widget de atendimento.

O arquivo privado atual `private/env/chatwoot.production.env` não define o conjunto de marca nem os remetentes. Portanto, vários fallbacks ainda são os do produto anterior.

`app/javascript/shared/composables/useBranding.js` faz somente substituições exatas e sensíveis a maiúsculas de “Chatwoot” nos componentes que o chamam. Isso não limpa traduções, templates, e-mails, SuperAdmin ou conteúdo carregado fora desses componentes.

`app/javascript/shared/components/Branding.vue` monta o “powered by” com nome, logo e URL configuráveis. Ele deve apontar exclusivamente para AceleraChat e ser testado no widget, portal e pesquisa de satisfação.

### 5.2 Vocabulário aprovado

| Atual | Destino público | Tratamento interno inicial |
|---|---|---|
| Chatwoot | AceleraChat | Renomear apresentação e integrações; preservar apenas referências técnicas/licenças inevitáveis até revisão |
| Captain/Capitão | Nemmo | Manter classes, tabelas e rotas internas `Captain`/`captain` nesta etapa |
| Enterprise | PRO | Manter pasta `enterprise/`, namespace `Enterprise::`, contratos, tabelas e chaves internas |
| Community | Plano base, se existir | Definir na nova matriz comercial |

Não deve haver na interface termos como “Enterprise edition”, “Community Support” ou instruções para adquirir planos externos.

## 6. Imagens e identidade visual

O pacote visual deve ser produzido antes do corte:

- logo horizontal claro em SVG;
- logo horizontal escuro em SVG;
- símbolo quadrado/thumbnail em SVG;
- versões monocromáticas;
- favicon 16, 32, 96 e 512;
- ícones Android e Apple Touch;
- tiles Microsoft 70, 144, 150 e 310;
- ícone e cores do PWA;
- avatar/bot do sistema;
- logo do widget;
- imagens de login, onboarding, SuperAdmin e e-mails;
- imagem Open Graph e social;
- identidade visual própria do Nemmo e seus estados vazios.

Locais principais a substituir:

- `public/brand-assets/logo.svg`;
- `public/brand-assets/logo_dark.svg`;
- `public/brand-assets/logo_thumbnail.svg`;
- `app/javascript/design-system/images/`;
- `app/javascript/widget/assets/images/logo.svg`;
- `app/javascript/dashboard/assets/images/`;
- `public/assets/images/`;
- `public/assets/images/dashboard/captain/logo.svg`;
- `public/manifest.json`;
- `public/browserconfig.xml`;
- favicons e famílias Apple/Android/Microsoft em `public/`.

`public/manifest.json` ainda contém nome “Chatwoot” e a cor azul `#1f93ff`. Foram encontrados também arquivos Apple Touch vazios; devem ser removidos ou regenerados corretamente.

## 7. Links que precisam ser trocados

### 7.1 Ajuda contextual

`app/javascript/dashboard/helper/featureHelper.js` contém atalhos diretos `chwt.app` para:

- agentes e bots;
- auditoria;
- campanhas;
- respostas prontas;
- e-mail e Facebook;
- atributos personalizados;
- dashboard apps;
- Central de Ajuda;
- caixas de entrada;
- integrações;
- etiquetas;
- macros;
- relatórios;
- SLA;
- equipes;
- webhooks;
- preços;
- SAML;
- Captain/Nemmo, documentos e cobrança.

`config/features.yml` repete links de ajuda para e-mail, Facebook, Central de Ajuda, bots, equipes, etiquetas, atributos, respostas prontas, integrações, campanhas, relatórios e SLA.

Cada link deve apontar para um artigo AceleraChat existente. Não se deve substituir por uma página inicial genérica, pois isso reduz a utilidade do apoio contextual.

### 7.2 Outros endpoints antigos

- `app/javascript/shared/constants/links.js`: changelog em `hub.2.chatwoot.com/changelogs`;
- `SidebarProfileMenu.vue`: guia do usuário e changelog antigos;
- `SidebarChangelogCard.vue`: blog antigo;
- `dashboard/constants/globals.js`: documentação, Central de Ajuda, depoimentos e status antigos;
- estados vazios do Captain: assistant, document, FAQ e tools;
- campanhas: exemplos, preços, chatbot e avaliação externa;
- migração de WhatsApp: `chwt.app/migrate-whatsapp`;
- validação de identidade do live chat: documentação antiga;
- signup/traduções: termos e privacidade antigos;
- configuração Microsoft: guia de desenvolvimento antigo;
- scripts legados de deployment: comunidade, documentação, versão, hub e migração;
- serviço de teste de push: fallback `app.chatwoot.com`.

Links obrigatórios de terceiros, como políticas da Meta, WhatsApp, Twilio ou TikTok, não devem ser mascarados. Apenas links de primeira parte devem migrar para AceleraChat.

## 8. Central de Ajuda AceleraChat

Recomendação de domínio: `ajuda.<domínio-acelerachat>`. O domínio definitivo ainda precisa ser aprovado.

### 8.1 Conteúdo essencial da primeira publicação

**Primeiros passos e administração**

- criar conta, entrar, recuperar senha e MFA;
- criar e gerenciar usuários;
- papéis: administrador, gerente e agente;
- equipes/setores e privacidade rígida;
- caixas de entrada e atribuição;
- transferência de conversa e responsável;
- contatos, empresas, etiquetas e atributos;
- respostas prontas, macros e automações.

**Canais**

- WhatsApp por QR/Evolution: conectar, reconectar, atribuir setor, segurança, limitações e risco de bloqueio;
- diferença entre a janela de 24 horas da API oficial e o canal QR;
- WhatsApp oficial, se continuar disponível, em documentação separada;
- e-mail, Facebook, Instagram, Telegram, LINE, SMS e live chat conforme os canais realmente ofertados.

**Operação**

- campanhas;
- relatórios;
- CSAT (pesquisa de satisfação do cliente);
- SLA;
- logs de auditoria;
- integrações, dashboard apps, webhooks e API;
- backup, restauração e atualização;
- exportação e exclusão de dados;
- status, incidentes e notas de versão.

**Nemmo**

- visão geral e criação de assistente;
- base de conhecimento/documentos;
- perguntas frequentes e cenários;
- ferramentas e APIs reais;
- transferência para atendimento humano;
- permissões, privacidade e limites;
- créditos/cobrança, se aplicável;
- diagnóstico e solução de problemas.

**Comercial**

- planos, assentos e recursos;
- assinatura recorrente;
- notas fiscais/faturas;
- alteração, cancelamento e reembolso;
- autoprovisionamento e acesso à instância;
- canais de suporte e prazos.

## 9. Páginas institucionais e operacionais

Estrutura recomendada:

- `www.<domínio>`: produto, recursos, planos, contato e confiança;
- `app.<domínio>`: aplicação;
- `ajuda.<domínio>`: documentação e abertura de chamados;
- `status.<domínio>`: disponibilidade e incidentes, em infraestrutura separada;
- `control.<domínio>`: assinaturas, instâncias e licenças PRO.

Páginas públicas necessárias:

- início/produto;
- recursos e canais;
- planos e preços;
- contato e suporte;
- segurança/Trust Center;
- status;
- changelog/notas de versão;
- requisitos técnicos e disponibilidade;
- login e cadastro;
- portal do cliente, cobrança e instâncias.

## 10. Páginas legais e LGPD

Os textos finais devem ser revisados por advogado de privacidade e/ou encarregado de dados. A auditoria técnica identificou a necessidade de:

1. **Termos de Uso/Serviço:** conta, uso aceitável, propriedade intelectual, responsabilidades, disponibilidade, suspensão, encerramento, cobrança, cancelamento, reembolso e foro.
2. **Aviso de Privacidade/LGPD:** controlador e operador, categorias de dados, finalidades e bases legais, retenção, compartilhamento, subprocessadores, transferências internacionais, segurança, cookies, Nemmo/IA, direitos e contato do encarregado.
3. **Política de Cookies:** categorias, duração e preferência/consentimento quando houver rastreadores opcionais.
4. **Exclusão de conta:** procedimento do administrador do cliente para encerrar a conta SaaS.
5. **Solicitação do titular:** confirmação, acesso, correção, anonimização, bloqueio, exclusão, portabilidade, informação sobre compartilhamento e revogação.
6. **Política de retenção e backups:** tabela interna por categoria e resumo público.
7. **DPA/Contrato de Operador:** obrigações entre AceleraChat e clientes empresariais.
8. **Lista de subprocessadores:** hospedagem, e-mail, pagamentos, IA, logs, canais e suporte.
9. **Segurança e vulnerabilidades:** práticas, canal de reporte e divulgação responsável.
10. **Incidentes:** processo de comunicação, status e contato.
11. **Uso Aceitável:** spam, fraude, abuso, conteúdo proibido e canais de terceiros.
12. **Assinatura, cancelamento e reembolso:** regras comerciais transparentes.
13. **SLA e suporte:** horários, níveis de severidade e metas.
14. **Transparência do Nemmo/IA:** provedores, dados enviados, retenção, treinamento, supervisão humana e decisões automatizadas.
15. **Canais de terceiros:** responsabilidades e políticas aplicáveis a WhatsApp/Meta e demais provedores.
16. **Avisos de software livre e terceiros:** preservar licenças e atribuições obrigatórias, sem confundi-las com a marca pública.

Referências oficiais para a implementação jurídica:

- [Lei nº 13.709/2018 — LGPD](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm), especialmente arts. 9, 18, 41 e 48;
- [Direitos dos titulares — ANPD](https://www.gov.br/anpd/pt-br/assuntos/titular-de-dados-1/direito-dos-titulares);
- [Regulamentações da ANPD](https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd);
- [Aviso de Privacidade da ANPD](https://www.gov.br/anpd/pt-br/acesso-a-informacao/aviso-de-privacidade), como referência de estrutura, não como texto a copiar.

### 10.1 Situação atual da exclusão de dados

Hoje existe exclusão de conta em `AccountDelete.vue`. A camada PRO marca a conta para exclusão e permite cancelamento por sete dias. `DeleteAccountsJob` executa a remoção e `AccountDeletionService` agenda a cascata de dados.

Lacunas encontradas:

- não existe página pública de solicitação LGPD;
- exclusão de conta empresarial e solicitação individual do titular não estão separadas;
- não há fluxo formal com protocolo, validação de identidade, prazo e comprovante;
- não há prova integrada da exclusão em subprocessadores;
- retenção de backups, objetos e logs não está documentada;
- o domínio de anonimização usa `chatwoot-deleted.invalid`;
- e-mail original pode aparecer em logs e notificação de conformidade;
- o prazo fixo de sete dias não está vinculado a uma política publicada;
- a exportação existente não representa uma exportação completa de titular;
- não há registro auditável de conclusão da solicitação.

O novo fluxo deve propagar correção/exclusão aos operadores aplicáveis, manter somente os registros legalmente necessários e produzir um comprovante sem expor dados pessoais em logs.

## 11. E-mails e comunicação

Pontos críticos:

- `app/mailers/application_mailer.rb` e `conversation_reply_mailer.rb` usam fallback `Chatwoot <accounts@chatwoot.com>`;
- o layout Liquid de e-mail usa “Chatwoot” como fallback;
- exclusão de conta usa assuntos, assinatura “The Chatwoot Team” e `hello@chatwoot.com`;
- notificações de conformidade usam “Chatwoot Installation/System”;
- o remetente padrão não está definido no ambiente privado auditado.

Endereços recomendados, após configurar SPF, DKIM e DMARC:

- `no-reply@<domínio>`;
- `suporte@<domínio>`;
- `privacidade@<domínio>`;
- `seguranca@<domínio>`;
- `financeiro@<domínio>`.

Todos os templates, assuntos, preheaders, logos, rodapés, links e respostas devem ser validados por mail preview e entrega real controlada.

## 12. SuperAdmin, login e onboarding

O SuperAdmin ainda possui títulos, logos, venda, suporte, “Community Support”, “Enterprise edition”, `sales@chatwoot.com` e versão Chatwoot. Os principais templates estão em:

- `app/views/super_admin/devise/sessions/new.html.erb`;
- `app/views/installation/onboarding/index.html.erb`;
- `app/views/super_admin/settings/show.html.erb`;
- `app/views/super_admin/application/_navigation.html.erb`;
- `app/views/super_admin/application/_javascript.html.erb`.

O onboarding AceleraChat deve cadastrar cliente, assinatura, organização e instância sem enviar informações para serviços antigos.

## 13. Como a camada Enterprise é liberada hoje

O código atual usa `lib/chatwoot_hub.rb` e `https://hub.2.chatwoot.com` para:

- `/ping`: sincronização de instalação, versão, ambiente, edição e métricas;
- `/instances`: registro opcional de empresa e responsável;
- `/events`: telemetria;
- `/send_push`: retransmissão de push;
- `/billing`: cobrança.

A instalação mantém um UUID em `InstallationConfig`. O job diário `Internal::CheckNewVersionsJob` sincroniza com o Hub e grava a última versão. A extensão em `enterprise/app/jobs/enterprise/internal/check_new_versions_job.rb` lê do retorno:

- plano;
- quantidade de assentos;
- token/hash/script do widget de suporte.

`Internal::ReconcilePlanConfigService` usa o plano para reconfigurar a marca e desativar recursos premium. Entre eles estão remoção de marca, auditoria, SLA, papéis personalizados, Captain/Nemmo, sincronização de documentos, notas de CSAT e atributos obrigatórios.

Detalhe importante: `DISABLE_TELEMETRY` reduz os dados enviados, mas não impede sozinho o `/ping`. A presença da camada é detectada por `ChatwootApp.enterprise?` verificando a pasta `enterprise`, salvo `DISABLE_ENTERPRISE`.

O contrato de produção versionado em `infra/compose/docker-compose.production.yaml` bloqueia `hub.2.chatwoot.com` para Rails e Sidekiq, e `docs/operations/PRODUCTION-RUNTIME-STATE.md` registra plano enterprise local. Isso precisa ser confirmado dentro dos containers em cada rito de release. O manifesto `infra/production/enterprise-runtime.yml` ainda referencia o SHA antigo `882b6...`, enquanto a produção está no SHA `2fb8bd4...`; essa divergência viola a rastreabilidade e deve ser corrigida no próximo deploy.

## 14. Como AceleraChat deve liberar o PRO

Criar um serviço próprio, provisoriamente chamado **Acelera Control**, com domínio `control.<domínio>`.

### 14.1 Responsabilidades

- cadastro do cliente e portal de assinatura;
- cobrança recorrente por provedor de pagamento;
- registro de tenants e instâncias;
- autoprovisionamento;
- emissão de permissões/entitlements assinados;
- limites de assentos e recursos;
- suporte, changelog e versão;
- trilha de auditoria de plano e pagamento.

### 14.2 Fluxo recomendado

1. O pagamento ou período de teste cria cliente, assinatura e instância.
2. A instância recebe um token de ativação de uso único e gera seu `instance_id` e par de chaves.
3. A instância chama `/v1/instances/heartbeat` com requisição assinada.
4. Envia somente metadados mínimos: ID, versão/SHA, plano e contagem necessária. Não envia mensagens, contatos ou conteúdo.
5. O Control retorna um documento assinado com plano, assentos, recursos, status, emissão, expiração e período de tolerância.
6. A instância valida a assinatura, guarda o último documento válido e reconcilia os recursos locais.
7. Webhooks de pagamento atualizam estados `active`, `past_due`, `canceled` e seus períodos de tolerância.

Mapeamento de compatibilidade:

| Atual | Acelera Control |
|---|---|
| installation identifier | `instance_id` |
| plan | `plan_code` |
| plan quantity | `seat_limit` |
| premium feature flags | `entitlements` |
| support token/hash/script | configuração própria de suporte |
| latest version | `latest_release` + SHA |

Requisitos de segurança e disponibilidade:

- assinatura criptográfica dos entitlements;
- rejeição e auditoria de adulteração;
- último estado válido em cache;
- tolerância a indisponibilidade do Control, sem bloqueio imediato do cliente;
- override emergencial assinado e auditado;
- ausência de dados pessoais no heartbeat;
- push direto pela infraestrutura AceleraChat, sem relay antigo;
- matriz de planos definida sem desativar involuntariamente privacidade rígida, canais QR ou Nemmo.

## 15. Preservação dos nomes internos

A transição de marca não exige renomear a arquitetura interna. A decisão recomendada é preservar:

- pasta `enterprise/`;
- namespace Ruby `Enterprise::`;
- métodos `enterprise?`;
- variáveis e chaves como `IS_ENTERPRISE` e `INSTALLATION_PRICING_PLAN`;
- classes, tabelas, filas, eventos e APIs `Captain`/`captain`;
- rotas internas `/captain`, desde que não sejam expostas como texto ou link público;
- nomes técnicos `chatwoot` usados por compatibilidade de banco, gems, pacotes ou código legado.

Somente a camada de apresentação e os serviços externos mudam:

- “Chatwoot” visível vira “AceleraChat”;
- “Capitão/Captain” visível vira “Nemmo”;
- “Enterprise” visível vira “PRO”;
- logos, remetentes, domínios, ajuda, suporte, telemetria, cobrança e licenciamento passam a ser próprios.

As buscas estruturais desta auditoria continuam úteis como uma lista de **não alterar por substituição global**. Referências internas só devem ser modificadas quando forem responsáveis por texto público, URL externa ou tráfego de rede. Essa estratégia reduz o risco de regressão em autoload, banco, APIs, jobs e integrações, sem deixar a marca antiga visível ao cliente.

## 16. Critérios de aceite

### 16.1 Marca

- nenhuma ocorrência visível de Chatwoot, Chat Woot, Capitão ou Enterprise;
- AceleraChat e Nemmo consistentes em desktop, mobile, widget, e-mail e SuperAdmin;
- PWA instalado com nome, logo e cores próprios;
- avisos obrigatórios de licenças preservados em área apropriada;
- nomes técnicos antigos permitidos apenas internamente, sem renderização para o cliente.

### 16.2 Links e rede

- nenhum `href`, `src`, redirect ou request de runtime para `chatwoot.com`, `chatwoot.help`, `chwt.app` ou `hub.2.chatwoot.com`;
- exceções somente quando documentadas como referência técnica/legal inevitável e nunca executadas em runtime;
- teste de egress/denylist dentro dos containers;
- Central de Ajuda com destino específico para cada link contextual.

### 16.3 PRO e cobrança

- ativação válida;
- assinatura expirada/adulterada;
- pagamento ativo, atrasado e cancelado;
- Control indisponível;
- período de tolerância;
- alteração de assentos e plano;
- autoprovisionamento e rollback;
- trilha de auditoria sem PII desnecessária.

### 16.4 Privacidade e exclusão

- solicitação autenticada e pública com protocolo;
- confirmação, acesso, correção, exportação e exclusão;
- exclusão propagada aos subprocessadores aplicáveis;
- retenção de backup validada;
- logs sem e-mails ou conteúdo desnecessário;
- comprovante final e auditoria do prazo.

### 16.5 Smoke visual e funcional

- login, recuperação de senha e onboarding;
- dashboard, conversas, caixas e equipes;
- privacidade rígida por setor e hierarquia gerente/admin;
- WhatsApp QR/Evolution e transferência;
- Nemmo e atendimento humano;
- SuperAdmin;
- widget, portal e CSAT;
- mail previews e entrega controlada;
- PWA e responsividade;
- criação, upgrade, downgrade e cancelamento de assinatura.

## 17. Plano de execução recomendado

1. Aprovar nome, domínio, logo, paleta e vocabulário.
2. Aprovar matriz de planos, assentos e recursos obrigatórios.
3. Criar páginas legais mínimas, Central de Ajuda inicial, status e canais de suporte.
4. Implementar Acelera Control e contrato de entitlements em ambiente de homologação.
5. Produzir e integrar todo o pacote visual.
6. Trocar configurações, textos, traduções, e-mails, SuperAdmin e links.
7. Manter os nomes internos e aplicar “PRO” e “Nemmo” somente na apresentação pública.
8. Aplicar testes automáticos de denylist, marca, entitlements, LGPD e e-mails.
9. Executar smoke autenticado completo em homologação.
10. Fazer um único push consolidado para economizar GitHub Actions.
11. Gerar imagem e manifestos com o mesmo SHA, registrar rollback e implantar.
12. Executar smoke pós-deploy e somente então encerrar a janela de rollback.

## 18. Decisões pendentes antes da implementação

- domínio oficial da AceleraChat;
- razão social, CNPJ, endereço e foro que aparecerão nos documentos;
- encarregado/DPO e canais de privacidade/segurança;
- provedor de pagamento e regras de cancelamento/reembolso;
- modelo de isolamento: instância por cliente, multi-tenant ou híbrido;
- matriz de planos, assentos, créditos Nemmo e recursos;
- provedores/subprocessadores finais;
- política de retenção, backups e logs;
- identidade visual final e personalidade do Nemmo;
- se será criado um alias público `/nemmo`; a rota interna `/captain` pode permanecer por compatibilidade.

## 19. Estratégia de commits, Actions, deploy e rollback

- commits locais pequenos e lógicos por pacote;
- SHA registrado em cada evidência e manifesto;
- testes locais antes de push;
- um único push do conjunto aprovado, evitando execuções redundantes de Actions;
- imagem Docker, manifesto PRO e release gerados do mesmo SHA;
- tag de release e referência explícita da imagem anterior;
- backup e validações pré-deploy;
- deploy controlado;
- smoke pós-deploy;
- rollback por imagem/SHA anterior, sem reconstrução durante incidente.

Nenhuma implementação deve começar por substituição global. Cada pacote deve ter lista de arquivos, testes, SHA-base, SHA-resultante e evidência de aceite.
