job "jupyter-notebook" {
  datacenters = ["dc1"]
  type = "service"

  # Garantir que o job será executado apenas no nó 'ip-10-0-2-135'
  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "ip-10-0-2-135"
  }

  # Definição do volume que será usado na tarefa

  group "jupyter-group" {
    task "jupyter" {
      driver = "docker"
        volume "notebooks-volume" {
            type        = "host"
            source      = "/home/ubuntu/notebooks"  # Caminho local no host onde os notebooks estão localizados
            destination = "/opt/jupyter/notebook"  # Onde os notebooks serão montados dentro do contêiner
        }

      config {
        image = "python:3.9"  # Usando uma imagem Python que você pode customizar com suas dependências, como o Jupyter e PySpark
        port_map = {
          http = 80
        }
      }

      env = {
        SPARK_HOME       = "/usr/local/spark"
        PYSPARK_PYTHON   = "/usr/local/bin/python"
        JUPYTER_PASSWORD = "urubu100"  # Senha para Jupyter
      }

      resources {
        cpu    = 500    # 0.5 CPUs
        memory = 1024   # 1 GB de memória
        network {
          mbits = 10
          port "http" {}
        }
      }

      # Montando os volumes dentro do contêiner
      volume_mount {
        volume      = "notebooks-volume"
        destination = "/opt/jupyter/notebook"
        read_only   = false
      }

      service {
        name = "jupyter-notebook"
        port = "http"
        tags = ["jupyter", "spark"]
        check {
          name     = "HTTP Check"
          type     = "http"
          path     = "/"
          port     = "http"
          interval = "10s"
          timeout  = "2s"
        }
      }

      template {
        destination = "/opt/jupyter/script/start.sh"
        change_mode  = "restart"
        change_signal = "SIGHUP"

        data = <<EOT
#!/bin/bash
PASSWORD_HASH=\$(/usr/bin/python3 -c "from notebook.auth import passwd; print(passwd('${env.JUPYTER_PASSWORD}'))")
/usr/bin/python3 -m notebook --NotebookApp.notebook_dir=/opt/jupyter/notebook --NotebookApp.password=\$PASSWORD_HASH --allow-root --ip 0.0.0.0 --port 80
EOT
      }
    }
  }
}
