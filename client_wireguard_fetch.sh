#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
VAULT_ADDR="https://vault.vault-url.nip.io"
VAULT_USERNAME="<Username>"
VAULT_PASSWORD="**********"
WG_CONF="$HOME/wg0-client.conf"
CLIENT_NAME="$VAULT_USERNAME"
SERVER_NAME="wireguard-server"
DEFAULT_CLIENT_IP="172.16.0.$((RANDOM % 100 + 10))/32"

export VAULT_ADDR

# === Check Requirements ===
for cmd in vault jq wg; do
    if ! command -v $cmd &>/dev/null; then
        echo "❌ Required command '$cmd' not found. Please install it first."
        exit 1
    fi
done

# === Login to Vault ===
echo "🔐 Logging in to Vault..."
VAULT_TOKEN=$(vault login -format=json -method=userpass username="$VAULT_USERNAME" password="$VAULT_PASSWORD" \
    | jq -r '.auth.client_token')

if [[ -z "$VAULT_TOKEN" || "$VAULT_TOKEN" == "null" ]]; then
    echo "❌ Login failed. Check username/password."
    exit 1
fi
export VAULT_TOKEN
echo "✅ Logged in to Vault."

# === Check/Create Private Key ===
echo "🔍 Checking for existing client key..."
if ! vault kv get wireguard/clients-private/$CLIENT_NAME &>/dev/null; then
    echo "🔑 Private key not found. Generating keypair..."

    CLIENT_PRIV=$(wg genkey)
    CLIENT_PUB=$(echo "$CLIENT_PRIV" | wg pubkey)

    vault kv put wireguard/clients-private/$CLIENT_NAME private_key="$CLIENT_PRIV"
    vault kv put wireguard/clients-public/$CLIENT_NAME public_key="$CLIENT_PUB" allowed_ips="$DEFAULT_CLIENT_IP"

    echo "✅ Keypair saved to Vault."
fi

# === Retrieve Client Private Key ===
echo "📥 Fetching private key..."
CLIENT_PRIV=$(vault kv get -format=json wireguard/clients-private/$CLIENT_NAME | jq -r '.data.data.private_key')

# === Retrieve Allowed IP ===
ALLOWED_IP=$(vault kv get -format=json wireguard/clients-public/$CLIENT_NAME | jq -r '.data.data.allowed_ips')

# === Retrieve Server Public Key and Endpoint ===
SERVER_PUB=$(vault kv get -format=json wireguard/server/$SERVER_NAME | jq -r '.data.data.public_key')
SERVER_ENDPOINT="4.255.255.214:51820"

if [[ -z "$CLIENT_PRIV" || -z "$SERVER_PUB" || -z "$ALLOWED_IP" ]]; then
    echo "❌ Failed to fetch all necessary config from Vault."
    exit 1
fi

# === Generate Client Config ===
echo "🛠 Writing WireGuard config to $WG_CONF..."

cat <<EOF > "$WG_CONF"
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $ALLOWED_IP
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 10.10.10.0/24
PersistentKeepalive = 25
EOF

echo "✅ Client WireGuard configuration ready at $WG_CONF"