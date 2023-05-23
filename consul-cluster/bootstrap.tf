resource "null_resource" "bootstrap" {
  depends_on = [
    null_resource.server,
  ]
  #  provisioner "local-exec" {
  #    command = "sleep 10"
  #  }
  provisioner "local-exec" {
    command = "mkdir -p ${var.secret_dir} && consul acl bootstrap -format=json > ${var.secret_dir}/consul-acl.json"
    environment = {
      CONSUL_HTTP_ADDR       = "https://${values(var.server_nodes)[0]}:8501"
      CONSUL_CACERT          = abspath(local_file.ca.filename)
      CONSUL_CLIENT_CERT     = abspath(local_file.cert.filename)
      CONSUL_CLIENT_KEY      = abspath(local_sensitive_file.key.filename)
      CONSUL_HTTP_SSL_VERIFY = false
    }
  }
}

data "local_sensitive_file" "acl" {
  depends_on = [null_resource.bootstrap]
  filename   = "${var.secret_dir}/consul-acl.json"
}
