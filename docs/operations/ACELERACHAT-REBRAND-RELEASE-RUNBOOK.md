# Runbook de release do rebranding AceleraChat

## 1. Controle da entrega

- SHA-base da implementação: `901a23fbed68b0e0cf2a2c8e850eab6ab454ad5f`.
- Branch de trabalho: `release/strict-team-conversation-privacy`.
- Aplicação pública: `https://atendimento.meugerenciador.pro`.
- Imagem principal de rollback: `b8932617338a4cd3762fa5cf89540fc68cdae5eb`.
- Perfil de corte: `PUBLIC_BRAND_PROFILE=acelerachat`.
- Acelera Control: obrigatoriamente `ACELERA_CONTROL_ENABLED=false`.
- Estratégia GitHub: um único push do SHA final para `main`; reutilizar os workflows existentes de build, deploy e rollback.

Este documento não autoriza o corte antes de todos os gates. O SHA final, o digest da imagem, o backup e os IDs dos workflows devem ser preenchidos na seção de evidências durante a janela.

## 2. O que foi implementado

### Perfil e identidade

- `PublicBrand` resolve a apresentação pública a partir do perfil versionado `acelerachat` e sobrepõe os valores persistidos sem alterar o PostgreSQL.
- perfil vazio conserva a resolução por `InstallationConfig`; perfil desconhecido impede a inicialização.
- URLs do perfil aceitam somente caminho interno ou HTTPS, sem credenciais e sem os hosts antigos bloqueados.
- defaults de novas instalações usam AceleraChat, Nemmo e PRO; nomes internos permanecem compatíveis.
- título, favicon, PWA, Open Graph, login, SSO, SuperAdmin, widget, portal, CSAT e e-mails recebem a identidade pública.
- SSO fica oculto sem usuários SAML e é preservado quando existe usuário SAML. O perfil AceleraChat não registra o middleware Google OAuth nesta entrega; uma ativação futura exige credenciais próprias e revisão explícita do perfil.

### Ativos

- inventário fechado: 55 ativos visuais auditados e 59 arquivos gerados.
- logo claro/escuro, símbolo, avatar Nemmo, favicons, badges, Android, Apple, Microsoft, widget, catálogo Nemmo, design system, manifesto, browserconfig e Open Graph.
- ativos antigos não são sobrescritos; continuam disponíveis ao SHA de rollback.
- o gerador determinístico é `scripts/generate_acelerachat_assets.py` e o gate é `scripts/audit_acelerachat_assets.py`.

### Ajuda e jurídico

- registro canônico de 22 links contextuais em `config/public_brand_profiles/acelerachat.yml`.
- frontend recebe o registro resolvido no runtime; `config/features.yml` é comparado pelo gate de marca.
- pacote com 76 documentos Markdown: 22 artigos de ajuda e 16 documentos legais, em `pt_BR` e `en`.
- portal gerenciado: slug `acelerachat`, layout `documentation`, locale padrão `pt_BR`.
- o sincronizador exige conta `1`, autor explícito com papel de administrador nessa conta, marca de propriedade do repositório e ausência de colisões manuais.
- `check` não altera dados; `sync` é transacional e idempotente.
- rotas estáveis: `/legal/terms`, `/legal/privacy`, `/legal/cookies` e `/legal/data-request`.
- nenhuma minuta incompleta é publicada: fatos ausentes ou inválidos retornam `503` e bloqueiam o sync.

### Solicitações LGPD

- protocolo aleatório, tipo, estado, e-mail/detalhes/notas criptografados e tokens armazenados somente como SHA-256.
- verificação em 24 horas, expiração de não verificados em sete dias, expurgo de conteúdo sensível em 90 dias e metadados mínimos por 730 dias.
- consulta pública exige token separado do token de verificação e usa `no-store`, `no-referrer` e `noindex`.
- CSRF, limites por IP/e-mail/token e hCaptcha opcional com validação do par site/server key.
- exclusão nunca é automática; SuperAdmin tem fila manual e trilha de eventos.
- o SuperAdmin pode vincular explicitamente uma conta, com evento auditável, para usar o procedimento de exclusão existente e registrar ações manuais em subprocessadores.
- idioma original do pedido é preservado para mensagens posteriores.

## 3. Configuração obrigatória

Os valores abaixo devem existir no secret store/arquivo de produção, nunca no Git:

```dotenv
PUBLIC_BRAND_PROFILE=acelerachat
LEGAL_ENTITY_NAME=
LEGAL_ENTITY_CNPJ=
LEGAL_ENTITY_ADDRESS=
LEGAL_DPO_NAME=
PRIVACY_CONTACT_EMAIL=bellartecomercial@gmail.com
SUPPORT_CONTACT_EMAIL=suporte@aifoodmanager.pro
ACELERACHAT_PUBLIC_CONTENT_AUTHOR_EMAIL=bellartecomercial@gmail.com
MAILER_SENDER_EMAIL=AceleraChat <suporte@aifoodmanager.pro>
SMTP_DOMAIN=aifoodmanager.pro
MAILER_DKIM_SELECTORS=hostingermail-a,hostingermail-b,hostingermail-c
ENABLE_ACCOUNT_SIGNUP=false
ACELERA_CONTROL_ENABLED=false
```

