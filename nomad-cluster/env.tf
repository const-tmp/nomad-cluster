resource "null_resource" "tls-dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${var.local_tls_dir}/nomad"
  }
}

resource "local_file" "nomad-ca" {
  depends_on = [null_resource.tls-dir]
  filename   = "${var.local_tls_dir}/nomad/ca.pem"
  content    = vault_pki_secret_backend_cert.cli.issuing_ca
}

resource "local_file" "nomad-cert" {
  depends_on = [null_resource.tls-dir]
  filename   = "${var.local_tls_dir}/nomad/client-cert.pem"
  content    = vault_pki_secret_backend_cert.cli.certificate
}

resource "local_sensitive_file" "nomad-key" {
  depends_on = [null_resource.tls-dir]
  filename   = "${var.local_tls_dir}/nomad/client-key.pem"
  content    = vault_pki_secret_backend_cert.cli.private_key
}

resource "local_sensitive_file" "env" {
  filename = var.env_file
  content  = <<EOF
export NOMAD_ADDR="https://${values(var.server_nodes)[0]}:4646"
export NOMAD_CACERT=${abspath(local_file.nomad-ca.filename)}
export NOMAD_CLIENT_CERT=${abspath(local_file.nomad-cert.filename)}
export NOMAD_CLIENT_KEY=${abspath(local_sensitive_file.nomad-key.filename)}
export NOMAD_HTTP_SSL_VERIFY=false
export NOMAD_TOKEN=${jsondecode(data.local_sensitive_file.bootstrap.content).SecretID}
EOF
}

resource "null_resource" "env" {
  provisioner "local-exec" {
    command = "grep 'source ${abspath(local_sensitive_file.env.filename)}' $HOME/.zshrc || echo 'source ${abspath(local_sensitive_file.env.filename)}' >> $HOME/.zshrc"
  }
}
