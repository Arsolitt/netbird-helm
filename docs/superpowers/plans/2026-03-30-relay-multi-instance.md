# Relay Multi-Instance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace single relay deployment with a list of per-instance deployments, each with its own ingress, STUN service, env vars, selector, and tolerations, with hard anti-affinity between different instances.

**Architecture:** `range` over `relay.instances` in each template. Helpers accept a dict (`root` + `instance`) for parameterized names and labels. Shared settings (image, replicaCount, resources, security contexts) stay at `relay` level; per-instance settings (env, ingress, stun, nodeSelector, tolerations, affinity) move to each instance.

**Tech Stack:** Helm 3 templates, Go template functions, kubeconform for validation.

---

### Task 1: Update Chart.yaml — Major Version Bump

**Files:**
- Modify: `charts/netbird/Chart.yaml:6`

- [ ] **Step 1: Bump major version**

Change line 6 from `version: 2.3.2` to `version: 3.0.0`.

- [ ] **Step 2: Commit**

```bash
git add charts/netbird/Chart.yaml
git commit -m "chore: bump chart version to 3.0.0 for relay multi-instance"
```

---

### Task 2: Update values.yaml — Restructure Relay Section

**Files:**
- Modify: `charts/netbird/values.yaml:473-672`

- [ ] **Step 1: Replace the relay section**

Replace the entire relay section (lines 473-672, from `## @section NetBird Relay (Microservice)` through `  initContainers: []`) with the following:

```yaml
## @section NetBird Relay (Microservice)

relay:
  ## @param relay.replicaCount Number of relay pod replicas.
  ##
  replicaCount: 1

  image:
    ## @param relay.image.repository Docker image repository for the relay component.
    ##
    repository: netbirdio/relay

    ## @param relay.image.pullPolicy Docker image pull policy.
    ##
    pullPolicy: IfNotPresent

    ## @param relay.image.tag Docker image tag.
    ##
    tag: ""

  ## @param relay.imagePullSecrets Docker registry credentials for pulling the relay image.
  ##
  imagePullSecrets: []

  serviceAccount:
    ## @param relay.serviceAccount.create Whether to create a service account.
    ##
    create: true

    ## @param relay.serviceAccount.annotations Annotations for the service account.
    ##
    annotations: {}

    ## @param relay.serviceAccount.name Name of the service account to use.
    ##
    name: ""

  ## @param relay.podSecurityContext Security context for the relay pod(s).
  ##
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 2222
    runAsGroup: 2222
    fsGroup: 2222
    seccompProfile:
      type: RuntimeDefault

  ## @param relay.securityContext Security context for the relay container.
  ##
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL

  ## @param relay.resources Resource requests and limits for the relay pod.
  ##
  resources: {}

  ## @param relay.gracefulShutdown Add delay before pod shutdown.
  ##
  gracefulShutdown: true

  ## @param relay.lifecycle Lifecycle hooks for the relay pod.
  ##
  lifecycle: {}

  ## List of relay instances. Each instance gets its own Deployment, Service, STUN Service, and Ingress.
  ## Remove `relay.enabled` — relay is active when this list is non-empty.
  ##
  ## @param relay.instances List of relay instance configurations.
  ##
  instances: []
  #  - name: default
  #    containerPort: 33080
  #    metrics:
  #      enabled: false
  #      port: 9090
  #    service:
  #      type: ClusterIP
  #      port: 33080
  #      name: http
  #    stun:
  #      enabled: false
  #      ports:
  #        - 53478
  #      service:
  #        type: LoadBalancer
  #        externalTrafficPolicy: Local
  #    ingress:
  #      enabled: false
  #      className: ""
  #      annotations: {}
  #      hosts: []
  #      tls: []
  #    env: {}
  #    envRaw: []
  #    envFromSecret: {}
  #    nodeSelector: {}
  #    tolerations: []
  #    affinity: {}
  #    deploymentAnnotations: {}
  #    podAnnotations: {}
  #    livenessProbe:
  #      initialDelaySeconds: 5
  #      periodSeconds: 5
  #      tcpSocket:
  #        port: http
  #    readinessProbe:
  #      initialDelaySeconds: 5
  #      periodSeconds: 5
  #      tcpSocket:
  #        port: http
  #    volumeMounts: []
  #    volumes: []
  #    initContainers: []
```

