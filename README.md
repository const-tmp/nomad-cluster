```
terraform apply
```
# mTLS
```
open $NOMAD_CACERT
openssl pkcs12 -inkey $NOMAD_CLIENT_KEY -in $NOMAD_CLIENT_CERT -export -out tls/nomad/cert.pfx
open tls/nomad/cert.pfx
open $CONSUL_CACERT
openssl pkcs12 -inkey $CONSUL_CLIENT_KEY -in $CONSUL_CLIENT_CERT -export -out tls/consul/cert.pfx
open tls/consul/cert.pfx
```
