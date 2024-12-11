job "jupyter-notebook" {
  datacenters = ["dc1"]
  type = "service"
  
  group "jupyter-group" {
    task "jupyter" {
      driver = "docker"
      
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

      volume {
        name      = "spark-volume"
        read_only = false
        # Usando tmpfs para criar um volume temporário dentro do contêiner
        source    = "tmpfs"
        target    = "/usr/local/spark"  # Diretório onde será montado no contêiner
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

      lifecycle {
        hook = "poststart"
        command = "bash"
        # O start.sh será tratado como um template, onde variáveis de ambiente serão substituídas.
        args = ["/opt/jupyter/script/start.sh"]
      }
    }
  }

  # Definição do volume do Nomad para o contêiner
  volume "spark-volume" {
    type        = "docker"
    source      = "tmpfs"  # Volume temporário
    read_only   = false
    destination = "/usr/local/spark"  # Onde o volume será montado no contêiner
  }
}
