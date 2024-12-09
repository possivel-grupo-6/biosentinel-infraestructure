#!/bin/bash
# Redirecionar logs para user-data.log
exec > >(sudo tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# Variáveis principais
CONFIGDIR="/ops/shared/config"
HOME_DIR="/home/ubuntu"

NOMAD_VERSION=${nomad_version}
NOMAD_DOWNLOAD="https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_linux_amd64.zip"
NOMAD_CONFIG_DIR="/etc/nomad.d"
NOMAD_DIR="/opt/nomad"

CONSUL_VERSION="1.20.1"
CONSUL_DOWNLOAD="https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip"
CONSUL_CONFIG_DIR="/etc/consul.d"
CONSUL_DIR="/opt/consul"

VAULT_VERSION="1.17.5"
VAULT_DOWNLOAD="https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_amd64.zip"
VAULT_CONFIG_DIR="/etc/vault.d"
VAULT_DIR="/opt/vault"

SERVER_COUNT=${server_count}
RETRY_JOIN="${retry_join}"
NOMAD_TOKEN=${nomad_token_id}
CONSUL_TOKEN=${consul_token_id}
VAULT_TOKEN=${vault_token_id}

# Capturar o endereço IP local
TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)

# Instalar dependências
sudo apt-get update
sudo apt-get install -y unzip tree redis-tools jq curl tmux apt-transport-https ca-certificates gnupg2 software-properties-common
sudo apt-get clean
sudo ufw disable || echo "ufw não instalado"

# Baixar e instalar Nomad
curl -L "$NOMAD_DOWNLOAD" > nomad.zip
sudo unzip nomad.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/nomad
sudo mkdir -p "$NOMAD_CONFIG_DIR" "$NOMAD_DIR"
sudo chmod 755 "$NOMAD_CONFIG_DIR" "$NOMAD_DIR"

# Baixar e instalar Consul
curl -L "$CONSUL_DOWNLOAD" > consul.zip
sudo unzip -o consul.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/consul
sudo mkdir -p "$CONSUL_CONFIG_DIR" "$CONSUL_DIR"
sudo chmod 755 "$CONSUL_CONFIG_DIR" "$CONSUL_DIR"

# Baixar e instalar o vault
curl -L "$VAULT_DOWNLOAD" > vault.zip
sudo unzip -o vault.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/vault
sudo mkdir -p "$VAULT_CONFIG_DIR" "$VAULT_DIR"
sudo chmod 755 "$VAULT_CONFIG_DIR" "$VAULT_DIR"

sudo groupadd vault

sudo useradd -r -g vault -d $VAULT_DIR -s /bin/false vault

sudo chown -R vault:vault $VAULT_DIR
sudo chown -R vault:vault $VAULT_CONFIG_DIR


# Instalar Docker
distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$distro $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce
sudo systemctl enable docker
sudo systemctl start docker

# Configurar Nomad
sudo sed -i "s/CONSUL_TOKEN/$NOMAD_TOKEN/g" "$CONFIGDIR/nomad.hcl"
sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" "$CONFIGDIR/nomad.hcl"
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/nomad.hcl"
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/nomad.hcl"
sudo cp "$CONFIGDIR/nomad.hcl" "$NOMAD_CONFIG_DIR"
sudo cp "$CONFIGDIR/nomad.service" /etc/systemd/system/nomad.service

sudo systemctl enable nomad.service
sudo systemctl start nomad.service

# Configurar Consul
sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" "$CONFIGDIR/consul.hcl"
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/consul.hcl"
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/consul.hcl"
sed -i "s/CONSUL_TOKEN/$CONSUL_TOKEN/g" "$CONFIGDIR/consul.hcl"
sudo cp "$CONFIGDIR/consul.hcl" "$CONSUL_CONFIG_DIR"
sudo cp "$CONFIGDIR/consul.service" /etc/systemd/system/consul.service

sudo systemctl enable consul.service
sudo systemctl start consul.service

