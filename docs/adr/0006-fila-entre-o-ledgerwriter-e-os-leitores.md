# ADR-0006: Fila entre o ledgerwriter e os leitores

- Status: rejeitado
- Data: 2025-03
- Time: Livro-razão
- RFC: https://lean-ptarmigan-dd2.notion.site/412bd621283f81a8be92e7b599b0c691

## Contexto

Cada instância do `balancereader` e do `transactionhistory` pergunta ao `ledger-db` o maior `transactionId` a cada 100 ms (ADR 4). O Gustavo Schmitt propôs no RFC 3 trocar essa consulta por uma fila de eventos de transação. O `ledgerwriter` publicaria cada transação gravada, e os leitores consumiriam a fila para atualizar o cache. A ideia era tirar a consulta periódica do banco e atualizar o saldo sem esperar o próximo ciclo.

## Decisão

Rejeitada. Os leitores continuam lendo o `ledger-db` por consulta periódica, como no ADR 4. Os motivos:

- A tabela `TRANSACTIONS` já funciona como fila. Ela só aceita inserção e o `TRANSACTION_ID` só cresce, então o leitor retoma de onde parou pedindo as transações com id maior que o último que viu.
- A fila criaria uma escrita dupla. O `ledgerwriter` teria que gravar no banco e publicar na fila, e se uma das duas falhasse o cache divergiria do livro-razão. Resolver isso direito pede uma tabela de saída lida por consulta periódica, que é o que já temos.
- O broker seria mais uma peça no plantão de 24 horas do Livro-razão e no ambiente local. Tudo isso para tirar um `MAX` sobre a chave primária, que o Postgres responde pelo índice.

## Consequências

- O saldo continua até um ciclo de leitura atrasado em relação ao livro-razão (100 ms por padrão).
- Cada instância de leitor faz a sua consulta periódica, então a carga no `ledger-db` cresce com o número de instâncias.
- A discussão volta se aparecer um terceiro consumidor de transações, como notificação para o cliente, ou se a consulta periódica pesar no `ledger-db`.

## Onde ver no código

- `src/ledger/balancereader`
