# Examples Directory Restructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reorganize and update `charts/netbird/examples/` with clear microservice mode examples for multiple ingress controllers and identity providers.

**Architecture:** Hierarchical structure under `microservice/` by ingress type then IDP. Each example has `values.yaml` and `README.md`. Base template from `docs/example-values.yaml`.

**Tech Stack:** Helm, Kubernetes, nginx-ingress, traefik, authentik/okta/google/auth0 IDPs

---

## Task 1: Create Directory Structure

**Files:**
- Create directories: `charts/netbird/examples/microservice/nginx-ingress/{authentik,okta,google,auth0}`
- Create directories: `charts/netbird/examples/microservice/traefik-ingress/authentik`

**Step 1: Create directories**

Run:
```bash
mkdir -p charts/netbird/examples/microservice/nginx-ingress/{authentik,okta,google,auth0}
mkdir -p charts/netbird/examples/microservice/traefik-ingress/authentik
```

Expected: Directories created

**Step 2: Verify structure**

Run:
```bash
ls -la charts/netbird/examples/microservice/
```

Expected:
```
nginx-ingress/
traefik-ingress/
```

---

## Task 2: Create nginx-ingress/authentik values.yaml

**Files:**
- Create: `charts/netbird/examples/microservice/nginx-ingress/authentik/values.yaml`

**Step 1: Create values.yaml**

Create file with content based on `docs/example-values.yaml`:

