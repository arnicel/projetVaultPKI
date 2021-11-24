provider "vault" {
    address = "https://vault.4as:8200/"
    skip_tls_verify = true
    # Token: export VAULT_TOKEN="xxxx"
}

resource "vault_ldap_auth_backend" "ldap" {
    path        = "ldap"
    url         = "ldap://192.168.100.22"
    userdn      = "CN=Users,DC=INSA,DC=4AS"
    userattr    = "sAMAccountName"
    binddn      = "CN=Vault,CN=Users,DC=INSA,DC=4AS"
    bindpass    = file("../../ssl/password.key")
    groupdn     = "CN=Users,DC=INSA,DC=4AS"
    groupfilter = "(&(objectClass=person)(sAMAccountName={{.Username}}))"
    groupattr   = "memberOf"
    upndomain   = "INSA.4AS"    
}

resource "vault_mount" "ssh-4as" {
    type = "ssh"
    path = "ssh-4as"

    # Accès pour 4h par défaut, jusqu'à 12h.
    default_lease_ttl_seconds = "14400"  # 4h
    max_lease_ttl_seconds     = "43200" # 1w
}

resource "vault_ssh_secret_backend_ca" "ssh-4as-ca" {
    backend = vault_mount.ssh-4as.path
    generate_signing_key = true
}

resource "vault_ssh_secret_backend_role" "ssh-4as-reseau" {
    name     = "reseau"
    backend  = vault_mount.ssh-4as.path
    key_type = "ca"
    algorithm_signer = "rsa-sha2-256"

    allow_user_certificates = true
    default_user = "reseau"
    allowed_users = "reseau"
    default_extensions = {
        permit-pty = ""
        permit-port-forwarding = ""
    }
}

resource "vault_ssh_secret_backend_role" "ssh-4as-opsi" {
    name     = "opsi"
    backend  = vault_mount.ssh-4as.path
    key_type = "ca"
    algorithm_signer = "rsa-sha2-256"

    allow_user_certificates = true
    default_user = "opsi"
    allowed_users = "opsi"
    default_extensions = {
        permit-pty = ""
        permit-port-forwarding = ""
    }
}

resource "vault_policy" "ssh-4as-full-access" {
  name = "ssh-4as-full-access"
  policy = <<EOT
path "ssh-4as/sign/*" {
  capabilities = ["update"]
}
EOT
}

resource "vault_policy" "ssh-4as-opsi" {
  name = "ssh-4as-opsi"
  policy = <<EOT
path "ssh-4as/sign/opsi" {
  capabilities = ["update"]
}
EOT
}

resource "vault_policy" "ssh-4as-reseau" {
  name = "ssh-4as-reseau"
  policy = <<EOT
path "ssh-4as/sign/reseau" {
  capabilities = ["update"]
}
EOT
}

resource "vault_pki_secret_backend" "ca-4as-cert" {
  path        = "ca-4as-cert"
}

resource "vault_pki_secret_backend_config_ca" "ca-4as-cert-ca" {
  backend = vault_pki_secret_backend.ca-4as-cert.path
  pem_bundle = file("../../ssl/vault.bundle.pem.key")
}

resource "vault_pki_secret_backend_role" "role" {
  backend          = vault_pki_secret_backend.ca-4as-cert.path
  name             = "domain_4as"
  ttl              = 30000000
  max_ttl          = 30000000
  allowed_domains  = ["4as"]
  allow_subdomains = true
}

resource "vault_policy" "domain-4as-sign" {
  name = "domain-4as-sign"
  policy = <<EOT
path "ca-4as-cert/issue/domain_4as" {
  capabilities = ["update"]
}
path "ca-4as-cert/roles" {
  capabilities = ["list"]
}
EOT
}

resource "vault_ldap_auth_backend_group" "group-etudiant" {
    groupname = "Etudiant"
    policies  = ["domain-4as-sign"]
    backend   = vault_ldap_auth_backend.ldap.path
}

resource "vault_ldap_auth_backend_group" "group-deploiement" {
    groupname = "deploiement"
    policies  = ["ssh-4as-opsi"]
    backend   = vault_ldap_auth_backend.ldap.path
}

resource "vault_ldap_auth_backend_group" "group-reseau" {
    groupname = "reseaux"
    policies  = ["ssh-4as-reseau"]
    backend   = vault_ldap_auth_backend.ldap.path
}

resource "vault_mount" "ssh-4as-host" {
    type = "ssh"
    path = "ssh-4as-host"

    # Accès pour 4h par défaut, jusqu'à 12h.
    default_lease_ttl_seconds = "14400"  # 4h
    max_lease_ttl_seconds     = "43200" # 1w
}

resource "vault_ssh_secret_backend_ca" "ssh-4as-host" {
    backend = vault_mount.ssh-4as-host.path
    generate_signing_key = true
}

resource "vault_ssh_secret_backend_role" "ssh-4as-host" {
    name     = "host-sign"
    backend  = vault_mount.ssh-4as-host.path
    key_type = "ca"
    algorithm_signer = "rsa-sha2-256"

    allow_host_certificates = true
    allowed_domains  = "4as"
    allow_subdomains = true
}

resource "vault_policy" "ssh-4as-host-full-access" {
  name = "ssh-4as-host-full-access"
  policy = <<EOT
path "ssh-4as-host/sign/*" {
  capabilities = ["update"]
}
EOT
}
