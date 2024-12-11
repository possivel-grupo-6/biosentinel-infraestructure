job "tns" {
  datacenters = ["dc1"]
  type        = "service"

  group "tns" {
    count = 1

    network {
      port "db" {
        static = 8000
      }

      port "app" {
        static = 8001
      }

      port "loadgen" {
        static = 8002
      }
    }

    restart {
      attempts = 5
      interval = "10s"
      delay    = "2s"
      mode     = "delay"
    }

    task "db" {
      driver = "docker"

      template {
        data = <<EOT
{{- with service "tempo" }}
JAEGER_AGENT_HOST={{ (index . 0).Address }}
JAEGER_AGENT_PORT={{ (index . 0).Port }}
{{ else }}
JAEGER_AGENT_HOST=localhost
JAEGER_AGENT_PORT=6831
{{ end }}
EOT
        destination = "local/jaeger_env"
        env         = true
      }

      config {
        image = "grafana/tns-db:latest"
        network_mode = "host" # Permite acesso à rede do host
        ports = ["db"]

        args = [
          "-log.level=debug",
          "-server.http-listen-port=${NOMAD_PORT_db}",
        ]
      }

      service {
        name = "db"
        port = "db"
        tags = ["app", "prometheus"]
      }
    }

    task "app" {
      driver = "docker"

      template {
        data = <<EOT
{{- with service "tempo" }}
JAEGER_AGENT_HOST={{ (index . 0).Address }}
JAEGER_AGENT_PORT={{ (index . 0).Port }}
{{ else }}
JAEGER_AGENT_HOST=localhost
JAEGER_AGENT_PORT=6831
{{ end }}
EOT
        destination = "local/jaeger_env"
        env         = true
      }

      config {
        image = "grafana/tns-app:latest"
        network_mode = "host" 
        ports = ["app"]

        args = [
          "-log.level=debug",
          "-server.http-listen-port=${NOMAD_PORT_app}",
          "http://db.service.dc1.consul:${NOMAD_PORT_db}",
        ]
      }

      service {
        name = "app"
        port = "app"
        tags = ["app", "prometheus"]
      }
    }

    task "loadgen" {
      driver = "docker"

      template {
        data = <<EOT
{{- with service "tempo" }}
JAEGER_AGENT_HOST={{ (index . 0).Address }}
JAEGER_AGENT_PORT={{ (index . 0).Port }}
{{ else }}
JAEGER_AGENT_HOST=localhost
JAEGER_AGENT_PORT=6831
{{ end }}
EOT
        destination = "local/jaeger_env"
        env         = true
      }

      config {
        image = "grafana/tns-loadgen:latest"
        network_mode = "host" 
        ports = ["loadgen"]

        args = [
          "-log.level=debug",
          "-server.http-listen-port=${NOMAD_PORT_loadgen}",
          "http://app.service.dc1.consul:${NOMAD_PORT_app}",
        ]
      }

      service {
        name = "loadgen"
        port = "loadgen"
        tags = ["app", "prometheus"]
      }
    }
  }
}