# Configurar vault
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/vault.hcl"
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/vault.hcl"
sed -i "s/VAULT_TOKEN/$VAULT_TOKEN/g" "$CONFIGDIR/vault.hcl"
sudo cp "$CONFIGDIR/vault.hcl" "$VAULT_CONFIG_DIR"
sudo cp "$CONFIGDIR/vault.service" /etc/systemd/system/vault.service

sudo systemctl enable vault.service
sudo systemctl start vault.service

# Adicionar IP ao /etc/hosts
echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts

# Configurar variáveis de ambiente
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append "/home/$HOME_DIR/.bashrc"
echo "export CONSUL_ADDR=http://$IP_ADDRESS:8500" | sudo tee --append "/home/$HOME_DIR/.bashrc"
echo "export VAULT_ADDR=http://$IP_ADDRESS:8200" | sudo tee --append "/home/$HOME_DIR/.bashrc"

# Verificar Consul está pronto antes de bootstrap
echo "Aguardando Consul inicializar..."
until curl -s http://127.0.0.1:8500/v1/status/leader | grep -q '\"'; do
  echo "Aguardando Consul estar pronto..."
  sleep 10
done
echo "Consul está pronto."

# CONSUL BOOTSTRAP
echo "Tentando bootstrap do Consul..."
bootstrap_status=$(consul acl bootstrap -format=json 2>&1 || true)

if echo "$bootstrap_status" | grep -q '"SecretID"'; then
  management_token=$(echo "$bootstrap_status" | jq -r '.SecretID')
  export CONSUL_HTTP_TOKEN=$management_token
  echo "Bootstrap concluído com sucesso. Token gerado: $management_token"
elif echo "$bootstrap_status" | grep -q 'ACL bootstrap no longer allowed'; then
  echo "Bootstrap já foi realizado anteriormente. Usando o token existente."
else
  echo "Erro ao tentar realizar o bootstrap do Consul. Verifique o status e logs."
fi

cd $HOME_DIR

cat > nomad-policy.hcl <<EOL
agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "write"
}

key_prefix "" {
  policy = "write"
}
check_prefix "" {
  policy = "write"
}

acl  = "write"
mesh = "write"
EOL

consul acl policy create -name "nomad-policy" -rules @nomad-policy.hcl
consul acl token create -description "Token do Nomad" -policy-name "nomad-policy" -secret "$NOMAD_TOKEN"

cat > admin-policy.hcl <<EOL

node_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "write"
}

key_prefix "" {
  policy = "write"
}

agent_prefix "" {
  policy = "write"
}

session_prefix "" {
  policy = "write"
}

query_prefix "" {
  policy = "write"
}

acl = "write"

EOL

consul acl policy create -name "admin-policy" -rules @admin-policy.hcl

consul acl token create -description "Token de admin" -policy-name "admin-policy" -secret "$CONSUL_TOKEN"

cat > vault-policy.hcl <<EOL

service_prefix "vault" {
  policy = "write"
}

key_prefix "vault/" {
  policy = "write"
}

agent_prefix "" {
  policy = "write"
}

session_prefix "" {
  policy = "write"
}

EOL

consul acl policy create -name "vault-policy" -rules @vault-policy.hcl

consul acl token create -description "Token de acesso do vault" -policy-name "vault-policy" -secret "$VAULT_TOKEN"

echo "Aguardando o Vault ficar acessível..."
export VAULT_ADDR="http://127.0.0.1:8200"
until curl -s $VAULT_ADDR/v1/sys/seal-status; do
  echo "Vault ainda não está acessível, aguardando..."
  sleep 5
done
echo "Vault está acessível."

echo "Verificando se o Vault está inicializado..."
if ! vault status | grep -q 'Initialized.*true'; then
  echo "Inicializando Vault..."
  INIT_OUTPUT=$(vault operator init -format=json)
  UNSEAL_KEY=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[0]')
  ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
  echo "$UNSEAL_KEY" > vault-unseal-key.txt
  echo "$ROOT_TOKEN" > vault-root-token.txt
