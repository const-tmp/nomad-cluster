output "consul_addr" {
  value = "https://${values(var.server_nodes)[0]}:8501"
}
output "ca" {
  value = vault_pki_secret_backend_cert.client-tls.issuing_ca
}
output "ca_file" {
  value = abspath(local_file.ca.filename)
}
output "cert" {
  value = vault_pki_secret_backend_cert.client-tls.certificate
}
output "cert_file" {
  value = abspath(local_file.cert.filename)
}
output "key" {
  value = vault_pki_secret_backend_cert.client-tls.private_key
}
output "key_file" {
  value = abspath(local_sensitive_file.key.filename)
}
output "token" {
  value     = jsondecode(data.local_sensitive_file.acl.content).SecretID
  sensitive = true
}
