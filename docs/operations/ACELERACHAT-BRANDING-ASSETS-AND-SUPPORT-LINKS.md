# Inventário de imagens e links de apoio da transição AceleraChat

## 1. Identificação e alcance

- Data da revisão: 25 de julho de 2026.
- Repositório: `D:\dev\workspaces\centraldeatendimentoCHAT\server`.
- Branch: `release/strict-team-conversation-privacy`.
- SHA-base auditado: `b8932617338a4cd3762fa5cf89540fc68cdae5eb`.
- Produção correspondente: `https://atendimento.meugerenciador.pro`.
- Estado: inventário aprovado para planejamento; a troca de marca ainda não foi
  implementada.

Este documento é o anexo executável da
`docs/operations/ACELERACHAT-TRANSITION-AUDIT.md`. Ele registra os ativos
visuais e os links de apoio que precisam ser substituídos, editados ou
explicitamente preservados. Nomes técnicos internos, licenças e referências
históricas não são autorização para exibir a marca antiga ao usuário.

A busca foi feita no código rastreado de `app/`, `config/`, `enterprise/`,
`lib/` e `public/`. Specs, stories, fixtures, documentação de desenvolvimento e
licenças são auditados separadamente, porque não devem bloquear o produto sem
uma avaliação de compatibilidade ou atribuição legal.

## 2. Regras de classificação

| Prioridade | Significado                                                                                                                  |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------- |
| P0         | Aparece para usuário ou navegador e bloqueia o corte público da marca                                                        |
| P1         | Apoio, e-mail, página pública ou integração que pode direcionar o usuário ao fornecedor antigo                               |
| P2         | Ambiente de desenvolvimento, exemplo ou peça visual que deve ser limpa para consistência, mas não bloqueia sozinha o runtime |
| Preservar  | Marca legítima de terceiro, referência técnica interna ou atribuição legal                                                   |

As ações usadas neste inventário são:

- **substituir:** gerar um novo ativo AceleraChat/Nemmo e remover o conteúdo
  visual anterior;
- **editar:** manter o arquivo ou fluxo, alterando textos, cores, metadados ou
  destino;
- **centralizar:** retirar URL literal e obtê-la de uma configuração própria;
- **remover:** eliminar a chamada ou opção quando ainda não existir serviço
  AceleraChat equivalente;
- **preservar:** não alterar sem uma decisão técnica, contratual ou legal.

## 3. Inventário obrigatório de imagens

Foram identificados **55 arquivos visuais diretamente relacionados à marca**.
Destes, 52 podem alcançar o produto ou uma superfície pública e três pertencem
ao design system de desenvolvimento. Fundos e ilustrações sem logotipo estão
em uma fila separada de revisão visual.

### 3.1 Logos centrais — P0

| Arquivo                                  | Uso confirmado                                                          | Ação                                                         |
| ---------------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------ |
| `public/brand-assets/logo.svg`           | Login, SSO, signup, onboarding, SuperAdmin e compartilhamento anual     | Substituir pelo logo horizontal AceleraChat para fundo claro |
| `public/brand-assets/logo_dark.svg`      | As mesmas telas em tema escuro                                          | Substituir pela variante para fundo escuro                   |
| `public/brand-assets/logo_thumbnail.svg` | favicon configurável, título/navegação do SuperAdmin e símbolo quadrado | Substituir pelo símbolo AceleraChat em SVG quadrado          |

Também devem ser editadas as referências e os textos alternativos em:

- `app/javascript/v3/views/login/Index.vue`;
- `app/javascript/v3/views/login/Saml.vue`;
- `app/javascript/v3/views/auth/signup/Index.vue`;
- `app/views/installation/onboarding/index.html.erb`;
- `app/views/super_admin/devise/sessions/new.html.erb`;
- `app/views/super_admin/application/_navigation.html.erb`;
- `app/javascript/dashboard/components-next/year-in-review/ShareModal.vue`;
- `config/installation_config.yml`;
- `enterprise/config/premium_installation_config.yml`.

O logo do SSO não é um ativo independente: a rota `/app/login/sso` lê
`globalConfig.logo`, `globalConfig.logoDark` e `installationName`. Trocar apenas
o SVG sem trocar a configuração deixaria o título da aba e o texto alternativo
como Chatwoot.

