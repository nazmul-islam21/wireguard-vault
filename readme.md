# 🌟 Full Step-by-Step: Zero Trust VPN using WireGuard + Hasi Vault

## 🎯 High-Level Design

- ✅ WireGuard Server on Ubuntu 20
- ✅ Vault Server at https://vault.vault-url.nip.io
- ✅ Vault Authentication:
    - Server → Vault → using AppRole
    - Client → Vault → using Username/Password
- ✅ Vault manages all keys dynamically:
    - Server keypairs
    - Client keypairs
    - Client public key auto-synced to server config
    - Private keys securely hidden inside Vault
- ✅ Zero Trust:
    - Clients only have access to their OWN keys.
    - No client has access to server private key.
    - Full rotation capability (refresh keys any time).

## 🛠 Step 1: Set Up Vault Properly

### 1.1 Login to Vault
``` bash
export VAULT_ADDR="https://vault.vault-url.nip.io"
vault login
```
### 1.2 Enable KV Secrets Engine (for Key Storage)
``` bash
vault secrets enable -path=wireguard kv-v2
```
### 1.3 Create Vault Policies

Server Policy (wireguard-server-policy.hcl):

``` hcl
path "wireguard/server/*" {
  capabilities = ["create", "update", "read", "list"]
}

path "wireguard/clients-public/*" {
  capabilities = ["read", "list"]
}
vault policy write wireguard-server wireguard-server-policy.hcl
Client Policy (wireguard-client-policy.hcl):

path "wireguard/clients-private/{{identity.entity.name}}" {
  capabilities = ["create", "update", "read"]
}

path "wireguard/clients-public/{{identity.entity.name}}" {
  capabilities = ["create", "update", "read"]
}

path "wireguard/server/*" {
  capabilities = ["read"]
}
```
vault policy write wireguard-client wireguard-client-policy.hcl
### 1.4 Enable AppRole (for server)

vault auth enable approle
Create AppRole for server:

    vault write auth/approle/role/wireguard-server-role \
        token_policies="wireguard-server" \
        token_ttl=24h \
        token_max_ttl=72h
    Fetch:

    vault read auth/approle/role/wireguard-server-role/role-id
    vault write -f auth/approle/role/wireguard-server-role/secret-id
### 1.5 Enable Userpass (for clients)

    vault auth enable userpass
    Create client users:

    vault write auth/userpass/users/client1 password="Client1StrongPassword!" policies="wireguard-client"
    vault write auth/userpass/users/client2 password="Client2StrongPassword!" policies="wireguard-client"
- ✅ Each client gets username/password.

## 🖥 Step 2: Setup WireGuard Server (Ubuntu)

### 2.1 Install WireGuard

    sudo apt update
    sudo apt install wireguard -y
### 2.2 Prepare Server Bash Script
```
$ chmod +x server_wireguard_sync.sh
$ ./server_wireguard_sync.sh
```
- ✅ Server auto-syncs client peers dynamically.

## 🧑‍💻 Step 3: Setup WireGuard Client Script

### 3.1 Prepare Client Bash Script

Each client will have a script: client_wireguard_fetch.sh

```
$ chmod client_wireguard_fetch.sh
$ ./client_wireguard_fetch.sh
```
✅ Clients auto-create their own wg0.conf file securely.

## 📜 Final Commands

Server Setup:

    sudo bash /usr/local/bin/server_wireguard_sync.sh
    Client Setup:

    bash ~/client_wireguard_fetch.sh
    Then start WireGuard normally:

    sudo wg-quick up wg0
## 🛡 Security Checkpoints

- Vault policies ensure strict separation.
- No private key leaks outside of Vault.
- WireGuard server only knows public keys.
- Clients cannot see other clients’ keys.
- Clients authenticate with password, server authenticate with AppRole.
✅ True Zero Trust VPN!

## 🎯 Diagram of Full System

    Client1 ⮑ [Login Username/Password] ➔ Vault ➔ Fetch Private Key + Server Public Key ➔ Build wg0.conf
    Client2 ⮑ [Login Username/Password] ➔ Vault ➔ Fetch Private Key + Server Public Key ➔ Build wg0.conf

    WireGuard Server ⮑ [Login AppRole] ➔ Vault ➔ Sync Clients' Public Keys ➔ Update wg0.conf
