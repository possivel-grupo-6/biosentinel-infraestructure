job "tempo" {
  datacenters = ["dc1"]
  type        = "service"

  group "tempo" {
    count = 1

    network {
      port "tempo" {
          static = "3400"
      }
      port "tempo-write" {
        static = "6831"
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "tempo" {
      driver = "docker"
      template {
        data = <<EOT
{{- with service "tempo" }}
JAEGER_AGENT_HOST={{ (index . 0).Address }}
{{ else }}
JAEGER_AGENT_HOST=localhost
{{ end }}
EOT
        destination = "local/jaeger_env"
        env         = true
      }

      env {
        JAEGER_TAGS          = "cluster=nomad"
        JAEGER_SAMPLER_TYPE  = "probabilistic"
        JAEGER_SAMPLER_PARAM = "1"
      }

      artifact {
        source      = "https://raw.githubusercontent.com/grafana/tempo/main/example/docker-compose/local/tempo.yaml"
        mode        = "file"
        destination = "/local/tempo.yml"
      }
      config {
        image = "grafana/tempo:latest"
        network_mode = "host" # Permite acesso à rede do host
        ports = ["tempo", "tempo-write"]
        args = [
          "-config.file=/local/tempo.yml",
          "-server.http-listen-port=${NOMAD_PORT_tempo}",
        ]
      }

      resources {
        cpu    = 200
        memory = 200
      }

      service {
        name = "tempo"
        port = "tempo"
        tags = ["monitoring","prometheus"]

        check {
          name     = "Tempo HTTP"
          type     = "http"
          path     = "/ready"
          interval = "5s"
          timeout  = "2s"

          check_restart {
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }
    }
  }
}