Os valores podem estar persistidos em `InstallationConfig` no PostgreSQL e
prevalecer sobre defaults do arquivo YAML. Antes do deploy, o rito deve
inventariar e atualizar de forma auditável `INSTALLATION_NAME`, `BRAND_NAME`,
`LOGO`, `LOGO_DARK`, `LOGO_THUMBNAIL`, `BRAND_URL` e `WIDGET_BRAND_URL`. Manter
os mesmos caminhos públicos no primeiro corte reduz o risco de o rollback de
imagem encontrar assets inexistentes. Cache do navegador, CDN, proxy e assets
compilados deve ser invalidado e conferido em sessão anônima.

### 3.2 Favicon, notificações e PWA — P0

| Família            | Arquivos                                                                                                                                                                                                                    | Quantidade | Ação                                                                            |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------: | ------------------------------------------------------------------------------- |
| Favicons normais   | `public/favicon-16x16.png`, `favicon-32x32.png`, `favicon-96x96.png`, `favicon-512x512.png`                                                                                                                                 |          4 | Regenerar a partir do símbolo aprovado                                          |
| Favicons com badge | `public/favicon-badge-16x16.png`, `favicon-badge-32x32.png`, `favicon-badge-96x96.png`                                                                                                                                      |          3 | Regenerar preservando o indicador de mensagem não lida                          |
| Android/PWA        | `public/android-icon-36x36.png`, `48x48`, `72x72`, `96x96`, `144x144`, `192x192`                                                                                                                                            |          6 | Regenerar todos os tamanhos                                                     |
| Apple              | `public/apple-icon-57x57.png`, `60x60`, `72x72`, `76x76`, `114x114`, `120x120`, `144x144`, `152x152`, `180x180`, `apple-icon.png`, `apple-icon-precomposed.png`, `apple-touch-icon.png`, `apple-touch-icon-precomposed.png` |         13 | Regenerar; os dois `apple-touch-icon*` estão vazios e não podem continuar assim |
| Microsoft          | `public/ms-icon-70x70.png`, `144x144.png`, `150x150.png`, `310x310.png`                                                                                                                                                     |          4 | Regenerar todos os tamanhos                                                     |

Arquivos de controle que precisam ser editados junto com as imagens:

- `app/views/layouts/vueapp.html.erb`: título, favicon, Apple Touch, Microsoft
  tile, descrição e manifesto;
- `app/javascript/dashboard/helper/AudioAlerts/faviconHelper.js`: validar a
  alternância entre favicon normal e favicon com badge;
- `public/manifest.json`: trocar `name`, `short_name`, `background_color` e
  `theme_color`;
- `public/browserconfig.xml`: revisar `TileColor` e manter os novos caminhos;
- `config/installation_config.yml`: revisar `DISPLAY_MANIFEST` e
  `LOGO_THUMBNAIL`.

Critério específico: aba normal, aba com notificação, atalho Android, atalho
iOS e instalação PWA devem mostrar o mesmo símbolo AceleraChat sem cache do
ativo anterior.

### 3.3 Widget e avatar do sistema — P0

| Arquivo                                                   | Uso                                            | Ação                                                      |
| --------------------------------------------------------- | ---------------------------------------------- | --------------------------------------------------------- |
| `app/javascript/widget/assets/images/logo.svg`            | Símbolo incorporado no widget                  | Substituir pelo símbolo AceleraChat                       |
| `app/javascript/dashboard/assets/images/bubble-logo.svg`  | Pré-visualização do widget                     | Substituir em conjunto com o widget real                  |
| `app/javascript/dashboard/assets/images/chatwoot_bot.png` | Fonte do avatar de mensagens automáticas       | Substituir e renomear em uma etapa controlada             |
| `public/assets/images/chatwoot_bot.png`                   | Avatar servido no widget e em notas de contato | Substituir; hoje é duplicado byte a byte do arquivo fonte |

As referências do avatar estão em `AgentMessage.vue`, `UnreadMessage.vue` e
`ContactNoteItem.vue`. A primeira migração pode preservar o caminho
`chatwoot_bot.png` por compatibilidade, mas o conteúdo e os textos alternativos
devem ser próprios. A renomeação física pode ocorrer depois, com teste contra
cache e assets compilados.

