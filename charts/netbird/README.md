# NetBird Helm Chart

Helm chart for deploying [NetBird](https://github.com/netbirdio/netbird) - a WireGuard-based mesh VPN platform.

## Deployment Modes

> **Warning:** Unified server mode is currently **unstable** and may not work correctly. Use **microservice mode** for production deployments.

### Unified Server Mode (Experimental)

Uses a single `netbirdio/netbird-server` image containing management, signal, and relay services. Enabled by default but currently unstable.

### Microservice Mode (Recommended)

Separate deployments for each component:
- **Management** - API and peer management
- **Signal** - Signaling server for NAT traversal
- **Relay** - Relay server for peer connections

## Configuration

The following tables list the configurable parameters of the NetBird chart and their default values.

### Global Configuration

| Parameter              | Description                           | Default |
| ---------------------- | ------------------------------------- | ------- |
| `global.namespace`     | Kubernetes namespace for components   | `""`    |
| `nameOverride`         | Override the name of the chart        | `""`    |
| `fullnameOverride`     | Override the full name of the chart   | `""`    |

### Server Configuration (Unified Mode)

| Parameter                                | Description                                                      | Default                  |
| ---------------------------------------- | ---------------------------------------------------------------- | ------------------------ |
| `server.enabled`                         | Enable unified server mode                                       | `true`                   |
| `server.replicaCount`                    | Number of server pod replicas                                    | `1`                      |
| `server.image.repository`                | Server image repository                                          | `netbirdio/netbird-server` |
| `server.image.tag`                       | Server image tag (defaults to appVersion)                        | `""`                     |
| `server.image.pullPolicy`                | Image pull policy                                                | `IfNotPresent`           |
| `server.containerPort`                   | Container port for HTTP service                                  | `8080`                   |
| `server.stunContainerPort`               | Container port for STUN service                                  | `53478`                  |

### Server Configuration File

| Parameter                                | Description                                                      | Default                  |
| ---------------------------------------- | ---------------------------------------------------------------- | ------------------------ |
| `server.config.listenAddress`            | Address for the server to listen on                              | `:8080`                  |
| `server.config.exposedAddress`           | Public address peers use to connect                              | `""`                     |
| `server.config.stunPorts`                | STUN server ports                                                | `[]`                     |
| `server.config.metricsPort`              | Metrics endpoint port                                            | `9090`                   |
| `server.config.healthcheckAddress`       | Healthcheck endpoint address                                     | `:9000`                  |
| `server.config.logLevel`                 | Log level (panic, fatal, error, warn, info, debug, trace)        | `info`                   |
| `server.config.logFile`                  | Log file location ("console" or path)                            | `console`                |
| `server.config.authSecret`               | Shared secret for relay authentication                           | `${NB_AUTH_SECRET}`      |
| `server.config.dataDir`                  | Data directory for all services                                  | `/var/lib/netbird/`      |
| `server.config.disableAnonymousMetrics`  | Disable anonymous metrics collection                             | `false`                  |
| `server.config.disableGeoliteUpdate`     | Disable GeoLite database updates                                 | `false`                  |

### Server TLS Configuration

| Parameter                                | Description                                                      | Default                  |
| ---------------------------------------- | ---------------------------------------------------------------- | ------------------------ |
| `server.config.tls.enabled`              | Enable TLS                                                       | `false`                  |
| `server.config.tls.certFile`             | Path to TLS certificate file                                     | `""`                     |
| `server.config.tls.keyFile`              | Path to TLS key file                                             | `""`                     |
| `server.config.tls.letsencrypt.enabled`  | Enable Let's Encrypt                                             | `false`                  |
| `server.config.tls.letsencrypt.dataDir`  | Let's Encrypt data directory                                     | `""`                     |
| `server.config.tls.letsencrypt.domains`  | Domains for Let's Encrypt certificate                            | `[]`                     |
| `server.config.tls.letsencrypt.email`    | Email for Let's Encrypt                                          | `""`                     |

### Server Authentication Configuration

| Parameter                                      | Description                                         | Default                  |
| ---------------------------------------------- | --------------------------------------------------- | ------------------------ |
| `server.config.auth.issuer`                    | OIDC issuer URL                                     | `""`                     |
| `server.config.auth.localAuthDisabled`         | Disable local authentication                        | `false`                  |
| `server.config.auth.signKeyRefreshEnabled`     | Enable signing key refresh                          | `false`                  |
| `server.config.auth.dashboardRedirectURIs`     | OAuth2 redirect URIs for dashboard                  | `[]`                     |
| `server.config.auth.cliRedirectURIs`           | OAuth2 redirect URIs for CLI                        | `["http://localhost:53000/"]` |
| `server.config.auth.owner.email`               | Initial admin user email                            |                          |
| `server.config.auth.owner.password`            | Initial admin user password                         |                          |

### Server Store Configuration

| Parameter                                | Description                                                      | Default                  |
| ---------------------------------------- | ---------------------------------------------------------------- | ------------------------ |
| `server.config.store.engine`             | Store engine (sqlite, postgres, mysql)                           | `sqlite`                 |
| `server.config.store.dsn`                | Connection string for postgres/mysql                             | `""`                     |
| `server.config.store.encryptionKey`      | Encryption key for data store                                    | `${NB_ENCRYPTION_KEY}`   |

### Server Init Container

| Parameter                                | Description                                                      | Default                  |
| ---------------------------------------- | ---------------------------------------------------------------- | ------------------------ |
| `server.initContainer.enabled`           | Enable init container for envsubst                               | `true`                   |
| `server.initContainer.image.repository`  | Init container image                                             | `dibi/envsubst`          |
| `server.initContainer.image.tag`         | Init container image tag                                         | `1`                      |
| `server.initContainer.envFromSecret`     | Environment variables from secrets for envsubst                  | `{}`                     |

### Server Service Configuration

| Parameter                                | Description                                                      | Default                  |
| ---------------------------------------- | ---------------------------------------------------------------- | ------------------------ |
| `server.service.type`                    | Service type                                                     | `ClusterIP`              |
| `server.service.port`                    | HTTP service port                                                | `80`                     |
| `server.service.name`                    | HTTP service name                                                | `http`                   |
| `server.service.externalTrafficPolicy`   | External traffic policy for LoadBalancer                         | `""`                     |
| `server.serviceStun.enabled`             | Enable STUN service                                              | `true`                   |
| `server.serviceStun.type`                | STUN service type                                                | `ClusterIP`              |
| `server.serviceStun.port`                | STUN service port                                                | `3478`                   |

### Server Ingress Configuration

| Parameter                                | Description                                                      | Default                  |
| ---------------------------------------- | ---------------------------------------------------------------- | ------------------------ |
| `server.ingress.enabled`                 | Enable HTTP ingress                                              | `false`                  |
| `server.ingress.className`               | Ingress class name                                               | `""`                     |
| `server.ingress.annotations`             | Ingress annotations                                              | `{}`                     |
| `server.ingress.tls`                     | TLS settings for ingress                                         | `[]`                     |
| `server.ingressGrpc.enabled`             | Enable gRPC ingress                                              | `false`                  |
| `server.ingressGrpc.className`           | gRPC ingress class name                                          | `""`                     |
| `server.ingressGrpc.annotations`         | gRPC ingress annotations                                         | `{}`                     |
| `server.ingressGrpc.tls`                 | TLS settings for gRPC ingress                                    | `[]`                     |

### Server Persistence Configuration

| Parameter                                | Description                                           | Default          |
| ---------------------------------------- | ----------------------------------------------------- | ---------------- |
| `server.persistentVolume.enabled`        | Enable persistent volume                              | `true`           |
| `server.persistentVolume.accessModes`    | Access modes for persistent volume                    | `[ReadWriteOnce]`|
| `server.persistentVolume.size`           | Size of persistent volume                             | `10Mi`           |
| `server.persistentVolume.storageClass`   | Storage class of persistent volume                    | `null`           |
| `server.persistentVolume.existingPVName` | Name of existing persistent volume                    | `""`             |

### Environment Variables

All components support three patterns for environment variables:

| Parameter              | Description                                          | Default |
| ---------------------- | ---------------------------------------------------- | ------- |
| `env`                  | Plain text environment variables                     | `{}`    |
| `envRaw`               | Raw environment variable sections (complex configs)  | `[]`    |
| `envFromSecret`        | Environment variables from Kubernetes secrets        | `{}`    |

Format for `envFromSecret`: `ENV_VAR: secretName/secretKey`

Example:
```yaml
server:
  envFromSecret:
    NB_AUTH_SECRET: netbird-secrets/auth-secret
    NB_ENCRYPTION_KEY: netbird-secrets/encryption-key
```

### Dashboard Configuration

| Parameter                        | Description                                   | Default              |
| -------------------------------- | --------------------------------------------- | -------------------- |
| `dashboard.enabled`              | Enable dashboard component                    | `true`               |
| `dashboard.replicaCount`         | Number of dashboard replicas                  | `1`                  |
| `dashboard.image.repository`     | Dashboard image repository                    | `netbirdio/dashboard`|
| `dashboard.image.tag`            | Dashboard image tag                           | `v2.32.5`            |
| `dashboard.image.pullPolicy`     | Image pull policy                             | `IfNotPresent`       |
| `dashboard.containerPort`        | Container port                                | `8080`               |

### Dashboard Service Configuration

| Parameter                        | Description                                   | Default              |
| -------------------------------- | --------------------------------------------- | -------------------- |
| `dashboard.service.type`         | Service type                                  | `ClusterIP`          |
| `dashboard.service.port`         | Service port                                  | `80`                 |
| `dashboard.service.name`         | Service name                                  | `http`               |

### Dashboard Ingress Configuration

| Parameter                        | Description                                   | Default              |
| -------------------------------- | --------------------------------------------- | -------------------- |
| `dashboard.ingress.enabled`      | Enable ingress                                | `false`              |
| `dashboard.ingress.className`    | Ingress class name                            | `""`                 |
| `dashboard.ingress.annotations`  | Ingress annotations                           | `{}`                 |
| `dashboard.ingress.tls`          | TLS configuration                             | `[]`                 |

### Microservice Mode - Management

| Parameter                              | Description                                   | Default                  |
| -------------------------------------- | --------------------------------------------- | ------------------------ |
| `management.enabled`                   | Enable management component                   | `false`                  |
| `management.replicaCount`              | Number of replicas                            | `1`                      |
| `management.image.repository`          | Image repository                              | `netbirdio/management`   |
| `management.image.tag`                 | Image tag                                     | `""`                     |
| `management.containerPort`             | HTTP container port                           | `8080`                   |
| `management.grpcContainerPort`         | gRPC container port                           | `33073`                  |

### Microservice Mode - Signal

| Parameter                        | Description                                   | Default              |
| -------------------------------- | --------------------------------------------- | -------------------- |
| `signal.enabled`                 | Enable signal component                       | `false`              |
| `signal.replicaCount`            | Number of replicas                            | `1`                  |
| `signal.image.repository`        | Image repository                              | `netbirdio/signal`   |
| `signal.image.tag`               | Image tag                                     | `""`                 |
| `signal.containerPort`           | Container port                                | `8080`               |
| `signal.logLevel`                | Log level                                     | `info`               |

### Microservice Mode - Relay

| Parameter                        | Description                                   | Default              |
| -------------------------------- | --------------------------------------------- | -------------------- |
| `relay.enabled`                  | Enable relay component                        | `false`              |
| `relay.replicaCount`             | Number of replicas                            | `1`                  |
| `relay.image.repository`         | Image repository                              | `netbirdio/relay`    |
| `relay.image.tag`                | Image tag                                     | `""`                 |
| `relay.containerPort`            | Container port                                | `33080`              |
| `relay.logLevel`                 | Log level                                     | `info`               |

### Relay STUN Configuration

| Parameter                                    | Description                           | Default          |
| -------------------------------------------- | ------------------------------------- | ---------------- |
| `relay.stun.enabled`                         | Enable embedded STUN server           | `false`          |
| `relay.stun.ports`                           | STUN server ports                     | `[53478]`        |
| `relay.stun.service.type`                    | Service type (LoadBalancer/ClusterIP) | `LoadBalancer`   |
| `relay.stun.service.externalTrafficPolicy`   | External traffic policy               | `Local`          |

### Resource Configuration

| Parameter              | Description                   | Default         |
| ---------------------- | ----------------------------- | --------------- |
| `resources.requests`   | CPU/Memory resource requests  | `{}`            |
| `resources.limits`     | CPU/Memory resource limits    | `{}`            |

### Pod Scheduling

| Parameter                  | Description                       | Default |
| -------------------------- | --------------------------------- | ------- |
| `nodeSelector`             | Node labels for pod assignment    | `{}`    |
| `tolerations`              | Toleration labels for pod assignment | `[]`  |
| `affinity`                 | Affinity settings for pod assignment | `{}`  |

### Metrics Configuration

| Parameter                              | Description                           | Default     |
| -------------------------------------- | ------------------------------------- | ----------- |
| `metrics.serviceMonitor.enabled`       | Create Prometheus ServiceMonitor      | `false`     |
| `metrics.serviceMonitor.namespace`     | Namespace for ServiceMonitor          | `""`        |
| `metrics.serviceMonitor.annotations`   | Annotations for ServiceMonitor        | `{}`        |
| `metrics.serviceMonitor.labels`        | Labels for ServiceMonitor             | `{}`        |
| `metrics.serviceMonitor.interval`      | Scrape interval                       | `""`        |

## Examples

### Basic Installation

```console
helm install netbird netbird/netbird
```

### With Custom Values

```console
helm install netbird netbird/netbird -f values.yaml
```

### With Ingress and TLS

```yaml
server:
  config:
    exposedAddress: "https://netbird.example.com"
  ingress:
    enabled: true
    className: nginx
    tls:
      - secretName: netbird-tls
        hosts:
          - netbird.example.com
  ingressGrpc:
    enabled: true
    className: nginx

dashboard:
  enabled: true
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: netbird.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: netbird-tls
        hosts:
          - netbird.example.com
```

### With PostgreSQL

```yaml
server:
  config:
    store:
      engine: postgres
      dsn: ${NB_STORE_DSN}
  initContainer:
    envFromSecret:
      NB_STORE_DSN: netbird-secrets/store-dsn
```

## Using Secrets

Create a Kubernetes secret with sensitive configuration:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: netbird-secrets
stringData:
  auth-secret: "your-relay-secret"
  encryption-key: "base64-encoded-32-byte-key"
```

Reference in values:

```yaml
server:
  initContainer:
    envFromSecret:
      NB_AUTH_SECRET: netbird-secrets/auth-secret
      NB_ENCRYPTION_KEY: netbird-secrets/encryption-key
```

## TODO / Roadmap

- [ ] **Implement unified server mode support** - The `netbirdio/netbird-server` unified image requires proper configuration and testing. Currently, use microservice mode with separate `management`, `signal`, and `relay` components.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](../../LICENSE) file for details.

## Credits

Based on [totmicro/helms](https://github.com/totmicro/helms).

## Additional Resources

- [NetBird Documentation](https://docs.netbird.io/)
- [NetBird GitHub](https://github.com/netbirdio/netbird)
- [Self-hosting Guide](https://docs.netbird.io/selfhosted/selfhosted-guide)
