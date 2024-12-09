job "prometheus" {
  datacenters = ["dc1"]

  group "prometheus" {
    count = 1

    network {
      port "http" {
        static = 9090  
      }
    }

    task "prometheus" {
    driver = "docker"

    config {
        image = "prom/prometheus:latest"
        network_mode = "host" # Permite acesso à rede do host

        volumes = [
        "local/prometheus:/etc/prometheus"
        ]
    }

    resources {
        cpu    = 500
        memory = 512
    }

    template {
        data = <<-EOT
        global:
          scrape_interval: 15s

        scrape_configs:
          - job_name: "vault"
            params:
              format: ['prometheus']
            scheme: http
            authorization:
              credentials_file: /home/ubuntu/prometheus-token
            consul_sd_configs:
              - server: "http://127.0.0.1:8500"
                services: ["vault"]
            metrics_path: "/v1/sys/metrics"
          - job_name: "consul"
            consul_sd_configs:
              - server: "consul.service.consul:8500"
                scheme: "http"
            metrics_path: "/metrics"
            relabel_configs:
              - source_labels: ["__meta_consul_tags"]
                regex: ".*prometheus.*"
                action: "keep"
          - job_name: "nomad"
            static_configs:
              - targets: ["nomad.service.consul:4646"]


          - job_name: "prometheus"
            static_configs:
              - targets: ["localhost:9090"]

        EOT
        destination = "local/prometheus/prometheus.yml"
    }
    service {
        name = "prometheus"
        port = "http"

        check {
        name     = "Prometheus HTTP Health Check"
        type     = "http"
        path     = "/-/healthy"
        interval = "10s"
        timeout  = "5s"
        }
      }
    }
  }
}