### 3.4 Nemmo, ainda apresentado visualmente como Captain — P0

Os 13 SVGs abaixo formam uma família e devem ser substituídos juntos para
evitar mistura entre Captain e Nemmo:

- `public/assets/images/dashboard/captain/logo.svg`;
- `assistant-light.svg` e `assistant-dark.svg`;
- `assistant-popover-light.svg` e `assistant-popover-dark.svg`;
- `document-light.svg` e `document-dark.svg`;
- `document-popover-light.svg` e `document-popover-dark.svg`;
- `faqs-light.svg` e `faqs-dark.svg`;
- `faqs-popover-light.svg` e `faqs-popover-dark.svg`.

Também devem ser substituídas as duas imagens do catálogo de integrações:

- `public/dashboard/images/integrations/captain.png`;
- `public/dashboard/images/integrations/captain-dark.png`.

As pastas e os caminhos internos `captain/` podem permanecer. O conteúdo
visual, o nome exibido, os textos alternativos e os links passam a usar Nemmo.
`enterprise/app/models/captain/assistant.rb` usa o `logo.svg` como avatar
padrão; por isso o teste deve incluir um assistente novo e um assistente antigo
sem avatar personalizado.

### 3.5 Design system — P2

| Arquivo                                                  | Estado                              | Ação                                             |
| -------------------------------------------------------- | ----------------------------------- | ------------------------------------------------ |
| `app/javascript/design-system/images/logo.png`           | Contém `@chatwoot Design System`    | Substituir ou remover a assinatura visual antiga |
| `app/javascript/design-system/images/logo-dark.png`      | Variante escura da mesma assinatura | Substituir junto com a variante clara            |
| `app/javascript/design-system/images/logo-thumbnail.svg` | Mesmo conteúdo do logo do widget    | Substituir pelo símbolo próprio                  |

Esses arquivos não são o logo principal do runtime, mas continuarão expondo a
marca anterior em documentação visual, Storybook ou ferramentas internas.

### 3.6 Imagens que exigem revisão visual, não substituição automática — P1/P2

| Grupo                    | Arquivos                                                                                                                                                 | Decisão registrada                                                                                                           |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Login/cadastro           | `app/javascript/dashboard/assets/images/auth/auth--bg.svg`, `bottom-right.svg`, `top-left.svg`, `signup-bg.jpg` e cópias em `public/assets/images/auth/` | Não contêm logo textual detectável. Revisar paleta e coerência; podem permanecer no primeiro corte se aprovadas visualmente  |
| Year in Review           | `public/assets/images/dashboard/year-in-review/*`                                                                                                        | Revisar paleta e assinatura; `ShareModal.vue` já sobrepõe o logo central, que é P0                                           |
| Estados vazios gerais    | `chat.svg`, `inboxes.svg`, `no-chat*.svg`, `no-inboxes.svg`, `no_page_image.png`                                                                         | Não substituir por busca textual; validar visualmente no smoke                                                               |
| Canais                   | `public/assets/images/dashboard/channels/*`                                                                                                              | Preservar logos legítimos de Meta, WhatsApp, Telegram, Google e outros provedores; alterar somente moldura/texto AceleraChat |
| Integrações de terceiros | `public/dashboard/images/integrations/*`, exceto `captain*.png`                                                                                          | Preservar marcas necessárias para identificar cada integração                                                                |
| Portal do cliente        | Logos enviados pelo próprio cliente e OG image gerada pelo portal                                                                                        | Não sobrescrever com a marca da plataforma; validar apenas fallback, metadados e segurança da URL                            |

Não existe um ativo local global dedicado de Open Graph para a aplicação. Os
portais usam `@og_image_url`; o corte deve criar um fallback AceleraChat e
testar artigos, categorias e página inicial do portal sem imagem própria.

## 4. Inventário de links de apoio contextuais — P0/P1

O destino definitivo deve ser configurável. Enquanto o domínio não for
aprovado, esta auditoria usa a raiz lógica `AJUDA_URL` para a Central de Ajuda,
`SITE_URL` para o site institucional, `STATUS_URL` para status e
`CONTROL_URL` para cobrança/assinatura. Nenhum placeholder pode chegar à
produção.

