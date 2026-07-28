# Política de credenciais

- Nenhum valor de segredo em Git, logs, screenshots, testes ou relatórios.
- Senhas, tokens, chaves e DSNs reais ficam somente em
  `credenciais/`, na raiz externa do workspace, ou em secret store autorizado.
- Arquivos de ambiente reais que contenham credenciais também ficam em
  `credenciais/`. `private/` fica reservado para recuperação e outros dados
  sensíveis que não sejam credenciais de acesso.
- A existência de uma credencial não autoriza seu uso.
- Não descriptografar cofres nem materializar chaves privadas durante auditoria.
- Rotacionar uma credencial exposta antes de reutilizá-la.
- Backups do PostgreSQL são dados sensíveis e ficam fora do clone.
