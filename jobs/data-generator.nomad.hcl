job "data-generator" {
  datacenters = ["dc1"]
  meta {
    version = "v3.0.0"
  }
  group "api-group" {
    task "api" {
      driver = "docker"

      config {
        image = "joaomiziaraspt/data-generator:latest"
        ports = ["http"]
      }

      service {
        name = "data-generator"
        port = "http"
        tags = ["app", "prometheus", "monitoring"]


        check {
          name     = "API HTTP Health Check"
          type     = "http"
          path     = "/metrics"
          interval = "10s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }

    network {
      port "http" {
        static = 8000
      }
    }
  }
}