### 4.0 Fontes canônicas que precisam ser próprias

| Configuração                                   | Uso                                           | Regra do corte                                                          |
| ---------------------------------------------- | --------------------------------------------- | ----------------------------------------------------------------------- |
| `BRAND_URL`                                    | Destino do nome/logo AceleraChat              | Apontar para `SITE_URL`                                                 |
| `WIDGET_BRAND_URL`                             | “Powered by” do widget e superfícies públicas | Apontar para página AceleraChat própria, sem fallback antigo            |
| `TERMS_URL`                                    | Signup, rodapés e páginas públicas            | Página de Termos publicada e versionada                                 |
| `PRIVACY_URL`                                  | Signup, rodapés e páginas públicas            | Aviso de Privacidade/LGPD publicado e versionado                        |
| `HELPCENTER_URL`                               | Central de Ajuda exposta ao frontend          | Apontar para `AJUDA_URL` ou ficar vazio sem gerar link quebrado         |
| `CHANGELOG_URL`                                | Feed e menu de notas da versão                | HTTPS próprio; vazio enquanto não existir                               |
| `MAILER_SUPPORT_EMAIL` e `MAILER_SENDER_EMAIL` | Respostas e remetentes de e-mail              | Endereço do domínio AceleraChat com SPF, DKIM e DMARC                   |
| `CHATWOOT_SUPPORT_*`                           | Chaves internas legadas do widget de suporte  | Aceitar somente URL/token/HMAC emitidos pela infraestrutura AceleraChat |
| `ACELERA_BILLING_PORTAL_URL`                   | Botões de cobrança e assinatura               | Portal próprio em HTTPS; ocultar o botão quando ausente                 |

Os defaults de marca existem tanto em `config/installation_config.yml` quanto
em `enterprise/config/premium_installation_config.yml`. O reconciliador de
plano não pode restaurar URL ou marca antiga durante upgrade, downgrade,
expiração ou indisponibilidade do Control.

O preflight de produção também deve consultar os valores já persistidos de
`TERMS_URL`, `PRIVACY_URL`, `CHATWOOT_SUPPORT_SCRIPT_URL`,
`CHATWOOT_SUPPORT_WEBSITE_TOKEN`, `CHATWOOT_SUPPORT_IDENTIFIER_HASH` e
configurações de changelog. Um default seguro no código não elimina um URL
antigo gravado anteriormente no banco.

### 4.1 Mapa central de ajuda por recurso

`app/javascript/dashboard/helper/featureHelper.js` contém 22 links diretos.
Todos devem ser centralizados e apontar para um artigo específico, não apenas
para a página inicial da ajuda.

| Chave atual         | Destino atual                           | Página AceleraChat obrigatória                          |
| ------------------- | --------------------------------------- | ------------------------------------------------------- |
| `agent_bots`        | `https://chwt.app/hc/agent-bots`        | `AJUDA_URL/integracoes/bots-de-agente`                  |
| `agents`            | `https://chwt.app/hc/agents`            | `AJUDA_URL/administracao/usuarios-e-perfis`             |
| `audit_logs`        | `https://chwt.app/hc/audit-logs`        | `AJUDA_URL/seguranca/logs-de-auditoria`                 |
| `campaigns`         | `https://chwt.app/hc/campaigns`         | `AJUDA_URL/campanhas/visao-geral`                       |
| `canned_responses`  | `https://chwt.app/hc/canned`            | `AJUDA_URL/produtividade/respostas-prontas`             |
| `channel_email`     | `https://chwt.app/hc/email`             | `AJUDA_URL/canais/email`                                |
| `channel_facebook`  | `https://chwt.app/hc/fb`                | `AJUDA_URL/canais/facebook`                             |
| `custom_attributes` | `https://chwt.app/hc/custom-attributes` | `AJUDA_URL/dados/atributos-personalizados`              |
| `dashboard_apps`    | `https://chwt.app/hc/dashboard-apps`    | `AJUDA_URL/integracoes/apps-do-painel`                  |
| `help_center`       | `https://chwt.app/hc/help-center`       | `AJUDA_URL/central-de-ajuda/visao-geral`                |
| `inboxes`           | `https://chwt.app/hc/inboxes`           | `AJUDA_URL/caixas-de-entrada/visao-geral`               |
| `integrations`      | `https://chwt.app/hc/integrations`      | `AJUDA_URL/integracoes/visao-geral`                     |
| `labels`            | `https://chwt.app/hc/labels`            | `AJUDA_URL/organizacao/etiquetas`                       |
| `macros`            | `https://chwt.app/hc/macros`            | `AJUDA_URL/produtividade/macros`                        |
| `reports`           | `https://chwt.app/hc/reports`           | `AJUDA_URL/relatorios/visao-geral`                      |
| `sla`               | `https://chwt.app/hc/sla`               | `AJUDA_URL/operacao/sla`                                |
| `team_management`   | `https://chwt.app/hc/teams`             | `AJUDA_URL/administracao/setores-equipes-e-privacidade` |
| `webhook`           | `https://chwt.app/hc/webhooks`          | `AJUDA_URL/desenvolvedores/webhooks`                    |
| `billing`           | `https://chwt.app/pricing`              | `CONTROL_URL/assinatura` ou página de planos própria    |
| `saml`              | `https://chwt.app/hc/saml`              | `AJUDA_URL/seguranca/login-sso-saml`                    |
| `captain`           | `https://chwt.app/captain-docs`         | `AJUDA_URL/nemmo/visao-geral`                           |
| `captain_billing`   | `https://chwt.app/hc/captain_billing`   | `AJUDA_URL/nemmo/creditos-e-cobranca`                   |

