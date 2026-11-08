#!/usr/bin/env bash
# Roda os testes de um serviço, ou de todos sem argumento, dentro de containers: só precisa do Docker.
# Uso: scripts/testar.sh [userservice|contacts|ledgerwriter|balancereader|transactionhistory]
set -euo pipefail
cd "$(dirname "$0")/.."

vazia=$(docker run --rm -v "$PWD:/w:ro" alpine:3.20 sh -c 'test -f /w/pom.xml || echo sim')
[ -z "$vazia" ] || {
  echo "FALHOU: $PWD aparece vazia dentro dos containers." \
    "Por padrão, o Colima só compartilha a pasta $HOME; clone o repositório dentro dela." >&2
  exit 1
}

testar() {
  case "$1" in
    userservice | contacts)
      local pasta="src/accounts/$1" imagem
      # O estágio base do Dockerfile do serviço tem o mesmo Python da imagem e o uv.
      imagem=$(docker build -q --target base "$pasta") || return 1
      # A pasta montada precisa ter o nome do serviço: os testes importam "$1.tests".
      docker run --rm -v "$PWD/$pasta:/w/$1:ro" -w "/w/$1" -v kota-uv:/root/.cache/uv \
        -e UV_PROJECT_ENVIRONMENT=/tmp/venv -e UV_LINK_MODE=copy -e PYTHONDONTWRITEBYTECODE=1 \
        "$imagem" uv run --frozen pytest -p no:cacheprovider
      ;;
    ledgerwriter | balancereader | transactionhistory)
      # O Maven roda com o usuário de quem chamou, para o target/ no host não ficar de root.
      # Esse usuário não existe na imagem e a JVM dá a ele user.home "?", então o HOME e o
      # repositório do Maven vão para /tmp, no volume kota-m2, que o Docker cria como root.
      docker run --rm -v kota-m2:/m2 alpine:3.20 chown -R "$(id -u):$(id -g)" /m2 || return 1
      # A imagem define MAVEN_CONFIG=/root/.m2, e o mvnw repassaria isso como fase do build.
      # O entrypoint da imagem precisa dessa variável, então o mvnw entra no lugar dele.
      docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/w -v kota-m2:/tmp/.m2 -w /w \
        -e HOME=/tmp -e MAVEN_OPTS=-Duser.home=/tmp -e MAVEN_CONFIG= --entrypoint ./mvnw \
        maven:3.9-eclipse-temurin-17 -B -pl "src/ledger/$1" -am test
      ;;
    *)
      echo "serviço desconhecido: $1" >&2
      return 2
      ;;
  esac
}

[ $# -gt 0 ] || set -- userservice contacts ledgerwriter balancereader transactionhistory
falharam=""
for servico in "$@"; do
  echo "== $servico"
  testar "$servico" || falharam="$falharam $servico"
done
[ -z "$falharam" ] || { echo "FALHOU:$falharam" >&2; exit 1; }
echo "OK: $*"
