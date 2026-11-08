# Disco cheio no ledger-db

## Quando usar

- O alerta de disco do `ledger-db` tocou e você está de plantão no Livro-razão.
- O log do `ledger-db` mostra `No space left on device`, ou o `ledgerwriter` não consegue gravar transações.

## Antes de começar

- Avise no #livro-razao que você está olhando o alerta. Uma linha basta.
- Não apague transação. O livro-razão só cresce, e é dele que saem o saldo e o extrato. Um `DELETE` em `TRANSACTIONS` é ignorado em silêncio pela regra `PREVENT_DELETE`, como conta o [ADR 3](../adr/0003-um-banco-por-dominio.md). Um `TRUNCATE` passa por cima dessa regra e apaga o livro-razão inteiro.
- Não rode `VACUUM FULL`. Ele trava as gravações do `ledgerwriter` enquanto reescreve a tabela e precisa de espaço livre do tamanho dela.
- Os comandos abaixo usam o `ledger-db` do ambiente local, onde os números são pequenos demais para decidir alguma coisa e servem só para ensaiar. Em produção, rode as mesmas consultas com o acesso de banco do incidente, que vence no fim do dia. A página Segurança e acesso a produção, no Notion, explica esse acesso.

## Passos

**1. Meça o tamanho do banco e veja o que cresceu.** Cole a saída no #livro-razao.

```bash
docker compose exec ledger-db psql -U admin -d postgresdb -c "
  SELECT pg_size_pretty(pg_database_size(current_database())) AS banco,
         pg_size_pretty(pg_relation_size('transactions')) AS tabela,
         pg_size_pretty(pg_indexes_size('transactions')) AS indices,
         round(pg_indexes_size('transactions')::numeric / nullif(pg_relation_size('transactions'), 0), 2) AS indices_por_tabela,
         (SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir()) AS wal"
```

**2. Se `wal` é a maior parte do disco**, não foi o livro-razão que cresceu. O Postgres não está conseguindo descartar o WAL, e isso costuma ser backup ou réplica parados. Isso é de Plataforma: chame o time no #plataforma-ajuda com a saída do passo 1. Não apague arquivo do WAL à mão.

**3. Se `indices_por_tabela` passa de 1,5**, refaça os dois índices por conta. Cada transação entra no meio deles, na posição da conta, e eles incham com o tempo. Refeitos, ficam em torno de 1,3 vez a tabela. A chave primária cresce em ordem e não precisa ser refeita.

Veja o tamanho de cada índice. Refazer um índice pede espaço livre no disco do tamanho dele, porque a cópia nova é construída antes de a antiga sair.

```bash
docker compose exec ledger-db psql -U admin -d postgresdb -c "\di+ transactions*"
```

Refaça um índice por vez. O `CONCURRENTLY` refaz o índice sem travar as gravações do `ledgerwriter`.

```bash
docker compose exec ledger-db psql -U admin -d postgresdb -c "REINDEX INDEX CONCURRENTLY transactions_from_acct_from_route_timestamp_idx"
docker compose exec ledger-db psql -U admin -d postgresdb -c "REINDEX INDEX CONCURRENTLY transactions_to_acct_to_route_timestamp_idx"
```

Se um desses comandos falhar no meio, sobra um índice inválido com o nome terminado em `_ccnew`, que também ocupa disco. Apague esse índice com `DROP INDEX CONCURRENTLY` e o nome dele antes de tentar de novo.

**4. Se foi a tabela que cresceu**, não há o que apagar. Peça mais disco para o `ledger-db` no #plataforma-ajuda, com a saída do passo 1.

## Como saber que deu certo

- O disco do `ledger-db` volta para baixo do alerta.
- Se você refez os índices, a medição do passo 1, rodada de novo, mostra `indices` menor.
- O `ledgerwriter` volta a gravar. Cada transferência nova aparece no log dele como `Submitted transaction successfully`, e o `No space left on device` some:

```bash
docker compose logs --since 10m ledgerwriter | grep -E "Submitted transaction successfully|No space left on device"
```

No ambiente local, sem ninguém transferindo, esse comando não mostra nada.

Depois, diga no #livro-razao se houve impacto para cliente e deixe o registro no histórico de incidentes do time, com os números do passo 1. Se você precisou fazer algo que não está aqui, acrescente a este runbook.

## Quem chamar

Livro-razão, no #livro-razao-ajuda. Se os passos não resolvem em meia hora, ou se um cliente já ficou sem conseguir transferir, chame o tech lead do Livro-razão, como manda a página Incidentes, no Notion.

Mais disco e o WAL são de Plataforma, no #plataforma-ajuda.