`config/features.yml` repete 12 desses destinos para e-mail, Facebook, Central
de Ajuda, bots, equipes, etiquetas, atributos, respostas prontas, integrações,
campanhas, relatórios e SLA. A implementação deve ter uma fonte canônica ou um
teste de igualdade entre backend e frontend; editar somente um dos arquivos
deixará links antigos ativos.

### 4.2 Navegação, suporte e versões

| Origem                             | Destino/estado atual                                         | Ação obrigatória                                                               |
| ---------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `SidebarProfileMenu.vue`           | Guia do usuário e changelog em `www.chatwoot.com`            | Trocar por `AJUDA_URL` e changelog AceleraChat                                 |
| `UpdateBanner.vue`                 | `github.com/chatwoot/chatwoot/releases`                      | Apontar para notas da release AceleraChat ou ocultar até o serviço existir     |
| `dashboard/constants/globals.js`   | documentação e Help Center em `www.chatwoot.com`             | Centralizar em `AJUDA_URL`                                                     |
| `dashboard/constants/globals.js`   | depoimentos em `testimonials.cdn.chatwoot.com`               | Hospedar JSON próprio ou remover o carrossel; não consultar o CDN antigo       |
| `dashboard/constants/globals.js`   | incidente Meta em `status.chatwoot.com/incident/948346`      | Trocar por artigo AceleraChat atualizado ou status oficial da Meta             |
| `config/installation_config.yml`   | `CHANGELOG_URL`                                              | Manter vazio até existir feed HTTPS próprio; depois configurar URL AceleraChat |
| SuperAdmin                         | `sales@chatwoot.com`, “Community Support” e suporte dinâmico | Trocar por suporte AceleraChat e remover opções antigas sem backend próprio    |
| `public_controller.rb`             | erro orienta escrever para `support@chatwoot.com`            | Trocar por canal AceleraChat configurável                                      |
| Mailer de exclusão por inatividade | `hello@chatwoot.com`                                         | Trocar por `privacidade@...` ou `suporte@...` configurado                      |

O widget de suporte do SuperAdmin e do menu lateral só pode carregar quando
URL, token e HMAC AceleraChat válidos estiverem configurados. Na ausência
deles, o botão deve ficar oculto e não deve usar fallback externo.

### 4.3 SSO, canais, Nemmo e campanhas

