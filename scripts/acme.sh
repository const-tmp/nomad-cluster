curl https://get.acme.sh | sh -s email=${email}
${acme_dir}/acme.sh --issue -d ${domain} --standalone
${acme_dir}/acme.sh --install-cert -d ${domain} \
  --key-file ${key_file} \
  --fullchain-file ${fullchain_file} \
  --reloadcmd "${reloadcmd}"
