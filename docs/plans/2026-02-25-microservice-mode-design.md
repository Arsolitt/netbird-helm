# Microservice Deployment Mode Design

**Date:** 2026-02-25
**Status:** Approved

## Overview

Add microservice deployment mode to the NetBird Helm chart alongside the existing unified server mode. Users can deploy management, signal, and relay as separate containers instead of the combined `netbird-server` image.

## Mode Selection

Mode is determined by which components are enabled in `values.yaml`:

- **Unified mode**: `server.enabled: true` (default, backward compatible)
- **Microservice mode**: Enable `management`, `signal`, and/or `relay` individually

### Compatibility Matrix

| Component | Can coexist with |
|-----------|------------------|
| `server` | `signal`, `relay` |
| `management` | `signal`, `relay` |

**Invalid combination:** `server.enabled: true` AND `management.enabled: true`

### Valid Deployment Patterns

1. **Unified (default)**: `server` alone - uses embedded signal/relay
2. **Hybrid - separate signal**: `server` + `signal` - unified with external signal
3. **Hybrid - separate relay**: `server` + `relay` - unified with external relay (optionally with STUN)
4. **Hybrid - both**: `server` + `signal` + `relay` - unified management only
5. **Full microservice**: `management` + `signal` + `relay` - completely split deployment
6. **Partial microservice**: `management` alone (uses external signal/relay endpoints)

## Components

### Management

- **Image:** `netbirdio/management`
- **Configuration:** JSON configmap with `{{ .VAR }}` placeholders (management handles substitution internally)
- **Services:** HTTP (API) + optional gRPC
- **Storage:** PersistentVolume for data

**values.yaml structure:**
```yaml
management:
  enabled: false
  configmap: |-
    {
      "Signal": { "Proto": "https", "URI": "{{ .SIGNAL_URI }}" },
      "Datadir": "/var/lib/netbird/",
      ...
    }
  env: {}
  envRaw: []
  envFromSecret: {}
  # Standard: image, replicaCount, ingress, ingressGrpc, service, serviceGrpc,
  # persistentVolume, resources, probes, etc.
```

### Signal

- **Image:** `netbirdio/signal`
- **Services:** gRPC only
- **Configuration:** Simple env vars

**values.yaml structure:**
```yaml
signal:
  enabled: false
  logLevel: info
  env: {}
  envRaw: []
  envFromSecret: {}
  # Standard: image, replicaCount, ingress (gRPC), service, resources, probes, etc.
```

### Relay

- **Image:** `netbirdio/relay`
- **Services:** HTTP + optional UDP for embedded STUN
- **Configuration:** Env vars, with structured STUN config

**values.yaml structure:**
```yaml
relay:
  enabled: false
  logLevel: info
  env: {}
  envRaw: []
  envFromSecret: {}
  
  stun:
    enabled: false
    ports: [3478]
    service:
      type: LoadBalancer
      externalTrafficPolicy: Local
  
  # Standard: image, replicaCount, ingress, service, resources, probes, etc.
```

### Dashboard

- Shared between both modes (no changes to existing configuration)
- Works identically with `server` or `management` as backend

## Relay STUN Service

When `relay.stun.enabled: true`:

1. **UDP Service created** (`relay-service-stun.yaml`):
   - One port per entry in `relay.stun.ports`
   - Type from `relay.stun.service.type` (LoadBalancer or ClusterIP)
   - `externalTrafficPolicy: Local` preserves source IP (important for STUN)

2. **Env vars injected in deployment:**
   - `NB_ENABLE_STUN: "true"`
   - `NB_STUN_PORTS: "3478,3479"` (comma-joined)

**Example values:**
```yaml
relay:
  enabled: true
  stun:
    enabled: true
    ports: [3478, 3479]
    service:
      type: LoadBalancer
      externalTrafficPolicy: Local
```

## Templates

### New Template Files

| Component | Templates |
|-----------|-----------|
| Management | `management-deployment.yaml`, `management-cm.yaml`, `management-service.yaml`, `management-service-grpc.yaml`, `management-ingress.yaml`, `management-ingress-grpc.yaml`, `management-pvc.yaml`, `management-serviceaccount.yaml` |
| Signal | `signal-deployment.yaml`, `signal-service.yaml`, `signal-ingress.yaml`, `signal-serviceaccount.yaml` |
| Relay | `relay-deployment.yaml`, `relay-service.yaml`, `relay-service-stun.yaml`, `relay-ingress.yaml`, `relay-serviceaccount.yaml` |

### Helper Functions

Add to `_helpers.tpl`:
- `netbird.management.labels` / `netbird.management.selectorLabels` / `netbird.management.serviceAccountName`
- `netbird.signal.labels` / `netbird.signal.selectorLabels` / `netbird.signal.serviceAccountName`
- `netbird.relay.labels` / `netbird.relay.selectorLabels` / `netbird.relay.serviceAccountName`

### Validation

Add validation helper that fails chart rendering if:
```
server.enabled: true AND management.enabled: true
```

## File Structure

```
charts/netbird/
├── Chart.yaml
├── values.yaml              # Updated with management/signal/relay sections
├── README.md                # Updated with both modes
├── templates/
│   ├── _helpers.tpl         # New helpers + validation
│   ├── server-*.yaml        # Existing (unchanged)
│   ├── management-*.yaml    # New (8 files)
│   ├── signal-*.yaml        # New (4 files)
│   ├── relay-*.yaml         # New (5 files)
│   ├── dashboard-*.yaml     # Existing (unchanged)
│   ├── service-monitor.yaml
│   └── xtraManifests.yaml
└── examples/
    ├── minimal/             # Existing unified example
    ├── microservice/        # NEW: full microservice
    └── hybrid/              # NEW: server + relay with STUN
```

## Examples

### examples/microservice/values.yaml

Full microservice deployment with all components separated, relay with embedded STUN.

### examples/hybrid/values.yaml

Unified server with separate relay for embedded STUN - simpler management but external STUN capability.

## Migration Path

Users on old microservice chart (`tmp/netbird`):
1. Copy `management.configmap` content to new `management.configmap`
2. Map env vars to `envFromSecret` format (`VAR: secretName/secretKey`)
3. Enable `relay.stun` section if using embedded STUN
4. Dashboard config unchanged

Users on unified mode:
- No changes required, fully backward compatible
