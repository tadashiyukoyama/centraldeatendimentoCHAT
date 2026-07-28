# Fundação operacional: e-mail, monitoramento e Nemmo

## Rastreabilidade

- SHA-base da implementação: `4204f4147f1a9b43c9740d2d739ef843d5ead817`.
- Um único push deve publicar o SHA final aprovado.
- Build e deploy devem usar a tag com o SHA completo.
- O rollback permanece apontado para a imagem ativa registrada antes do corte.

## E-mail transacional

O remetente público aprovado para esta instalação é
`suporte@aifoodmanager.pro`. O mesmo endereço também pode operar como caixa
de entrada, mas os dois papéis permanecem separados: o SMTP global fica no
ambiente protegido e as credenciais IMAP/SMTP da caixa ficam no canal
criptografado no banco.

Configuração mínima:

```dotenv
MAILER_SENDER_EMAIL=AceleraChat <suporte@aifoodmanager.pro>
SMTP_DOMAIN=aifoodmanager.pro
SMTP_ADDRESS=smtp.hostinger.com
SMTP_PORT=465
SMTP_USERNAME=suporte@aifoodmanager.pro
SMTP_PASSWORD=<segredo>
SMTP_AUTHENTICATION=login
SMTP_ENABLE_STARTTLS_AUTO=false
SMTP_SSL=true
SMTP_OPENSSL_VERIFY_MODE=peer
MAILER_DKIM_SELECTORS=hostingermail-a,hostingermail-b,hostingermail-c
PRIVACY_CONTACT_EMAIL=bellartecomercial@gmail.com
SUPPORT_CONTACT_EMAIL=suporte@aifoodmanager.pro
```

Esta configuração usa TLS implícito na porta 465:

```dotenv
SMTP_ENABLE_STARTTLS_AUTO=false
SMTP_SSL=true
```

Antes do deploy:

```bash
bundle exec rake acelerachat:email:check
```

O gate autentica no SMTP sem enviar mensagem e sem imprimir credenciais,
verifica um único modo de transporte seguro, coerência entre remetente, usuário
SMTP e domínio, MX, SPF, os três DKIM por TXT ou CNAME e DMARC. O contato
jurídico pode usar outro domínio válido. Depois do deploy, um administrador
executa um único envio controlado:

```bash
bundle exec rake "acelerachat:email:test[destinatario@example.com]"
```

O teste registra somente o domínio do destinatário e o SHA. A senha SMTP nunca
deve aparecer em commit, log ou argumento de linha de comando.

## Monitoramento de erros

Rails, Sidekiq e o frontend Vue usam Sentry quando um DSN próprio é informado.
O release é sempre associado ao SHA completo da imagem.

Configuração mínima:

```dotenv
SENTRY_DSN=<dsn HTTPS do backend>
SENTRY_FRONTEND_DSN=<dsn HTTPS opcional do frontend>
SENTRY_ENVIRONMENT=production
SENTRY_TRACES_SAMPLE_RATE=0.0
SENTRY_SEND_DEFAULT_PII=false
```

Erros continuam ativos com amostragem de performance em `0.0`. O AceleraChat
força PII desligada e remove usuário, IP, cookies, corpo, query string,
credenciais, e-mail, telefone e documentos antes do envio. Variáveis locais e
propagação de rastreamento também ficam desligadas.

Antes do deploy:

```bash
bundle exec rake acelerachat:monitoring:check
```

Depois do deploy:

```bash
bundle exec rake acelerachat:monitoring:test
```

O operador deve confirmar no painel Sentry o evento com o SHA do release e
configurar alertas de primeira ocorrência, regressão e aumento de volume. O DSN
é configuração de produção; token administrativo do Sentry não é necessário no
aplicativo.

## Autosserviço do Nemmo

Administradores configuram as ferramentas no próprio assistente:

- captura de nome, telefone, e-mail e empresa;
- agenda de demonstração com especialista da conta;
- avisos e consultas de pagamento com equipe financeira da conta.

Os seletores são isolados por conta no frontend e no backend. A ativação sem
dependência obrigatória é rejeitada. Agentes comuns têm visualização sem poder
alterar a configuração.

Agenda e financeiro são internos e auditáveis. Integrações externas com
calendário, CRM, ERP ou meio de pagamento continuam uma etapa separada e não
podem ser simuladas pelo modelo.

## Ordem de corte

1. Gerar as caixas e registros DNS do domínio próprio.
2. Criar os projetos Sentry e copiar apenas os DSNs.
3. Instalar os segredos no arquivo de produção protegido.
4. Executar `acelerachat:release:preflight`.
5. Fazer backup PostgreSQL validado.
6. Implantar a imagem pelo SHA completo. O script repete os gates de e-mail e
   monitoramento com a imagem imutável, antes do marcador de bootstrap e de
   qualquer operação persistente.
7. Executar os testes controlados de e-mail e Sentry.
8. Validar uma alteração de ferramentas do Nemmo com um administrador e a
   negação da mesma alteração com um agente comum.
9. Encerrar a janela de rollback somente após os três smokes passarem.

## Caixa de entrada de suporte

A caixa `Suporte AI Food Manager` (ID `16`) usa a integração nativa:

```dotenv
EMAIL=suporte@aifoodmanager.pro
IMAP_ADDRESS=imap.hostinger.com
IMAP_PORT=993
IMAP_ENABLE_SSL=true
IMAP_AUTHENTICATION=login
SMTP_ADDRESS=smtp.hostinger.com
SMTP_PORT=465
SMTP_DOMAIN=aifoodmanager.pro
SMTP_ENABLE_SSL_TLS=true
SMTP_ENABLE_STARTTLS_AUTO=false
SMTP_OPENSSL_VERIFY_MODE=peer
SMTP_AUTHENTICATION=login
```

As duas senhas do canal são gravadas somente depois de confirmar que
`ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`,
`ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` e
`ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` estão presentes em produção.
O endpoint administrativo informa apenas se cada credencial está configurada;
ele nunca devolve o valor da senha ao navegador. Atualizações sem uma nova
senha preservam a credencial existente e continuam validando a conexão com o
valor armazenado.

A credencial atual da caixa ID `16` deve ser preservada. Por decisão explícita
do operador, esta entrega não pode rotacionar nem alterar automaticamente a
senha no provedor, no AceleraChat ou no secret store. A senha permanece
armazenada fora do Git e a decisão de mantê-la fica registrada como risco
operacional aceito para este corte.
O Sidekiq consulta o IMAP a cada minuto. O smoke envia uma mensagem externa
para a caixa, confirma a criação da conversa e responde pela própria conversa.