- [ ] **Step 2: Commit**

```bash
git add charts/netbird/values.yaml
git commit -m "feat(relay): restructure values.yaml for multi-instance relay"
```

---

### Task 3: Update _helpers.tpl — Parameterize Relay Helpers

**Files:**
- Modify: `charts/netbird/templates/_helpers.tpl:172-201`

- [ ] **Step 1: Replace relay helper definitions**

Replace lines 172-201 (from `{{/* Relay selector labels */}}` through `{{- end }}`) with:

```yaml
{{/*
Relay selector labels (parameterized for per-instance)
*/}}
{{- define "netbird.relay.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netbird.name" .root }}-relay-{{ .instance.name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: relay
{{- end }}

{{/*
Relay labels (parameterized for per-instance)
*/}}
{{- define "netbird.relay.labels" -}}
helm.sh/chart: {{ include "netbird.chart" .root }}
{{ include "netbird.relay.selectorLabels" . }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end }}

{{/*
Create the name of the relay service account to use
*/}}
{{- define "netbird.relay.serviceAccountName" -}}
{{- if .Values.relay.serviceAccount.create }}
{{- default (printf "%s-relay" (include "netbird.fullname" .)) .Values.relay.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.relay.serviceAccount.name }}
{{- end }}
{{- end }}
```

