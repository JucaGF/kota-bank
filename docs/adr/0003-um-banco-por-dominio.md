# ADR-0003: Um banco por domínio

- Status: aceito
- Data: 2024-06
- Time: Plataforma
- RFC: https://lean-ptarmigan-dd2.notion.site/412bd621283f81b38df0d494a6872d6c

## Contexto

Ao sair do monolito (ADR 1), o livro-razão precisou de um banco novo, porque o antigo vivia na mesma máquina do `ledgermonolith`. O mais simples de operar era criar a tabela de transações no Postgres que o time de Contas já usava, com uma instância só para backup, monitoramento e atualização. A Nádia Saliba propôs o contrário no RFC 2.

## Decisão

Cada domínio tem o seu Postgres, e só os serviços do domínio conectam nele:

- `accounts-db`, do time de Contas, com as tabelas `users` e `contacts`. Só o `userservice` e o `contacts` conectam (`ACCOUNTS_DB_URI`).
- `ledger-db`, do Livro-razão, com a tabela `TRANSACTIONS`. Só os serviços do livro-razão conectam (`SPRING_DATASOURCE_URL`).

Quem precisa de dado de outro domínio pede pela API, com o JWT do cliente. Nenhum serviço lê o banco de outro time.

## Consequências

- Cada banco segue as regras do seu domínio. O `ledger-db` só aceita inserção, porque as regras `PREVENT_UPDATE` e `PREVENT_DELETE` ignoram em silêncio qualquer `UPDATE` ou `DELETE` em `TRANSACTIONS`. O `accounts-db` atualiza cadastro normalmente.
- O `ledgerwriter` não confere se a conta de destino existe, porque não enxerga o `accounts-db`. O `TransactionValidator` só valida o formato da conta e da agência, se quem envia é o dono do token, se origem e destino são diferentes e se o valor é positivo.
- São dois bancos para fazer backup, monitorar e migrar. O `ledger-db` só cresce, e quando ele enche o caminho é o runbook do `ledger-db` cheio.

## Onde ver no código

- `src/accounts/accounts-db`
- `src/ledger/ledger-db`
