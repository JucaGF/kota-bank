# ADR-0004: Saldo e extrato com cache em memória, lidos do livro-razão

- Status: aceito
- Data: 2024-08
- Time: Livro-razão

## Contexto

No monolito, saldo e extrato saíam de um cache só por conta (`AccountInfo`), que um `LedgerReader` em segundo plano mantinha em dia perguntando ao banco pelas transações novas. Com a quebra (ADR 1), saldo e extrato foram para serviços diferentes, e cada leitor precisou decidir de onde tirar os dados. O saldo é a soma de todas as transações da conta, e o site pede saldo e extrato toda vez que abre a página inicial. Consultar o `ledger-db` a cada requisição poria essa soma no caminho de cada página. Um cache compartilhado num serviço à parte seria mais uma peça para o plantão operar.

## Decisão

Cada leitor repete o modelo do monolito, com o seu próprio cache em memória (`LoadingCache` do Guava), mantido em dia pela leitura do livro-razão.

- Na primeira consulta de uma conta, o cache carrega do `ledger-db`. O `balancereader` carrega a soma, e o `transactionhistory` carrega as últimas `HISTORY_LIMIT` transações (100 por padrão).
- Um `LedgerReader` em segundo plano pergunta ao `ledger-db` o maior `transactionId` a cada `POLL_MS` (100 ms por padrão). Quando aparece transação nova, ele lê só as que vieram depois da última vista e atualiza as contas que já estão no cache.
- O extrato expira em `CACHE_MINUTES` (60 por padrão). O saldo não expira, e o limite é o número de contas (`CACHE_SIZE`).

## Consequências

- Depois da primeira consulta, saldo e extrato respondem da memória, sem ir ao banco.
- O saldo pode estar até um ciclo de leitura atrasado. Como o `ledgerwriter` confere o saldo pelo `balancereader`, duas transferências da mesma conta no mesmo ciclo podem passar com o saldo antigo. Aceitamos esse risco com o ciclo de 100 ms.
- Cada instância tem o seu cache. Ao reiniciar, ela começa vazia e recarrega cada conta do banco na primeira consulta.
- Se o maior `transactionId` do banco diminuir, como num banco restaurado de backup, o `LedgerReader` para, o `/healthy` passa a responder erro e o serviço precisa ser reiniciado.
- O `LedgerReader` do monolito foi copiado para os dois leitores, sem biblioteca compartilhada (ADR 1).

## Onde ver no código

- `src/ledger/balancereader`
- `src/ledger/transactionhistory`
