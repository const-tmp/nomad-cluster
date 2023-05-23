data "vultr_os" "os" {
  filter {
    name   = "id"
    values = [var.os_id]
  }
}

locals {
  default-packages = [
    "jq",
    "socat",
    "fail2ban",
  ]
  install-hc = {
    package_update  = true
    package_upgrade = true
    apt             = {
      sources = {
        "hashicorp.list" = {
          source    = "deb [signed-by=$KEY_FILE] https://apt.releases.hashicorp.com $RELEASE main"
          keyserver = "https://apt.releases.hashicorp.com/gpg"
          keyid     = "798AEC654E5C15428C8E42EEAA16FCBCA621E701"
        }
      }
    }
    packages = concat([
      "consul",
      "vault",
      "nomad",
    ], local.default-packages)
    runcmd = [
      ["sed", "-i", "s/IPV6=yes/IPV6=no/", "/etc/default/ufw"],
      ["ufw", "allow", "80/tcp", "comment", "HTTP"],
      ["ufw", "allow", "8500:8503,8300:8302/tcp", "comment", "Consul TCP"],
      ["ufw", "allow", "8301:8302/udp", "comment", "Consul UDP"],
      ["ufw", "allow", "8600", "comment", "Consul DNS"],
      ["ufw", "allow", "4646:4648/tcp", "comment", "Nomad TCP"],
      ["ufw", "allow", "4648/udp", "comment", "Nomad UDP"],
    ]
    power_state = {
      delay     = "now"
      mode      = "reboot"
      message   = "Reboot after installing"
      condition = true
    }
  }
}

module "vm" {
  source       = "../modules/vm"
  os_id        = var.os_id
  ssh_key_name = var.ssh_key_name
  instances    = {
    waw = {
      region    = "waw"
      instances = {
        infra = {
          count = 1
        }
        nomad-client = {
          count = 1
          plan  = "vc2-2c-4gb"
        }
        patroni = {
          count = 1
        }
      }
    }
    fra = {
      region    = "fra"
      instances = {
        infra = {
          count = 1
        }
        #        nomad-client = {
        #          count = 1
        #          plan  = "vc2-2c-4gb"
        #        }
        patroni = {
          count = 1
        }
      }
    }
    sto = {
      region    = "sto"
      instances = {
        infra = {
          count = 1
        }
        #        nomad-client = {
        #          count = 1
        #          plan  = "vc2-2c-4gb"
        #        }
        patroni = {
          count = 1
        }
      }
    }
  }
  cloud_config = {
    infra        = local.install-hc
    nomad-client = {
      package_update  = true
      package_upgrade = true
      apt             = {
        sources = {
          "hashicorp.list" = {
            source    = "deb [signed-by=$KEY_FILE] https://apt.releases.hashicorp.com $RELEASE main"
            keyserver = "https://apt.releases.hashicorp.com/gpg"
            keyid     = "798AEC654E5C15428C8E42EEAA16FCBCA621E701"
          }
          "docker.list" = {
            source    = "deb [signed-by=$KEY_FILE] https://download.docker.com/linux/${data.vultr_os.os.family} $RELEASE stable"
            keyserver = "https://download.docker.com/linux/${data.vultr_os.os.family}/gpg"
            keyid     = "9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
          }
        }
      }
      packages = concat([
        "consul",
        "vault",
        "nomad",
        "docker-ce",
        "docker-ce-cli",
        "containerd.io",
        "docker-buildx-plugin",
        "docker-compose-plugin",
      ], local.default-packages)
      runcmd = [
        ["sed", "-i", "s/IPV6=yes/IPV6=no/", "/etc/default/ufw"],
        ["ufw", "allow", "80/tcp", "comment", "HTTP"],
        ["ufw", "allow", "8300:8302/tcp", "comment", "Consul TCP"],
        ["ufw", "allow", "8301:8302/udp", "comment", "Consul UDP"],
        ["ufw", "allow", "4646:4648/tcp", "comment", "Nomad TCP"],
        ["ufw", "allow", "4648/udp", "comment", "Nomad UDP"],
        ["ufw", "allow", "20000:32000/udp", "comment", "Nomad tasks UDP"],
        ["ufw", "allow", "20000:32000/tcp", "comment", "Nomad tasks TCP"],
        [
          "curl", "-L", "-o", "cni-plugins.tgz",
          "https://github.com/containernetworking/plugins/releases/download/v1.2.0/cni-plugins-linux-amd64-v1.2.0.tgz"
        ],
        ["mkdir", "-p", "/opt/cni/bin"],
        ["tar", "-C", "/opt/cni/bin", "-xzf", "cni-plugins.tgz"],
        ["echo", "1", "|", "sudo", "tee", "/proc/sys/net/bridge/bridge-nf-call-arptables"],
        ["echo", "1", "|", "sudo", "tee", "/proc/sys/net/bridge/bridge-nf-call-ip6tables"],
        ["echo", "1", "|", "sudo", "tee", "/proc/sys/net/bridge/bridge-nf-call-iptables"],
      ]
      power_state = {
        delay     = "now"
        mode      = "reboot"
        message   = "Reboot after installing"
        condition = true
      }
    }
    patroni = {
      package_update  = true
      package_upgrade = true
      apt             = {
        sources = {
          "hashicorp.list" = {
            source    = "deb [signed-by=$KEY_FILE] https://apt.releases.hashicorp.com $RELEASE main"
            keyserver = "https://apt.releases.hashicorp.com/gpg"
            keyid     = "798AEC654E5C15428C8E42EEAA16FCBCA621E701"
          }
        }
      }
      packages = concat([
        "consul",
        "vault",
        "postgresql",
        "libpq-dev",
        "python3-dev",
        "python3-pip",
        "python3-virtualenv",
      ], local.default-packages)
      runcmd = [
        ["sed", "-i", "s/IPV6=yes/IPV6=no/", "/etc/default/ufw"],
        ["ufw", "allow", "80/tcp", "comment", "HTTP"],
        ["ufw", "allow", "5432,6432,8008/tcp", "comment", "Patroni"],
        ["ufw", "allow", "8300:8302/tcp", "comment", "Consul TCP"],
        ["ufw", "allow", "8301:8302/udp", "comment", "Consul UDP"],
        <<EOC
sudo -iu postgres bash << EOF
mkdir -p patroni
pushd patroni
virtualenv venv
venv/bin/pip install psycopg patroni[consul]
popd
EOF
EOC
      ]
      power_state = {
        delay     = "now"
        mode      = "reboot"
        message   = "Reboot after installing"
        condition = true
      }
    }
  }
}
