#!/bin/bash

set -euo pipefail

### === CONFIGURATION ===
VAULT_ADDR="https://vault.vault-url.nip.io"
ROLE_ID="***********"
SECRET_ID="**********"
SERVER_NAME="wireguard-server"
WG_INTERFACE_IP="172.16.0.1/24"
LISTEN_PORT=51820
WG_CONF="/etc/wireguard/wg0.conf"

export VAULT_ADDR

### === AUTHENTICATE TO VAULT ===
echo "🔐 Authenticating to Vault via AppRole..."

VAULT_TOKEN=$(vault write -format=json auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID" \
    | jq -r '.auth.client_token')

if [[ -z "$VAULT_TOKEN" || "$VAULT_TOKEN" == "null" ]]; then
  echo "❌ Failed to get Vault token. Check ROLE_ID or SECRET_ID."
  exit 1
fi

export VAULT_TOKEN
echo "✅ Vault token retrieved."

### === CHECK/CREATE SERVER PRIVATE KEY ===
echo "🔍 Checking if server key exists in Vault..."

if ! vault kv get -field=private_key wireguard/server/$SERVER_NAME &>/dev/null; then
  echo "🔑 Server private key not found. Generating new keypair..."

  SERVER_PRIV=$(wg genkey)
  SERVER_PUB=$(echo "$SERVER_PRIV" | wg pubkey)

  vault kv put wireguard/server/$SERVER_NAME \
    private_key="$SERVER_PRIV" \
    public_key="$SERVER_PUB" \
    interface_ip="$WG_INTERFACE_IP" \
    listen_port="$LISTEN_PORT"

  echo "✅ Server keypair saved to Vault."
fi

### === RETRIEVE SERVER KEY ===
echo "📥 Fetching server private key from Vault..."

SERVER_PRIV=$(vault kv get -field=private_key wireguard/server/$SERVER_NAME)
if [[ -z "$SERVER_PRIV" ]]; then
  echo "❌ Empty private key fetched. Aborting."
  exit 1
fi

### === GENERATE BASE CONFIG ===
echo "⚙️  Creating WireGuard server config..."

cat <<EOF > "$WG_CONF"
[Interface]
PrivateKey = $SERVER_PRIV
Address = $WG_INTERFACE_IP
ListenPort = $LISTEN_PORT
SaveConfig = true
EOF

### === APPEND CLIENT PEERS ===
echo "🔄 Syncing client public keys..."

client_list=$(vault kv list -format=json wireguard/clients-public | jq -r '.[]')

for client in $client_list; do
  pubkey=$(vault kv get -field=public_key wireguard/clients-public/$client 2>/dev/null || true)
  allowed_ips=$(vault kv get -field=allowed_ips wireguard/clients-public/$client 2>/dev/null || true)

  if [[ -n "$pubkey" && -n "$allowed_ips" ]]; then
    echo "✅ Adding client: $client ($allowed_ips)"

    cat <<EOF >> "$WG_CONF"

[Peer]
PublicKey = $pubkey
AllowedIPs = $allowed_ips
EOF
  else
    echo "⚠️  Skipping client $client due to missing keys"
  fi
done

### === APPLY CONFIG ===
echo "📡 Applying WireGuard config..."

wg syncconf wg0 <(wg-quick strip wg0)

echo "✅ Server WireGuard configuration updated and applied."