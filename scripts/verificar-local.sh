#!/usr/bin/env bash
# Sobe o banco com docker compose e confere, como um cliente faria, que o login e a home funcionam.
# MARCA: texto que a página de login precisa mostrar (padrão Kota).
# KOTA_PORTA: porta do site na máquina (padrão 8080).
set -euo pipefail
cd "$(dirname "$0")/.."

marca="${MARCA:-Kota}"
export KOTA_PORTA="${KOTA_PORTA:-8080}"
url="http://localhost:$KOTA_PORTA"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

falha() {
  echo "FALHOU: $*" >&2
  docker compose ps -a >&2 || true
  exit 1
}

# O usuário e a senha de demo são os que o compose dá ao frontend para preencher o login.
docker compose config frontend > "$tmp/frontend.yml" || falha "docker compose config"
do_frontend() { awk -v chave="$1:" '$1 == chave { gsub(/"/, "", $2); print $2; exit }' "$tmp/frontend.yml"; }
usuario=$(do_frontend DEFAULT_USERNAME)
senha=$(do_frontend DEFAULT_PASSWORD)
[ -n "$usuario" ] && [ -n "$senha" ] || falha "o compose não dá DEFAULT_USERNAME e DEFAULT_PASSWORD ao frontend"

docker compose up -d --build || falha "docker compose up"
# O prazo começa depois do build: na primeira subida, só o build pode passar de 3 minutos.
prazo=$((SECONDS + 180))

until [ "$(curl -s -o "$tmp/login.html" -w '%{http_code}' "$url/login")" = 200 ]; do
  [ "$SECONDS" -lt "$prazo" ] || falha "GET $url/login não respondeu 200 em 180 s"
  sleep 3
done
texto_visivel() {
  perl -0777 -pe 's/<!--.*?-->//gs; s/<head\b.*?<\/head>//gis; s/<(script|style)\b.*?<\/\1>//gis; s/<[^>]*>/ /g; s/\s+/ /g' "$1"
}
[[ "$(texto_visivel "$tmp/login.html")" == *"$marca"* ]] || falha "a página de login não mostra \"$marca\""
# O login.js não envia o formulário se o usuário não casar com o pattern do campo; o curl abaixo não passa por ele.
padrao=$(perl -ne 'print $1 if /id="login-username"[^>]*\bpattern="([^"]*)"/' "$tmp/login.html")
[[ -z "$padrao" || "$usuario" =~ ^($padrao)$ ]] || falha "o formulário de login recusa \"$usuario\" (pattern \"$padrao\")"

entrar() {
  local resposta
  resposta=$(curl -s -o /dev/null -c "$tmp/cookies" -w '%{http_code} %{redirect_url}' \
    --data-urlencode "username=$usuario" --data-urlencode "password=$senha" "$url/login")
  [ "${resposta%% *}" = 302 ] && [[ "${resposta#* }" == */home ]] \
    || { motivo="POST /login devolveu \"$resposta\", esperado 302 para /home"; return 1; }
  grep -q $'\ttoken\t' "$tmp/cookies" \
    || { motivo="POST /login não devolveu o cookie token"; return 1; }
  [ "$(curl -s -o "$tmp/home.html" -b "$tmp/cookies" -w '%{http_code}' "$url/home")" = 200 ] \
    || { motivo="GET /home não respondeu 200"; return 1; }
  grep -A1 'id="current-balance"' "$tmp/home.html" | tail -n 1 | grep -q '[0-9]' \
    || { motivo="a home não mostra o saldo (balancereader)"; return 1; }
  grep -q 'id="transaction-list"' "$tmp/home.html" \
    || { motivo="a home não mostra o histórico (transactionhistory)"; return 1; }
}

motivo=""
until entrar; do
  [ "$SECONDS" -lt "$prazo" ] || falha "$motivo (180 s esgotados)"
  sleep 3
done
echo "OK: $url mostra \"$marca\", o login de $usuario leva à home com saldo e histórico"
