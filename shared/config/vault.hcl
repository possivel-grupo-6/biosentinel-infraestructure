storage "consul" {
  address      = "127.0.0.1:8500"
  path         = "vault/"
  service      = "vault"
  service_tags = "secrets"
  token        = "VAULT_TOKEN"
  scheme       = "http"
}

api_addr     = "http://IP_ADDRESS:8200"
cluster_addr = "http://IP_ADDRESS:8201"

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1

}

disable_mlock = true
ui            = true

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname          = true
}

seal "awskms" {
  region     = "us-east-1" 
  kms_key_id = "arn:aws:kms:us-east-1:345137894335:key/1d75f115-b2e3-4027-8379-59500a6ccf03"
}


retry_join = ["RETRY_JOIN"]
