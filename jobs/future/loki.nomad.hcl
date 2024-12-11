job "loki" {
  datacenters = ["dc1"]
  type        = "service"

  group "loki" {
    count = 1

    network {
      dns {
        servers = ["172.17.0.1", "8.8.8.8", "8.8.4.4"]
      }
      port "http" {
        static = 3100
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "loki" {
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

      config {
        image = "grafana/loki:latest"
        network_mode = "host" 
        ports = ["http"]
        args = [
          "-config.file",
          "/etc/loki/local-config.yaml",
        ]
      }

      resources {
        cpu    = 200
        memory = 200
      }

      service {
        name = "loki"
        port = "http"
        tags = ["monitoring","prometheus"]

        check {
          name     = "Loki HTTP"
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