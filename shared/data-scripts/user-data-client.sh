#!/bin/bash

set -e

# Configuração para saída de logs do user-data
exec > >(sudo tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# Variáveis de Configuração
CONFIGDIR="/ops/shared/config"
HOME_DIR="ubuntu"

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

RETRY_JOIN="${retry_join}"
NOMAD_TOKEN=${nomad_token_id}
CONSUL_TOKEN=${consul_token_id}
VAULT_TOKEN=${vault_token_id}

# Instala dependências iniciais
sudo apt-get update
sudo apt-get install -y unzip jq curl software-properties-common apt-transport-https ca-certificates gnupg2

# Obtém IP da instância EC2
TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)

# Baixa e instala o Nomad
curl -L $NOMAD_DOWNLOAD > nomad.zip
sudo unzip nomad.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/nomad
sudo chown root:root /usr/local/bin/nomad
sudo mkdir -p $NOMAD_CONFIG_DIR
sudo chmod 755 $NOMAD_CONFIG_DIR

# Baixa e instala o Consul
curl -L $CONSUL_DOWNLOAD > consul.zip
sudo unzip -o consul.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/consul
sudo chown root:root /usr/local/bin/consul
sudo mkdir -p /etc/consul.d
sudo chmod 755 /etc/consul.d

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

# Instalar o Docker
distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$distro $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce

# Habilitar e iniciar o Docker
sudo systemctl enable docker
sudo systemctl start docker


# Configurar Nomad
sudo sed -i "s/CONSUL_TOKEN/$NOMAD_TOKEN/g" "$CONFIGDIR/nomad_client.hcl"
sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" "$CONFIGDIR/nomad_client.hcl"
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/nomad_client.hcl"
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/nomad_client.hcl"
sudo cp "$CONFIGDIR/nomad_client.hcl" "$NOMAD_CONFIG_DIR"
sudo cp "$CONFIGDIR/nomad.service" /etc/systemd/system/nomad.service

sudo systemctl enable nomad.service
sudo systemctl start nomad.service

# Configurar Consul
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" "$CONFIGDIR/consul_client.hcl"
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" "$CONFIGDIR/consul_client.hcl"
sed -i "s/CONSUL_TOKEN/$CONSUL_TOKEN/g" "$CONFIGDIR/consul_client.hcl"
sudo cp "$CONFIGDIR/consul_client.hcl" "$CONSUL_CONFIG_DIR"
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

# Criação de local para o grafana

sudo mkdir -p /opt/grafana/
sudo chown -R 472:472 /opt/grafana
sudo chmod -R 755 /opt/grafana


# Espera o Nomad estabelecer a conexão com o cluster
for i in {1..9}; do
    sleep 2
    LEADER=$(nomad operator raft list-peers | grep leader || true)
    if [ -n "$LEADER" ]; then
        echo "Cluster leader encontrado: $LEADER"
        break
    fi
done


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


# Configura a variável de ambiente para o Nomad
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append /home/ubuntu/.bashrc

# Configuração final do servidor
echo "Configuração completa! Nomad, Docker e Java foram instalados com sucesso."
