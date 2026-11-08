# ADR-0005: Python em Contas e Canais, Java no Livro-razão

- Status: aceito
- Data: 2024-11
- Time: Plataforma

## Contexto

A Kota tem duas linguagens no backend desde antes da quebra do monolito (ADR 1). O `userservice`, o `contacts` e o `frontend` são Python, e o livro-razão sempre foi Java. Com a quebra, o Java passou de um serviço para três, e apareceu a proposta de reescrever o livro-razão em Python, para ter um jeito só de construir, testar e contratar. A conta não fechou. Reescrever o livro-razão seria mexer no código que grava dinheiro, sem nenhum ganho para o cliente.

## Decisão

A linguagem segue o time dono do serviço.

- Contas e Canais usam Python, com Flask e gunicorn. Cada serviço declara as dependências no `pyproject.toml` e trava as versões no `uv.lock`.
- Livro-razão usa Java 17 com Spring Boot. O build é Maven, pelo `mvnw` da raiz, e o `pom.xml` da raiz junta os módulos.

Serviços de linguagens diferentes conversam só por HTTP com JWT, nunca por biblioteca compartilhada. O time de Plataforma mantém os dois caminhos de build e teste.

## Consequências

- Quem muda de Contas para o Livro-razão troca de linguagem e troca `uv run pytest` por `./mvnw test`.
- O lint também é por linguagem, com o `.pylintrc` da raiz para Python e um `checkstyle.xml` em cada serviço Java.
- Regra que vale para todos existe duas vezes, uma em cada linguagem. A validação do JWT (ADR 2) é o exemplo mais visível.
- Serviço novo nasce na linguagem do time dono. Um time que queira uma terceira linguagem abre um RFC antes.

## Onde ver no código

- `src/accounts`
- `src/ledger`
