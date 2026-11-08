# loadgenerator

<!-- kota:servico:inicio -->

**Time:** Plataforma (#plataforma)

**Responsáveis:** Nádia Saliba (tech lead), Eduardo Kaminski (gestor)

**Depende de:** frontend

**Como rodar:** `docker compose up --build loadgenerator`

**Como testar:** sem testes automatizados

<!-- kota:servico:fim -->

<!-- Modificado pela Kota a partir do original (Apache-2.0). -->

## O que faz

Simula clientes usando o site, para ver como o banco se comporta sob carga. Em homologação, o teste de carga roda com ele.

## Como funciona

O `loadgenerator` roda o Locust sem interface, contra o `frontend` em `FRONTEND_ADDR`, com `USERS` clientes simulados ao mesmo tempo. Cada cliente simulado:

1. Abre as telas de login e de cadastro e se cadastra com um usuário aleatório.
2. Deposita 1.000.000,00 de outra agência, para ter saldo.
3. Abre a home, transfere, deposita valores de até 1.000,00 e entra de novo, com um segundo entre uma ação e outra.
4. De vez em quando sai e volta ao passo 1, com outro usuário.

As transferências vão para 50 contas sorteadas na subida, que não existem no `accounts-db`. O `ledgerwriter` aceita, porque não confere se a conta de destino existe.

Cada cliente simulado vira um cliente de verdade no `accounts-db`, e cada transação fica no `ledger-db`. Os volumes guardam esses dados de uma subida para outra. Para voltar aos dados de demonstração, siga o runbook [Subir o ambiente local do zero](../../docs/runbooks/subir-do-zero.md).

No `docker-compose.yml`, o `loadgenerator` só sobe com o profile `carga`. Para subir o banco com a carga, rode:

```bash
docker compose --profile carga up --build
```

Para parar, aperte `Ctrl+C` e rode `docker compose --profile carga down`. Sem o `--profile carga`, o `docker compose down` deixa o container do `loadgenerator` para trás.

## Variáveis de ambiente

Os valores do ambiente local ficam no [`docker-compose.yml`](../../docker-compose.yml).

| Variável | O que é |
|---|---|
| `FRONTEND_ADDR` | Endereço e porta do `frontend`. |
| `USERS` | Quantos clientes simulados rodam ao mesmo tempo. O padrão é 10. |
| `LOG_LEVEL` | Nível do log do Locust. O padrão é `info`. |

## Decisões

Nenhum ADR tem `src/loadgenerator` em "Onde ver no código". O [ADR 7: Ambiente local com docker compose construído do código](../../docs/adr/0007-ambiente-local-com-docker-compose-construido-do-codigo.md) decide que o `loadgenerator` só sobe com o profile `carga`.
