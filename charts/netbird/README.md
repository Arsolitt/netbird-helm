# netbird

![Version: 2.0.0](https://img.shields.io/badge/Version-2.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.60.2](https://img.shields.io/badge/AppVersion-0.60.2-informational?style=flat-square)

# NetBird Helm Chart

This Helm chart installs and configures the [NetBird](https://github.com/netbirdio/netbird) services within a Kubernetes cluster. The chart deploys the unified NetBird server (management, signal, and relay) along with the web dashboard.

## Prerequisites

- Helm 3.x
- Kubernetes 1.19+

## Installation

To install the chart with the release name `netbird`:

```bash
helm repo add totmicro https://totmicro.github.io/helms
helm install netbird totmicro/netbird
```

You can override default values by specifying a `values.yaml` file:

```bash
helm install netbird totmicro/netbird -f values.yaml
```

### Uninstalling the Chart

To uninstall/delete the `netbird` release:

```bash
helm uninstall netbird
```

This will remove all the resources associated with the release.

## Architecture

### Version 2.0.0+ (Unified Server)

Starting from version 2.0.0, this chart uses the unified `netbirdio/netbird-server` image that combines management, signal, and relay services into a single component. This simplifies deployment and configuration.

The unified server provides:
- **Management API** - HTTP endpoints for dashboard and API
- **Signal Service** - gRPC service for peer coordination
- **Relay Service** - TURN/STUN relay for NAT traversal

## Migration from 1.x to 2.0.0

Version 2.0.0 introduces breaking changes. Follow this guide to migrate:

### Key Changes

| 1.x Component | 2.x Equivalent |
|---------------|----------------|
| `management.*` | `server.*` |
| `signal.*` | `server.*` (integrated) |
| `relay.*` | `server.*` (integrated) |

### Configuration Mapping

**Old (1.x):**
```yaml
management:
  enabled: true
  env:
    NB_AUTH_SECRET: "secret"
signal:
  enabled: true
relay:
  enabled: true
```

**New (2.x):**
```yaml
server:
  enabled: true
  config:
    authSecret: "${NB_AUTH_SECRET}"
  initContainer:
    envFromSecret:
      NB_AUTH_SECRET: my-secret/auth-secret
```

### Removed Values

The following component-specific sections are removed:
- `management.*`
- `signal.*`
- `relay.*`

Replace with `server.*` configuration.

### Service Changes

| Old Service | New Service |
|-------------|-------------|
| `management` HTTP | `server` HTTP (port 80) |
| `management-grpc` | `server` gRPC (via same HTTP port) |
| `signal` | `server` gRPC (via same HTTP port) |
| `relay` | `server` relay (via same HTTP port) |
| - | `server-stun` (port 3478, new) |

## Configuration

### Basic Example

```yaml
server:
  enabled: true
  config:
    exposedAddress: "https://netbird.example.com:443"
    auth:
      issuer: "https://your-idp.com"
    store:
      engine: "sqlite"

dashboard:
  enabled: true
  ingress:
    enabled: true
    hosts:
      - host: netbird.example.com
        paths:
          - path: /
            pathType: Prefix
```

### Secrets with envsubst Pattern

The unified server uses an envsubst pattern for secrets. Configuration values can reference environment variables using `${VAR}` syntax:

```yaml
server:
  config:
    authSecret: "${NB_AUTH_SECRET}"
    store:
      encryptionKey: "${NB_ENCRYPTION_KEY}"
      dsn: "${NB_STORE_DSN}"

  initContainer:
    envFromSecret:
      NB_AUTH_SECRET: netbird-secrets/auth-secret
      NB_ENCRYPTION_KEY: netbird-secrets/encryption-key
      NB_STORE_DSN: netbird-secrets/store-dsn
```

The init container performs variable substitution before the main server starts.

### PostgreSQL/Mysql Database

For production deployments, use PostgreSQL or MySQL instead of SQLite:

```yaml
server:
  config:
    store:
      engine: "postgres"
      dsn: "${NB_STORE_DSN}"
  initContainer:
    envFromSecret:
      NB_STORE_DSN: netbird-secrets/store-dsn
```

### Ingress Configuration

The chart supports split ingress for HTTP and gRPC traffic:

#### HTTP Ingress (API, Dashboard, Relay)

```yaml
server:
  ingress:
    enabled: true
    className: "nginx"
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    hosts:
      - host: netbird.example.com
        paths:
          - path: /relay
            pathType: ImplementationSpecific
          - path: /ws-proxy/
            pathType: ImplementationSpecific
          - path: /api
            pathType: ImplementationSpecific
          - path: /oauth2
            pathType: ImplementationSpecific
    tls:
      - secretName: netbird-tls
        hosts:
          - netbird.example.com
```

#### gRPC Ingress (Signal, Management gRPC)

```yaml
server:
  ingressGrpc:
    enabled: true
    className: "nginx"
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
    hosts:
      - host: netbird.example.com
        paths:
          - path: /signalexchange.SignalExchange/
            pathType: ImplementationSpecific
          - path: /management.ManagementService/
            pathType: ImplementationSpecific
          - path: /management.ProxyService/
            pathType: ImplementationSpecific
    tls:
      - secretName: netbird-tls
        hosts:
          - netbird.example.com
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| dashboard.affinity | object | `{}` |  |
| dashboard.containerPort | int | `80` |  |
| dashboard.enabled | bool | `true` |  |
| dashboard.env | object | `{}` |  |
| dashboard.envFromSecret | object | `{}` |  |
| dashboard.envRaw | list | `[]` |  |
| dashboard.image.pullPolicy | string | `"IfNotPresent"` |  |
| dashboard.image.repository | string | `"netbirdio/dashboard"` |  |
| dashboard.image.tag | string | `"v2.22.2"` |  |
| dashboard.imagePullSecrets | list | `[]` |  |
| dashboard.ingress.annotations | object | `{}` |  |
| dashboard.ingress.className | string | `""` |  |
| dashboard.ingress.enabled | bool | `false` |  |
| dashboard.ingress.hosts[0].host | string | `"chart-example.local"` |  |
| dashboard.ingress.hosts[0].paths[0].path | string | `"/"` |  |
| dashboard.ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| dashboard.ingress.tls | list | `[]` |  |
| dashboard.initContainers | list | `[]` |  |
| dashboard.lifecycle | object | `{}` |  |
| dashboard.livenessProbe.httpGet.path | string | `"/"` |  |
| dashboard.livenessProbe.httpGet.port | string | `"http"` |  |
| dashboard.livenessProbe.periodSeconds | int | `5` |  |
| dashboard.nodeSelector | object | `{}` |  |
| dashboard.podAnnotations | object | `{}` |  |
| dashboard.podCommand.args | list | `[]` |  |
| dashboard.podSecurityContext | object | `{}` |  |
| dashboard.readinessProbe.httpGet.path | string | `"/"` |  |
| dashboard.readinessProbe.httpGet.port | string | `"http"` |  |
| dashboard.readinessProbe.initialDelaySeconds | int | `5` |  |
| dashboard.readinessProbe.periodSeconds | int | `5` |  |
| dashboard.replicaCount | int | `1` |  |
| dashboard.resources | object | `{}` |  |
| dashboard.securityContext | object | `{}` |  |
| dashboard.service.name | string | `"http"` |  |
| dashboard.service.port | int | `80` |  |
| dashboard.service.type | string | `"ClusterIP"` |  |
| dashboard.serviceAccount.annotations | object | `{}` |  |
| dashboard.serviceAccount.create | bool | `true` |  |
| dashboard.serviceAccount.name | string | `""` |  |
| dashboard.tolerations | list | `[]` |  |
| dashboard.volumeMounts | list | `[]` |  |
| dashboard.volumes | list | `[]` |  |
| extraManifests | object | `{}` |  |
| fullnameOverride | string | `""` |  |
| global.namespace | string | `""` |  |
| metrics.serviceMonitor.annotations | object | `{}` |  |
| metrics.serviceMonitor.enabled | bool | `false` |  |
| metrics.serviceMonitor.honorLabels | bool | `false` |  |
| metrics.serviceMonitor.interval | string | `""` |  |
| metrics.serviceMonitor.jobLabel | string | `""` |  |
| metrics.serviceMonitor.labels | object | `{}` |  |
| metrics.serviceMonitor.metricRelabelings | list | `[]` |  |
| metrics.serviceMonitor.namespace | string | `""` |  |
| metrics.serviceMonitor.relabelings | list | `[]` |  |
| metrics.serviceMonitor.scrapeTimeout | string | `""` |  |
| metrics.serviceMonitor.selector | object | `{}` |  |
| nameOverride | string | `""` |  |
| server.affinity | object | `{}` |  |
| server.config.auth.cliRedirectURIs | list | `["http://localhost:53000/"]` |  |
| server.config.auth.dashboardRedirectURIs | list | `[]` |  |
| server.config.auth.issuer | string | `""` |  |
| server.config.auth.localAuthDisabled | bool | `false` |  |
| server.config.auth.signKeyRefreshEnabled | bool | `false` |  |
| server.config.authSecret | string | `"${NB_AUTH_SECRET}"` | Shared secret for relay authentication. Use ${VAR} for envsubst. |
| server.config.dataDir | string | `"/var/lib/netbird/"` |  |
| server.config.disableAnonymousMetrics | bool | `false` |  |
| server.config.disableGeoliteUpdate | bool | `false` |  |
| server.config.exposedAddress | string | `""` | Public address peers use to connect. |
| server.config.healthcheckAddress | string | `":9000"` |  |
| server.config.listenAddress | string | `":80"` |  |
| server.config.logFile | string | `"console"` |  |
| server.config.logLevel | string | `"info"` |  |
| server.config.metricsPort | int | `9090` |  |
| server.config.store.dsn | string | `""` | Connection string for postgres/mysql. Use ${VAR} for envsubst. |
| server.config.store.encryptionKey | string | `"${NB_ENCRYPTION_KEY}"` | Encryption key. Use ${VAR} for envsubst. |
| server.config.store.engine | string | `"sqlite"` | Store engine: sqlite, postgres, or mysql. |
| server.config.stunPorts | list | `[]` |  |
| server.config.tls.letsencrypt.awsRoute53 | bool | `false` | Use AWS Route53 for DNS validation |
| server.config.tls.certFile | string | `""` |  |
| server.config.tls.enabled | bool | `false` |  |
| server.config.tls.keyFile | string | `""` |  |
| server.config.tls.letsencrypt.dataDir | string | `""` |  |
| server.config.tls.letsencrypt.domains | list | `[]` |  |
| server.config.tls.letsencrypt.email | string | `""` |  |
| server.config.tls.letsencrypt.enabled | bool | `false` |  |
| server.containerPort | int | `80` |  |
| server.deploymentAnnotations | object | `{}` |  |
| server.enabled | bool | `true` |  |
| server.env | object | `{}` |  |
| server.envFromSecret | object | `{}` |  |
| server.envRaw | list | `[]` |  |
| server.gracefulShutdown | bool | `true` |  |
| server.image.pullPolicy | string | `"IfNotPresent"` |  |
| server.image.repository | string | `"netbirdio/netbird-server"` |  |
| server.image.tag | string | `""` |  |
| server.imagePullSecrets | list | `[]` |  |
| server.initContainer.enabled | bool | `true` |  |
| server.initContainer.env | object | `{}` |  |
| server.initContainer.envFromSecret | object | `{}` | Environment variables from secrets for envsubst. Format: ENV_VAR: secretName/secretKey |
| server.initContainer.envRaw | list | `[]` |  |
| server.initContainer.image.pullPolicy | string | `"IfNotPresent"` |  |
| server.initContainer.image.repository | string | `"alpine"` |  |
| server.initContainer.image.tag | string | `"3.19"` |  |
| server.ingress.annotations | object | `{}` |  |
| server.ingress.className | string | `""` |  |
| server.ingress.enabled | bool | `false` |  |
| server.ingress.hosts[0].host | string | `"netbird.example.com"` |  |
| server.ingress.hosts[0].paths[0].path | string | `"/relay"` |  |
| server.ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| server.ingress.hosts[0].paths[1].path | string | `"/ws-proxy/"` |  |
| server.ingress.hosts[0].paths[1].pathType | string | `"ImplementationSpecific"` |  |
| server.ingress.hosts[0].paths[2].path | string | `"/api"` |  |
| server.ingress.hosts[0].paths[2].pathType | string | `"ImplementationSpecific"` |  |
| server.ingress.hosts[0].paths[3].path | string | `"/oauth2"` |  |
| server.ingress.hosts[0].paths[3].pathType | string | `"ImplementationSpecific"` |  |
| server.ingress.tls | list | `[]` |  |
| server.ingressGrpc.annotations | object | `{}` |  |
| server.ingressGrpc.className | string | `""` |  |
| server.ingressGrpc.enabled | bool | `false` |  |
| server.ingressGrpc.hosts[0].host | string | `"netbird.example.com"` |  |
| server.ingressGrpc.hosts[0].paths[0].path | string | `"/signalexchange.SignalExchange/"` |  |
| server.ingressGrpc.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| server.ingressGrpc.hosts[0].paths[1].path | string | `"/management.ManagementService/"` |  |
| server.ingressGrpc.hosts[0].paths[1].pathType | string | `"ImplementationSpecific"` |  |
| server.ingressGrpc.hosts[0].paths[2].path | string | `"/management.ProxyService/"` |  |
| server.ingressGrpc.hosts[0].paths[2].pathType | string | `"ImplementationSpecific"` |  |
| server.ingressGrpc.tls | list | `[]` |  |
| server.lifecycle | object | `{}` |  |
| server.livenessProbe.failureThreshold | int | `3` |  |
| server.livenessProbe.httpGet.path | string | `"/health"` |  |
| server.livenessProbe.httpGet.port | int | `9000` |  |
| server.livenessProbe.initialDelaySeconds | int | `15` |  |
| server.livenessProbe.periodSeconds | int | `10` |  |
| server.livenessProbe.timeoutSeconds | int | `3` |  |
| server.metrics.enabled | bool | `false` |  |
| server.metrics.port | int | `9090` |  |
| server.nodeSelector | object | `{}` |  |
| server.persistentVolume.accessModes | list | `["ReadWriteOnce"]` |  |
| server.persistentVolume.annotations | object | `{}` |  |
| server.persistentVolume.enabled | bool | `true` |  |
| server.persistentVolume.existingPVName | string | `""` |  |
| server.persistentVolume.size | string | `"10Mi"` |  |
| server.persistentVolume.storageClass | string | `nil` |  |
| server.podAnnotations | object | `{}` |  |
| server.podSecurityContext | object | `{}` |  |
| server.readinessProbe.failureThreshold | int | `3` |  |
| server.readinessProbe.httpGet.path | string | `"/health"` |  |
| server.readinessProbe.httpGet.port | int | `9000` |  |
| server.readinessProbe.initialDelaySeconds | int | `15` |  |
| server.readinessProbe.periodSeconds | int | `10` |  |
| server.readinessProbe.timeoutSeconds | int | `3` |  |
| server.replicaCount | int | `1` |  |
| server.resources | object | `{}` |  |
| server.securityContext | object | `{}` |  |
| server.service.externalTrafficPolicy | string | `""` |  |
| server.service.name | string | `"http"` |  |
| server.service.port | int | `80` |  |
| server.service.type | string | `"ClusterIP"` |  |
| server.serviceAccount.annotations | object | `{}` |  |
| server.serviceAccount.create | bool | `true` |  |
| server.serviceAccount.name | string | `""` |  |
| server.serviceStun.enabled | bool | `true` |  |
| server.serviceStun.externalTrafficPolicy | string | `""` |  |
| server.serviceStun.port | int | `3478` |  |
| server.serviceStun.type | string | `"ClusterIP"` |  |
| server.strategy.rollingUpdate.maxSurge | string | `"25%"` |  |
| server.strategy.rollingUpdate.maxUnavailable | string | `"25%"` |  |
| server.strategy.type | string | `"RollingUpdate"` |  |
| server.tolerations | list | `[]` |  |
| server.volumeMounts | list | `[]` |  |
| server.volumes | list | `[]` |  |

For more configuration options, refer to the `values.yaml` file.

You can find working examples [here](./examples)

## STUN/TURN Server

If you need to deploy a High Available stun/turn server, please refer to this [blog](https://medium.com/l7mp-technologies/deploying-a-scalable-stun-service-in-kubernetes-c7b9726fa41d)

## Contributing

We welcome contributions to improve this chart! Please submit a pull request to the GitHub repository with any changes or suggestions.