```yaml
fullnameOverride: netbird

server:
  enabled: false

management:
  enabled: true
  configmap: |-
    {
      "Stuns": [
        {
          "Proto": "udp",
          "URI": "{{ .STUN_SERVER }}",
          "Username": "",
          "Password": ""
        }
      ],
      "TURNConfig": {
        "TimeBasedCredentials": false,
        "CredentialsTTL": "12h0m0s",
        "Secret": "secret",
        "Turns": []
      },
      "Relay": {
        "Addresses": ["rels://netbird.example.com:443/relay"],
        "CredentialsTTL": "24h",
        "Secret": "{{ .RELAY_PASSWORD }}"
      },
      "Signal": {
        "Proto": "https",
        "URI": "netbird.example.com:443",
        "Username": "",
        "Password": ""
      },
      "Datadir": "/var/lib/netbird/",
      "DataStoreEncryptionKey": "{{ .DATASTORE_ENCRYPTION_KEY }}",
      "HttpConfig": {
        "LetsEncryptDomain": "",
        "CertFile": "",
        "CertKey": "",
        "AuthAudience": "{{ .IDP_CLIENT_ID }}",
        "AuthIssuer": "https://auth.example.com/application/o/netbird/",
        "AuthUserIDClaim": "",
        "AuthKeysLocation": "https://auth.example.com/application/o/netbird/jwks/",
        "OIDCConfigEndpoint": "https://auth.example.com/application/o/netbird/.well-known/openid-configuration",
        "IdpSignKeyRefreshEnabled": false
      },
      "EmbeddedIdP": {
        "Enabled": false,
        "LocalAuthDisabled": true
      },
      "IdpManagerConfig": {
        "ManagerType": "authentik",
        "ClientConfig": {
          "Issuer": "https://auth.example.com/application/o/netbird",
          "TokenEndpoint": "https://auth.example.com/application/o/token/",
          "ClientID": "{{ .IDP_CLIENT_ID }}",
          "ClientSecret": "",
          "GrantType": "client_credentials"
        },
        "ExtraConfig": {
          "Password": "{{ .IDP_SERVICE_ACCOUNT_PASSWORD }}",
          "Username": "{{ .IDP_SERVICE_ACCOUNT_USER }}"
        },
        "Auth0ClientCredentials": null,
        "AzureClientCredentials": null,
        "KeycloakClientCredentials": null,
        "ZitadelClientCredentials": null
      },
      "DeviceAuthorizationFlow": {
        "Provider": "hosted",
        "ProviderConfig": {
          "ClientID": "{{ .IDP_CLIENT_ID }}",
          "ClientSecret": "",
          "Domain": "auth.example.com",
          "Audience": "{{ .IDP_CLIENT_ID }}",
          "TokenEndpoint": "https://auth.example.com/application/o/token/",
          "DeviceAuthEndpoint": "https://auth.example.com/application/o/device/",
          "AuthorizationEndpoint": "",
          "Scope": "openid",
          "UseIDToken": false,
          "RedirectURLs": null
        }
      },
      "PKCEAuthorizationFlow": {
        "ProviderConfig": {
          "ClientID": "{{ .IDP_CLIENT_ID }}",
          "ClientSecret": "",
          "Domain": "",
          "Audience": "{{ .IDP_CLIENT_ID }}",
          "TokenEndpoint": "https://auth.example.com/application/o/token/",
          "DeviceAuthEndpoint": "",
          "AuthorizationEndpoint": "https://auth.example.com/application/o/authorize/",
          "Scope": "openid profile email offline_access api",
          "UseIDToken": false,
          "RedirectURLs": ["http://localhost:53000"]
        }
      },
      "StoreConfig": {
        "Engine": "postgres"
      },
      "ReverseProxy": {
        "TrustedHTTPProxies": null,
        "TrustedHTTPProxiesCount": 0,
        "TrustedPeers": null
      }
    }
  ingress:
    enabled: true
    className: nginx
    annotations:
    hosts:
      - host: netbird.example.com
        paths:
          - path: /api
            pathType: ImplementationSpecific
    tls:
      - secretName: wildcard.example.com-tls
        hosts:
          - netbird.example.com
  ingressGrpc:
    enabled: true
    className: nginx
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: GRPC
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    hosts:
      - host: netbird.example.com
        paths:
          - path: /management.ManagementService
            pathType: ImplementationSpecific
    tls:
      - secretName: wildcard.example.com-tls
        hosts:
          - netbird.example.com
  persistentVolume:
    enabled: false
  envFromSecret:
    NETBIRD_STORE_ENGINE_POSTGRES_DSN: netbird/postgresDSN
    NB_ACTIVITY_EVENT_POSTGRES_DSN: netbird/postgresDSN
    STUN_SERVER: netbird/stunServer
    TURN_SERVER: netbird/turnServer
    TURN_SERVER_USER: netbird/turnServerUser
    TURN_SERVER_PASSWORD: netbird/turnServerPassword
    RELAY_PASSWORD: netbird/relayPassword
    DATASTORE_ENCRYPTION_KEY: netbird/datastoreEncryptionKey
    IDP_CLIENT_ID: netbird/idpClientID
    IDP_SERVICE_ACCOUNT_USER: netbird/idpServiceAccountUser
    IDP_SERVICE_ACCOUNT_PASSWORD: netbird/idpServiceAccountPassword
  env:
    NB_DISABLE_GEOLOCATION: true
    NB_ACTIVITY_EVENT_STORE_ENGINE: postgres

signal:
  enabled: true
  ingress:
    enabled: true
    className: nginx
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: GRPC
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    hosts:
      - host: netbird.example.com
        paths:
          - path: /signalexchange.SignalExchange
            pathType: ImplementationSpecific
    tls:
      - secretName: wildcard.example.com-tls
        hosts:
          - netbird.example.com

relay:
  enabled: true
  stun:
    enabled: true
    ports:
      - 53478
    service:
      type: LoadBalancer
      externalTrafficPolicy: Local
  ingress:
    enabled: true
    className: nginx
    annotations:
    hosts:
      - host: netbird.example.com
        paths:
          - path: /relay
            pathType: ImplementationSpecific
    tls:
      - secretName: wildcard.example.com-tls
        hosts:
          - netbird.example.com
  env:
    NB_LOG_LEVEL: info
    NB_LISTEN_ADDRESS: ":33080"
    NB_EXPOSED_ADDRESS: rels://netbird.example.com:443/relay
  envFromSecret:
    NB_AUTH_SECRET: netbird/relayPassword

dashboard:
  enabled: true
  ingress:
    enabled: true
    className: nginx
    annotations:
    hosts:
      - host: netbird.example.com
        paths:
          - path: /
            pathType: ImplementationSpecific
    tls:
      - secretName: wildcard.example.com-tls
        hosts:
          - netbird.example.com
  env:
    NETBIRD_MGMT_API_ENDPOINT: https://netbird.example.com:443
    NETBIRD_MGMT_GRPC_API_ENDPOINT: https://netbird.example.com:443
    AUTH_CLIENT_SECRET:
    AUTH_AUTHORITY: https://auth.example.com/application/o/netbird/
    USE_AUTH0: false
    AUTH_SUPPORTED_SCOPES: openid profile email offline_access api
    AUTH_REDIRECT_URI:
    AUTH_SILENT_REDIRECT_URI:
    NETBIRD_TOKEN_SOURCE: accessToken
    NGINX_SSL_PORT:
    LETSENCRYPT_DOMAIN:
    LETSENCRYPT_EMAIL:
  envFromSecret:
    AUTH_CLIENT_ID: netbird/idpClientID
    AUTH_AUDIENCE: netbird/idpClientID
```

