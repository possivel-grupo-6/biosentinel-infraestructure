output "nomad_ip" {
  value = "http://${aws_instance.server[0].public_ip}:4646/ui"
}

output "consul_token_secret" {
  value = random_uuid.Consul_token.result
}

output "nomad_token_secret" {
  value = random_uuid.nomad_token.result
}
output "IP_Addresses" {
  value = <<CONFIGURATION

It will take a little bit for setup to complete and the UI to become available.
Once it is, you can access the Nomad UI at:

http://${aws_instance.server[0].public_ip}:4646/ui

Set the Nomad address, run the bootstrap, export the management token, set the token variable, and test connectivity:

export NOMAD_ADDR=http://${aws_instance.server[0].public_ip}:4646 && \
nomad acl bootstrap | grep -i secret | awk -F "=" '{print $2}' | xargs > nomad-management.token && \
export NOMAD_TOKEN=$(cat nomad-management.token) && \
nomad server members && \
nomad ui -authenticate
'

Copy the token value and use it to log in to the UI:

cat nomad-management.token

The Consul UI can be accessed at http://${aws_instance.server[0].public_ip}:8500/ui
with the token: ${random_uuid.Consul_token.result}

export CONSUL_HTTP_ADDR=http://${aws_instance.server[0].public_ip}:8500 && \
export CONSUL_HTTP_TOKEN=${random_uuid.Consul_token.result}

CONFIGURATION
}