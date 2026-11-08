# ledger-db

<!-- kota:servico:inicio -->

**Time:** Livro-razão (#livro-razao)

**Responsáveis:** Thiago Nakamura (tech lead), Natália Brandão (gestor)

**Depende de:** nada

**Como rodar:** `docker compose up --build ledger-db`

**Como testar:** sem testes automatizados

<!-- kota:servico:fim -->

<!-- Modificado pela Kota a partir do original (Apache-2.0). -->

## O que faz

É o Postgres do Livro-razão. Guarda todas as transações da Kota na tabela `TRANSACTIONS`, e é dela que saem o saldo e o extrato. Só os serviços do livro-razão conectam nele.

## Como funciona

A imagem é a `postgres:16.15-alpine` com os dois scripts de `initdb/`. O Postgres roda os scripts só quando o volume de dados está vazio.

- `0_init_tables.sql` cria a tabela `TRANSACTIONS`, um índice pela conta e agência de origem, outro pela conta e agência de destino e as regras `PREVENT_UPDATE` e `PREVENT_DELETE`.
- `1_create_transactions.sh` grava as transações de demonstração em três períodos. Em cada período, cada conta de demonstração recebe um depósito de 2.500,00 de outra agência, e as contas fazem de 15 a 20 transferências entre si. Diferente do `accounts-db`, este script grava as transações com qualquer valor de `USE_DEMO_DATA` que não seja vazio, inclusive `False`.

Cada transação tem a conta e a agência de origem, a conta e a agência de destino, o valor em centavos (`AMOUNT`) e a data e hora. O `TRANSACTION_ID` só cresce. O `balancereader` e o `transactionhistory` usam o maior id para saber se há transação nova, e um banco restaurado com um id menor faz os dois pararem de ler.

O livro-razão só aceita inserção. As regras `PREVENT_UPDATE` e `PREVENT_DELETE` trocam qualquer `UPDATE` ou `DELETE` em `TRANSACTIONS` por nada, sem dar erro. Uma correção entra como transação nova. Um `TRUNCATE` passa por cima das regras e apaga o livro-razão inteiro.

Os números de conta das transações de demonstração são os dos clientes que o `initdb` do `accounts-db` cria. Mudar um número pede mudar os dois scripts. Como os scripts só rodam com o volume vazio, mudar o `initdb/` não muda um banco que já subiu. Para recriar o banco, siga o runbook [Subir o ambiente local do zero](../../../docs/runbooks/subir-do-zero.md).

O banco só cresce. Quando o disco enche, siga o runbook [Disco cheio no ledger-db](../../../docs/runbooks/ledger-db-cheio.md).

No ambiente local, o banco não tem porta aberta na máquina. Para consultar, entre pelo container:

```bash
docker compose exec ledger-db psql -U admin -d postgresdb
```

## Variáveis de ambiente

Os valores do ambiente local ficam no [`docker-compose.yml`](../../../docker-compose.yml).

| Variável | O que é |
|---|---|
| `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | Nome do banco, usuário e senha que o Postgres cria na primeira subida. |
| `USE_DEMO_DATA` | Vazia, o banco sobe sem as transações de demonstração. Qualquer outro valor grava as transações. |
| `LOCAL_ROUTING_NUM` | Número da agência da Kota, gravado nas transações de demonstração. |

## Decisões

- [ADR 1: Quebrar o monolito do livro-razão em três serviços](../../../docs/adr/0001-quebrar-o-monolito-do-livro-razao-em-tres-servicos.md). A tabela `TRANSACTIONS` saiu da máquina do `ledgermonolith`, e os três serviços do livro-razão passaram a ler e gravar nela.
- [ADR 3: Um banco por domínio](../../../docs/adr/0003-um-banco-por-dominio.md). O livro-razão tem um Postgres só dele, separado do `accounts-db`, e só aceita inserção.
- [ADR 5: Python em Contas e Canais, Java no Livro-razão](../../../docs/adr/0005-python-em-contas-e-canais-java-no-livro-razao.md). Os serviços que usam este banco são Java. Aqui só há SQL e shell, nos scripts de `initdb/`.
