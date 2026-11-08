# ADR-0002: JWT assinado pelo userservice e validado em cada serviço

- Status: aceito
- Data: 2024-04
- Time: Contas

## Contexto

O monolito do livro-razão já validava o token sozinho. O `JWTVerifierGenerator` dele lia na subida a chave pública (`PUB_KEY_PATH`) e conferia a assinatura que o `userservice` faz com a chave privada. O `frontend` e o `contacts` faziam o mesmo em Python. Esse acordo nunca tinha sido escrito.

Com a quebra do livro-razão em três serviços (ADR 1), o `JWTVerifierGenerator` ia ser copiado para cada um, e a validação passaria a existir em cinco serviços: `frontend`, `contacts`, `ledgerwriter`, `balancereader` e `transactionhistory`. Antes de multiplicar as cópias, o time de Contas pesou as alternativas. Se cada serviço perguntasse ao `userservice` a cada requisição, o login entraria no caminho de todo saldo e todo extrato. Uma chave secreta compartilhada simplificaria a validação, mas qualquer serviço poderia emitir token em nome de qualquer cliente.

## Decisão

Fica o modelo que o monolito já usava, agora registrado. O `userservice` é o único serviço que emite token. No login, ele confere a senha com bcrypt e assina um JWT RS256 com a chave privada (`PRIV_KEY_PATH`). O token leva `user`, `acct`, `name`, `iat` e `exp`, e vale por `TOKEN_EXPIRY_SECONDS`.

Os outros serviços validam o token sozinhos, com a chave pública (`PUB_KEY_PATH`) que leem na subida. Depois de validar, cada um confere se o recurso pedido é do dono do token. O `balancereader` compara a conta da URL com `acct`, e o `contacts` compara o usuário da URL com `user`.

## Consequências

- Com o `userservice` fora do ar, ninguém consegue entrar, mas quem já entrou continua vendo saldo e transferindo até o token vencer.
- Não dá para revogar um token. O logout do site só apaga o cookie, e o token continua válido até o `exp`.
- Trocar o par de chaves derruba todas as sessões e exige reiniciar todos os serviços, porque cada um lê a chave pública só na subida. O passo a passo fica no runbook de troca da chave do JWT.
- A chave privada nunca entra no repositório. Cada ambiente gera o seu par.
- A validação existe em Python (`pyjwt`, no `frontend` e no `contacts`) e em Java (`java-jwt`, no `JWTVerifierGenerator` de cada serviço do livro-razão). Mudar o formato do token mexe nas duas.

## Onde ver no código

- `src/accounts/userservice`
