# Segredos, banco e dados sensíveis

## Onde cada coisa fica

| Dado | Desenvolvimento local | Produção |
|---|---|---|
| Env real do Chatwoot | `private/env/chatwoot.local.env` | secret store ou `/opt/centraldeatendimentoCHAT/private/env/chatwoot.production.env` |
| Chaves/certificados | `private/credentials/` | secret store/ACL restrita do host |
| PostgreSQL vivo | `runtime/data/postgres/` | volume dedicado fora do clone |
| Redis vivo | `runtime/data/redis/` | volume dedicado fora do clone |
| Uploads/Active Storage | `runtime/data/storage/` | volume dedicado ou S3 compatível |
| Dump e checksum | `private/recovery/database/` | armazenamento privado de backup |
| Exemplo de configuração | `infra/env/*.example` | não usar diretamente em produção |

## Segredos da Evolution API

- A chave global fica somente no env privado do Chatwoot.
- Token de instância e segredo de webhook ficam em colunas criptografadas no
  PostgreSQL do Chatwoot.
- O `provider_config` guarda apenas a referência ao provisionamento.
- QR Code, pairing code, `apikey`, segredo JWT e mídia em base64 não podem ser
  persistidos em logs, artifacts ou memória do Codex.
- Active Record Encryption é obrigatório antes de habilitar a integração.

## Regras

1. `.env` real nunca entra no GitHub.
2. A existência de uma credencial não autoriza seu uso.
3. Segredos não podem aparecer em logs, testes, screenshots, relatórios ou mensagens.
4. Credencial exposta deve ser rotacionada antes de qualquer reutilização.
5. Backups de conversas e contatos são dados sensíveis e seguem a mesma proteção dos segredos operacionais.
6. Em CI/CD, usar secrets/environments do GitHub e nunca escrever o valor no output.
7. Em produção, o arquivo de ambiente deve ser montado no host e somente lido pelo Compose autorizado.

## Rotação e incidente

Em suspeita de exposição, interromper o uso, registrar apenas o identificador do
segredo, revogar/rotacionar pela autoridade responsável, atualizar o manifesto
sem valor, revisar logs e só então reabilitar o serviço. Não copiar o segredo
para a documentação para provar a correção.