**Step 2: Validate**

Run:
```bash
helm lint charts/netbird -f charts/netbird/examples/microservice/nginx-ingress/authentik/values.yaml
```

Expected: `Linting OK`

---

## Task 3: Create nginx-ingress/authentik README.md

**Files:**
- Create: `charts/netbird/examples/microservice/nginx-ingress/authentik/README.md`

**Step 1: Create README.md**

```markdown
# NetBird Self-Hosted Setup with Authentik

This example deploys NetBird in microservice mode using:

- **Ingress Controller**: Nginx Ingress
- **Database Storage**: External PostgreSQL
- **Identity Provider**: Authentik

## Prerequisites

Configure your Authentik Identity Provider following the [NetBird documentation](https://docs.netbird.io/selfhosted/identity-providers#authentik).

Required parameters:
- `idpClientID` - Client ID from Authentik application
- `idpServiceAccountUser` - Service account username
- `idpServiceAccountPassword` - Service account password

## Kubernetes Secret Configuration

Create a secret named `netbird`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: netbird
  namespace: netbird
stringData:
  idpClientID: "your-client-id"
  idpServiceAccountUser: "service-account-user"
  idpServiceAccountPassword: "service-account-password"
  postgresDSN: "postgresql://netbird:password@postgres:5432/netbird"
  relayPassword: "random-relay-secret"
  stunServer: "stun:stun.example.com:3478"
  turnServer: "turn:turn.example.com:3478"
  turnServerUser: "turn-user"
  turnServerPassword: "turn-password"
  datastoreEncryptionKey: "base64-encoded-32-byte-key"
```

Generate encryption key:
```bash
openssl rand -base64 32
```

## Deployment

```bash
helm install netbird charts/netbird \
  -n netbird \
  -f charts/netbird/examples/microservice/nginx-ingress/authentik/values.yaml
```

## Endpoints