Key changes:
- `selectorLabels` and `labels` now accept `.` as a dict with `.root` and `.instance` fields
- `selectorLabels` includes `app.kubernetes.io/component: relay` for anti-affinity
- Name pattern changes from `-relay` to `-relay-{{ .instance.name }}`
- `serviceAccountName` stays unchanged (uses plain `.` since it's shared)

- [ ] **Step 2: Commit**

```bash
git add charts/netbird/templates/_helpers.tpl
git commit -m "feat(relay): parameterize relay helpers for multi-instance"
```

---

### Task 4: Update 00-validations.yaml — Add Relay Instance Validation

**Files:**
- Modify: `charts/netbird/templates/00-validations.yaml`

- [ ] **Step 1: Add relay validation rules**

Replace the entire file with:

```yaml
{{- if and .Values.server.enabled .Values.management.enabled -}}
{{- fail "Cannot enable both server (unified mode) and management (microservice mode). Choose one deployment mode." -}}
{{- end -}}
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

- [ ] **Step 2: Commit**

```bash
git add charts/netbird/templates/00-validations.yaml
git commit -m "feat(relay): add validation for relay.instances"
```

---

### Task 5: Rewrite relay-deployment.yaml — Range Over Instances

**Files:**
- Modify: `charts/netbird/templates/relay-deployment.yaml`

- [ ] **Step 1: Replace the entire deployment template**

Replace the entire file with:

```yaml
{{- range $instance := .Values.relay.instances -}}
{{- $context := dict "root" $ "instance" $instance -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "netbird.fullname" $ }}-relay-{{ $instance.name }}
  namespace: {{ include "netbird.namespace" $ }}
  {{- with $instance.deploymentAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "netbird.relay.labels" $context | nindent 4 }}
spec:
  replicas: {{ $.Values.relay.replicaCount }}
  selector:
    matchLabels:
      {{- include "netbird.relay.selectorLabels" $context | nindent 6 }}
  template:
    metadata:
      {{- with $instance.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "netbird.relay.selectorLabels" $context | nindent 8 }}
    spec:
      {{- with $.Values.relay.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "netbird.relay.serviceAccountName" $ }}
      securityContext:
        {{- toYaml $.Values.relay.podSecurityContext | nindent 8 }}
      {{- with $instance.initContainers }}
      initContainers:
        {{- tpl (toYaml .) $ | nindent 6 }}
      {{- end }}
      containers:
        - name: {{ $.Chart.Name }}-relay-{{ $instance.name }}
          securityContext:
            {{- toYaml $.Values.relay.securityContext | nindent 12 }}
          image: "{{ $.Values.relay.image.repository }}:{{ $.Values.relay.image.tag | default $.Chart.AppVersion }}"
          imagePullPolicy: {{ $.Values.relay.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ $instance.containerPort }}
              protocol: TCP
            {{- if $instance.metrics.enabled }}
            - name: metrics
              containerPort: {{ $instance.metrics.port }}
              protocol: TCP
            {{- end }}
            {{- if $instance.stun.enabled }}
            {{- range $port := $instance.stun.ports }}
            - name: stun-{{ $port }}
              containerPort: {{ $port }}
              protocol: UDP
            {{- end }}
            {{- end }}
          {{- if $instance.livenessProbe }}
          livenessProbe:
            {{- toYaml $instance.livenessProbe | nindent 12 }}
          {{- end }}
          {{- if $instance.readinessProbe }}
          readinessProbe:
            {{- toYaml $instance.readinessProbe | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml $.Values.relay.resources | nindent 12 }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
          {{- if $instance.volumeMounts }}
          {{- $instance.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
          {{- if or $.Values.relay.gracefulShutdown $.Values.relay.lifecycle }}
          lifecycle:
            {{- if $.Values.relay.gracefulShutdown }}
            preStop:
              exec:
                command: ["sh", "-c", "echo Waiting 5 seconds to allow terminating current connections >/proc/1/fd/1; sleep 5"]
            {{- end }}
            {{- with $.Values.relay.lifecycle }}
            {{- if .postStart }}
            postStart:
              {{- toYaml .postStart | nindent 14 }}
            {{- end }}
            {{- end }}
          {{- end }}
          env:
          {{- if or ($instance.env) ($instance.envRaw) ($instance.envFromSecret) $instance.stun.enabled }}
          {{- range $key, $val := $instance.env }}
            - name: {{ $key }}
              value: {{ $val | quote }}
          {{- end }}
          {{- if $instance.envRaw }}
            {{- with $instance.envRaw }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
          {{- range $key, $val := $instance.envFromSecret }}
            - name: {{ $key }}
              valueFrom:
                secretKeyRef:
                  name: {{ (splitList "/" $val)._0 }}
                  key: {{ (splitList "/" $val)._1 }}
          {{- end }}
          {{- if $instance.stun.enabled }}
            - name: NB_ENABLE_STUN
              value: "true"
            - name: NB_STUN_PORTS
              value: {{ join "," $instance.stun.ports | quote }}
          {{- end }}
          {{- end }}
      volumes:
        - name: tmp
          emptyDir:
            medium: Memory
        {{- if $instance.volumes }}
        {{- $instance.volumes | toYaml | nindent 8 }}
        {{- end }}
      {{- with $instance.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      affinity:
        {{- if $instance.affinity }}
        {{- toYaml $instance.affinity | nindent 8 }}
        {{- else }}
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app.kubernetes.io/component: relay
                matchExpressions:
                  - key: app.kubernetes.io/name
                    operator: NotIn
                    values:
                      - {{ include "netbird.name" $ }}-relay-{{ $instance.name }}
              topologyKey: kubernetes.io/hostname
        {{- end }}
      {{- with $instance.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}
```

Key changes:
- `range` over `relay.instances` instead of `if .Values.relay.enabled`
- `$context` dict passed to helpers
- Shared values from `$.Values.relay`, per-instance from `$instance`
- Default hard pod anti-affinity when `$instance.affinity` is not set
- `splitList` instead of `split` for envFromSecret (Helm 3 compatibility)

- [ ] **Step 2: Commit**

```bash
git add charts/netbird/templates/relay-deployment.yaml
git commit -m "feat(relay): rewrite deployment template for multi-instance"
```

---

### Task 6: Rewrite relay-service.yaml — Range Over Instances

**Files:**
- Modify: `charts/netbird/templates/relay-service.yaml`

- [ ] **Step 1: Replace the entire service template**

Replace the entire file with:

```yaml
{{- range $instance := .Values.relay.instances -}}
{{- $context := dict "root" $ "instance" $instance -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "netbird.fullname" $ }}-relay-{{ $instance.name }}
  namespace: {{ include "netbird.namespace" $ }}
  labels:
    {{- include "netbird.relay.labels" $context | nindent 4 }}
spec:
  type: {{ $instance.service.type }}
  ports:
    - port: {{ $instance.service.port }}
      targetPort: {{ $instance.service.name | default "http" }}
      protocol: TCP
      name: {{ $instance.service.name | default "http" }}
    {{- if $instance.metrics.enabled }}
    - port: {{ $instance.metrics.port }}
      targetPort: metrics
      protocol: TCP
      name: metrics
    {{- end }}
  selector:
    {{- include "netbird.relay.selectorLabels" $context | nindent 4 }}
{{- end -}}
```

- [ ] **Step 2: Commit**

```bash
git add charts/netbird/templates/relay-service.yaml
git commit -m "feat(relay): rewrite service template for multi-instance"
```

---

### Task 7: Rewrite relay-service-stun.yaml — Range Over Instances

**Files:**
- Modify: `charts/netbird/templates/relay-service-stun.yaml`

- [ ] **Step 1: Replace the entire STUN service template**

Replace the entire file with:

```yaml
{{- range $instance := .Values.relay.instances -}}
{{- if $instance.stun.enabled -}}
{{- $context := dict "root" $ "instance" $instance -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "netbird.fullname" $ }}-relay-{{ $instance.name }}-stun
  namespace: {{ include "netbird.namespace" $ }}
  labels:
    {{- include "netbird.relay.labels" $context | nindent 4 }}
spec:
  type: {{ $instance.stun.service.type }}
  {{- if and (eq $instance.stun.service.type "LoadBalancer") $instance.stun.service.externalTrafficPolicy }}
  externalTrafficPolicy: {{ $instance.stun.service.externalTrafficPolicy }}
  {{- end }}
  ports:
    {{- range $port := $instance.stun.ports }}
    - port: {{ $port }}
      targetPort: {{ $port }}
      protocol: UDP
      name: stun-{{ $port }}
    {{- end }}
  selector:
    {{- include "netbird.relay.selectorLabels" $context | nindent 4 }}
{{- end -}}
{{- end -}}
```

- [ ] **Step 2: Commit**

```bash
git add charts/netbird/templates/relay-service-stun.yaml
git commit -m "feat(relay): rewrite STUN service template for multi-instance"
```

---

### Task 8: Rewrite relay-ingress.yaml — Range Over Instances

**Files:**
- Modify: `charts/netbird/templates/relay-ingress.yaml`

- [ ] **Step 1: Replace the entire ingress template**

Replace the entire file with:

```yaml
{{- range $instance := .Values.relay.instances -}}
{{- if $instance.ingress.enabled -}}
{{- $context := dict "root" $ "instance" $instance -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "netbird.fullname" $ }}-relay-{{ $instance.name }}
  namespace: {{ include "netbird.namespace" $ }}
  labels:
    {{- include "netbird.relay.labels" $context | nindent 4 }}
  {{- with $instance.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if $instance.ingress.className }}
  ingressClassName: {{ $instance.ingress.className | quote }}
  {{- end }}
  {{- if $instance.ingress.tls }}
  tls:
    {{- toYaml $instance.ingress.tls | nindent 4 }}
  {{- end }}
  rules:
    {{- range $instance.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "netbird.fullname" $ }}-relay-{{ $instance.name }}
                port:
                  number: {{ $instance.service.port }}
          {{- end }}
    {{- end }}
{{- end -}}
{{- end -}}
```

- [ ] **Step 2: Commit**

```bash
git add charts/netbird/templates/relay-ingress.yaml
git commit -m "feat(relay): rewrite ingress template for multi-instance"
```

---

### Task 9: Update relay-serviceaccount.yaml — Change Enable Guard

**Files:**
- Modify: `charts/netbird/templates/relay-serviceaccount.yaml`

- [ ] **Step 1: Replace the entire serviceaccount template**

Replace the entire file with:

```yaml
{{- if .Values.relay.instances -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "netbird.relay.serviceAccountName" . }}
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.relay.labels" (dict "root" . "instance" (index .Values.relay.instances 0)) | nindent 4 }}
  {{- with .Values.relay.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
```

Note: The labels use the first instance for the SA labels (SA is shared). This is a cosmetic choice — SA doesn't need per-instance labels.

- [ ] **Step 2: Commit**

```bash
git add charts/netbird/templates/relay-serviceaccount.yaml
git commit -m "feat(relay): update serviceaccount template for multi-instance"
```

---

### Task 10: Update service-monitor.yaml — Add Relay ServiceMonitor Block

**Files:**
- Modify: `charts/netbird/templates/service-monitor.yaml`

- [ ] **Step 1: Append relay ServiceMonitor block after the server block**

Add the following after the existing server ServiceMonitor block (after line 39 `{{- end -}}`):

```yaml

{{- range $instance := .Values.relay.instances -}}
{{- if and $instance.metrics.enabled $.Values.metrics.serviceMonitor.enabled -}}
{{- $context := dict "root" $ "instance" $instance -}}
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "netbird.fullname" $ }}-relay-{{ $instance.name }}
  namespace: {{ $.Values.metrics.serviceMonitor.namespace | default (include "netbird.namespace" $) }}
  labels:
    {{- include "netbird.relay.labels" $context | nindent 4 }}
    {{- with $.Values.metrics.serviceMonitor.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $.Values.metrics.serviceMonitor.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  endpoints:
    - port: metrics
      {{- with $.Values.metrics.serviceMonitor.interval }}
      interval: {{ . }}
      {{- end }}
      {{- with $.Values.metrics.serviceMonitor.scrapeTimeout }}
      scrapeTimeout: {{ . }}
      {{- end }}
      {{- with $.Values.metrics.serviceMonitor.metricRelabelings }}
      metricRelabelings:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $.Values.metrics.serviceMonitor.relabelings }}
      relabelings:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      path: /metrics
  namespaceSelector:
    matchNames:
      - {{ include "netbird.namespace" $ }}
  selector:
    matchLabels:
      {{- include "netbird.relay.selectorLabels" $context | nindent 6 }}
{{- end -}}
{{- end -}}
```

- [ ] **Step 2: Commit**

```bash
git add charts/netbird/templates/service-monitor.yaml
git commit -m "feat(relay): add per-instance ServiceMonitor for relay"
```

---

### Task 11: Update Example Values Files

**Files:**
- Modify: `charts/netbird/examples/hybrid/values.yaml`
- Modify: `charts/netbird/examples/microservice/traefik-ingress/authentik/values.yaml`
- Modify: `charts/netbird/examples/microservice/nginx-ingress/authentik/values.yaml`
- Modify: `charts/netbird/examples/microservice/nginx-ingress/okta/values.yaml`
- Modify: `charts/netbird/examples/microservice/nginx-ingress/google/values.yaml`
- Modify: `charts/netbird/examples/microservice/nginx-ingress/auth0/values.yaml`

In every file, replace the `relay:` block. The pattern is the same: remove `enabled: true`, wrap everything under `instances:` with a single `name: default` entry.

- [ ] **Step 1: Update hybrid/values.yaml**

Replace the relay section (from `relay:` through the `envFromSecret` block) with:

```yaml
relay:
  instances:
    - name: default
      stun:
        enabled: true
        ports:
          - 3478
        service:
          type: LoadBalancer
          externalTrafficPolicy: Local
      ingress:
        enabled: true
        className: nginx
        hosts:
          - host: netbird.example.com
            paths:
              - path: /relay
                pathType: ImplementationSpecific
        tls:
          - secretName: wildcard-example-com-tls
            hosts:
              - netbird.example.com
      env:
        NB_LOG_LEVEL: info
        NB_LISTEN_ADDRESS: ":33080"
        NB_EXPOSED_ADDRESS: rels://netbird.example.com:443/relay
      envFromSecret:
        NB_AUTH_SECRET: netbird/relayPassword
```

- [ ] **Step 2: Update microservice/traefik-ingress/authentik/values.yaml**

Replace the relay section with:

```yaml
relay:
  instances:
    - name: default
      stun:
        enabled: true
        ports:
          - 53478
        service:
          type: LoadBalancer
          externalTrafficPolicy: Local
      ingress:
        enabled: true
        className: traefik
        annotations:
          traefik.ingress.kubernetes.io/router.entrypoints: websecure
          traefik.ingress.kubernetes.io/router.tls: "true"
        hosts:
          - host: netbird.example.com
            paths:
              - path: /relay
                pathType: ImplementationSpecific
        tls:
          - secretName: wildcard.example.com-tls
            hosts:
              - netbird.example.com
      env:
        NB_LOG_LEVEL: info
        NB_LISTEN_ADDRESS: ":33080"
        NB_EXPOSED_ADDRESS: rels://netbird.example.com:443/relay
      envFromSecret:
        NB_AUTH_SECRET: netbird/relayPassword
```

- [ ] **Step 3: Update microservice/nginx-ingress/authentik/values.yaml**

Replace the relay section with:

```yaml
relay:
  instances:
    - name: default
      stun:
        enabled: true
        ports:
          - 53478
        service:
          type: LoadBalancer
          externalTrafficPolicy: Local
      ingress:
        enabled: true
        className: nginx
        annotations:
        hosts:
          - host: netbird.example.com
            paths:
              - path: /relay
                pathType: ImplementationSpecific
        tls:
          - secretName: wildcard.example.com-tls
            hosts:
              - netbird.example.com
      env:
        NB_LOG_LEVEL: info
        NB_LISTEN_ADDRESS: ":33080"
        NB_EXPOSED_ADDRESS: rels://netbird.example.com:443/relay
      envFromSecret:
        NB_AUTH_SECRET: netbird/relayPassword
```

- [ ] **Step 4: Update microservice/nginx-ingress/okta/values.yaml**

Same relay block as authentik nginx (Step 3).

- [ ] **Step 5: Update microservice/nginx-ingress/google/values.yaml**

Same relay block as authentik nginx (Step 3).

- [ ] **Step 6: Update microservice/nginx-ingress/auth0/values.yaml**

Same relay block as authentik nginx (Step 3).

- [ ] **Step 7: Commit**

```bash
git add charts/netbird/examples/
git commit -m "feat(relay): update example values for multi-instance relay"
```

---

### Task 12: Validate

- [ ] **Step 1: Run helm lint**

```bash
helm lint charts/netbird
```

Expected: No errors.

- [ ] **Step 2: Template with an example that uses relay**

```bash
helm template x charts/netbird -f charts/netbird/examples/hybrid/values.yaml
```

Expected: Valid YAML with resources named `netbird-relay-default`, `netbird-relay-default-stun`, `netbird-relay` (serviceaccount).

- [ ] **Step 3: Template with multiple relay instances**

Create a temporary values file with 2 relay instances and template:

```bash
cat > /tmp/multi-relay-values.yaml << 'EOF'
fullnameOverride: netbird
server:
  enabled: false
relay:
  instances:
    - name: us-east
      containerPort: 33080
      stun:
        enabled: true
        ports: [53478]
        service:
          type: LoadBalancer
      env:
        NB_EXPOSED_ADDRESS: rels://us.example.com:443/relay
    - name: eu-west
      containerPort: 33080
      stun:
        enabled: true
        ports: [53478]
        service:
          type: LoadBalancer
      env:
        NB_EXPOSED_ADDRESS: rels://eu.example.com:443/relay
EOF
helm template x charts/netbird -f /tmp/multi-relay-values.yaml > /tmp/multi-relay-output.yaml
```

Expected: Two deployments (`netbird-relay-us-east`, `netbird-relay-eu-west`), each with hard anti-affinity excluding the other instance's name.

- [ ] **Step 4: Run kubeconform**

```bash
helm dep up charts/netbird && \
  helm template x charts/netbird -f charts/netbird/examples/hybrid/values.yaml --include-crds > helm_output.yaml && \
  cat helm_output.yaml | kubeconform -summary -strict -ignore-missing-schemas -kubernetes-version=1.30.0 -cache /tmp
```

Expected: No validation errors.

- [ ] **Step 5: Verify anti-affinity in output**

```bash
grep -A 15 "podAntiAffinity" /tmp/multi-relay-output.yaml
```

Expected: Both deployments have `requiredDuringSchedulingIgnoredDuringExecution` with `NotIn` matching the other instance's name.

- [ ] **Step 6: Cleanup temp files**

```bash
rm -f /tmp/multi-relay-values.yaml /tmp/multi-relay-output.yaml helm_output.yaml
```

- [ ] **Step 7: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: validation fixes for relay multi-instance"
```

(Only if fixes were needed. Skip if Step 1-5 all passed cleanly.)
