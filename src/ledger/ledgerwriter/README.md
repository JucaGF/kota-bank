# ledgerwriter

<!-- kota:servico:inicio -->

**Time:** Livro-razão (#livro-razao)

**Responsáveis:** Thiago Nakamura (tech lead), Natália Brandão (gestor)

**Depende de:** balancereader, ledger-db

**Como rodar:** `docker compose up --build ledgerwriter`

**Como testar:** `scripts/testar.sh ledgerwriter`

<!-- kota:servico:fim -->

<!-- Modificado pela Kota a partir do original (Apache-2.0). -->

## O que faz

Valida e grava as transações no livro-razão: as transferências entre contas da Kota e os depósitos que vêm de outra agência. É o único serviço que grava na tabela `TRANSACTIONS` do `ledger-db`.

## Como funciona

Cada `POST /transactions` passa por estes passos, nesta ordem:

1. Confere o JWT com a chave pública. Um token inválido recebe 401.
2. Recusa o pedido se o `uuid` dele já apareceu na última hora. Assim, um clique duplo no site não grava a mesma transação duas vezes. Os `uuid` ficam na memória, então cada instância tem os seus e um reinício esquece todos.
3. O `TransactionValidator` confere o formato da conta (10 dígitos) e da agência (9 dígitos), se quem envia uma transferência é o dono do token, se origem e destino são diferentes e se o valor é positivo. Ele não confere se a conta de destino existe, porque o livro-razão não enxerga o `accounts-db`, como explica o [ADR 3](../../../docs/adr/0003-um-banco-por-dominio.md).
4. Numa transferência, pergunta ao `balancereader` o saldo de quem envia e recusa se o saldo não cobre o valor. Um depósito vem de outra agência e não passa por essa conferência.
5. Grava a transação e responde 201.

Validação que falha, `uuid` repetido e saldo insuficiente voltam com 400 e a mensagem do erro. Se o `balancereader` não responde, a transferência recebe 500. Por isso o `ledgerwriter` depende do `balancereader` de pé.

O saldo que o `balancereader` devolve pode estar até um ciclo de leitura atrasado. Duas transferências da mesma conta no mesmo ciclo podem passar com o saldo antigo, um risco que o [ADR 4](../../../docs/adr/0004-saldo-e-extrato-com-cache-em-memoria-lidos-do-livro-razao.md) aceita.

## Rotas

| Rota | Método | Pede token | O que faz |
|---|---|---|---|
| `/transactions` | POST | sim | Valida e grava uma transação. Responde 201, 400 para pedido inválido, repetido ou sem saldo e 401 para token inválido. |
| `/ready` | GET | | Responde `ok`. |
| `/version` | GET | | Devolve o valor de `VERSION`. |

O corpo do `POST /transactions` é um JSON com `fromAccountNum`, `fromRoutingNum`, `toAccountNum`, `toRoutingNum`, `amount`, em centavos, e `uuid`.

## Variáveis de ambiente

Os valores do ambiente local ficam no [`docker-compose.yml`](../../../docker-compose.yml).

| Variável | O que é |
|---|---|
| `PUB_KEY_PATH` | Caminho da chave pública do JWT. O serviço lê o arquivo uma vez, na subida. |
| `LOCAL_ROUTING_NUM` | Número da agência da Kota. Uma transação com essa agência na origem é transferência e passa pela conferência de saldo. |
| `BALANCES_API_ADDR` | Endereço e porta do `balancereader`. |
| `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` | Conexão com o `ledger-db`. |
| `VERSION`, `PORT`, `LOG_LEVEL` | Versão que o `/version` devolve, porta do servidor e nível do log. |
| `ENABLE_TRACING` | Com `true`, liga os traces. O compose usa `false`. |
| `ENABLE_METRICS` | Com `false`, desliga o envio de métricas. O compose usa `false`. |
| `JAVA_TOOL_OPTIONS` | Opções da JVM. O compose limita a memória com `-Xmx256m` e explica o porquê num comentário. |

## Decisões

- [ADR 1: Quebrar o monolito do livro-razão em três serviços](../../../docs/adr/0001-quebrar-o-monolito-do-livro-razao-em-tres-servicos.md). A gravação saiu do `ledgermonolith` para cá, e o saldo passou a vir do `balancereader`, por HTTP. Correção na gravação vai aqui, nunca no monolito.
- [ADR 5: Python em Contas e Canais, Java no Livro-razão](../../../docs/adr/0005-python-em-contas-e-canais-java-no-livro-razao.md). O serviço é do Livro-razão e por isso é Java 17 com Spring Boot, com build pelo `mvnw` da raiz.
