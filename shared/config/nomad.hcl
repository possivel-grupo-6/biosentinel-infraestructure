# Values for server_count, retry_join, and ip_address are
# placed here during Terraform setup and come from the 
# ../shared/data-scripts/user-data-server.sh script

data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"
datacenter = "dc1"

advertise {
  http = "IP_ADDRESS"
  rpc  = "IP_ADDRESS"
  serf = "IP_ADDRESS"
}

acl {
  enabled = true
}

server {
  enabled          = true
  bootstrap_expect = SERVER_COUNT

  server_join {
    retry_join = ["RETRY_JOIN"]
  }
}

vault {
  enabled = true
  address = "http://127.0.0.1:8200"
  auth_method = "approle"
  task_token_ttl = "1h"
  approle {
    role_id   = "ROLE_ID"
    secret_id = "SECRET_ID"
  }
  create_from_role = "nomad-cluster"
}

telemetry {
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

consul {
  address = "127.0.0.1:8500"
  client_service_name = "nomad-client"
  server_service_name = "nomad-server"
  auto_advertise = true
  token = "CONSUL_TOKEN"
  server_auto_join = true
  client_auto_join = true
}
