job "patroni" {
  type             = "service"

  group "group" {
    count = 3

    spread {
      attribute = "${node.unique.id}"
    }

    network {
      port api { to = 8080 }
      port pg { to = 5432 }
    }

    task "db" {
      driver = "docker"

      template {
        data        = <<EOL
scope: postgres
name: pg-{{env "node.unique.name"}}
namespace: /nomad

restapi:
  listen: 0.0.0.0:{{env "NOMAD_PORT_api"}}
  connect_address: {{env "NOMAD_ADDR_api"}}

consul:
  host: localhost:8500
  register_service: true

bootstrap:
  method: initdb
  dcs:
    synchronous_mode: true
  initdb:  # List options to be passed on to initdb
    - encoding: UTF8
    - locale: en_US.UTF-8
    - data-checksums
  pg_hba:  # Add following lines to pg_hba.conf after running 'initdb'
    - host replication replicator 127.0.0.1/32 md5
    - host all all 0.0.0.0/0 md5

postgresql:
  listen: 0.0.0.0:5432
  connect_address: {{env "NOMAD_ADDR_pg"}}
  use_unix_socket: true
  data_dir: /alloc/data
  authentication:
    replication:
      username: repl
      password: repl
    superuser:
      username: postgres
      password: postgres
  create_replica_methods:
    - basebackup
  basebackup:
    max-rate: '100M'
    checkpoint: 'fast'
EOL
        destination = "/secrets/patroni.yml"
      }

      config {
        image        = "ghcr.io/ccakes/nomad-pgsql-patroni:15.1-2.tsdb_gis"
        ports        = ["api", "pg"]
        network_mode = "host"
      }
    }
  }
}
