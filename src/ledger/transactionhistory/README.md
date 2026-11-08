# transactionhistory

<!-- kota:servico:inicio -->

**Time:** Livro-razão (#livro-razao)

**Responsáveis:** Thiago Nakamura (tech lead), Natália Brandão (gestor)

**Depende de:** ledger-db

**Como rodar:** `docker compose up --build transactionhistory`

**Como testar:** `scripts/testar.sh transactionhistory`

<!-- kota:servico:fim -->

<!-- Modificado pela Kota a partir do original (Apache-2.0). -->

## O que faz

Responde o extrato de cada conta da Kota: as últimas transações, de entrada e de saída, da mais recente para a mais antiga. O extrato sai das transações da conta no `ledger-db`, e o `transactionhistory` guarda as últimas num cache em memória. O site pede o extrato toda vez que abre a home.

## Como funciona

O cache funciona como decide o [ADR 4](../../../docs/adr/0004-saldo-e-extrato-com-cache-em-memoria-lidos-do-livro-razao.md):

- Na primeira consulta de uma conta, o cache carrega do `ledger-db` as últimas `HISTORY_LIMIT` transações dela.
- Um `LedgerReader` em segundo plano, cópia do que roda no `balancereader`, pergunta ao `ledger-db` o maior `transactionId` a cada `POLL_MS`. Quando aparece transação nova, ele lê só as que vieram depois da última que viu e põe cada uma no começo do extrato das contas que já estão no cache. Acima de `HISTORY_LIMIT`, a transação mais antiga sai.
- O extrato de uma conta expira `CACHE_MINUTES` depois de carregado e volta do banco na consulta seguinte.

Por isso o extrato pode estar até um ciclo de leitura atrasado. Uma transferência que acabou de sair pode faltar na home que abre logo depois dela. Cada instância tem o seu cache e, ao reiniciar, começa vazia.

Se o maior `transactionId` do banco diminuir, como num banco restaurado de backup, o `LedgerReader` para. O `/healthy` passa a responder 500, e o serviço precisa ser reiniciado.

Todo pedido de extrato traz o JWT. O `transactionhistory` confere a assinatura com a chave pública e compara a conta da URL com o `acct` do token. Uma conta de outro cliente recebe 401.

## Rotas

| Rota | Método | Pede token | O que faz |
|---|---|---|---|
| `/transactions/<accountid>` | GET | sim | Devolve o extrato da conta. Responde 401 se a conta não é a do token. |
| `/healthy` | GET | | Responde `ok` enquanto o `LedgerReader` roda e 500 quando ele parou. |
| `/ready` | GET | | Responde `ok`. |
| `/version` | GET | | Devolve o valor de `VERSION`. |

## Variáveis de ambiente

Os valores do ambiente local ficam no [`docker-compose.yml`](../../../docker-compose.yml).

| Variável | O que é |
|---|---|
| `POLL_MS` | Intervalo, em milissegundos, entre duas perguntas ao `ledger-db`. O padrão é 100. |
| `HISTORY_LIMIT` | Quantas transações o extrato de cada conta guarda. O padrão é 100. |
| `CACHE_MINUTES` | Em quantos minutos o extrato de uma conta expira. O padrão é 60. |
| `CACHE_SIZE` | Quantas contas o cache guarda. O padrão do código é 1.000.000, e o compose usa 1.000. |
| `EXTRA_LATENCY_MILLIS` | Atraso artificial, em milissegundos, em cada resposta de extrato, para testes. Sem a variável, não há atraso. |
| `PUB_KEY_PATH` | Caminho da chave pública do JWT. O serviço lê o arquivo uma vez, na subida. |
| `LOCAL_ROUTING_NUM` | Número da agência da Kota. Só contas dessa agência têm extrato aqui. |
| `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` | Conexão com o `ledger-db`. |
| `VERSION`, `PORT`, `LOG_LEVEL` | Versão que o `/version` devolve, porta do servidor e nível do log. |
| `ENABLE_TRACING` | Com `true`, liga os traces. O compose usa `false`. |
| `ENABLE_METRICS` | Com `false`, desliga o envio de métricas. O compose usa `false`. |
| `JAVA_TOOL_OPTIONS` | Opções da JVM. O compose limita a memória com `-Xmx256m` e explica o porquê num comentário. |

## Decisões

- [ADR 1: Quebrar o monolito do livro-razão em três serviços](../../../docs/adr/0001-quebrar-o-monolito-do-livro-razao-em-tres-servicos.md). O extrato saiu do `ledgermonolith` para um serviço próprio. Uma mudança no extrato só reinicia o `transactionhistory`.
- [ADR 4: Saldo e extrato com cache em memória, lidos do livro-razão](../../../docs/adr/0004-saldo-e-extrato-com-cache-em-memoria-lidos-do-livro-razao.md). O cache em memória e o `LedgerReader` que o mantém em dia.
- [ADR 5: Python em Contas e Canais, Java no Livro-razão](../../../docs/adr/0005-python-em-contas-e-canais-java-no-livro-razao.md). O serviço é do Livro-razão e por isso é Java 17 com Spring Boot, com build pelo `mvnw` da raiz.