| Fluxo                   | Arquivos                                                                  | Destino atual                                                   | Substituição exigida                                                     |
| ----------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------ |
| SSO/SAML                | `featureHelper.js`                                                        | `chwt.app/hc/saml`                                              | Artigo próprio explicando configuração, domínios e recuperação de acesso |
| Microsoft               | `config/installation_config.yml`                                          | `chwt.app/dev/ms`                                               | Guia próprio de criação do aplicativo Microsoft                          |
| Migração de WhatsApp    | `WhatsappManualMigrationBanner.vue` e `WhatsappManualMigrationDialog.vue` | `chwt.app/migrate-whatsapp`                                     | Guia próprio que diferencie API oficial e QR/Evolution                   |
| Identidade do live chat | `ConfigurationPage.vue`                                                   | documentação Chatwoot                                           | Guia próprio de HMAC/identity validation                                 |
| Nemmo — assistente      | `AssistantPageEmptyState.vue` e `captain/assistants/Index.vue`            | `chwt.app/captain-assistant`                                    | `AJUDA_URL/nemmo/criar-assistente`                                       |
| Nemmo — documentos      | `DocumentPageEmptyState.vue` e `captain/documents/Index.vue`              | `chwt.app/captain-document`                                     | `AJUDA_URL/nemmo/base-de-conhecimento`                                   |
| Nemmo — FAQ             | `ResponsePageEmptyState.vue`, `responses/Index.vue` e `Pending.vue`       | `chwt.app/captain-faq`                                          | `AJUDA_URL/nemmo/perguntas-frequentes`                                   |
| Nemmo — ferramentas     | `CustomToolsPageEmptyState.vue`                                           | `chwt.app/hc/captain-tools`                                     | `AJUDA_URL/nemmo/ferramentas`                                            |
| Exemplos do Nemmo       | `captainEmptyStateContent.js`                                             | seis artigos em `www.chatwoot.com`                              | Substituir por exemplos próprios ou dados locais neutros                 |
| Exemplos de campanhas   | `CampaignEmptyStateContent.js`                                            | páginas Chatwoot, padrão de URL Chatwoot e `chwt.app/g2-review` | Reescrever exemplos com AceleraChat, domínio neutro e avaliação própria  |

### 4.4 Termos, privacidade e Central de Ajuda pública

| Família                     | Abrangência confirmada                                                                 | Ação                                                                                               |
| --------------------------- | -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Termos e privacidade padrão | `config/installation_config.yml` e `enterprise/config/premium_installation_config.yml` | Definir URLs AceleraChat e impedir fallback para a marca antiga                                    |
| Signup traduzido            | 56 arquivos `app/javascript/dashboard/i18n/locale/*/signup.json`                       | Remover URLs literais e usar `TERMS_URL`/`PRIVACY_URL`; validar `pt_BR` e fallback inglês          |
| Formulário de signup        | `app/javascript/v3/views/auth/signup/components/Signup/Form.vue`                       | Remover a substituição baseada em strings Chatwoot e renderizar URLs configuradas diretamente      |
| Exemplos do Help Center     | 55 arquivos `app/javascript/dashboard/i18n/locale/*/helpCenter.json`                   | Trocar exemplos `app.chatwoot.com` e instrução CNAME `chatwoot.help` por host dinâmico AceleraChat |
| Portal público              | templates de `app/views/public/api/v1/portals/` e `_portal_head.html.erb`              | Preservar logo do cliente, mas garantir fallback, favicon, OG e textos sem marca antiga            |

Termos, privacidade, exclusão de dados, subprocessadores e suporte precisam
estar publicados antes de os links serem trocados. Um link AceleraChat que
retorne 404 também bloqueia o corte.

### 4.5 Metadados e artefatos de implantação

| Arquivo                                  | Problema                                                           | Ação                                                                          |
| ---------------------------------------- | ------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| `app.json`                               | website e logo remoto em `chatwoot.com`                            | Trocar pelos metadados AceleraChat ou remover o artefato se não for suportado |
| `public/manifest.json`                   | nome Chatwoot e cores antigas                                      | Editar junto com o pacote PWA                                                 |
| `app/views/layouts/vueapp.html.erb`      | título da aba e descrição derivados de configuração ainda Chatwoot | Definir `INSTALLATION_NAME=AceleraChat` e revisar o texto de descrição        |
| `app/javascript/v3/views/login/Saml.vue` | logo e `installationName` globais ainda antigos                    | Cobrir no smoke direto de `/app/login/sso`                                    |

## 5. Links que devem ser preservados ou avaliados separadamente

Não se deve fazer substituição global de todos os links que contêm nomes de
terceiros.

