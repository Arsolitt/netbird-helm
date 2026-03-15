# NetBird Self-Hosted Setup with Okta

This example deploys NetBird in microservice mode using:

- **Ingress Controller**: Nginx Ingress
- **Database Storage**: SQLite (for simpler setup)
- **Identity Provider**: Okta

## Prerequisites

Configure your Okta Identity Provider following the [NetBird documentation](https://docs.netbird.io/selfhosted/identity-providers#okta).

Required parameters:
- `idpClientID` - Client ID from Okta application
- `oktaApiToken` - Okta API token with directory read permissions
- `idpNativeAppClientID` - Native app client ID for device authorization flow

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
  oktaApiToken: "your-okta-api-token"
  idpNativeAppClientID: "your-native-app-client-id"
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
  -f charts/netbird/examples/microservice/nginx-ingress/okta/values.yaml
```

## Endpoints

- `netbird.example.com` - Dashboard, API, gRPC services, relay
