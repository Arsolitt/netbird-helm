# NetBird Self-Hosted Setup with Google Workspace

This example deploys NetBird in microservice mode using:

- **Ingress Controller**: Nginx Ingress
- **Database Storage**: SQLite (for simpler setup)
- **Identity Provider**: Google Workspace

## Prerequisites

Configure your Google Workspace following the [NetBird documentation](https://docs.netbird.io/selfhosted/identity-providers#google-workspace).

Required parameters:
- `idpClientID` - Google OAuth client ID
- `idpClientSecret` - Google OAuth client secret
- `customerID` - Google Workspace Customer ID (find it [here](https://support.google.com/a/answer/10070793))
- Service account with domain-wide delegation

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
  idpClientSecret: "your-client-secret"
  customerID: "your-customer-id"
  relayPassword: "random-relay-secret"
  stunServer: "stun:stun.example.com:3478"
  turnServer: "turn:turn.example.com:3478"
  turnServerUser: "turn-user"
  turnServerPassword: "turn-password"
  datastoreEncryptionKey: "base64-encoded-32-byte-key"
```

You also need a secret for the GCP service account key:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: netbird-gcp-service-account
  namespace: netbird
stringData:
  sa.json: |
    {
      "type": "service_account",
      "project_id": "your-project-id",
      "private_key_id": "key-id",
      "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----",
      "client_email": "service-account@project.iam.gserviceaccount.com",
      "client_id": "client-id",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/..."
    }
```

Generate encryption key

```bash
openssl rand -base64 32
```

## Deployment

```bash
helm install netbird charts/netbird \
  -n netbird \
  -f charts/netbird/examples/microservice/nginx-ingress/google/values.yaml
```

## Endpoints

- `netbird.example.com` - Dashboard, API, gRPC services, relay
