# ADR-0007: Ambiente local com docker compose construído do código

- Status: aceito
- Data: 2025-09
- Time: Plataforma

## Contexto

Para testar uma mudança de ponta a ponta, a pessoa precisava subir dois bancos, seis serviços e um par de chaves do JWT, cada um com as suas variáveis. Cada time tinha o seu jeito, e a chave costumava ser copiada de alguém. Imagem pronta de registro ajudava a subir tudo, mas não testava o código da branch.

## Decisão

Um `docker-compose.yml` na raiz sobe o banco inteiro com `docker compose up --build`. Cada serviço do banco é construído do código da branch, pelo Dockerfile da própria pasta, nunca de imagem pronta. Os três do livro-razão usam a raiz como contexto de build, porque o `pom.xml` da raiz junta os módulos Java (ADR 5).

- O serviço `jwt-chaves` gera o par de chaves do JWT na primeira subida e o guarda no volume `chaves`, que os outros serviços montam só para leitura. Nenhuma chave entra no repositório.
- `accounts-db` e `ledger-db` sobem com os próprios scripts de `initdb` e os dados de demonstração, cada um no seu volume.
- O site fica em `http://localhost:8080`, e a porta muda com `KOTA_PORTA`.
- O `loadgenerator` só sobe com o profile `carga`. O `ledgermonolith` não faz parte do compose.

O `scripts/verificar-local.sh` sobe tudo e confere o login de ponta a ponta.

## Consequências

- Docker é o único requisito para subir o banco e rodar os testes.
- A primeira subida demora, porque o Maven baixa as dependências dos serviços Java.
- Dados e chaves sobrevivem a `docker compose down`. Com `docker compose down -v`, os volumes somem, os dois bancos voltam aos dados de demonstração e as chaves mudam, então as sessões abertas caem.
- As senhas dos bancos e os dados de demonstração do compose valem só na máquina de quem desenvolve.

## Onde ver no código

- `docker-compose.yml`
