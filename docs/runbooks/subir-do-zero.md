# Subir o ambiente local do zero

## Quando usar

- O ambiente local não sobe depois de uma atualização do `docker-compose.yml`. O motivo costuma ser um volume de uma versão anterior, e o `ledger-db` ou o `accounts-db` não fica saudável.
- Os dados locais ficaram num estado que você não sabe desfazer, e você quer voltar aos dados de demonstração.
- O site abre e os bancos estão saudáveis, mas o login de `cliente.demo` com a senha `kota-demo` mostra "Login Failed", e o `scripts/verificar-local.sh` falha depois de 180 s. O `accounts-db` só carrega os dados de demonstração quando o volume `accounts-db-dados` está vazio. Se você subiu o ambiente antes da troca do usuário de demonstração, o banco ainda tem o usuário antigo.
- É a primeira vez que você sobe o banco nesta máquina.

## Antes de começar

- Você só precisa do Docker, com o `docker compose`. Cada serviço é construído do código da pasta, então esteja na branch que quer subir.
- `docker compose down -v` apaga os volumes do ambiente local, e só os dele. Os dois bancos voltam aos dados de demonstração, o par de chaves do JWT muda e as sessões abertas no site caem. Homologação e produção não mudam. Os volumes estão explicados no [ADR 7](../adr/0007-ambiente-local-com-docker-compose-construido-do-codigo.md).
- O site usa a porta 8080. Se ela estiver ocupada, escolha outra antes dos passos com `export KOTA_PORTA=8090`.
- A primeira subida demora, porque o Maven baixa as dependências dos serviços Java.

## Passos

Na raiz do repositório:

```bash
# 1. Para tudo e apaga os volumes chaves, accounts-db-dados e ledger-db-dados.
docker compose down -v

# 2. Constrói cada serviço a partir do código e sobe o banco inteiro.
docker compose up -d --build

# 3. Confere, como um cliente faria, que o login e a home funcionam.
scripts/verificar-local.sh
```

## Como saber que deu certo

- O `scripts/verificar-local.sh` termina com `OK: http://localhost:8080 mostra "Kota", o login de cliente.demo leva à home com saldo e histórico`.
- `docker compose ps` mostra oito serviços de pé, com `accounts-db` e `ledger-db` saudáveis (`healthy`). O `jwt-chaves` não aparece, porque gera as chaves e termina.
- No navegador, `http://localhost:8080` abre o login da Kota, e você entra com `cliente.demo` e a senha `kota-demo`.

Se o script falhar, ele mostra o estado de cada serviço. Leia o log do serviço que caiu, por exemplo com `docker compose logs ledger-db`.

## Quem chamar

Plataforma, no #plataforma-ajuda. O `docker-compose.yml` e o ambiente local são do time. Conte o que o `scripts/verificar-local.sh` mostrou e cole a saída de `docker compose ps -a`.

Se o erro está no build ou no código de um serviço, pergunte também no canal de ajuda do time dono dele.
