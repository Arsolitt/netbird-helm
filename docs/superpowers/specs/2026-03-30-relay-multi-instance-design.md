# Relay Multi-Instance Design

## Problem

Currently the relay component is a single deployment. Production deployments need multiple relay instances across different nodes/regions, each with its own ingress, STUN service, environment variables, and scheduling constraints.

## Decision

Break the relay component into a list of instances. Each instance generates its own Deployment, Service, STUN Service, Ingress, and ServiceMonitor. No backward compatibility required — this is a major version bump.

## Approach

`range` over `relay.instances` in each template file. Helpers accept a dict (`root` + `instance`) for parameterized names and labels.

## Values Structure

```yaml
relay:
  # Shared settings across all instances
  image:
    repository: netbirdio/relay
    pullPolicy: IfNotPresent
    tag: ""
  imagePullSecrets: []
  replicaCount: 1
  serviceAccount:
    create: true
    annotations: {}
    name: ""
  podSecurityContext: {}
  securityContext: {}
  resources: {}
  gracefulShutdown: true

  # Per-instance settings
  instances:
    - name: us-east
      containerPort: 33080
      metrics:
        enabled: false
        port: 9090
      service:
        type: ClusterIP
        port: 33080
      stun:
        enabled: false
        ports: [53478]
        service:
          type: LoadBalancer
          externalTrafficPolicy: Local
      ingress:
        enabled: false
        className: ""
        annotations: {}
        hosts: []
        tls: []
      env: {}
      envRaw: []
      envFromSecret: {}
      nodeSelector: {}
      tolerations: []
      affinity: {}
      deploymentAnnotations: {}
      podAnnotations: {}
      volumeMounts: []
      volumes: []
      initContainers: []
```

`relay.enabled` is removed. Relay is active when `relay.instances` is non-empty.

**Shared settings** (level `relay`): image, replicaCount, resources, podSecurityContext, securityContext, imagePullSecrets, serviceAccount, gracefulShutdown.

**Per-instance settings** (level `relay.instances[n]`): env, envRaw, envFromSecret, ingress, stun, nodeSelector, tolerations, affinity, containerPort, metrics, service, deploymentAnnotations, podAnnotations, volumeMounts, volumes, initContainers.

Each instance requires a `name` field used in resource names.

## Resource Naming

Pattern: `{{ fullname }}-relay-<instance.name>`

- Deployment: `netbird-relay-us-east`
- Service: `netbird-relay-us-east`
- STUN Service: `netbird-relay-us-east-stun`
- Ingress: `netbird-relay-us-east`
- ServiceMonitor: `netbird-relay-us-east`

ServiceAccount: one shared `{{ fullname }}-relay` for all instances.

## Helpers (`_helpers.tpl`)

Helpers change to accept a dict with `root` and `instance`:

```yaml
{{- define "netbird.relay.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netbird.name" .root }}-relay-{{ .instance.name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: relay
{{- end -}}

{{- define "netbird.relay.labels" -}}
helm.sh/chart: {{ include "netbird.chart" .root }}
{{ include "netbird.relay.selectorLabels" . }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end -}}
```

`app.kubernetes.io/component: relay` is used for anti-affinity matching across instances.

## Anti-Affinity

Hard pod anti-affinity (required) prevents pods of different relay instances from landing on the same node. Pods of the same instance (replicas) can coexist on a node.

Default rule injected into each instance's deployment (unless `instance.affinity` is set by user):

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/component: relay
          matchExpressions:
            - key: app.kubernetes.io/name
              operator: NotIn
              values:
                - <current-instance-full-name>
        topologyKey: kubernetes.io/hostname
```

"Match relay pods whose name is NOT mine" — same-instance pods excluded, different-instance pods excluded from the node.

Users can override by setting `affinity` on an instance, which replaces the entire affinity block.

## Template Changes

### `relay-deployment.yaml`
- `range` over `relay.instances`, build `$context := dict "root" $ "instance" $instance`
- Shared values (image, replicaCount, resources, security contexts, gracefulShutdown) from `$.Values.relay`
- Per-instance values (containerPort, env, stun env vars, nodeSelector, tolerations, volumes, initContainers) from `$instance`
- Affinity: merge default anti-affinity with user-provided `$instance.affinity`
- STUN env vars (`NB_ENABLE_STUN`, `NB_STUN_PORTS`) conditionally injected when `$instance.stun.enabled`

### `relay-service.yaml`
- `range` over instances, standard Service with `$context`

### `relay-service-stun.yaml`
- `range` over instances, inner `if` on `$instance.stun.enabled`

### `relay-ingress.yaml`
- `range` over instances, inner `if` on `$instance.ingress.enabled`

### `relay-serviceaccount.yaml`
- Unchanged. Single shared ServiceAccount for all instances.

### `service-monitor.yaml`
- New relay block: `range` over instances, inner `if` on `$instance.metrics.enabled`
- Selects by specific instance's selectorLabels

## Validation (`00-validations.yaml`)

```yaml
{{- if .Values.relay.instances -}}
{{- if not (kindIs "slice" .Values.relay.instances) -}}
{{- fail "relay.instances must be a list." -}}
{{- end -}}
{{- range $i, $inst := .Values.relay.instances -}}
{{- if not $inst.name -}}
{{- fail (printf "relay.instances[%d] must have a 'name' field." $i) -}}
{{- end -}}
{{- end -}}
{{- end -}}
```

## Management Config

No automatic changes. Users continue to manually specify `Relay.Addresses` in management/server config, same as current behavior.

## Examples

Update all example values files to use the new structure with a single instance in `relay.instances`:

- `charts/netbird/examples/hybrid/values.yaml`
- `charts/netbird/examples/microservice/*/values.yaml`

## Version

Major version bump (no backward compatibility).