| Categoria                           | Exemplos                                                   | Tratamento                                                                                       |
| ----------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Políticas e documentação de canal   | Meta/Facebook, WhatsApp Business, Twilio, TikTok           | Preservar quando a informação for necessária e o destino for oficial                             |
| Login e consentimento de provedores | Google, Microsoft, Meta, Instagram, TikTok                 | Preservar logos e URLs oficiais; revisar somente textos AceleraChat ao redor                     |
| Integrações                         | Slack, Shopify, Linear, Notion, OpenAI, Dialogflow         | Preservar identificação legítima da integração                                                   |
| Dependências técnicas internas      | imports `@chatwoot/utils`, namespaces, rotas e tabelas     | Não renomear nesta frente; não são links de apoio ao usuário                                     |
| Referências históricas no código    | comentários para issues/commits do upstream                | Podem permanecer sem renderização ou egress; revisar durante limpeza técnica                     |
| Licenças                            | `LICENSE`, `enterprise/LICENSE` e atribuições obrigatórias | Preservar conforme obrigação legal, em área apropriada e sem apresentá-las como marca do produto |

## 6. Gate de implementação e verificação

### 6.1 Antes de editar

1. Aprovar logo, símbolo, paleta e nome AceleraChat.
2. Aprovar identidade do Nemmo.
3. Aprovar os domínios de site, ajuda, status e Control.
4. Publicar as páginas P0/P1 da Central de Ajuda e páginas legais.
5. Definir os remetentes e configurar SPF, DKIM e DMARC.

### 6.2 Testes automáticos obrigatórios

- teste de ausência de `chatwoot.com`, `chatwoot.help`, `chwt.app` e
  `github.com/chatwoot/chatwoot/releases` em `href`, `src`, redirects e requests
  de runtime;
- allowlist separada para comentários, specs e licenças;
- teste das 22 chaves de `featureHelper.js`, proibindo URL vazia ou genérica;
- teste de paridade dos 12 links duplicados em `config/features.yml`;
- teste dos valores `INSTALLATION_NAME`, `BRAND_NAME`, logos, termos,
  privacidade, suporte e changelog;
- teste de renderização de login, SSO, signup, onboarding e SuperAdmin;
- teste do favicon normal e com badge;
- teste de manifesto PWA e ausência de arquivos de ícone vazios;
- teste de e-mail sem remetente, logo, assinatura ou link antigo;
- teste de egress dentro de Rails e Sidekiq.

### 6.3 Smoke visual obrigatório

- aba do navegador, favicon e nome instalado do PWA;
- login por senha, recuperação, signup e `/app/login/sso`;
- onboarding e SuperAdmin;
- menu do perfil: suporte, guia, changelog e cobrança;
- cabeçalhos de todas as configurações que usam ajuda contextual;
- caixas de entrada, incluindo WhatsApp QR/Evolution;
- Nemmo: visão geral, assistente, documentos, FAQ e ferramentas;
- widget real e pré-visualização, inclusive avatar automático;
- portal/Help Center, artigo compartilhado e Open Graph;
- e-mails de confirmação, convite, redefinição e exclusão;
- favicon com notificação não lida em tema claro e escuro.

### 6.4 Rastreabilidade e rollback

Cada pacote de troca deve registrar:

- SHA-base;
- lista de arquivos alterados;
- hash ou origem dos novos ativos;
- testes executados e evidências visuais;
- SHA resultante;
- imagem Docker e digest correspondentes;
- SHA anterior homologado para rollback.

O deploy deve usar uma única imagem imutável pelo SHA completo. A troca de
marca não exige migration de banco; caso alguma configuração seja persistida,
o backup e a compatibilidade com o SHA anterior devem ser comprovados antes do
corte. O push deve ser consolidado depois dos testes locais para economizar
GitHub Actions.

## 7. Critério de encerramento deste inventário

Este inventário só pode ser marcado como concluído quando:

1. os 55 ativos obrigatórios estiverem substituídos ou tiverem exceção
   documentada;
2. todos os links P0/P1 apontarem para páginas AceleraChat existentes;
3. nenhum domínio antigo receber tráfego de runtime;
4. logos de terceiros e atribuições legais permanecerem corretos;
5. smoke visual e funcional for aprovado em homologação e produção;
6. SHA, digest da imagem, evidências e rollback estiverem registrados.
