# NetBird Unified Server Helm Chart Refactoring Design

**Date:** 2026-02-24
**Status:** Approved
**Breaking Change:** Yes (Chart version 2.0.0)

## Overview

Refactor the NetBird Helm chart to support the unified `netbird-server` container architecture, consolidating separate management, signal, and relay deployments into a single server deployment with YAML configuration and envsubst-based secret injection.

## Background

NetBird has consolidated its architecture. Instead of running separate management, signal, and relay containers, everything is now combined into a single `netbird-server` container. This chart refactoring aligns with that change.

## Architecture

### Component Consolidation

| Before | After |
|--------|-------|
| management deployment | server deployment |
| signal deployment | (embedded in server) |
| relay deployment | (embedded in server) |
| dashboard deployment | dashboard deployment (unchanged) |

### Services

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| server | 80 | TCP | HTTP + gRPC (management, signal, relay, API, OAuth2) |
| server-stun | 3478 | UDP | STUN for NAT traversal |
| server-metrics | 9090 | TCP | Prometheus metrics (internal) |

### Health Checks

- Healthcheck endpoint on `:9000` (separate from main port)
- Liveness/readiness probes hit `:9000/health`

## Template Structure

### Files to Delete

```
templates/management-deployment.yaml
templates/management-service.yaml
templates/management-service-grpc.yaml
templates/management-ingress.yaml
templates/management-ingress-grpc.yaml
templates/management-cm.yaml
templates/management-pvc.yaml
templates/management-serviceaccount.yaml
templates/signal-deployment.yaml
templates/signal-service.yaml
templates/signal-ingress.yaml
templates/signal-serviceaccount.yaml
templates/relay-deployment.yaml
templates/relay-service.yaml
templates/relay-ingress.yaml
templates/relay-serviceaccount.yaml
```

### Files to Create

```
templates/server-deployment.yaml
templates/server-service.yaml           # HTTP/gRPC on port 80
templates/server-service-stun.yaml      # STUN on port 3478/UDP
templates/server-ingress.yaml           # HTTP paths
templates/server-ingress-grpc.yaml      # gRPC paths
templates/server-cm.yaml                # Config template
templates/server-pvc.yaml               # Data volume
templates/server-serviceaccount.yaml
```

### Files to Modify

```
templates/_helpers.tpl    # Replace management/signal/relay helpers with server.*
templates/service-monitor.yaml  # Update selector for server component
Chart.yaml                # Bump to 2.0.0
values.yaml               # New schema
README.md                 # Update documentation
```

## values.yaml Schema

### Top-Level Structure

```yaml
global: {...}           # Unchanged
nameOverride: ""        # Unchanged
fullnameOverride: ""    # Unchanged

server:                 # NEW - replaces management/signal/relay
  enabled: true
  image: {...}
  config: {...}         # Maps to config.yaml structure
  env: {...}            # For envsubst variables
  envRaw: {...}         # Raw env vars
  envFromSecret: {...}  # Secret references for envsubst
  initContainer: {...}  # envsubst settings
  service: {...}
  serviceStun: {...}
  ingress: {...}
  ingressGrpc: {...}
  # ... standard K8s settings

dashboard: {...}        # Unchanged
metrics: {...}          # Unchanged
extraManifests: {...}   # Unchanged
```

### server.config Schema

```yaml
server:
  config:
    listenAddress: ":80"
    exposedAddress: ""              # Required - e.g., "https://netbird.example.com:443"
    metricsPort: 9090
    healthcheckAddress: ":9000"
    logLevel: "info"
    logFile: "console"
    tls:
      enabled: false
      certFile: ""
      keyFile: ""
      letsencrypt:
        enabled: false
        dataDir: ""
        domains: []
        email: ""
        awsRoute53: false
    authSecret: "${NB_AUTH_SECRET}"  # envsubst placeholder
    dataDir: "/var/lib/netbird/"
    auth:
      issuer: ""
      localAuthDisabled: false
      signKeyRefreshEnabled: false
      dashboardRedirectURIs: []
      cliRedirectURIs: ["http://localhost:53000/"]
    store:
      engine: "sqlite"
      dsn: "${NB_STORE_DSN}"         # envsubst placeholder
      encryptionKey: "${NB_ENCRYPTION_KEY}"
    disableAnonymousMetrics: false
    disableGeoliteUpdate: false
```

### Init Container Configuration

