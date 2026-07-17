# Política de credenciais

- Nenhum valor de segredo em Git, logs, screenshots, testes ou relatórios.
- Valores reais somente em `private/env/`, `private/credentials/` ou secret store autorizado.
- A existência de uma credencial não autoriza seu uso.
- Não descriptografar cofres nem materializar chaves privadas durante auditoria.
- Rotacionar uma credencial exposta antes de reutilizá-la.
- Backups do PostgreSQL são dados sensíveis e ficam fora do clone.
