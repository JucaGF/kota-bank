# balancereader

<!-- kota:servico:inicio -->

**Time:** Livro-razão (#livro-razao)

**Responsáveis:** Thiago Nakamura (tech lead), Natália Brandão (gestor)

**Depende de:** ledger-db

**Como rodar:** `docker compose up --build balancereader`

**Como testar:** `scripts/testar.sh balancereader`

<!-- kota:servico:fim -->

<!-- Modificado pela Kota a partir do original (Apache-2.0). -->

## O que faz

Responde o saldo de cada conta da Kota. O saldo não fica gravado em tabela nenhuma. Ele é a soma das transações da conta no `ledger-db`, e o `balancereader` guarda essa soma num cache em memória. O site pede o saldo toda vez que abre a home, e o `ledgerwriter` pede antes de gravar cada transferência.

## Como funciona

O cache funciona como decide o [ADR 4](../../../docs/adr/0004-saldo-e-extrato-com-cache-em-memoria-lidos-do-livro-razao.md):

- Na primeira consulta de uma conta, o cache carrega do `ledger-db` o que entrou na conta menos o que saiu.
- Um `LedgerReader` em segundo plano pergunta ao `ledger-db` o maior `transactionId` a cada `POLL_MS`. Quando aparece transação nova, ele lê só as que vieram depois da última que viu e atualiza o saldo das contas que já estão no cache.
- O saldo não expira. O cache guarda até `CACHE_SIZE` contas.

Por isso o saldo pode estar até um ciclo de leitura atrasado em relação ao livro-razão. Cada instância tem o seu cache e, ao reiniciar, começa vazia.

Se o maior `transactionId` do banco diminuir, como num banco restaurado de backup, o `LedgerReader` para. O `/healthy` passa a responder 500, e o serviço precisa ser reiniciado.

Todo pedido de saldo traz o JWT. O `balancereader` confere a assinatura com a chave pública e compara a conta da URL com o `acct` do token. Uma conta de outro cliente recebe 401.

## Rotas

| Rota | Método | Pede token | O que faz |
|---|---|---|---|
| `/balances/<accountid>` | GET | sim | Devolve o saldo da conta, em centavos. Responde 401 se a conta não é a do token. |
| `/healthy` | GET | | Responde `ok` enquanto o `LedgerReader` roda e 500 quando ele parou. |
| `/ready` | GET | | Responde `ok`. |
| `/version` | GET | | Devolve o valor de `VERSION`. |

## Variáveis de ambiente

Os valores do ambiente local ficam no [`docker-compose.yml`](../../../docker-compose.yml).

| Variável | O que é |
|---|---|
| `POLL_MS` | Intervalo, em milissegundos, entre duas perguntas ao `ledger-db`. O padrão é 100. |
| `CACHE_SIZE` | Quantas contas o cache guarda. O padrão é 1.000.000. |
| `PUB_KEY_PATH` | Caminho da chave pública do JWT. O serviço lê o arquivo uma vez, na subida. |
| `LOCAL_ROUTING_NUM` | Número da agência da Kota. Só contas dessa agência têm saldo aqui. |
| `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` | Conexão com o `ledger-db`. |
| `VERSION`, `PORT`, `LOG_LEVEL` | Versão que o `/version` devolve, porta do servidor e nível do log. |
| `ENABLE_TRACING` | Com `true`, liga os traces. O compose usa `false`. |
| `ENABLE_METRICS` | Com `false`, desliga o envio de métricas. O compose usa `false`. |
| `JAVA_TOOL_OPTIONS` | Opções da JVM. O compose limita a memória com `-Xmx256m` e explica o porquê num comentário. |

## Decisões

- [ADR 1: Quebrar o monolito do livro-razão em três serviços](../../../docs/adr/0001-quebrar-o-monolito-do-livro-razao-em-tres-servicos.md). O saldo saiu do `ledgermonolith` para um serviço próprio, e o `ledgerwriter` passou a depender dele de pé.
- [ADR 4: Saldo e extrato com cache em memória, lidos do livro-razão](../../../docs/adr/0004-saldo-e-extrato-com-cache-em-memoria-lidos-do-livro-razao.md). O cache em memória e o `LedgerReader` que o mantém em dia.
- [ADR 5: Python em Contas e Canais, Java no Livro-razão](../../../docs/adr/0005-python-em-contas-e-canais-java-no-livro-razao.md). O serviço é do Livro-razão e por isso é Java 17 com Spring Boot, com build pelo `mvnw` da raiz.
- [ADR 6: Fila entre o ledgerwriter e os leitores](../../../docs/adr/0006-fila-entre-o-ledgerwriter-e-os-leitores.md), rejeitado. Trocar a consulta periódica por uma fila de eventos foi proposto e recusado. A consulta ao maior `transactionId` continua.
