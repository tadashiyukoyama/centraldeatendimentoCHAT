# Operação do WhatsApp nativo por QR Code

## Estado

O código desta integração foi preparado em branch isolada. Este documento não
prova instalação da Evolution API, migration executada, configuração da VPS ou
deploy. Esses fatos só podem ser declarados após os respectivos gates e
evidências operacionais.

Arquitetura canônica:
[`docs/architecture/NATIVE-EVOLUTION-WHATSAPP.md`](../architecture/NATIVE-EVOLUTION-WHATSAPP.md).

## Pré-requisitos

- Evolution API `2.3.7` no contrato atualmente validado;
- um domínio HTTPS dedicado, previsto como
  `evolution.meugerenciador.pro`;
- uma única instalação multi-instância;
- PostgreSQL e Redis próprios da Evolution, criados e persistidos pelo ICP;
- Evolution sem a integração Chatwoot embutida;
- Chatwoot com Active Record Encryption configurado;
- backup válido do banco Chatwoot antes da migration em ambiente com dados;
- autorização separada para alterar infraestrutura, executar migration e
  realizar deploy.

## Variáveis do Chatwoot

```dotenv
EVOLUTION_API_ENABLED=true
EVOLUTION_API_URL=https://evolution.example.com
EVOLUTION_API_KEY=<segredo-global>

# Opcionais: proteção adicional do ingresso Evolution.
EVOLUTION_API_BASIC_AUTH_USER=<usuario>
EVOLUTION_API_BASIC_AUTH_PASSWORD=<senha>
```

Também são obrigatórias:

```dotenv
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<segredo>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<segredo>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<segredo>
FRONTEND_URL=https://chatwoot.example.com
```

Nenhum valor real deve ser colocado no Git, output de workflow ou relatório.

## Gate de ativação

1. Confirmar backup e política de rollback aplicável ao banco atual.
2. Confirmar SHA da aplicação e imagem imutável autorizada.
3. Validar DNS e TLS do Chatwoot e da Evolution, sem `--insecure`.
4. Validar que PostgreSQL e Redis da Evolution são dedicados e persistentes.
5. Confirmar que a integração Chatwoot embutida na Evolution está desativada.
6. Confirmar o segredo global por leitura segura, sem imprimi-lo.
7. Executar migration e registrar seu resultado.
8. Configurar as variáveis reais no secret store/arquivo root-owned.
9. Fazer deploy pelo workflow versionado.
10. Executar o smoke controlado abaixo.

## Smoke controlado

Usar um número de teste autorizado:

1. abrir `Nova caixa de entrada > WhatsApp`;
2. selecionar `WhatsApp via QR Code`;
3. criar a sessão e verificar que o QR aparece sem chave, URL ou nome interno;
4. confirmar em teste automatizado que um webhook de QR ou conexão recebido
   antes da resposta de criação não causa `ActiveRecord::StaleObjectError` nem
   regride o estado do provisionamento;
5. confirmar que todos os eventos de QR e conexão terminaram como
   `processed` ou `ignored`, sem evento `failed` e sem retry pendente;
6. escanear o QR e confirmar a criação de uma única caixa com o número real;
7. enviar texto para o número e confirmar contato, conversa e mensagem;
8. responder pelo Chatwoot e confirmar `source_id`, envio e status;
9. testar uma mídia pequena nos dois sentidos;
10. confirmar que evento repetido não duplica a mensagem;
11. desconectar e reconectar sem criar uma segunda caixa;
12. cancelar uma sessão QR não concluída e comprovar a remoção remota;
13. procurar `apikey`, `jwt_key`, `token`, `secret`, `qrcode`, `pairingCode`,
    `base64` e envelopes `evolution` nos logs, filas e retries;
14. confirmar que não restou job órfão após cancelar a sessão;
15. confirmar saúde de Rails, Sidekiq, Chatwoot PostgreSQL/Redis e dos três
    serviços dedicados da Evolution.

O smoke não deve usar número de cliente, campanha, conteúdo pessoal ou caixa
real sem autorização específica.

## Falhas e resposta

| Sintoma                 | Verificação                                    | Ação segura                                       |
| ----------------------- | ---------------------------------------------- | ------------------------------------------------- |
| QR não aparece          | feature flag, URL/TLS e saúde da Evolution     | corrigir contrato; não expor a chave ao navegador |
| QR expira               | estado e `expires_at`                          | cancelar e criar um novo provisionamento          |
| conecta sem criar caixa | `connection.update`, `wuid` e `fetchInstances` | manter fail-closed; não cadastrar número fictício |
| entrada não chega       | assinatura JWT, evento e Sidekiq               | corrigir webhook; não desativar autenticação      |
| mídia falha             | tamanho, tipo e endpoint de base64             | registrar apenas erro sanitizado                  |
| saída falha             | token da instância e estado da sessão          | não substituir pelo segredo global no canal       |
| duplicidade             | chave em `whatsapp_evolution_events`           | preservar idempotência; não apagar ledger         |
| QR falha após criação   | `lock_version`, ordem do webhook e resposta    | preservar estado avançado e compensação remota    |
| evento QR falha no job  | concorrência, eventos `failed` e retries       | serializar transições; remover payload órfão       |
| segredo aparece em fila | payload aninhado e argumentos do Active Job    | bloquear deploy; sanitizar antes do enqueue        |

## Rollback

Rollback de imagem não desfaz a migration. Antes do primeiro deploy desta
integração, o plano deve definir uma das duas estratégias:

- manter as tabelas sem uso, com `EVOLUTION_API_ENABLED=false`; ou
- executar migration reversa somente com backup, janela e autorização
  específicos.

Desativar a flag impede novos provisionamentos, mas não deve ser usado como
substituto para encerrar sessões existentes. A remoção de uma caixa Evolution
deve passar pelo teardown para logout e exclusão remota.
