<!-- Modificado pela Kota a partir do original (Apache-2.0). -->
# Kota

A Kota é um banco digital. Este repositório tem o código do internet banking da Kota: o site em que o cliente vê o saldo e o extrato, transfere e deposita, e os serviços que o site chama. Os serviços são em Python e Java, e os dados ficam em dois bancos PostgreSQL, um de contas e outro do livro-razão.

## Serviços

Cada serviço tem uma pasta em `src/` e um time responsável.

<!-- kota:sistemas:inicio -->

| Serviço | Linguagem | O que faz | Time |
|---|---|---|---|
| [frontend](src/frontend) | Python | Site do banco: login, cadastro, saldo, transferência e depósito. | Canais |
| [userservice](src/accounts/userservice) | Python | Cadastro e login dos clientes; assina o JWT que os outros serviços conferem. | Contas |
| [contacts](src/accounts/contacts) | Python | Contatos de cada cliente, usados para transferir. | Contas |
| [accounts-db](src/accounts/accounts-db) | Postgres | Banco de contas e contatos. | Contas |
| [ledgerwriter](src/ledger/ledgerwriter) | Java | Valida e grava as transações no livro-razão. | Livro-razão |
| [balancereader](src/ledger/balancereader) | Java | Saldo de cada conta, com cache, lido do livro-razão. | Livro-razão |
| [transactionhistory](src/ledger/transactionhistory) | Java | Extrato de cada conta, com cache, lido do livro-razão. | Livro-razão |
| [ledger-db](src/ledger/ledger-db) | Postgres | Banco do livro-razão, com todas as transações. | Livro-razão |
| [loadgenerator](src/loadgenerator) | Python | Simula clientes usando o site, para testar o banco sob carga. | Plataforma |
| [ledgermonolith](src/ledgermonolith) | Java | Versão antiga, em monolito, dos três serviços do livro-razão. | Livro-razão |

<!-- kota:sistemas:fim -->

O `ledgermonolith` não sobe no ambiente local. O [ADR 1](docs/adr/0001-quebrar-o-monolito-do-livro-razao-em-tres-servicos.md) conta por que ele foi dividido nos três serviços Java do livro-razão.

## Como subir o banco

Você só precisa do Docker, com o `docker compose`. Na raiz do repositório, rode:

```sh
docker compose up --build
```

O compose constrói cada serviço do banco a partir do código da pasta, gera o par de chaves do JWT e sobe os dois bancos com os dados de demonstração. A primeira subida demora mais, porque baixa as imagens base e as dependências do Maven.

Quando o log do `frontend-1` mostrar `Listening at: http://0.0.0.0:8080`, abra `http://localhost:8080` e entre com o usuário `cliente.demo` e a senha `kota-demo`. A tela de login já vem preenchida com os dois.

Se a porta 8080 estiver ocupada, escolha outra com `KOTA_PORTA`:

```sh
KOTA_PORTA=8090 docker compose up --build
```

Com isso, o site abre em `http://localhost:8090`.

Para parar, aperte `Ctrl+C` no terminal do compose e rode `docker compose down`. Os dados e as chaves ficam nos volumes e voltam na próxima subida. Para voltar aos dados de demonstração, siga o runbook [Subir o ambiente local do zero](docs/runbooks/subir-do-zero.md).

## Como testar

Os testes rodam dentro de containers, então aqui também você só precisa do Docker. Para rodar os testes de todos os serviços, rode:

```sh
scripts/testar.sh
```

Para rodar os testes de um serviço, passe o nome dele (`userservice`, `contacts`, `ledgerwriter`, `balancereader` ou `transactionhistory`):

```sh
scripts/testar.sh userservice
```

Nos serviços Python, o script roda o `pytest`. Nos Java, roda o `./mvnw test`.

No Colima, o repositório precisa estar dentro da sua pasta pessoal (`$HOME`). Fora dela, a pasta aparece vazia dentro dos containers, e o `scripts/testar.sh` avisa e para.

Para conferir o banco inteiro como um cliente faria, rode:

```sh
scripts/verificar-local.sh
```

O script sobe o compose, entra com `cliente.demo`, confere que a home mostra o saldo e o histórico e termina com `OK`. Ele também lê a `KOTA_PORTA`.

Para simular clientes usando o site, suba o `loadgenerator` junto com o resto:

```sh
docker compose --profile carga up --build
```

Para parar, aperte `Ctrl+C` e rode `docker compose --profile carga down`. Sem o `--profile carga`, o `docker compose down` deixa o container do `loadgenerator` para trás.

## Decisões

As decisões de arquitetura ficam em [`docs/adr/`](docs/adr/), um ADR por arquivo, com o contexto, a decisão e as consequências.

## Runbooks

Os procedimentos de operação ficam em [`docs/runbooks/`](docs/runbooks/):

- [Subir o ambiente local do zero](docs/runbooks/subir-do-zero.md)
- [Trocar o par de chaves do JWT](docs/runbooks/trocar-chave-jwt.md)
- [Disco cheio no ledger-db](docs/runbooks/ledger-db-cheio.md)

## Origem do código

Baseado no [Bank of Anthos](https://github.com/GoogleCloudPlatform/bank-of-anthos) v0.6.11, sob a licença Apache-2.0. O `LICENSE` foi mantido, e os arquivos modificados trazem o aviso "Modificado pela Kota a partir do original (Apache-2.0)."

A Kota é um banco fictício. Os clientes, as contas e as transações de demonstração são inventados.
