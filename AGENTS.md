# AGENTS.md - Guidelines for AI Coding Agents

Helm chart repository for deploying [NetBird](https://github.com/netbirdio/netbird) VPN components to Kubernetes. Version 2.0+ uses a unified server image (`netbirdio/netbird-server`) combining management, signal, and relay services.

## Build/Lint/Test Commands

```bash
# Lint
helm lint charts/netbird
helm lint --quiet charts/netbird  # CI mode

# Full validation (same as CI)
helm dep up charts/netbird && \
  helm template x charts/netbird --include-crds > helm_output.yaml && \
  cat helm_output.yaml | kubeconform -summary -strict -ignore-missing-schemas -kubernetes-version=1.30.0 -cache /tmp

# Template debugging
helm template <release> charts/netbird                    # Basic
helm template <release> charts/netbird -f values.yaml     # With custom values
helm template <release> charts/netbird --debug 2>&1       # Debug mode

# Package & install
helm package charts/netbird
helm install netbird charts/netbird --dry-run
```

## Code Style Guidelines

### Helm Template Structure

- **File Naming**: kebab-case with component prefix and resource suffix (e.g., `server-deployment.yaml`)
- **Template Order**: Files prefixed with `00-` load first (e.g., `00-validations.yaml`)
- **Enable Guards**: All component templates MUST start and end with enable guards:
  ```yaml
  {{- if .Values.<component>.enabled -}}
  ...
  {{- end -}}
  ```

### Template Formatting

- **Indentation**: 2 spaces throughout
- **nindent**: Use for multi-line blocks: `{{- include "netbird.server.labels" . | nindent 4 }}`
- **Whitespace**: Always use `{{-` and `-}}` to trim whitespace
- **with blocks**: `{{- with .Values.field }}` for optional nested values
- **range blocks**: `{{- range $key, $val := .Values.map }}` for map iteration

### Helper Functions (_helpers.tpl)

Template naming: `netbird.<component>.<purpose>` (e.g., `netbird.server.labels`)

```yaml
{{- define "netbird.component.labels" -}}
helm.sh/chart: {{ include "netbird.chart" . }}
{{ include "netbird.component.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

### Resource Naming

- **Resources**: `{{ include "netbird.fullname" . }}-<component>` (e.g., `netbird-server`)
- **Namespace**: Always use `{{ include "netbird.namespace" . }}` for cross-namespace support
- **Labels**: Kubernetes recommended labels (`app.kubernetes.io/name`, `app.kubernetes.io/instance`)

### Values.yaml Structure

```yaml
## @section Component Name
## @param component.enabled Enable or disable this component.
component:
  enabled: true
  ## @param component.field Description.
  field: "value"
```

- Group by component (global, server, dashboard, management, signal, relay, metrics)
- Use `@section` and `@param` annotations for documentation

### YAML Style

- Lists: `- item` with space after dash
- Empty values: `{}` for maps, `[]` for lists, `""` for strings
- Quote all string values in templates: `{{ .Values.field | quote }}`

### Environment Variables

```yaml
# 1. Simple key-value
env:
  KEY: "value"

# 2. Raw (complex values like valueFrom)
envRaw:
  - name: COMPLEX_VAR
    valueFrom:
      secretKeyRef:
        name: secret-name
        key: key-name

# 3. From secrets shorthand (format: ENV_VAR: secretName/secretKey)
envFromSecret:
  ENV_VAR: secretName/secretKey
```

### ConfigMap Pattern (envsubst)

Server uses init container with envsubst for secrets:

```yaml
data:
  config.yaml.tmpl: |
    authSecret: {{ .Values.server.config.authSecret | quote }}

initContainers:
  - name: config-processor
    command: ["/bin/sh", "-c"]
    args:
      - envsubst < /etc/netbird-template/config.yaml.tmpl > /etc/netbird/config.yaml
```

### Image Tags

```yaml
image: "{{ .Values.component.image.repository }}:{{ .Values.component.image.tag | default .Chart.AppVersion }}"
```

### Pod Annotations (Config Checksum)

```yaml
annotations:
  checksum/config: {{ include (print .Template.BasePath "/server-cm.yaml") . | sha256sum }}
```

### Volumes Pattern

```yaml
volumes:
  - name: config-template
    configMap:
      name: {{ include "netbird.fullname" . }}-server
  - name: config-rendered
    emptyDir: {}
  - name: data
    {{- if .Values.component.persistentVolume.enabled }}
    persistentVolumeClaim:
      claimName: {{ include "netbird.fullname" . }}-server
    {{- else }}
    emptyDir: {}
    {{- end }}
```

### Validation Pattern

Use `00-validations.yaml` for fail-fast checks:

```yaml
{{- if and .Values.server.enabled .Values.management.enabled -}}
{{- fail "Cannot enable both server (unified mode) and management (microservice mode)." -}}
{{- end -}}
```

## Chart Versioning

- Update `version` in `Chart.yaml` for each chart change
- Update `appVersion` when NetBird application version changes
- Releases are automated via GitHub Actions on merge to main

## File Structure

```
netbird-helm/
├── charts/netbird/
│   ├── Chart.yaml              # Chart metadata
│   ├── values.yaml             # Default values with @param docs
│   ├── templates/
│   │   ├── _helpers.tpl        # Reusable template functions
│   │   ├── 00-validations.yaml # Fail-fast validation checks
│   │   ├── server-*.yaml       # Server resources
│   │   ├── dashboard-*.yaml    # Dashboard resources
│   │   ├── management-*.yaml   # Management (microservice mode)
│   │   ├── signal-*.yaml       # Signal (microservice mode)
│   │   ├── relay-*.yaml        # Relay (microservice mode)
│   │   └── service-monitor.yaml
│   └── examples/               # Example values (minimal, hybrid, microservice)
├── .github/workflows/
│   ├── validate.yml            # PR validation (lint + kubeconform)
│   └── release.yml             # Chart release on main
└── AGENTS.md
```

## Common Tasks

### Adding a New Component

1. Create templates: `<component>-deployment.yaml`, `<component>-service.yaml`
2. Add helpers in `_helpers.tpl` (labels, selectorLabels, serviceAccountName)
3. Add defaults in `values.yaml` with `@param` annotations
4. Update `charts/netbird/README.md`

### Modifying Templates

1. Maintain backward compatibility
2. Add `@param` docs for new values
3. Run validation: `helm lint charts/netbird && helm template x charts/netbird --include-crds | kubeconform -summary`

### Deployment Modes

- **Unified (server.enabled: true)**: Single deployment with management, signal, relay
- **Microservice (management.enabled/signal.enabled/relay.enabled: true)**: Separate deployments
- Cannot enable both modes simultaneously (validated in 00-validations.yaml)
