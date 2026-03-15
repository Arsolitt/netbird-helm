# Security Hardening Design

## Overview

Apply security hardening to all NetBird chart components: non-root execution, read-only filesystems, dropped capabilities, and unprivileged ports.

## Changes

### 1. Port Changes

| Component | Port Type | Current | New |
|-----------|-----------|---------|-----|
| server | HTTP | 80 | 8080 |
| server | STUN | 3478 | 53478 |
| server | healthcheck | 9000 | 9000 |
| management | HTTP | 80 | 8080 |
| management | gRPC | 33073 | 33073 |
| signal | gRPC | 80 | 8080 |
| relay | HTTP | 33080 | 33080 |
| relay | STUN | 3478 | 53478 |
| dashboard | HTTP | 80 | 8080 |

Service ports remain unchanged (80, 3478). Only containerPort values change.

### 2. Security Context Defaults

**podSecurityContext** (all components):
```yaml
runAsNonRoot: true
runAsUser: 2222
runAsGroup: 2222
fsGroup: 2222
seccompProfile:
  type: RuntimeDefault
```

**securityContext** (all containers):
```yaml
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop:
    - ALL
```

### 3. Volume Mounts by Component

**server:**
- `/tmp` → tmpfs (emptyDir with medium: Memory)
- `/etc/netbird` → emptyDir (readOnly, written by init container)
- `/var/lib/netbird` → PVC (read-write)

**management:**
- `/tmp` → tmpfs
- `/etc/netbird` → configMap (readOnly)
- `/var/lib/netbird` → PVC (read-write)

**signal:**
- `/tmp` → tmpfs
- No persistent volumes

**relay:**
- `/tmp` → tmpfs
- No persistent volumes

**dashboard:**
- `/tmp` → tmpfs
- No persistent volumes

**server init container:**
- Same securityContext defaults
- `/etc/netbird` → emptyDir (read-write)

### 4. Files to Modify

**values.yaml:**
- Add `podSecurityContext` and `securityContext` defaults to: management, signal, relay, server, dashboard
- Update `containerPort` values
- Update `server.config.healthcheckAddress` if needed (already :9000)
- Update `server.config.stunPorts` default to [53478]
- Update `relay.stun.ports` default to [53478]

**Deployment templates:**
- `server-deployment.yaml`: add tmpfs volume, mount /tmp, add securityContext to init container
- `management-deployment.yaml`: add tmpfs volume, mount /tmp
- `signal-deployment.yaml`: add tmpfs volume, mount /tmp
- `relay-deployment.yaml`: add tmpfs volume, mount /tmp
- `dashboard-deployment.yaml`: add tmpfs volume, mount /tmp

### 5. Implementation Approach

Explicit defaults in values.yaml for each component. No template-level merging logic. Users can override any value.

## Breaking Changes

- Ports below 1024 moved to unprivileged ports (80 → 8080, 3478 → 53478)
- Containers now run as non-root user 2222
- Filesystem is read-only except for mounted volumes

Users with custom `podSecurityContext` or `securityContext` will need to merge values manually.
