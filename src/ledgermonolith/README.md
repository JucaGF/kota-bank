# ledgermonolith

<!-- kota:servico:inicio -->

**Time:** Livro-razão (#livro-razao)

**Responsáveis:** Thiago Nakamura (tech lead), Natália Brandão (gestor)

**Depende de:** ledger-db

**Como rodar:** legado, fora do docker compose

**Como testar:** sem testes automatizados

<!-- kota:servico:fim -->

<!-- Modificado pela Kota a partir do original (Apache-2.0). -->

## O que faz

É a versão antiga do livro-razão, num serviço só. Fica no repositório como legado. Não sobe em nenhum ambiente, nem no `docker-compose.yml`, e não recebe mudança nova. O [ADR 1](../../docs/adr/0001-quebrar-o-monolito-do-livro-razao-em-tres-servicos.md) conta por que ele foi dividido em três serviços, o [`ledgerwriter`](../ledger/ledgerwriter), o [`balancereader`](../ledger/balancereader) e o [`transactionhistory`](../ledger/transactionhistory).

Correção no livro-razão vai nesses três serviços, nunca aqui.

## Como funciona

O monolito é um serviço Spring Boot com o que hoje são os três serviços do livro-razão. Ele tem as rotas dos três: `POST /transactions` para gravar, `GET /balances/<accountid>` para o saldo e `GET /transactions/<accountid>` para o extrato. Saldo e extrato saíam de um cache único por conta (`AccountInfo`), mantido em dia por um `LedgerReader`. O `LedgerReader` de hoje, no `balancereader` e no `transactionhistory`, foi copiado daqui.

O monolito rodava numa máquina com o Postgres instalado nela mesma. A tabela `TRANSACTIONS` que ele usava hoje fica no `ledger-db`. As pastas `init/` e `scripts/` e o `config.yaml` são da época em que ele rodava nessa máquina e não valem para nenhum ambiente da Kota hoje.

O `pom.xml` da raiz ainda lista esta pasta entre os módulos. Por isso os Dockerfiles do `ledgerwriter`, do `balancereader` e do `transactionhistory` copiam a pasta para o build.

## Decisões

- [ADR 1: Quebrar o monolito do livro-razão em três serviços](../../docs/adr/0001-quebrar-o-monolito-do-livro-razao-em-tres-servicos.md). O monolito virou o `ledgerwriter`, o `balancereader` e o `transactionhistory` e ficou no repositório como legado.
