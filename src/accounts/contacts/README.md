# contacts

<!-- kota:servico:inicio -->

**Time:** Contas (#contas)

**Responsáveis:** Rodrigo Queiroz (tech lead), Camila Azevedo (gestor)

**Depende de:** accounts-db

**Como rodar:** `docker compose up --build contacts`

**Como testar:** `scripts/testar.sh contacts`

<!-- kota:servico:fim -->

<!-- Modificado pela Kota a partir do original (Apache-2.0). -->

## O que faz

Guarda os contatos de cada cliente: contas da Kota para onde ele transfere e contas de outras agências de onde ele deposita. O site mostra essa lista nos formulários de transferência e de depósito. Os contatos ficam na tabela `contacts` do `accounts-db`.

## Como funciona

Todo pedido traz o JWT do cliente. O `contacts` confere a assinatura com a chave pública e compara o usuário da URL com o `user` do token, como decide o [ADR 2](../../../docs/adr/0002-jwt-assinado-pelo-userservice-e-validado-em-cada-servico.md). Um pedido para outro usuário recebe 401.

Um contato novo precisa de:

- Um nome de até 30 caracteres entre letras sem acento, números e espaços, que comece por letra ou número.
- Uma conta de 10 dígitos e uma agência de 9 dígitos.
- O campo `is_external`, que diz se a conta é de outra agência. Uma conta de outra agência não pode ter a agência da Kota.

O `contacts` recusa com 409 a conta do próprio cliente, uma conta que já está na lista e um nome que já está na lista. Ele não confere se a conta do contato existe.

## Rotas

| Rota | Método | Pede token | O que faz |
|---|---|---|---|
| `/contacts/<username>` | GET | sim | Devolve os contatos do cliente. |
| `/contacts/<username>` | POST | sim | Grava um contato novo. Responde 201, 400 para campo faltando ou inválido e 409 para contato repetido. |
| `/ready` | GET | | Responde `ok`. |
| `/version` | GET | | Devolve o valor de `VERSION`. |

## Variáveis de ambiente

Os valores do ambiente local ficam no [`docker-compose.yml`](../../../docker-compose.yml).

| Variável | O que é |
|---|---|
| `PUB_KEY_PATH` | Caminho da chave pública do JWT. O `contacts` lê o arquivo uma vez, na subida. |
| `LOCAL_ROUTING_NUM` | Número da agência da Kota, que uma conta de outra agência não pode ter. |
| `ACCOUNTS_DB_URI` | URI completa do `accounts-db`, com usuário e senha. |
| `VERSION`, `PORT`, `LOG_LEVEL` | Versão que o `/version` devolve, porta do gunicorn e nível do log. |
| `ENABLE_TRACING` | Com `true`, liga os traces. Sem ela, o serviço não sobe. O compose usa `false`. |

## Decisões

- [ADR 5: Python em Contas e Canais, Java no Livro-razão](../../../docs/adr/0005-python-em-contas-e-canais-java-no-livro-razao.md). O serviço é de Contas e por isso é Python, com Flask e gunicorn.
