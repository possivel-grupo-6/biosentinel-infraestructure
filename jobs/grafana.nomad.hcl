job "grafana" {
  datacenters = ["dc1"]

  group "grafana" {
    count = 1

    network {
      port "http" {
        static = 3000
      }
    }

    service {
      name = "grafana"
      port = "http"
      tags = ["dashboard", "urlprefix-/"]

      check {
        type     = "http"
        path     = "/login"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["http"]
      }

      env {
        GF_SECURITY_ADMIN_USER     = "admin"
        GF_SECURITY_ADMIN_PASSWORD = "admin"
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
