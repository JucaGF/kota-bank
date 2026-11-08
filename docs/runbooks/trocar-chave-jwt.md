# Trocar o par de chaves do JWT

## Quando usar

- Na troca programada do par de chaves, com data marcada.
- Quando há suspeita de que a chave privada vazou. Antes de qualquer passo, escreva para seguranca@kota.example. É um incidente de segurança, e a troca é feita junto com a segurança.

## Antes de começar

- A troca derruba todas as sessões abertas. Todo token assinado com a chave antiga deixa de valer, e o cliente precisa entrar de novo. Numa troca programada, anuncie a data no #contas com alguns dias de antecedência e avise o atendimento antes.
- Cada serviço lê a chave só quando sobe, como diz o [ADR 2](../adr/0002-jwt-assinado-pelo-userservice-e-validado-em-cada-servico.md). Depois do par novo, todos os serviços que montam o volume `chaves` precisam reiniciar. O `userservice` assina com a chave privada. O `contacts`, o `frontend`, o `ledgerwriter`, o `balancereader` e o `transactionhistory` conferem com a pública. Um serviço que não reiniciou continua com a chave antiga e recusa todo token novo.
- Os comandos abaixo são do ambiente local, onde a troca se ensaia. Lá o par fica no volume `chaves`, gerado pelo serviço `jwt-chaves`, como decidido no [ADR 7](../adr/0007-ambiente-local-com-docker-compose-construido-do-codigo.md). Em homologação e em produção a ordem é a mesma, mas a configuração é de Plataforma, então combine a troca com o time no #plataforma-ajuda.
- O ambiente local precisa estar de pé. Se não estiver, siga antes o runbook [subir do zero](subir-do-zero.md). Com outra porta em `KOTA_PORTA`, troque o 8080 dos comandos.

## Passos

Na raiz do repositório:

```bash
# 1. Entra no site e guarda a sessão de antes da troca. A home responde 200.
curl -s -o /dev/null -c /tmp/sessao-antiga --data-urlencode username=cliente.demo --data-urlencode password=kota-demo http://localhost:8080/login
curl -s -o /dev/null -w '%{http_code}\n' -b /tmp/sessao-antiga http://localhost:8080/home

# 2. Apaga o par atual do volume chaves.
docker compose run --rm jwt-chaves rm -f /chaves/privatekey /chaves/publickey

# 3. Gera o par novo. Sem a chave pública no volume, o jwt-chaves cria outro par.
docker compose run --rm jwt-chaves

# 4. Reinicia todos os serviços que leem a chave.
docker compose restart userservice contacts frontend ledgerwriter balancereader transactionhistory
```

## Como saber que deu certo

```bash
# Um login novo funciona em todos os serviços: a home mostra saldo e histórico.
scripts/verificar-local.sh

# A sessão de antes da troca caiu: a home manda para o login.
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' -b /tmp/sessao-antiga http://localhost:8080/home
```

O script termina com `OK`, e o último comando mostra `302 http://localhost:8080/login`. Se o script falhar porque a home não mostra o saldo ou o histórico, algum serviço do livro-razão não reiniciou e ainda tem a chave antiga.

Em produção, acompanhe por uma hora os logins com sucesso e os erros de cada serviço, como depois de um deploy. Os logins voltam ao patamar de antes da troca.

## Quem chamar

Contas, no #contas-ajuda. O `userservice` e o par de chaves são do time. Suspeita de vazamento vai antes para seguranca@kota.example.

Se um serviço de outro time não volta depois do reinício, chame também o time dele: Livro-razão no #livro-razao-ajuda, para o `ledgerwriter`, o `balancereader` e o `transactionhistory`, e Canais no #canais-ajuda, para o `frontend`.
