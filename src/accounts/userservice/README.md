# userservice

<!-- kota:servico:inicio -->

**Time:** Contas (#contas)

**Responsáveis:** Rodrigo Queiroz (tech lead), Camila Azevedo (gestor)

**Depende de:** accounts-db

**Como rodar:** `docker compose up --build userservice`

**Como testar:** `scripts/testar.sh userservice`

<!-- kota:servico:fim -->

<!-- Modificado pela Kota a partir do original (Apache-2.0). -->

## O que faz

Cadastra os clientes e faz o login. É o único serviço que emite o JWT que os outros serviços conferem. Os clientes ficam na tabela `users` do `accounts-db`.

## Como funciona

No cadastro (`POST /users`), o `userservice` confere que todos os campos vieram preenchidos, que o usuário tem de 2 a 15 letras, números ou `_` e que as duas senhas são iguais. Depois guarda a senha só como hash bcrypt e sorteia um número de conta de 10 dígitos que nenhuma outra conta tem.

No login (`GET /login`, com usuário e senha na query string), ele confere a senha com bcrypt e assina um JWT RS256 com a chave privada. O token leva `user`, `acct`, `name`, `iat` e `exp` e vale por `TOKEN_EXPIRY_SECONDS`. No `docker-compose.yml`, isso dá uma hora.

O `userservice` lê a chave privada e a pública uma vez, na subida. Trocar o par pede reiniciar este serviço e todos os que conferem o token, como mostra o runbook [Trocar o par de chaves do JWT](../../../docs/runbooks/trocar-chave-jwt.md).

## Rotas

| Rota | Método | Pede token | O que faz |
|---|---|---|---|
| `/users` | POST | | Cadastra o cliente. Responde 201, 400 para campo faltando ou inválido e 409 para usuário que já existe. |
| `/login` | GET | | Confere usuário e senha e devolve `{"token": "..."}`. Responde 404 para usuário que não existe e 401 para senha errada. |
| `/ready` | GET | | Responde `ok`. |
| `/version` | GET | | Devolve o valor de `VERSION`. |

## Variáveis de ambiente

Os valores do ambiente local ficam no [`docker-compose.yml`](../../../docker-compose.yml).

| Variável | O que é |
|---|---|
| `PRIV_KEY_PATH` | Caminho da chave privada que assina o JWT. |
| `PUB_KEY_PATH` | Caminho da chave pública do mesmo par. |
| `TOKEN_EXPIRY_SECONDS` | Validade do token, em segundos. |
| `ACCOUNTS_DB_URI` | URI completa do `accounts-db`, com usuário e senha. |
| `VERSION`, `PORT`, `LOG_LEVEL` | Versão que o `/version` devolve, porta do gunicorn e nível do log. |
| `ENABLE_TRACING` | Com `true`, liga os traces. Sem ela, o serviço não sobe. O compose usa `false`. |

## Decisões

- [ADR 2: JWT assinado pelo userservice e validado em cada serviço](../../../docs/adr/0002-jwt-assinado-pelo-userservice-e-validado-em-cada-servico.md). Só o `userservice` emite token, e cada serviço confere o token sozinho, com a chave pública.
- [ADR 5: Python em Contas e Canais, Java no Livro-razão](../../../docs/adr/0005-python-em-contas-e-canais-java-no-livro-razao.md). O serviço é de Contas e por isso é Python, com Flask e gunicorn.
