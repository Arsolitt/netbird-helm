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

Generate encryption key

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
