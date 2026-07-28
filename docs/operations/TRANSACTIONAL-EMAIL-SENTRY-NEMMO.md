# Fundação operacional: e-mail, monitoramento e Nemmo

## Rastreabilidade

- SHA-base da implementação: `4204f4147f1a9b43c9740d2d739ef843d5ead817`.
- Um único push deve publicar o SHA final aprovado.
- Build e deploy devem usar a tag com o SHA completo.
- O rollback permanece apontado para a imagem ativa registrada antes do corte.

## E-mail transacional

O remetente público deve ser de domínio próprio da AceleraChat. Uma caixa de
outro produto ou de um cliente não pode ser reutilizada como remetente global.

Configuração mínima:

```dotenv
MAILER_SENDER_EMAIL=AceleraChat <no-reply@meugerenciador.pro>
SMTP_DOMAIN=meugerenciador.pro
SMTP_ADDRESS=<servidor SMTP>
SMTP_PORT=<porta>
SMTP_USERNAME=no-reply@meugerenciador.pro
SMTP_PASSWORD=<segredo>
SMTP_AUTHENTICATION=login
SMTP_ENABLE_STARTTLS_AUTO=true
SMTP_OPENSSL_VERIFY_MODE=peer
MAILER_DKIM_SELECTOR=<seletor>
PRIVACY_CONTACT_EMAIL=privacidade@meugerenciador.pro
SUPPORT_CONTACT_EMAIL=suporte@meugerenciador.pro
```

O provedor pode exigir TLS implícito na porta 465. Nesse caso:

```dotenv
SMTP_ENABLE_STARTTLS_AUTO=false
SMTP_SSL=true
```

Antes do deploy:

```bash
bundle exec rake acelerachat:email:check
```

O gate autentica no SMTP sem enviar mensagem e sem imprimir credenciais,
verifica um único modo de transporte seguro, coerência do domínio, MX, SPF,
DKIM por TXT ou CNAME e DMARC. Depois do deploy, um administrador executa um
único envio controlado:

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