`LEGAL_ENTITY_CNPJ` é opcional. Quando vazio, nenhuma menção ou rótulo de CNPJ é publicado; quando informado, o gate valida o formato. Também são obrigatórias as três chaves de Active Record Encryption. hCaptcha pode ficar totalmente ausente; se usado, `HCAPTCHA_SITE_KEY` e `HCAPTCHA_SERVER_KEY` devem existir juntos.

Antes do corte, confirmar manualmente que estes endereços recebem mensagens:

- `suporte@aifoodmanager.pro` como suporte e remetente autorizado;
- `bellartecomercial@gmail.com` como contato de privacidade provisório.

O gate DNS exige MX, SPF, DKIM e DMARC. A existência individual de uma caixa postal deve ser comprovada por envio controlado; DNS sozinho não prova entrega.

## 4. Gates locais

Executar a partir da raiz do repositório:

```powershell
git rev-parse HEAD
git status --short
python scripts/generate_acelerachat_public_content.py
python scripts/audit_acelerachat_assets.py
corepack pnpm exec vitest --run app/javascript/shared/helpers/specs/publicBrand.spec.js app/javascript/shared/helpers/specs/publicBrandMessages.spec.js app/javascript/shared/composables/specs/useBranding.spec.js app/javascript/dashboard/helper/AudioAlerts/specs/faviconHelper.spec.js app/javascript/dashboard/api/specs/changelog.spec.js
corepack pnpm exec vite build
bundle exec rails db:migrate RAILS_ENV=test
git diff --exit-code -- db/schema.rb
bundle exec rspec spec/lib/public_brand_spec.rb spec/lib/public_brand_i18n_spec.rb spec/lib/global_config_spec.rb spec/services/acelerachat spec/models/privacy_request_spec.rb spec/jobs/privacy_request_cleanup_job_spec.rb spec/mailers/application_mailer_brand_spec.rb spec/mailers/privacy_request_mailer_spec.rb spec/mailers/confirmation_instructions_spec.rb spec/mailers/administrator_notifications/account_notification_mailer_spec.rb spec/requests/public spec/requests/public_brand_login_spec.rb spec/requests/super_admin/privacy_requests_spec.rb spec/controllers/super_admin/instance_statuses_controller_spec.rb
bundle exec rake acelerachat:brand:audit
```

Em Windows, definir variáveis pelo mecanismo do PowerShell. O gate Ruby e a imagem Docker devem ser executados em ambiente que tenha Ruby/Bundler e Docker; não registrar como aprovado se a ferramenta estiver ausente.

Build local da mesma imagem usada em produção:

```text
docker build --file docker/production/Dockerfile --tag acelerachat-rebrand:<SHA_COMPLETO> .
```

## 5. Preflight conectado e conteúdo público

No ambiente conectado ao PostgreSQL de produção, usando a imagem final, executar primeiro sem mutação:

```text
bundle exec rake acelerachat:brand:audit
bundle exec rake acelerachat:email:check
bundle exec rake acelerachat:monitoring:check
bundle exec rake acelerachat:public_content:check
```

A tarefa agregada `acelerachat:release:preflight` executa os quatro gates quando
o perfil AceleraChat está ativo e apenas informa `skipped` quando o perfil está
vazio. Ela não deve substituir a leitura das saídas individuais na primeira
publicação.

Critérios de aprovação:

- perfil exatamente `acelerachat`;
- saída registra a quantidade de usuários SAML e o modo SSO resultante (`hidden` ou `preserved_and_rebranded`);
- 22 links canônicos e 76 documentos;
- 55 ativos e todos os hashes válidos;
- zero referência de egress para hosts antigos em runtime;
- conta `1` existente;
- autor explícito com papel de administrador na conta `1`;
- nenhum portal/artigo manual em colisão;
- criptografia configurada;
- fatos legais completos e válidos;
- DNS, autenticação SMTP e caixas postais aprovados;
- Sentry próprio aprovado, sem PII e associado ao SHA completo.

## 6. GitHub, imagem e deploy

1. Consolidar o trabalho local em um único SHA final rastreável.
2. Revisar `git diff --check`, `git status` e registrar o SHA.
3. Fazer um único push para `main`.
4. Aguardar o workflow existente `Build production image`, acionado pelo push.
5. Registrar o digest imutável publicado em `ghcr.io/tadashiyukoyama/centraldeatendimentochat:<SHA>`.
6. Executar o preflight conectado com a imagem final.
7. Acionar `Deploy production image through ICP` com o SHA completo.

O deploy existente valida ancestralidade, contrato remoto, imagem imutável, DNS/ingress e backup PostgreSQL antes da migration aditiva. Não alterar o contrato root-owned durante esta entrega.

Depois de `db:chatwoot_prepare` e antes de encerrar a janela, executar uma única vez:

```text
bundle exec rake acelerachat:release:sync
```

Essa tarefa sincroniza somente conteúdo marcado como gerenciado. Não executar `sync` em uma imagem diferente do SHA implantado.

## 7. Smoke pós-deploy

### Acesso e marca

- login por senha, recuperação, convite e MFA;
- SSO redirecionado ao login sem usuários SAML;
- SSO preservado e rebrandeado se o preflight encontrou SAML;
- aba, favicon normal/com badge, manifesto, instalação PWA e Open Graph;
- claro/escuro em desktop e celular;
- dashboard, SuperAdmin, widget, portal e CSAT sem marca antiga.

### Operação

- conversas, caixas, setores, gerente/administrador e privacidade rígida;
- transferência retira a conversa do setor anterior;
- WhatsApp QR/Evolution recebe e envia, sem bloqueio indevido da janela oficial de 24 horas;
- reconexão da sessão e transferência de conversa;
- Nemmo: visão geral, assistente, documentos, FAQ, ferramentas e handoff humano.

### Conteúdo e privacidade

- os 22 links retornam `200` e chegam ao artigo correto no idioma esperado;
- portal raiz redireciona para `pt_BR` e inglês funciona;
- quatro rotas legais em português e inglês;
- pedido LGPD, e-mail, confirmação, protocolo, consulta protegida e fila SuperAdmin;
- e-mails têm remetente, assunto, logo, assinatura e links AceleraChat;
- smoke transacional entregue e evento controlado recebido no Sentry com o SHA.

### Rede

Capturar a rede de sessão anônima e autenticada. O aceite exige zero requisição, redirect, `href`, `src` ou `fetch` para `chatwoot.com`, `chatwoot.help`, `chwt.app`, GitHub Releases antigo e CDN de depoimentos antiga. Domínios oficiais de provedores configurados são permitidos.

## 8. Rollback

Alvo principal: a imagem imutável registrada em `shared/active-image`
imediatamente antes do corte. Copiar o SHA observado para a evidência da janela:

```text
<SHA_ATIVO_ANTES_DO_CORTE>
```

Acionar o workflow existente `Roll back production image through ICP`, informar o SHA completo e a confirmação `ROLLBACK`.

O rollback restaura código, assets e marca porque o branding persistido não foi alterado. A migration LGPD é aditiva; a tabela pode permanecer. Os artigos gerenciados e o portal também podem permanecer sem links públicos no código antigo. Para reversão pública integral, arquivar o portal `acelerachat` após confirmar o rollback da imagem.

Não executar reset de banco nem apagar a tabela LGPD durante rollback. Preservar o dump, checksum, metadata e trilha de solicitações.

## 9. Evidências da janela

Preencher sem segredos:

| Evidência              | Valor                                           |
| ---------------------- | ----------------------------------------------- |
| SHA-base               | `4204f4147f1a9b43c9740d2d739ef843d5ead817`      |
| SHA final              | pendente                                        |
| Digest GHCR            | pendente                                        |
| Workflow build         | pendente                                        |
| Workflow deploy        | pendente                                        |
| Imagem anterior        | observar `shared/active-image` antes do corte   |
| Backup PostgreSQL      | pendente                                        |
| SHA-256 do backup      | pendente                                        |
| `brand:audit`          | pendente no runtime Ruby                        |
| `public_content:check` | pendente no runtime conectado                   |
| `email:check`          | bloqueado: MX/SPF/DMARC ausentes; DKIM pendente |
| `monitoring:check`     | bloqueado: DSNs Sentry próprios pendentes       |
| `public_content:sync`  | pendente                                        |
| Smoke                  | pendente                                        |
| Captura de rede        | pendente                                        |

## 10. Evidência local já obtida

- gerador de conteúdo: 76 documentos;
- auditor de ativos: 55 ativos, 59 arquivos, zero erro;
- contraste: azul/branco `5.17`, claro/escuro `17.06`, ciano/escuro `7.35`;
- scanner estático equivalente ao gate: 22 links canônicos, 76 documentos e zero referência bloqueada em runtime;
- Vitest direcionado: 5 arquivos, 19 testes aprovados;
- ESLint direcionado: 46 arquivos alterados, zero erro;
- Prettier: 134 arquivos aprovados; `config/newrelic.yml` usa ERB e não é analisável pelo parser YAML do Prettier;
- Vite produção: 4.729 módulos, build aprovado em 1m22s;
- sintaxe Ruby: 59 arquivos Ruby/Rake/schema aprovados com Ruby 3.4.9/Prism;
- DNS público observado em 28/07/2026: sem MX, SPF ou DMARC para `meugerenciador.pro`; DKIM não pode ser testado sem seletor. O corte permanece bloqueado;
- fatos jurídicos e e-mail do administrador autor ainda não foram fornecidos; conteúdo público não pode ser sincronizado;
- RSpec não executado: o projeto exige Ruby 3.4.4, a estação tem 3.4.9 e faltam gems Git/plataforma; Docker também não está instalado. Ambos continuam gates obrigatórios antes do push.
