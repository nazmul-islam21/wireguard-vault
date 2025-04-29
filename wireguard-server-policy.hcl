# Full access to server key
path "wireguard/data/server/*" {
  capabilities = ["create", "update", "read", "list"]
}

# Allow listing version metadata (optional)
path "wireguard/metadata/server/*" {
  capabilities = ["list", "read"]
}

# Allow reading client public keys
path "wireguard/data/clients-public/*" {
  capabilities = ["read", "list"]
}

path "wireguard/metadata/clients-public/*" {
  capabilities = ["list"]
}
