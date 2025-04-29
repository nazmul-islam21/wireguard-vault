# Allow user to manage its own private key
path "wireguard/data/clients-private/*" {
  capabilities = ["create", "update", "read"]
}

# Allow user to manage its own public key
path "wireguard/data/clients-public/*" {
  capabilities = ["create", "update", "read"]
}

# Allow user to read server public key
path "wireguard/data/server/*" {
  capabilities = ["read"]
}
