# AGENTS.md - Guidelines for AI Coding Agents

This is a Helm chart repository for deploying [NetBird](https://github.com/netbirdio/netbird) VPN components (management, signal, relay, dashboard) to Kubernetes.

## Build/Lint/Test Commands

### Primary Validation

```bash
# Lint chart
helm lint charts/netbird
helm lint --quiet charts/netbird  # CI mode

# Template and validate against K8s schemas
helm template x charts/netbird --include-crds > helm_output.yaml && \
  cat helm_output.yaml | kubeconform -summary -strict -ignore-missing-schemas -kubernetes-version=1.30.0 -cache /tmp && \
  cat helm_output.yaml | kubeconform -summary -strict -ignore-missing-schemas -kubernetes-version=1.31.0 -cache /tmp
```

### Template Generation

```bash
helm template <release-name> charts/netbird                    # Basic
helm template <release-name> charts/netbird -f values.yaml     # With custom values
helm template <release-name> charts/netbird -n <namespace>     # With namespace
```

### Dependency & Package

```bash
helm dep up charts/netbird              # Update dependencies
helm package charts/netbird             # Package chart
helm install netbird charts/netbird --dry-run  # Test install
```

## Code Style Guidelines

### Helm Template Structure

- **File Naming**: kebab-case, grouped by component with resource suffix (e.g., `management-deployment.yaml`)
- **Enable Guards**: All component templates start with:
  ```yaml
  {{- if .Values.<component>.enabled -}}
  ```

### Template Formatting

- **Indentation**: 2 spaces
- **nindent**: Use for multi-line blocks: `{{- include "netbird.management.labels" . | nindent 4 }}`
- **Whitespace**: Use `{{-` and `-}}` to trim whitespace
- **with blocks**: Use `{{- with .Values.field }}` for optional nested values

### Helper Functions (_helpers.tpl)

```yaml
{{/*
Description of template.
*/}}
{{- define "netbird.component.labels" -}}
helm.sh/chart: {{ include "netbird.chart" . }}
{{ include "netbird.component.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

### Naming Conventions

- **Template Names**: `netbird.<component>.<purpose>` (e.g., `netbird.management.labels`)
- **Resource Names**: `{{ include "netbird.fullname" . }}-<component>`
- **Labels**: Use Kubernetes recommended labels (`app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `helm.sh/chart`)

### Values.yaml Structure

```yaml
## @section Component Name
## @param component.enabled Enable or disable this component.
component:
  enabled: true
```

- Group by component (global, management, signal, relay, dashboard, metrics)
- Provide sensible defaults
- Use `@section` and `@param` annotations

### YAML Style

- Lists: `- item` with space
- Empty values: `{}` for maps, `[]` for lists, `""` for strings
- Multi-line: Use `|` for block scalars

### Conditional Blocks

```yaml
{{- if .Values.component.field }}
field:
  {{- toYaml .Values.component.field | nindent 2 }}
{{- end }}
```

### Environment Variables

Three patterns in deployments:

```yaml
# 1. Simple key-value
env:
  KEY: "value"

# 2. Raw (complex values)
envRaw:
  - name: COMPLEX_VAR
    valueFrom:
      secretKeyRef:
        name: secret-name
        key: key-name

# 3. From secrets shorthand
envFromSecret:
  ENV_VAR: secretName/secretKey
```

### Volume/VolumeMount

```yaml
# In values.yaml
volumes: []
volumeMounts: []

# In templates
{{- if .Values.component.volumes }}
{{- .Values.component.volumes | toYaml | nindent 8 }}
{{- end }}
```

### Image Tags

```yaml
image: "{{ .Values.component.image.repository }}:{{ .Values.component.image.tag | default .Chart.AppVersion }}"
```

## Chart Versioning

- Update `version` in `Chart.yaml` for each change
- Update `appVersion` when NetBird application version changes
- Releases are automated via GitHub Actions

## File Structure

```
netbird-helm/
├── charts/netbird/
│   ├── Chart.yaml          # Chart metadata
│   ├── values.yaml         # Default values
│   ├── README.md           # Chart docs
│   ├── templates/
│   │   ├── _helpers.tpl    # Reusable functions
│   │   ├── *-deployment.yaml
│   │   ├── *-service.yaml
│   │   └── *-ingress.yaml
│   └── examples/           # Example values
├── .github/workflows/
│   ├── validate.yml        # PR validation
│   └── release.yml         # Chart release
└── README.md
```

## Common Tasks

### Adding a New Component

1. Create templates: `<component>-deployment.yaml`, `<component>-service.yaml`
2. Add helpers in `_helpers.tpl`
3. Add defaults in `values.yaml`
4. Update `charts/netbird/README.md`

### Modifying Templates

1. Maintain backward compatibility
2. Add `@param` docs for new values
3. Run validation before committing
