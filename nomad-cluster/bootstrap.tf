resource "null_resource" "bootstrap" {
  depends_on = [null_resource.nomad]

#  provisioner "local-exec" {
#    command = "sleep 10"
#  }

  provisioner "local-exec" {
    command = "mkdir -p secret && nomad acl bootstrap -json > ${var.secret_dir}/nomad-acl.json"
    environment = {
      NOMAD_ADDR            = "https://${values(var.server_nodes)[0]}:4646"
      NOMAD_CACERT          = local_file.nomad-ca.filename
      NOMAD_CLIENT_CERT     = local_file.nomad-cert.filename
      NOMAD_CLIENT_KEY      = local_sensitive_file.nomad-key.filename
      NOMAD_HTTP_SSL_VERIFY = false
    }
  }
}

data "local_sensitive_file" "bootstrap" {
  depends_on = [null_resource.bootstrap]
  filename   = "${var.secret_dir}/nomad-acl.json"
}
