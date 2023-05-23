variable "patroni_nodes" {
  type = map(string)
}
variable "scope" {
  type = string
}
variable "namespace" {
  type = string
}
variable "postgres_version" {
  default = 13
}
variable "data_dir" {
  default = "/var/lib/postgresql/%d/main"
}
variable "bin_dir" {
  default = "/usr/lib/postgresql/%d/bin"
}
variable "config_dir" {
  default = "/etc/postgresql/%d/main"
}
variable "pgpass" {
  default = "/var/lib/postgresql/.pgpass_patroni"
}


resource "null_resource" "provision" {
  for_each = var.patroni_nodes

  connection {
    host  = each.value
    agent = true
  }

  provisioner "file" {
    content     = <<EOF
[Unit]
Description=Runners to orchestrate a high-availability PostgreSQL - Patroni
After=syslog.target network.target

[Service]
Type=simple

User=postgres
Group=postgres

# Read in configuration file if it exists, otherwise proceed
EnvironmentFile=-/etc/patroni_env.conf

# The default is the user's home directory, and if you want to change it, you must provide an absolute path.
# WorkingDirectory=~

# Where to send early-startup messages from the server
# This is normally controlled by the global default set by systemd
# StandardOutput=syslog

# Pre-commands to start watchdog device
# Uncomment if watchdog is part of your patroni setup
ExecStartPre=-/usr/bin/sudo /sbin/modprobe softdog
ExecStartPre=-/usr/bin/sudo /bin/chown postgres /dev/watchdog

# Start the patroni process
ExecStart=/var/lib/postgresql/patroni/venv/bin/patroni /etc/patroni/patroni.yaml

# Send HUP to reload from patroni.yml
ExecReload=/bin/kill -s HUP $MAINPID

# Only kill the patroni process, not it's children, so it will gracefully stop postgres
KillMode=process

# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=60

# Restart the service if it crashed
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    destination = "/etc/systemd/system/patroni.service"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /etc/patroni/",
      "openssl ecparam -name prime256v1 -out /etc/patroni/prime256v1.ecparam",
      "openssl req -x509 -newkey ec:/etc/patroni/prime256v1.ecparam -keyout ${format(var.data_dir, var.postgres_version)}/server.key -out ${format(var.data_dir, var.postgres_version)}/server.crt -sha256 -days 3650 -nodes -subj \"/CN=${each.key}\"",
      "chmod 600 ${format(var.data_dir, var.postgres_version)}/server.key",
      "chown postgres:postgres ${format(var.data_dir, var.postgres_version)}/server.key ${format(var.data_dir, var.postgres_version)}/server.crt"
    ]
  }

  provisioner "file" {
    content = yamlencode({
      scope     = var.scope
      name      = each.key
      namespace = var.namespace
      consul    = {
        host             = "127.0.0.1:8500"
        register_service = true
      }
      restapi = {
        listen          = "0.0.0.0:8008"
        connect_address = "${each.value}:8008"
      }
      postgresql = {
        listen          = "0.0.0.0:5432"
        connect_address = "${each.value}:5432"
        use_unix_socket = "true"
        data_dir        = format(var.data_dir, var.postgres_version)
        bin_dir         = format(var.bin_dir, var.postgres_version)
        config_dir      = format(var.config_dir, var.postgres_version)
        pgpass          = var.pgpass
        authentication  = {
          replication = {
            username = "replicator"
            password = "replicator-pass"
          }
          superuser = {
            username = "postgres"
            password = "postgres-pass"
          }
        }
      }
      bootstrap = {
        method = "initdb"
        initdb = [
          { encoding = "UTF8" },
          { locale = "en_US.UTF-8" },
          "data-checksums",
        ]
        pg_hba = [
          "hostssl replication replicator 0.0.0.0/0 scram-sha-256",
          "hostssl all all 0.0.0.0/0 scram-sha-256",
          "host replication replicator 127.0.0.1/32 scram-sha-256",
          "host all all 127.0.0.1/32 scram-sha-256",
        ]
        dcs = {
          synchronous_mode        = true
#          synchronous_mode        = "on"
#          synchronous_mode_strict = "on",
          postgresql              = {
            use_pg_rewind = true
            parameters    = {
              password_encryption       = "scram-sha-256"
              ssl                       = "on"
#              synchronous_commit        = "on"
#              synchronous_standby_names = "*"
            }
          }
        }
      }
    })
    destination = "/etc/patroni/patroni.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chown -R postgres:postgres /etc/patroni/",
      "systemctl disable postgresql.service --now",
      "rm -r ${format(var.data_dir, var.postgres_version)}/*",
      "systemctl daemon-reload",
      "systemctl enable patroni.service",
      "systemctl restart patroni.service",
    ]
  }
}
