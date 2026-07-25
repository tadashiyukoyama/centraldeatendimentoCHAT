# Cliente Acelera Control

## Objetivo

Substituir toda comunicação operacional com o antigo Hub por um contrato AceleraChat opt-in, autenticado e com falha segura. Os nomes internos `ChatwootHub`, `enterprise` e as chaves legadas permanecem por compatibilidade; nenhum deles define um destino externo.

## Estado padrão

O cliente fica desativado por padrão. Sem configuração completa:

- nenhum heartbeat é enviado;
- o plano e os recursos persistidos localmente são preservados;
- registro de onboarding e telemetria não enviam dados;
- relay externo de push fica indisponível;
- changelog externo fica vazio;
- cobrança e suporte externos não são renderizados.

## Configuração

```dotenv
ACELERA_CONTROL_ENABLED=false
ACELERA_CONTROL_URL=
ACELERA_CONTROL_TOKEN=
ACELERA_CONTROL_PUBLIC_KEY=
ACELERA_CONTROL_INCLUDE_USAGE=false
ACELERA_BILLING_PORTAL_URL=
```

O cliente somente é habilitado quando `ACELERA_CONTROL_ENABLED=true` e URL, token e chave pública são válidos. A URL deve usar HTTPS, não pode conter credenciais e não pode pertencer a `chatwoot.com`, `chatwoot.help` ou `chwt.app`.

Em arquivos dotenv de linha única, a chave PEM pode usar `\n` escapado. Tokens e chaves nunca devem ser versionados.

## Heartbeat

Endpoint:

```text
POST /v1/instances/heartbeat
Authorization: Bearer <token da instância>
Content-Type: application/json
```

Payload mínimo:

```json
{
  "instance_id": "uuid persistido",
  "app_version": "4.15.1",
  "source_sha": "sha da imagem",
  "deployment_env": "docker",
  "edition": ""
}
```

O domínio público da instalação, contas, contatos, mensagens e conteúdo não são enviados. Quando `ACELERA_CONTROL_INCLUDE_USAGE=true` e `DISABLE_TELEMETRY` não está ativo, somente `active_users_count` é acrescentado.

Timeouts:

- conexão: 3 segundos;
- resposta: 5 segundos.

Indisponibilidade, timeout ou resposta inválida retornam um resultado vazio. O job não apaga nem rebaixa o último plano persistido durante o período de tolerância assinado.

## Envelope assinado

O Control deve responder:

```json
{
  "payload": "base64(JSON UTF-8)",
  "signature": "base64(assinatura dos bytes exatos de payload)"
}
```

O cliente aceita RSA/ECDSA com SHA-256 e Ed25519/Ed448 conforme o tipo da chave pública configurada. A assinatura é validada antes de interpretar ou persistir qualquer permissão.

Exemplo do JSON interno de `payload`:

```json
{
  "instance_id": "uuid persistido",
  "plan_code": "pro",
  "seat_limit": 25,
  "status": "active",
  "expires_at": "2026-08-25T12:00:00Z",
  "grace_until": "2026-09-01T12:00:00Z",
  "features": ["audit_logs", "nemmo"],
  "latest_release": {
    "version": "5.0.0",
    "sha": "sha da release"
  },
  "support": {
    "base_url": "https://suporte.acelerachat.example",
    "website_token": "token",
    "identifier_hash": "hash"
  }
}
```

Validações obrigatórias:

- assinatura válida;
- `instance_id` idêntico ao da instalação;
- plano reconhecido;
- limite de assentos inteiro e não negativo;
- `grace_until` ainda válido;
- features com formato estrito;
- suporte somente por HTTPS e fora dos domínios antigos.

O plano público `pro` é mapeado para o valor interno `enterprise`, preservando a lógica existente. Quando o gerenciamento está ativado, o plano local continua válido até `grace_until`; depois desse instante a aplicação passa para `community` e limite zero até receber um novo entitlement válido. Com o Control desativado, o plano local atual continua sendo a fonte de verdade.

## Persistência compatível

Após validação, o job mantém as chaves internas existentes:

- `INSTALLATION_PRICING_PLAN`;
- `INSTALLATION_PRICING_PLAN_QUANTITY`;
- `CHATWOOT_SUPPORT_WEBSITE_TOKEN`;
- `CHATWOOT_SUPPORT_IDENTIFIER_HASH`;
- `CHATWOOT_SUPPORT_SCRIPT_URL`.

Metadados próprios são gravados em:

- `ACELERA_CONTROL_ENTITLEMENTS`;
- `ACELERA_CONTROL_STATUS`;
- `ACELERA_CONTROL_EXPIRES_AT`;
- `ACELERA_CONTROL_GRACE_UNTIL`;
- `ACELERA_CONTROL_RELEASE_SHA`.

Campos ausentes em uma resposta válida não apagam os valores persistidos. Respostas sem assinatura ou com plano desconhecido são ignoradas.

## Marca e plano

O reconciliador pode desativar recursos premium quando recebe um downgrade válido para `community`, mas não pode restaurar nome, logo, URLs, termos ou privacidade antigos. A marca AceleraChat é independente do plano comercial.

## Push, suporte, cobrança e changelog

- Push mobile deve usar Firebase configurado diretamente na instância.
- `ENABLE_PUSH_RELAY_SERVER` permanece apenas como chave de compatibilidade e não habilita relay.
- O widget de suporte só é renderizado quando URL HTTPS, token e hash estão presentes.
- O botão de cobrança só aparece com `ACELERA_BILLING_PORTAL_URL` válido.
- `CHANGELOG_URL` inicia vazio e poderá apontar para o feed próprio quando ele existir.

## Rito de ativação futura

1. Implementar e homologar o servidor Acelera Control.
2. Gerar par de chaves de assinatura fora da instância.
3. Guardar a chave privada somente no Control e distribuir apenas a pública.
4. Emitir token individual revogável por instância.
5. Testar assinatura válida, adulterada, instância errada, timeout, expiração e tolerância.
6. Configurar as variáveis no secret store.
7. Ativar primeiro em homologação.
8. Confirmar egress somente para o domínio aprovado.
9. Fazer deploy por SHA com rollback.
10. Ativar em produção e auditar o primeiro heartbeat sem dados pessoais.

Enquanto esse rito não for concluído, `ACELERA_CONTROL_ENABLED` deve permanecer `false`.

## Gate de qualidade

O workflow `.github/workflows/acelera-control-check.yml` executa um único job direcionado nesta branch. Ele valida somente os arquivos e contratos desta frente:

- RuboCop dos arquivos Ruby alterados;
- specs do cliente, facade de compatibilidade, job, reconciliação, push e onboarding;
- lint dos arquivos JavaScript/Vue alterados;
- teste do changelog sem comunicação externa.

O gate não constrói imagem e não realiza deploy. O SHA aprovado deve ser registrado antes de qualquer etapa de produção.
