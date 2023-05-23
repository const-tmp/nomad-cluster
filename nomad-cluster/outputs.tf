output "nomad_addr" {
  value = "https://${values(var.server_nodes)[0]}:4646"
}
output "ca" {
  value = vault_pki_secret_backend_cert.cli.issuing_ca
}
output "cert" {
  value = vault_pki_secret_backend_cert.cli.certificate
}
output "key" {
  value     = vault_pki_secret_backend_cert.cli.private_key
  sensitive = true
}
output "token" {
  value = jsondecode(data.local_sensitive_file.bootstrap.content).SecretID
}