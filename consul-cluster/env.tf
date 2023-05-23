resource "null_resource" "tls-dir" {
  provisioner "local-exec" {
    command="mkdir -p ${var.local_tls_dir}/consul"
  }
}

resource "local_file" "ca" {
  depends_on=[null_resource.tls-dir]
  filename = "${var.local_tls_dir}/consul/ca.pem"
  content  = vault_pki_secret_backend_cert.client-tls.issuing_ca
}

resource "local_file" "cert" {
  depends_on=[null_resource.tls-dir]
  filename = "${var.local_tls_dir}/consul/client-cert.pem"
  content  = vault_pki_secret_backend_cert.client-tls.certificate
}

resource "local_sensitive_file" "key" {
  depends_on=[null_resource.tls-dir]
  filename = "${var.local_tls_dir}/consul/client-key.pem"
  content  = vault_pki_secret_backend_cert.client-tls.private_key
}

resource "local_sensitive_file" "env" {
  filename = var.env_file
  content  = <<EOF
export CONSUL_HTTP_ADDR="https://${values(var.server_nodes)[0]}:8501"
export CONSUL_CACERT=${abspath(local_file.ca.filename)}
export CONSUL_CLIENT_CERT=${abspath(local_file.cert.filename)}
export CONSUL_CLIENT_KEY=${abspath(local_sensitive_file.key.filename)}
export CONSUL_HTTP_SSL_VERIFY=false
export CONSUL_HTTP_TOKEN=${jsondecode(data.local_sensitive_file.acl.content).SecretID}
EOF
}

resource "null_resource" "env" {
  provisioner "local-exec" {
    command = "grep 'source ${abspath(local_sensitive_file.env.filename)}' $HOME/.zshrc || echo 'source ${abspath(local_sensitive_file.env.filename)}' >> $HOME/.zshrc"
  }
}