- `netbird.example.com` - Dashboard, API, gRPC services, relay
```

---

## Task 4: Create nginx-ingress/okta values.yaml

**Files:**
- Create: `charts/netbird/examples/microservice/nginx-ingress/okta/values.yaml`

**Step 1: Create values.yaml with Okta IDP config**

Key differences from authentik:
- `IdpManagerConfig.ManagerType: "okta"`
- `IdpManagerConfig.ExtraConfig: { "ApiToken": "{{ .OKTA_API_TOKEN }}" }`
- Okta-specific endpoints in DeviceAuthorizationFlow and PKCEAuthorizationFlow
- Secret keys: `idpClientID`, `oktaApiToken`, `idpNativeAppClientID`

**Step 2: Validate**

Run:
```bash
helm lint charts/netbird -f charts/netbird/examples/microservice/nginx-ingress/okta/values.yaml
```

Expected: `Linting OK`

---

## Task 5: Create nginx-ingress/okta README.md

**Files:**
- Create: `charts/netbird/examples/microservice/nginx-ingress/okta/README.md`

**Step 1: Create README.md**

Document Okta-specific prerequisites:
- Okta domain (e.g., `example.okta.com`)
- API token with directory read permissions
- Native app client ID for device flow

---

## Task 6: Create nginx-ingress/google values.yaml

**Files:**
- Create: `charts/netbird/examples/microservice/nginx-ingress/google/values.yaml`

**Step 1: Create values.yaml with Google IDP config**

Key differences:
- `IdpManagerConfig.ManagerType: "google"`
- `IdpManagerConfig.ExtraConfig: { "CustomerId": "{{ .CUSTOMER_ID }}", "ServiceAccountKey": "{{ .SERVICE_ACCOUNT_KEY }}" }`
- Google-specific endpoints
- Secret keys: `idpClientID`, `idpClientSecret`, `customerID`, `sa.json` (separate secret)

**Step 2: Validate**

Run:
```bash
helm lint charts/netbird -f charts/netbird/examples/microservice/nginx-ingress/google/values.yaml
```

Expected: `Linting OK`

---

## Task 7: Create nginx-ingress/google README.md

**Files:**
- Create: `charts/netbird/examples/microservice/nginx-ingress/google/README.md`

**Step 1: Create README.md**

Document Google Workspace prerequisites:
- Customer ID
- Service account with domain-wide delegation
- OAuth client ID and secret

---

## Task 8: Create nginx-ingress/auth0 values.yaml

**Files:**
- Create: `charts/netbird/examples/microservice/nginx-ingress/auth0/values.yaml`

**Step 1: Create values.yaml with Auth0 IDP config**

Key differences:
- `IdpManagerConfig.ManagerType: "auth0"`
- `IdpManagerConfig.ExtraConfig: { "Audience": "https://example.eu.auth0.com/api/v2/" }`
- Auth0-specific endpoints
- Multiple client IDs: `idpClientID`, `idpClientSecret`, `idpInteractiveClientID`, `idpDashboardClientID`
- Dashboard `USE_AUTH0: "true"`

**Step 2: Validate**

Run:
```bash
helm lint charts/netbird -f charts/netbird/examples/microservice/nginx-ingress/auth0/values.yaml
```

Expected: `Linting OK`

---

## Task 9: Create nginx-ingress/auth0 README.md

**Files:**
- Create: `charts/netbird/examples/microservice/nginx-ingress/auth0/README.md`

**Step 1: Create README.md**

Document Auth0 prerequisites:
- Multiple applications (M2M, Native, SPA)
- Client IDs and secrets for each

---

## Task 10: Create traefik-ingress/authentik values.yaml

**Files:**
- Create: `charts/netbird/examples/microservice/traefik-ingress/authentik/values.yaml`

**Step 1: Create values.yaml with Traefik annotations**

Key differences from nginx:
- Ingress annotations:
  ```yaml
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
  ```
- gRPC ingress annotations:
  ```yaml
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/backend.protocol: h2c
  ```

**Step 2: Validate**

Run:
```bash
helm lint charts/netbird -f charts/netbird/examples/microservice/traefik-ingress/authentik/values.yaml
```

Expected: `Linting OK`

---

## Task 11: Create traefik-ingress/authentik README.md

**Files:**
- Create: `charts/netbird/examples/microservice/traefik-ingress/authentik/README.md`

**Step 1: Create README.md**

Document Traefik-specific setup:
- Traefik ingress controller requirement
- Certificate resolver configuration (optional)

---

## Task 12: Remove Old Examples

**Files:**
- Remove: `charts/netbird/examples/microservice/values.yaml`
- Remove: `charts/netbird/examples/traefik-ingress/` (entire directory)

**Step 1: Remove old files**

Run:
```bash
rm charts/netbird/examples/microservice/values.yaml
rm -rf charts/netbird/examples/traefik-ingress
```

**Step 2: Verify structure**

Run:
```bash
ls -la charts/netbird/examples/
```

Expected:
```
hybrid/
minimal/
microservice/
```

---

## Task 13: Final Validation

**Step 1: Run helm lint on all examples**

Run:
```bash
for f in charts/netbird/examples/microservice/nginx-ingress/*/values.yaml charts/netbird/examples/microservice/traefik-ingress/*/values.yaml; do
  echo "Linting $f"
  helm lint charts/netbird -f "$f"
done
```

Expected: All pass with `Linting OK`

**Step 2: Validate generated manifests**

Run:
```bash
helm template test charts/netbird -f charts/netbird/examples/microservice/nginx-ingress/authentik/values.yaml | kubeconform -summary
```

Expected: All resources valid

---

## Task 14: Commit Changes

**Step 1: Stage all changes**

Run:
```bash
git add charts/netbird/examples/microservice/
git status
```

**Step 2: Commit**

Run:
```bash
git commit -m "feat: restructure examples by ingress controller and IDP

- Add nginx-ingress examples: authentik, okta, google, auth0
- Add traefik-ingress example: authentik
- Remove old flat microservice/values.yaml
- Remove old traefik-ingress (hybrid mode)
- All examples use microservice mode with postgres"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Create directory structure | directories |
| 2-3 | nginx-ingress/authentik | values.yaml, README.md |
| 4-5 | nginx-ingress/okta | values.yaml, README.md |
| 6-7 | nginx-ingress/google | values.yaml, README.md |
| 8-9 | nginx-ingress/auth0 | values.yaml, README.md |
| 10-11 | traefik-ingress/authentik | values.yaml, README.md |
| 12 | Remove old examples | - |
| 13 | Final validation | - |
| 14 | Commit | - |
