# Examples Directory Restructure Design

## Overview

Reorganize and update the `charts/netbird/examples/` directory to provide clear, up-to-date examples for deploying NetBird in microservice mode with various ingress controllers and identity providers.

## Current State

### Existing Examples

| Location | Content | Issues |
|----------|---------|--------|
| `charts/netbird/examples/microservice/values.yaml` | Older format, nginx+authentik | Missing new config fields, outdated env vars |
| `charts/netbird/examples/traefik-ingress/authentik/` | Hybrid/server mode | Not microservice mode, outdated |
| `docs/example-values.yaml` | Current microservice + nginx + authentik | Reference template |
| `docs/examples/nginx-ingress/{authentik,okta,google,auth0}/` | Multiple IDPs | Older format, missing new fields |
| `docs/examples/traefik-ingress/authentik/` | Traefik + authentik | Older format |

### Problems

1. Examples in `charts/netbird/examples/` are outdated
2. No clear structure separating ingress controller from IDP
3. Missing examples for okta, google, auth0 in microservice mode
4. Old examples use deprecated patterns (image.tag overrides, useBackwardsGrpcService)

## Target Structure

```
charts/netbird/examples/
├── minimal/                    # Keep as-is
├── hybrid/                     # Keep as-is
└── microservice/
    ├── nginx-ingress/
    │   ├── authentik/
    │   │   ├── values.yaml
    │   │   └── README.md
    │   ├── okta/
    │   │   ├── values.yaml
    │   │   └── README.md
    │   ├── google/
    │   │   ├── values.yaml
    │   │   └── README.md
    │   └── auth0/
    │       ├── values.yaml
    │       └── README.md
    └── traefik-ingress/
        └── authentik/
            ├── values.yaml
            └── README.md
```

## Implementation Details

### Base Template

Use `docs/example-values.yaml` as the reference for:
- Microservice mode (`server.enabled: false`, separate components)
- Environment variables structure
- Ingress annotations patterns
- ConfigMap structure with `{{ .EnvVarName }}` placeholders

### IDP-Specific Configurations

Each IDP requires different config blocks in `management.configmap`:

| Section | authentik | okta | google | auth0 |
|---------|-----------|------|--------|-------|
| `IdpManagerConfig.ManagerType` | authentik | okta | google | auth0 |
| `IdpManagerConfig.ExtraConfig` | Username, Password | ApiToken | CustomerId, ServiceAccountKey | Audience |
| `DeviceAuthorizationFlow` | Custom endpoints | Okta endpoints | Google endpoints | Auth0 endpoints |
| `PKCEAuthorizationFlow` | Custom endpoints | Okta endpoints | Google endpoints | Auth0 endpoints |

### Required Secret Keys by IDP

| IDP | Required Secrets |
|-----|------------------|
| authentik | idpClientID, idpServiceAccountUser, idpServiceAccountPassword |
| okta | idpClientID, oktaApiToken, idpNativeAppClientID |
| google | idpClientID, idpClientSecret, customerID, sa.json (service account) |
| auth0 | idpClientID, idpClientSecret, idpInteractiveClientID, idpDashboardClientID |

### Standard Updates Across All Examples

1. Add `NB_ACTIVITY_EVENT_POSTGRES_DSN` env var for event storage
2. Add `NB_ACTIVITY_EVENT_STORE_ENGINE: postgres` env var
3. Add `NB_DISABLE_GEOLOCATION: true` env var
4. Add `EmbeddedIdP` block (disabled) to configmap
5. Remove `image.tag` overrides (use Chart.appVersion)
6. Remove `useBackwardsGrpcService` (deprecated)
7. Use wildcard TLS pattern: `wildcard.example.com-tls`

### Traefik-Specific Considerations

Traefik examples need:
- `traefik.ingress.kubernetes.io/router.entrypoints: websecure`
- `traefik.ingress.kubernetes.io/router.tls: "true"`
- `traefik.ingress.kubernetes.io/backend.protocol: h2c` for gRPC services
- IngressRoute CRD via `extraManifests` for complex routing (optional)

## Files to Create

### nginx-ingress/authentik
- `values.yaml` - Based on docs/example-values.yaml
- `README.md` - Prerequisites, secret config, deployment

### nginx-ingress/okta
- `values.yaml` - Adapt IDP config from docs/examples/nginx-ingress/okta/
- `README.md` - Okta-specific prerequisites

### nginx-ingress/google
- `values.yaml` - Adapt IDP config from docs/examples/nginx-ingress/google/
- `README.md` - Google Workspace setup, service account

### nginx-ingress/auth0
- `values.yaml` - Adapt IDP config from docs/examples/nginx-ingress/auth0/
- `README.md` - Auth0 application setup

### traefik-ingress/authentik
- `values.yaml` - Traefik annotations + authentik IDP config
- `README.md` - Traefik-specific setup

## Files to Remove/Replace

- `charts/netbird/examples/microservice/values.yaml` → replace with new structure
- `charts/netbird/examples/traefik-ingress/` → replace with microservice/traefik-ingress/

## Success Criteria

- All examples pass `helm lint`
- All examples render valid Kubernetes manifests
- README.md files document required secrets clearly
- Consistent structure across all examples
