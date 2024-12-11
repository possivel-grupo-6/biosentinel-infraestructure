job "prometheus" {
  datacenters = ["dc1"]

  group "prometheus-group" {
    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        network_mode = "host" # Permite acesso à rede do host
        ports = ["prometheus"]
        args = [
          "--config.file=/local/prometheus.yml",
          "--web.enable-admin-api"
        ]

      }

      template {
        data = <<EOT
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'data-generator'
    consul_sd_configs:
      - server: '127.0.0.1:8500'
        services: ["data-generator"]  # Nome do serviço registrado no Consul
    metrics_path: "/metrics"  # Caminho onde as métricas estão sendo expostas

    relabel_configs:
      # Extrai informações do Consul e adiciona um label customizado 'source'
      - source_labels: [__meta_consul_service_metadata_external_source]
        target_label: source
        regex: (.*)
        replacement: '$1'

      # Extrai o 'task_id' baseado no ID do serviço no Consul (assumindo padrão Nomad)
      - source_labels: [__meta_consul_service_id]
        regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
        target_label: 'task_id'
        replacement: '$1'

      # Filtra apenas serviços com a tag 'prometheus' (ajuste a tag no Consul se necessário)
      - source_labels: [__meta_consul_tags]
        regex: '.*,prometheus,.*'
        action: keep  # Só mantém serviços que tenham a tag 'prometheus'

      # Extrai a tag 'app' ou 'monitoring' para criar um grupo de métricas
      - source_labels: [__meta_consul_tags]
        regex: ',(app|monitoring),'
        target_label: 'group'
        replacement: '$1'

      # Utiliza o nome do serviço no Consul como o valor do label 'job'
      - source_labels: [__meta_consul_service]
        target_label: job

      # Utiliza o nome do nó Consul como o valor do label 'instance'
      - source_labels: ['__meta_consul_node']
        regex: '(.*)'
        target_label: 'instance'
        replacement: '$1'
EOT
        destination = "/local/prometheus.yml"
      }

      service {
        name = "prometheus"
        port = "prometheus"

        check {
          name     = "Prometheus HTTP Health Check"
          type     = "http"
          path     = "/-/healthy"
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
      port "prometheus" {
        static = 9090
      }
    }
  }
}