else
  echo "Vault já está inicializado."
  UNSEAL_KEY=$(cat vault-unseal-key.txt)
  ROOT_TOKEN=$(cat vault-root-token.txt)
fi
export VAULT_TOKEN="$ROOT_TOKEN"

echo "Verificando se o Vault está selado..."
if vault status | grep -q 'Sealed.*true'; then
  echo "Deselando Vault..."
  vault operator unseal "$UNSEAL_KEY"
fi

if ! vault status | grep -q "Leader *true"; then
  echo "Este nó não é o líder do cluster Vault. Redirecionando para o líder..."
  LEADER_ADDR=$(curl -s http://127.0.0.1:8200/v1/sys/leader | jq -r '.leader_address')
  export VAULT_ADDR=$LEADER_ADDR
  echo "Conectado ao líder do Vault: $LEADER_ADDR"
fi

# Criar uma política para o Nomad acessar segredos
cat > nomad-policy.hcl <<EOL
path "secret/*" {
  capabilities = ["read", "list"]
}

path "auth/approle/login" {
  capabilities = ["create", "read"]
}
EOL

vault policy write nomad-policy nomad-policy.hcl

vault policy write prometheus-metrics - << EOF
path "/sys/metrics" {
  capabilities = ["read"]
}
EOF

vault token create \
  -field=token \
  -policy prometheus-metrics \
  > /home/ubuntu/prometheus-token

# Criar um AppRole para o Nomad
vault auth enable approle
vault write auth/approle/role/nomad \
  token_ttl=1h \
  token_max_ttl=4h \
  policies="nomad-policy"

# Recuperar o RoleID e SecretID
ROLE_ID=$(vault read -field=role_id auth/approle/role/nomad/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/nomad/secret-id)

# Salvar RoleID e SecretID para o Nomad
echo "$ROLE_ID" > nomad-role-id.txt
echo "$SECRET_ID" > nomad-secret-id.txt

# Substituir o RoleID e SecretID no arquivo nomad.hcl
ROLE_ID=$(cat nomad-role-id.txt)
SECRET_ID=$(cat nomad-secret-id.txt)

sudo sed -i "s/ROLE_ID/$ROLE_ID/g" "$NOMAD_CONFIG_DIR/nomad.hcl"
sudo sed -i "s/SECRET_ID/$SECRET_ID/g" "$NOMAD_CONFIG_DIR/nomad.hcl"

# Criação de local para o grafana

sudo mkdir -p /opt/grafana/
sudo chown -R 472:472 /opt/grafana
sudo chmod -R 755 /opt/grafana


# config do dns

CONFIG_DIR="/etc/systemd/resolved.conf.d"
CONFIG_FILE="$CONFIG_DIR/consul.conf"

if [ ! -d "$CONFIG_DIR" ]; then
  echo "Criando diretório $CONFIG_DIR..."
  sudo mkdir -p "$CONFIG_DIR"
fi

echo "Adicionando configurações ao arquivo $CONFIG_FILE..."
sudo bash -c "cat > $CONFIG_FILE <<EOF
[Resolve]
DNS=127.0.0.1:8600
DNSSEC=false
Domains=~consul
EOF
"

echo "Reiniciando o serviço systemd-resolved..."
sudo systemctl restart systemd-resolved

echo "Verificando configurações aplicadas..."
resolvectl status | grep -A 5 "DNS Servers" || echo "Verificação falhou. Confirme as configurações manualmente."

sudo systemctl restart consul
sudo systemctl restart nomad
sudo systemctl restart vault

# Reiniciar o Nomad para aplicar as alterações
sudo systemctl restart nomad

# Verificar status dos serviços
for service in nomad consul; do
  sudo systemctl status $service || echo "Erro ao iniciar $service"
done

echo "Configuração completa."