```yaml
server:
  initContainer:
    enabled: true
    image:
      repository: alpine
      tag: "3.19"
      pullPolicy: IfNotPresent
    env: {}
    envRaw: []
    envFromSecret:
      NB_AUTH_SECRET: netbird-secrets/auth-secret
      NB_ENCRYPTION_KEY: netbird-secrets/encryption-key
      NB_STORE_DSN: netbird-secrets/store-dsn
```

## Config Template & envsubst

### Approach

1. User writes `${VAR}` placeholders directly in values.yaml config fields
2. ConfigMap stores template with placeholders preserved
3. Init container runs envsubst to render final config
4. Main container reads rendered config

### ConfigMap (server-cm.yaml)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "netbird.fullname" . }}-server
data:
  config.yaml.tmpl: |
    server:
      listenAddress: {{ .Values.server.config.listenAddress | quote }}
      exposedAddress: {{ .Values.server.config.exposedAddress | quote }}
      authSecret: {{ .Values.server.config.authSecret | quote }}
      # ... rest of config
```

### Init Container (in server-deployment.yaml)

```yaml
initContainers:
  - name: config-processor
    image: "{{ .Values.server.initContainer.image.repository }}:{{ .Values.server.initContainer.image.tag }}"
    command: ["/bin/sh", "-c"]
    args:
      - |
        apk add --no-cache gettext
        envsubst < /etc/netbird/config.yaml.tmpl > /etc/netbird/config.yaml
    env:
      # Standard env/envRaw/envFromSecret pattern from values
    volumeMounts:
      - name: config-template
        mountPath: /etc/netbird
        readOnly: true
      - name: config-rendered
        mountPath: /etc/netbird
```

## Services

### Primary Service (server-service.yaml)

```yaml
server:
  service:
    type: ClusterIP
    port: 80
    name: http
    externalTrafficPolicy: Local  # For LoadBalancer
```

### STUN Service (server-service-stun.yaml)

```yaml
server:
  serviceStun:
    enabled: true
    type: ClusterIP  # ClusterIP or LoadBalancer only
    port: 3478
    protocol: UDP
    externalTrafficPolicy: Local
```

## Ingress

### Two Separate Ingress Resources

**server-ingress-grpc.yaml** - gRPC paths (requires h2c backend):
- `/signalexchange.SignalExchange/`
- `/management.ManagementService/`
- `/management.ProxyService/`

**server-ingress.yaml** - HTTP paths:
- `/relay`
- `/ws-proxy/`
- `/api`
- `/oauth2`

### values.yaml Configuration

```yaml
server:
  ingressGrpc:
    enabled: false
    className: ""
    annotations: {}  # User provides ingress-class-specific annotations
    hosts:
      - host: netbird.example.com
        paths:
          - path: /signalexchange.SignalExchange/
            pathType: ImplementationSpecific
          - path: /management.ManagementService/
            pathType: ImplementationSpecific
          - path: /management.ProxyService/
            pathType: ImplementationSpecific
    tls: []

  ingress:
    enabled: false
    className: ""
    annotations: {}
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
    tls: []
```

## Examples

### Directory Changes

Delete existing examples and create new ones:
- `examples/nginx-ingress/authentik/values.yaml`
- `examples/traefik-ingress/authentik/values.yaml`
- `examples/istio/zitadel/values.yaml`
- `examples/minimal/values.yaml`

### Minimal Example

```yaml
server:
  enabled: true
  config:
    exposedAddress: "https://netbird.example.com:443"
    auth:
      issuer: "https://idp.example.com/oauth2"
  initContainer:
    envFromSecret:
      NB_AUTH_SECRET: netbird/auth-secret
      NB_ENCRYPTION_KEY: netbird/encryption-key

dashboard:
  enabled: true
  env:
    NETBIRD_MGMT_API_ENDPOINT: https://netbird.example.com
    AUTH_AUTHORITY: https://idp.example.com/oauth2
```

## Scope Limitations

**In scope for this iteration:**
- Unified server deployment with embedded signal, relay, STUN
- YAML configuration with envsubst
- Split ingress (gRPC + HTTP)
- STUN service (ClusterIP + LoadBalancer)

**Out of scope (future iteration):**
- External signal server (`signalUri`)
- External relay servers (`relays`)
- External STUN servers (`stuns`)

## Migration Notes

- Version 2.0.0 is a breaking change
- Replace `management`, `signal`, `relay` sections with single `server` section
- Config format changes from JSON to YAML with envsubst placeholders
- Dashboard configuration unchanged
