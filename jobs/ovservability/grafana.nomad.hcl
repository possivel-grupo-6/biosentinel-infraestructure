job "grafana" {
  datacenters = ["dc1"]

  group "grafana-group" {
    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        network_mode = "host" # Permite acesso à rede do host
        ports = ["grafana"]
      }
      env {
        GF_LOG_LEVEL          = "DEBUG"
        GF_LOG_MODE           = "console"
        GF_SERVER_HTTP_PORT   = "${NOMAD_PORT_http}"
        GF_PATHS_PROVISIONING = "/local/grafana/provisioning"
      }

      template {
        data = <<EOTC
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://{{ with service "prometheus" }}{{ (index . 0).Address }}:{{ (index . 0).Port }}{{ else }}no-prometheus-service{{ end }}
    jsonData:
      # Aqui você pode adicionar outras configurações específicas, se necessário
      timeInterval: "5s"
EOTC
        destination = "/local/grafana/provisioning/datasources/ds.yaml"
      }

      service {
        name = "grafana"
        port = "grafana"

        check {
          name     = "Grafana HTTP Health Check"
          type     = "http"
          path     = "/api/health"
          interval = "10s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }

    network {
      port "grafana" {
        static = 3000
      }
    }
  }
}
