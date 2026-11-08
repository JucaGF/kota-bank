# frontend

<!-- kota:servico:inicio -->

**Time:** Canais (#canais)

**Responsáveis:** Larissa Fagundes (tech lead), Priscila Antunes (gestor)

**Depende de:** userservice, contacts, ledgerwriter, balancereader, transactionhistory

**Como rodar:** `docker compose up --build frontend`

**Como testar:** sem testes automatizados

<!-- kota:servico:fim -->

<!-- Modificado pela Kota a partir do original (Apache-2.0). -->

## O que faz

É o site da Kota. Nele o cliente se cadastra, entra, vê o saldo e o extrato, transfere para outra conta da Kota e deposita a partir de uma conta de outra agência.

O `frontend` não tem banco de dados. Cada página chama os serviços de Contas e do Livro-razão e monta o HTML com o que eles devolvem.

## Como funciona

O login vai para o `userservice`, que devolve o JWT. O `frontend` guarda o token no cookie `token`, com a mesma validade dele, e confere a assinatura com a chave pública em cada página e em cada transação. Sem token válido, o cliente cai na tela de login.

A home faz três chamadas ao mesmo tempo: o saldo ao `balancereader`, o extrato ao `transactionhistory` e os contatos ao `contacts`. Cada chamada espera até `BACKEND_TIMEOUT` segundos. Se uma delas falha, a home abre mesmo assim, com `$---` no lugar do saldo ou um aviso de erro no lugar do extrato.

Transferência e depósito vão para o `ledgerwriter`, com o valor em centavos e um `uuid` que a página gera a cada envio. O `ledgerwriter` recusa um `uuid` repetido, então um clique duplo não grava a transação duas vezes. Se o cliente informa um contato novo no formulário, o `frontend` grava o contato no `contacts` antes de mandar a transação. Depois que o `ledgerwriter` aceita, o `frontend` espera 250 ms antes de voltar para a home, para dar tempo de o `balancereader` e o `transactionhistory` lerem a transação nova.

O logout só apaga o cookie. O token continua válido até vencer, como registra o [ADR 2](../../docs/adr/0002-jwt-assinado-pelo-userservice-e-validado-em-cada-servico.md).

## Rotas

| Rota | Método | Pede token | O que faz |
|---|---|---|---|
| `/` | GET | sim | Mostra a home com token válido e a tela de login sem ele. |
| `/home` | GET | sim | Mostra saldo, extrato e contatos. Sem token válido, redireciona para `/login`. |
| `/login` | GET | | Mostra a tela de login. Com token válido, redireciona para `/home`. |
| `/login` | POST | | Manda usuário e senha ao `userservice` e grava o token no cookie. |
| `/signup` | GET | | Mostra a tela de cadastro. |
| `/signup` | POST | | Cadastra o cliente no `userservice` e já faz o login. |
| `/logout` | POST | | Apaga o cookie e volta para a tela de login. |
| `/payment` | POST | sim | Manda uma transferência ao `ledgerwriter`. |
| `/deposit` | POST | sim | Manda ao `ledgerwriter` um depósito vindo de uma conta de outra agência. |
| `/ready` | GET | | Responde `ok`. |
| `/version` | GET | | Devolve o valor de `VERSION`. |

O código também tem `/consent`, a tela de consentimento de um login por OAuth para app de terceiro, e `/whereami`, que diz em que cluster o serviço roda. As duas rotas vêm do código de origem, e o `docker-compose.yml` não configura nenhuma delas.

## Variáveis de ambiente

Os valores do ambiente local ficam no [`docker-compose.yml`](../../docker-compose.yml).

| Variável | O que é |
|---|---|
| `PUB_KEY_PATH` | Caminho da chave pública do JWT. O `frontend` lê o arquivo uma vez, na subida. |
| `LOCAL_ROUTING_NUM` | Número da agência da Kota. Vai na origem e no destino das transferências e no destino dos depósitos. |
| `USERSERVICE_API_ADDR`, `CONTACTS_API_ADDR`, `TRANSACTIONS_API_ADDR`, `BALANCES_API_ADDR`, `HISTORY_API_ADDR` | Endereço e porta do `userservice`, do `contacts`, do `ledgerwriter`, do `balancereader` e do `transactionhistory`. |
| `BACKEND_TIMEOUT` | Quanto tempo, em segundos, cada chamada a outro serviço espera. O padrão é 4, e o login espera o dobro. |
| `DEFAULT_USERNAME`, `DEFAULT_PASSWORD` | Usuário e senha que já vêm preenchidos na tela de login. São opcionais. |
| `BANK_NAME` | Nome do banco na barra do site. O padrão é `Kota`. |
| `KOTA_LOGO` | Com `true`, a barra mostra o logo da Kota no lugar do `BANK_NAME`. O padrão é `false`. |
| `SCHEME` | Esquema dos redirecionamentos, `http` ou `https`. O padrão é `http`. |
| `VERSION`, `PORT`, `LOG_LEVEL` | Versão que o `/version` devolve, porta do gunicorn e nível do log. |
| `ENABLE_TRACING` | Com `true`, liga os traces. Sem ela, o serviço não sobe. O compose usa `false`. |

## Decisões

Nenhum ADR tem `src/frontend` em "Onde ver no código". Dois ADRs decidem como o site funciona:

- [ADR 2: JWT assinado pelo userservice e validado em cada serviço](../../docs/adr/0002-jwt-assinado-pelo-userservice-e-validado-em-cada-servico.md). O `frontend` confere o token sozinho, com a chave pública.
- [ADR 5: Python em Contas e Canais, Java no Livro-razão](../../docs/adr/0005-python-em-contas-e-canais-java-no-livro-razao.md). O site é de Canais e por isso é Python, com Flask e gunicorn.
