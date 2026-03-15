# NetBird Self-Hosted Setup with Auth0

This example deploys NetBird in microservice mode using:

- **Ingress Controller**: Nginx Ingress
- **Database Storage**: SQLite (for simpler setup)
- **Identity Provider**: Auth0

## Prerequisites

Configure your Auth0 tenant following the [NetBird documentation](https://docs.netbird.io/selfhosted/identity-providers#auth0).

You need to create multiple Auth0 applications:
1. **Machine-to-Machine (M2M)** - For management service
2. **Native** - For device authorization flow
3. **Single Page Application (SPA)** - For dashboard

Required parameters:
- `idpClientID` - M2M application client ID
- `idpClientSecret` - M2M application client secret
- `idpInteractiveClientID` - Native application client ID
- `idpDashboardClientID` - SPA application client ID

## Kubernetes Secret Configuration

Create a secret named `netbird`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: netbird
  namespace: netbird
stringData:
  idpClientID: "your-m2m-client-id"
  idpClientSecret: "your-m2m-client-secret"
  idpInteractiveClientID: "your-native-client-id"
  idpDashboardClientID: "your-spa-client-id"
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
  -f charts/netbird/examples/microservice/nginx-ingress/auth0/values.yaml
```

## Endpoints
- `netbird.example.com` - Dashboard, API, gRPC services, relay
