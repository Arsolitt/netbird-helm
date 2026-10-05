# NetBird Helm Chart

Helm chart for deploying [NetBird](https://github.com/netbirdio/netbird) - a WireGuard-based mesh VPN platform.

## Deployment Modes

> **Note:** Unified server mode requires a complete `server.config` - the chart defaults are placeholders and the `netbird-server` process exits at startup until `exposedAddress`, `authSecret`, `auth.issuer` and a base64 `store.encryptionKey` are set. `ci/server-minimal-values.yaml` is a minimal working set.

### Unified Server Mode

Uses a single `netbirdio/netbird-server` image containing management, signal, relay and STUN services. Enabled by default; requires a complete `server.config` as described above.

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
| `server.livenessProbe`                   | Liveness probe (TCP check on the `http` container port)          | `tcpSocket: http`        |
| `server.readinessProbe`                  | Readiness probe (TCP check on the `http` container port)         | `tcpSocket: http`        |

### Server Configuration File

| Parameter                                | Description                                                      | Default                  |
| ---------------------------------------- | ---------------------------------------------------------------- | ------------------------ |
| `server.config.listenAddress`            | Address for the server to listen on                              | `:8080`                  |
| `server.config.exposedAddress`           | Public address peers use to connect                              | `""`                     |
| `server.config.stunPorts`                | STUN server ports                                                | `[]`                     |
| `server.config.stuns`                    | External STUN servers (list of `{uri}`); disables the local STUN server | `[]`              |
| `server.config.relays.addresses`         | External relay addresses; disables the local relay server        | `[]`                     |
| `server.config.relays.credentialsTTL`    | External relay credentials TTL                                   | `""`                    |
| `server.config.relays.secret`            | External relay shared secret                                     | `""`                    |
| `server.config.signalUri`                | External signal server URI; disables the local signal server     | `""`                     |
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
| `server.config.auth.sessionCookieEncryptionKey` | AES key for embedded IdP session cookies (envsubst-able, e.g. `${NB_IDP_SESSION_COOKIE_ENCRYPTION_KEY}`); 16/24/32 raw bytes or base64 to those lengths | `""` |
| `server.config.auth.mfaSessionMaxLifetime`     | Max MFA session lifetime (e.g. `24h`)               | `""`                     |
| `server.config.auth.mfaSessionIdleTimeout`     | MFA session idle timeout (e.g. `1h`)                | `""`                     |
| `server.config.auth.mfaSessionRememberMe`      | Pre-check "remember me" on login                    | `false`                  |
| `server.config.auth.dashboardRedirectURIs`     | OAuth2 redirect URIs for dashboard                  | `[]`                     |
| `server.config.auth.dashboardPostLogoutRedirectURIs` | OAuth2 post-logout redirect URIs for dashboard | `[]`                    |
| `server.config.auth.cliRedirectURIs`           | OAuth2 redirect URIs for CLI                        | `["http://localhost:53000/"]` |
| `server.config.auth.owner.email`               | Initial admin user email                            |                          |
| `server.config.auth.owner.password`            | Initial admin user password                         |                          |

### Server Store Configuration

| Parameter                                | Description                                                      | Default                  |
| ---------------------------------------- | ---------------------------------------------------------------- | ------------------------ |
| `server.config.store.engine`             | Store engine (sqlite, postgres, mysql)                           | `sqlite`                 |
| `server.config.store.dsn`                | Connection string for postgres/mysql                             | `""`                     |
| `server.config.store.encryptionKey`      | Encryption key for data store                                    | `${NB_ENCRYPTION_KEY}`   |
| `server.config.store.file`               | Custom SQLite file path (defaults to `{dataDir}/store.db`)       | `""`                     |
| `server.config.activityStore.engine`     | Activity events store engine (sqlite, postgres)                  | `""`                     |
| `server.config.activityStore.dsn`        | Activity events store connection string                          | `""`                     |
| `server.config.activityStore.file`       | Custom activity events SQLite path (defaults to `{dataDir}/events.db`) | `""`               |
| `server.config.authStore.engine`         | Embedded IdP store engine (sqlite3, postgres)                    | `""`                     |
| `server.config.authStore.dsn`            | Embedded IdP store connection string                             | `""`                     |
| `server.config.authStore.file`           | Custom embedded IdP SQLite path (defaults to `{dataDir}/idp.db`) | `""`                     |
| `server.config.reverseProxy.trustedHTTPProxies` | CIDRs of trusted reverse proxies                            | `[]`                     |
| `server.config.reverseProxy.trustedHTTPProxiesCount` | Number of trusted proxies in front of the server      | `0`                      |
| `server.config.reverseProxy.trustedPeers` | CIDRs of trusted peer networks                                  | `[]`                     |
| `server.config.reverseProxy.accessLogRetentionDays` | HTTP access log retention in days; negative disables cleanup | `0`             |
| `server.config.reverseProxy.accessLogCleanupIntervalHours` | Access-log cleanup interval in hours                 | `0`                      |
| `server.config.agentNetwork.pricingDefaultsFile` | Default LLM pricing table path (relative to dataDir)     | `""`                     |

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
| `server.service.externalIPs`             | External IPs for the server service                              | `[]`                     |
| `server.service.annotations`             | Annotations for the server service                               | `{}`                     |
| `server.serviceStun.enabled`             | Enable STUN service                                              | `true`                   |
| `server.serviceStun.type`                | STUN service type                                                | `ClusterIP`              |
| `server.serviceStun.port`                | STUN service port                                                | `3478`                   |
| `server.serviceStun.externalTrafficPolicy` | External traffic policy for LoadBalancer                       | `""`                     |
| `server.serviceStun.externalIPs`         | External IPs for the STUN service                                | `[]`                     |
| `server.serviceStun.annotations`         | Annotations for the STUN service                                 | `{}`                     |

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
| `dashboard.image.tag`            | Dashboard image tag                           | `v2.94.0`            |
| `dashboard.image.pullPolicy`     | Image pull policy                             | `IfNotPresent`       |
| `dashboard.containerPort`        | Container port                                | `8080`               |

### Dashboard Service Configuration

| Parameter                        | Description                                   | Default              |
| -------------------------------- | --------------------------------------------- | -------------------- |
| `dashboard.service.type`         | Service type                                  | `ClusterIP`          |
| `dashboard.service.port`         | Service port                                  | `80`                 |
| `dashboard.service.name`         | Service name                                  | `http`               |
| `dashboard.service.externalIPs`  | External IPs for the dashboard service        | `[]`                 |
| `dashboard.service.annotations`  | Annotations for the dashboard service         | `{}`                 |

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
| `management.strategy`                  | Deployment strategy                           | `RollingUpdate` 25%/25%  |
| `management.service.annotations`       | Annotations for the management HTTP service   | `{}`                     |
| `management.service.externalIPs`       | External IPs for the management HTTP service  | `[]`                     |
| `management.serviceGrpc.annotations`   | Annotations for the management gRPC service   | `{}`                     |
| `management.serviceGrpc.externalIPs`   | External IPs for the management gRPC service  | `[]`                     |
| `management.metrics.enabled`           | Expose metrics port and add `--metrics-port` to the management args | `false` |
| `management.metrics.port`              | Metrics port                                  | `9090`                   |

### Microservice Mode - Signal

| Parameter                        | Description                                   | Default              |
| -------------------------------- | --------------------------------------------- | -------------------- |
| `signal.enabled`                 | Enable signal component                       | `false`              |
| `signal.replicaCount`            | Number of replicas                            | `1`                  |
| `signal.image.repository`        | Image repository                              | `netbirdio/signal`   |
| `signal.image.tag`               | Image tag                                     | `""`                 |
| `signal.containerPort`           | Container port                                | `8080`               |
| `signal.logLevel`                | Log level                                     | `info`               |
| `signal.strategy`                | Deployment strategy                           | `RollingUpdate` 25%/25% |
| `signal.service.annotations`     | Annotations for the signal service            | `{}`                 |
| `signal.service.externalIPs`     | External IPs for the signal service           | `[]`                 |
| `signal.metrics.enabled`         | Expose metrics port (adds `--metrics-port` arg) | `false`            |
| `signal.metrics.port`            | Metrics port                                  | `9090`               |

### Microservice Mode - Relay

The relay is active when `relay.instances` is non-empty; each instance gets its own Deployment, Service, STUN Service, and Ingress.

Each instance that should run needs the upstream relay's required environment variables:
`NB_LISTEN_ADDRESS` (matching `containerPort`), `NB_EXPOSED_ADDRESS` and `NB_AUTH_SECRET`; the relay
container exits at startup without them (see `ci/` for working examples). `strategy` defaults to
`{type: Recreate}` when omitted.

| Parameter                                    | Description                                                       | Default          |
| -------------------------------------------- | ----------------------------------------------------------------- | ---------------- |
| `relay.instances`                            | List of relay instance configurations                             | `[]`             |
| `relay.instances[].name`                     | Instance name (required, must be unique)                          | —                |
| `relay.instances[].replicaCount`             | Number of replicas for the instance                               | `1`              |
| `relay.instances[].containerPort`            | HTTP container port                                               | `33080`          |
| `relay.instances[].strategy`                 | Deployment strategy; defaults to `{type: Recreate}` when omitted  | `{type: Recreate}` |
| `relay.instances[].metrics.enabled`          | Expose metrics port and set `NB_METRICS_PORT`                     | `false`          |
| `relay.instances[].metrics.port`             | Metrics port                                                      | `9090`           |
| `relay.instances[].service.type`             | Service type                                                      | `ClusterIP`      |
| `relay.instances[].service.port`             | Service port                                                      | `33080`          |
| `relay.instances[].service.name`             | Service port name                                                 | `http`           |
| `relay.instances[].service.externalIPs`      | External IPs for the instance service                             | `[]`             |
| `relay.instances[].service.annotations`      | Annotations for the instance service                              | `{}`             |
| `relay.instances[].stun.enabled`             | Enable embedded STUN server                                       | `false`          |
| `relay.instances[].stun.hostPort`            | Expose STUN UDP ports on the host via hostPort (pods spread across nodes; one node per replica) | `false` |
| `relay.instances[].stun.ports`               | STUN server ports (required when `stun.enabled` is true)          | `[]`             |
| `relay.instances[].stun.service.type`        | STUN service type (LoadBalancer/ClusterIP)                        | `ClusterIP`      |
| `relay.instances[].stun.service.externalTrafficPolicy` | External traffic policy                                 | `""`             |
| `relay.instances[].stun.service.externalIPs` | External IPs for the STUN service                                 | `[]`             |
| `relay.instances[].stun.service.annotations` | Annotations for the STUN service                                  | `{}`             |
| `relay.instances[].ingress.enabled`          | Enable ingress for the instance                                   | `false`          |
| `relay.instances[].env`                      | Environment variables for the instance                            | `{}`             |
| `relay.instances[].envRaw`                   | Raw environment variable sections for the instance                | `[]`             |
| `relay.instances[].envFromSecret`            | Environment variables from secrets for the instance               | `{}`             |

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
| `metrics.serviceMonitor.scrapeTimeout` | Scrape timeout                        | `""`        |
| `metrics.serviceMonitor.metricRelabelings` | Metric relabelings                | `[]`        |
| `metrics.serviceMonitor.relabelings`   | Relabelings                           | `[]`        |

When `metrics.serviceMonitor.enabled` is true, a ServiceMonitor is created for every component whose own metrics are enabled:
`server.metrics.enabled`, `management.metrics.enabled`, `signal.metrics.enabled`, and each `relay.instances[].metrics.enabled`.
The management and signal values are also passed to the processes as `--metrics-port` args; relay instances pass `NB_METRICS_PORT`.

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
