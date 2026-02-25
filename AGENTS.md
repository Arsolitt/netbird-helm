# AGENTS.md - Guidelines for AI Coding Agents

This is a Helm chart repository for deploying [NetBird](https://github.com/netbirdio/netbird) VPN components to Kubernetes. Version 2.0+ uses a unified server image (`netbirdio/netbird-server`) combining management, signal, and relay services.

## Build/Lint/Test Commands

### Primary Validation

```bash
# Lint chart
helm lint charts/netbird
helm lint --quiet charts/netbird  # CI mode

# Full validation (same as CI)
helm dep up charts/netbird && \
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

### Package & Install

```bash
helm package charts/netbird                           # Package chart
helm install netbird charts/netbird --dry-run         # Test install
```

## Code Style Guidelines

### Helm Template Structure

- **File Naming**: kebab-case with component prefix and resource suffix (e.g., `server-deployment.yaml`, `server-cm.yaml`)
- **Enable Guards**: All component templates MUST start and end with:
  ```yaml
  {{- if .Values.<component>.enabled -}}
  ...
  {{- end -}}
  ```

### Template Formatting

- **Indentation**: 2 spaces throughout
- **nindent**: Use for multi-line blocks: `{{- include "netbird.server.labels" . | nindent 4 }}`
- **Whitespace**: Always use `{{-` and `-}}` to trim whitespace
- **with blocks**: Use `{{- with .Values.field }}` for optional nested values
- **range blocks**: Use `{{- range $key, $val := .Values.map }}` for map iteration

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

Template naming: `netbird.<component>.<purpose>` (e.g., `netbird.server.labels`, `netbird.server.selectorLabels`)

### Resource Naming

- **Resources**: `{{ include "netbird.fullname" . }}-<component>` (e.g., `netbird-server`)
- **Namespace**: Always use `{{ include "netbird.namespace" . }}` for cross-namespace support
- **Labels**: Kubernetes recommended labels (`app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `helm.sh/chart`)

### Values.yaml Structure

```yaml
## @section Component Name
## @param component.enabled Enable or disable this component.
component:
  enabled: true
  ## @param component.field Description.
  field: "value"
```

- Group by component (global, server, dashboard, metrics)
- Use `@section` and `@param` annotations for documentation
- Provide sensible defaults

### YAML Style

- Lists: `- item` with space after dash
- Empty values: `{}` for maps, `[]` for lists, `""` for strings
- Multi-line: Use `|` for block scalars
- Quote all string values in templates: `{{ .Values.field | quote }}`

### Conditional Blocks

```yaml
{{- if .Values.component.field }}
field:
  {{- toYaml .Values.component.field | nindent 2 }}
{{- end }}
```

### Environment Variables

Three patterns for deployments:

```yaml
# 1. Simple key-value (rendered as list of env vars)
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

Template pattern for env vars:
```yaml
{{- if or (.Values.component.env) (.Values.component.envRaw) (.Values.component.envFromSecret) }}
env:
{{- range $key, $val := .Values.component.env }}
  - name: {{ $key }}
    value: {{ $val | quote }}
{{- end }}
{{- if .Values.component.envRaw }}
  {{- with .Values.component.envRaw }}
    {{- toYaml . | nindent 10 }}
  {{- end }}
{{- end }}
{{- range $key, $val := .Values.component.envFromSecret }}
  - name: {{ $key }}
    valueFrom:
      secretKeyRef:
        name: {{ (split "/" $val)._0 }}
        key: {{ (split "/" $val)._1 }}
{{- end }}
{{- end }}
```

### ConfigMap Pattern (envsubst)

The server uses an init container with envsubst for secrets:

```yaml
# ConfigMap stores template with ${VAR} placeholders
data:
  config.yaml.tmpl: |
    authSecret: {{ .Values.server.config.authSecret | quote }}

# Init container substitutes variables
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

Include checksum for automatic rollout on config changes:

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
  {{- if .Values.component.volumes }}
  {{- .Values.component.volumes | toYaml | nindent 8 }}
  {{- end }}
```

## Chart Versioning

- Update `version` in `Chart.yaml` for each chart change
- Update `appVersion` when NetBird application version changes
- Releases are automated via GitHub Actions

## File Structure

```
netbird-helm/
├── charts/netbird/
│   ├── Chart.yaml              # Chart metadata
│   ├── values.yaml             # Default values with @param docs
│   ├── README.md               # Chart documentation
│   ├── templates/
│   │   ├── _helpers.tpl        # Reusable template functions
│   │   ├── server-*.yaml       # Server resources (deployment, cm, svc, ingress)
│   │   ├── dashboard-*.yaml    # Dashboard resources
│   │   └── service-monitor.yaml
│   └── examples/               # Example values files
├── .github/workflows/
│   ├── validate.yml            # PR validation (lint + kubeconform)
│   └── release.yml             # Chart release
└── AGENTS.md
```

## Common Tasks

### Adding a New Component

1. Create templates: `<component>-deployment.yaml`, `<component>-service.yaml`
2. Add helpers in `_helpers.tpl` (labels, selectorLabels, serviceAccountName)
3. Add defaults in `values.yaml` with `@param` annotations
4. Update `charts/netbird/README.md` (run `helm-docs` if available)

### Modifying Templates

1. Maintain backward compatibility
2. Add `@param` docs for new values
3. Run validation before committing: `helm lint charts/netbird && helm template x charts/netbird --include-crds | kubeconform -summary`
