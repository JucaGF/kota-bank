#!/bin/bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# Modificado pela Kota a partir do original (Apache-2.0).

# Immediately exit if any error occurs during script execution.
set -o errexit

# Skip adding data if not enabled
if [ "$USE_DEMO_DATA" != "True"  ]; then
  echo "no demo users added"
  exit 0
fi


# Expected environment variables
readonly ENV_VARS=(
  "POSTGRES_DB"
  "POSTGRES_USER"
  "LOCAL_ROUTING_NUM"
)


add_user() {
  # Uso:  add_user "CONTA" "USUARIO" "NOME" "SOBRENOME" "ENDERECO" "UF" "CEP"
  echo "adding user: $2"
  psql -X -v ON_ERROR_STOP=1 -v account="$1" -v username="$2" -v firstname="$3" -v lastname="$4" -v address="$5" -v state="$6" -v zip="$7" -v passhash="$DEFAULT_PASSHASH" --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    INSERT INTO users VALUES (:'account', :'username', :'passhash', :'firstname', :'lastname', '2000-01-01', '-3', :'address', :'state', :'zip', '111-22-3333') ON CONFLICT DO NOTHING;
EOSQL
}


add_external_account() {
  # Usage:  add_external_account "OWNER_USERNAME" "LABEL" "ACCOUNT" "ROUTING"
  echo "user $1 adding contact: $2"
  psql -X -v ON_ERROR_STOP=1 -v username="$1" -v label="$2" -v account="$3" -v routing="$4" --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    INSERT INTO contacts VALUES (:'username', :'label', :'account', :'routing', 'true') ON CONFLICT DO NOTHING;
EOSQL
}


add_contact() {
  # Usage:  add_contact "OWNER_USERNAME" "CONTACT_LABEL" "CONTACT_ACCOUNT"
  echo "user $1 adding external account: $2"
  psql -X -v ON_ERROR_STOP=1 -v username="$1" -v label="$2" -v account="$3" -v routing="$LOCAL_ROUTING_NUM" --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    INSERT INTO contacts VALUES (:'username', :'label', :'account', :'routing', 'false') ON CONFLICT DO NOTHING;
EOSQL
}


# Load test data into the database
create_accounts() {
  # Add demo users.
  add_user "1011226111" "cliente.demo" "Cliente" "Demo" "Rua das Acácias, 120, São Paulo" "SP" "04567-010"
  add_user "1033623433" "marina.teixeira" "Marina" "Teixeira" "Avenida Beira-Mar, 845, Fortaleza" "CE" "60165-121"
  add_user "1055757655" "renato.moraes" "Renato" "Moraes" "Rua das Araucárias, 302, Curitiba" "PR" "80410-030"
  add_user "1077441377" "luiza.prado" "Luiza" "Prado" "Rua do Sol, 58, Recife" "PE" "50030-230"

  # Make everyone contacts of each other
  add_contact "cliente.demo" "Marina Teixeira" "1033623433"
  add_contact "cliente.demo" "Renato Moraes" "1055757655"
  add_contact "cliente.demo" "Luiza Prado" "1077441377"
  add_contact "marina.teixeira" "Cliente Demo" "1011226111"
  add_contact "marina.teixeira" "Renato Moraes" "1055757655"
  add_contact "marina.teixeira" "Luiza Prado" "1077441377"
  add_contact "renato.moraes" "Cliente Demo" "1011226111"
  add_contact "renato.moraes" "Marina Teixeira" "1033623433"
  add_contact "renato.moraes" "Luiza Prado" "1077441377"
  add_contact "luiza.prado" "Cliente Demo" "1011226111"
  add_contact "luiza.prado" "Marina Teixeira" "1033623433"
  add_contact "luiza.prado" "Renato Moraes" "1055757655"

  # Add external accounts
  add_external_account "cliente.demo" "External Bank" "9099791699" "808889588"
  add_external_account "marina.teixeira" "External Bank" "9099791699" "808889588"
  add_external_account "renato.moraes" "External Bank" "9099791699" "808889588"
  add_external_account "luiza.prado" "External Bank" "9099791699" "808889588"
}


main() {
  # Check environment variables are set
  for env_var in ${ENV_VARS[@]}; do
    if [[ -z "${!env_var}" ]]; then
      echo "Error: environment variable '$env_var' not set. Aborting."
      exit 1
    fi
  done

  # Hash bcrypt, em hexadecimal, da senha de demo 'kota-demo' (DEMO_LOGIN_PASSWORD no docker-compose.yml).
  # Gerado com:  bcrypt.hashpw(b'kota-demo', bcrypt.gensalt()).hex()
  DEFAULT_PASSHASH='\x24326224313224644c7075375272753270614c475a6374424d4458482e7570336a646c4654746669626b4c39626b6971356b345141396e2f45534c36'

  create_accounts
}


main
