# NetBird Self-Hosted Setup with Traefik and Authentik

This example deploys NetBird in microservice mode using:

- **Ingress Controller**: Traefik
- **Database Storage**: External PostgreSQL
- **Identity Provider**: Authentik

## Prerequisites

Configure your Authentik Identity Provider following the [NetBird documentation](https://docs.netbird.io/selfhosted/identity-providers#authentik).

Required parameters:
- `idpClientID` - Client ID from Authentik application
- `idpServiceAccountUser` - Service account username
- `idpServiceAccountPassword` - Service account password

## Traefik Configuration

This example uses Traefik-specific annotations:
- `traefik.ingress.kubernetes.io/router.entrypoints: websecure` - Use secure entrypoint
- `traefik.ingress.kubernetes.io/router.tls: "true"` - Enable TLS
- `traefik.ingress.kubernetes.io/backend.protocol: h2c` - For gRPC services (signal, management gRPC)

You may also want to configure a certificate resolver:
```yaml
annotations:
  traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt
```

## Kubernetes Secret Configuration

Create a secret named `netbird`

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
  -f charts/netbird/examples/microservice/traefik-ingress/authentik/values.yaml
```

## Endpoints
- `netbird.example.com` - Dashboard, API, gRPC services, relay
