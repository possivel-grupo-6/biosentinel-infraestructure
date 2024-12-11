job "mysql" {
  datacenters = ["dc1"]
  type = "service"

  group "mysql-group" {
    network {
      port "db" {
        static = 3306  
      }
    }

    task "mysql-task" {
      driver = "docker"

      config {
        image = "mysql:8.0"  
        ports = ["db"]       
      }

      env = {
        MYSQL_ROOT_PASSWORD = "urubu100"  
        MYSQL_DATABASE = "biosentinel-database"        
        MYSQL_USER = "user"       
        MYSQL_PASSWORD = "passwd" 
      }

      resources {
        cpu    = 500  
        memory = 512  
      }

      service {
        name = "fastlog-mysql"   
        port = "db"              
        tags = ["mysql", "db"]   
        provider = "consul"      

        check {
          name     = "MySQL TCP Check"
          type     = "tcp"
          interval = "10s"       
          timeout  = "2s"        
        }
      }
    }
  }
}
