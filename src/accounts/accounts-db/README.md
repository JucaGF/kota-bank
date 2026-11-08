# accounts-db

<!-- kota:servico:inicio -->

**Time:** Contas (#contas)

**Responsáveis:** Rodrigo Queiroz (tech lead), Camila Azevedo (gestor)

**Depende de:** nada

**Como rodar:** `docker compose up --build accounts-db`

**Como testar:** sem testes automatizados

<!-- kota:servico:fim -->

<!-- Modificado pela Kota a partir do original (Apache-2.0). -->

## O que faz

É o Postgres do time de Contas. Guarda os clientes, na tabela `users`, e os contatos de cada um, na tabela `contacts`. Só o `userservice` e o `contacts` conectam nele.

## Como funciona

A imagem é a `postgres:16.15-alpine` com os dois scripts de `initdb/`. O Postgres roda os scripts só quando o volume de dados está vazio.

- `0-accounts-schema.sql` cria as tabelas `users` e `contacts` e os índices por número de conta e por usuário.
- `1-load-testdata.sh` carrega os clientes de demonstração quando `USE_DEMO_DATA` é `True`. São quatro clientes, um deles o `cliente.demo`, todos contatos uns dos outros. Cada um também tem uma conta de outra agência salva para depositar.

A senha de cada cliente fica só como hash bcrypt, na coluna `passhash`. O hash da senha de demonstração está escrito no `1-load-testdata.sh`, junto com o comando que o gera. Se a senha de demonstração mudar no `docker-compose.yml`, gere o hash de novo.

Os números de conta dos clientes de demonstração se repetem no `initdb` do `ledger-db`, que grava as transações deles. Mudar um número pede mudar os dois scripts.

Como os scripts só rodam com o volume vazio, mudar o `initdb/` não muda um banco que já subiu. Para recriar o banco, siga o runbook [Subir o ambiente local do zero](../../../docs/runbooks/subir-do-zero.md).

No ambiente local, o banco não tem porta aberta na máquina. Para consultar, entre pelo container:

```bash
docker compose exec accounts-db psql -U accounts-admin -d accounts-db
```

## Variáveis de ambiente

Os valores do ambiente local ficam no [`docker-compose.yml`](../../../docker-compose.yml).

| Variável | O que é |
|---|---|
| `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | Nome do banco, usuário e senha que o Postgres cria na primeira subida. |
| `USE_DEMO_DATA` | Com `True`, carrega os clientes de demonstração. |
| `LOCAL_ROUTING_NUM` | Número da agência da Kota, gravado nos contatos de demonstração que são contas da Kota. |

## Decisões

- [ADR 3: Um banco por domínio](../../../docs/adr/0003-um-banco-por-dominio.md). Cada domínio tem o seu Postgres, e nenhum serviço do Livro-razão lê este banco. Por isso o `ledgerwriter` não confere se a conta de destino existe.
- [ADR 5: Python em Contas e Canais, Java no Livro-razão](../../../docs/adr/0005-python-em-contas-e-canais-java-no-livro-razao.md). Os serviços que usam este banco são Python. Aqui só há SQL e shell, nos scripts de `initdb/`.
