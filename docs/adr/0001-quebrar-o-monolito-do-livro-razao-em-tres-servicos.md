# ADR-0001: Quebrar o monolito do livro-razão em três serviços

- Status: aceito
- Data: 2024-03
- Time: Livro-razão
- RFC: https://lean-ptarmigan-dd2.notion.site/412bd621283f8124b3e9e8825d85de18

## Contexto

O livro-razão rodava num serviço só, o `ledgermonolith`. Gravar transação, calcular saldo e montar extrato aconteciam no mesmo processo, com um cache único por conta (`AccountInfo`, com saldo e últimas transações juntos). O monolito rodava numa máquina com o Postgres instalado nela mesma.

O site pede saldo e extrato toda vez que abre a página inicial, e transação é gravada bem menos. Para aguentar mais leitura, a gente precisava subir mais cópias do monolito, e cada cópia levava a gravação junto. Qualquer mudança no extrato reiniciava também o caminho da transferência. O Thiago Nakamura levou o problema para o RFC 1.

## Decisão

Separar o monolito em três serviços, que leem e gravam a mesma tabela de transações (`TRANSACTIONS`):

- `ledgerwriter` valida e grava a transação. Antes de gravar, pergunta o saldo de quem envia ao `balancereader`, por HTTP.
- `balancereader` responde o saldo de cada conta.
- `transactionhistory` responde o extrato de cada conta.

Cada serviço tem o seu código, sem biblioteca compartilhada entre eles. O que os três usam do monolito, como `JWTVerifierGenerator`, `Transaction` e `TransactionRepository`, é copiado para cada um. O `ledgermonolith` fica no repositório como legado. Ele não sobe em nenhum ambiente e não recebe mudança nova.

## Consequências

- Saldo e extrato escalam sem levar a gravação junto. Uma mudança no extrato só reinicia o `transactionhistory`.
- A transferência ganhou uma chamada de rede. No monolito, o saldo vinha do cache local; agora o `ledgerwriter` depende do `balancereader` de pé.
- Tem código repetido de propósito. `JWTVerifierGenerator`, `Transaction` e `TransactionRepository` existem nos três serviços. Um bug ali se corrige em mais de um lugar.
- Saldo e extrato, que no monolito saíam do mesmo `AccountInfo`, passam a viver em serviços diferentes. Como cada leitor mantém os seus dados em dia fica para uma decisão própria.
- A tabela de transações sai da máquina do monolito junto com ele. Em qual Postgres ela vai morar fica para uma decisão própria.
- O monolito ainda compila pelo `pom.xml` da raiz. Correção no livro-razão vai nos três serviços, nunca nele.

## Onde ver no código

- `src/ledgermonolith`
- `src/ledger`
