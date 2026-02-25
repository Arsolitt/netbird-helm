# Microservice Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add microservice deployment mode to the NetBird Helm chart with management, signal, and relay components alongside the existing unified server mode.

**Architecture:** Enable-flag based mode selection. Components: management (JSON configmap with `{{ .VAR }}`), signal (gRPC), relay (HTTP + optional embedded STUN with UDP service). Only server+management conflict. Dashboard shared.

**Tech Stack:** Helm 3, Kubernetes 1.30+, Go templates

---

## Task 1: Add Validation Helper

**Files:**
- Modify: `charts/netbird/templates/_helpers.tpl`

**Step 1: Add validation helper at end of file**

Add after the `netbird.namespace` definition:

```yaml
{{/*
Validate that server and management are not both enabled.
*/}}
{{- if and .Values.server.enabled .Values.management.enabled -}}
{{- fail "Cannot enable both server (unified mode) and management (microservice mode). Choose one deployment mode." -}}
{{- end -}}
```

**Step 2: Run validation to verify helper works**

Run: `helm template x charts/netbird 2>&1 | head -5`
Expected: No error (management defaults to disabled)

**Step 3: Test conflict detection**

Run: `helm template x charts/netbird --set server.enabled=true --set management.enabled=true 2>&1`
Expected: Error message about conflicting modes

**Step 4: Commit**

```bash
git add charts/netbird/templates/_helpers.tpl
git commit -m "feat: add validation for server/management conflict"
```

---

## Task 2: Add Management Helpers

**Files:**
- Modify: `charts/netbird/templates/_helpers.tpl`

**Step 1: Add management helper functions**

Add after the validation helper:

```yaml
{{/*
Management selector labels
*/}}
{{- define "netbird.management.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netbird.name" . }}-management
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Management labels
*/}}
{{- define "netbird.management.labels" -}}
helm.sh/chart: {{ include "netbird.chart" . }}
{{ include "netbird.management.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Create the name of the management service account to use
*/}}
{{- define "netbird.management.serviceAccountName" -}}
{{- if .Values.management.serviceAccount.create }}
{{- default (printf "%s-management" (include "netbird.fullname" .)) .Values.management.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.management.serviceAccount.name }}
{{- end }}
{{- end }}
```

**Step 2: Verify template parses**

Run: `helm lint charts/netbird`
Expected: No errors

**Step 3: Commit**

```bash
git add charts/netbird/templates/_helpers.tpl
git commit -m "feat: add management helper functions"
```

---

## Task 3: Add Signal Helpers

**Files:**
- Modify: `charts/netbird/templates/_helpers.tpl`

**Step 1: Add signal helper functions**

Add after management helpers:

```yaml
{{/*
Signal selector labels
*/}}
{{- define "netbird.signal.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netbird.name" . }}-signal
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Signal labels
*/}}
{{- define "netbird.signal.labels" -}}
helm.sh/chart: {{ include "netbird.chart" . }}
{{ include "netbird.signal.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Create the name of the signal service account to use
*/}}
{{- define "netbird.signal.serviceAccountName" -}}
{{- if .Values.signal.serviceAccount.create }}
{{- default (printf "%s-signal" (include "netbird.fullname" .)) .Values.signal.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.signal.serviceAccount.name }}
{{- end }}
{{- end }}
```

**Step 2: Verify template parses**

Run: `helm lint charts/netbird`
Expected: No errors

**Step 3: Commit**

```bash
git add charts/netbird/templates/_helpers.tpl
git commit -m "feat: add signal helper functions"
```

---

## Task 4: Add Relay Helpers

**Files:**
- Modify: `charts/netbird/templates/_helpers.tpl`

**Step 1: Add relay helper functions**

Add after signal helpers:

```yaml
{{/*
Relay selector labels
*/}}
{{- define "netbird.relay.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netbird.name" . }}-relay
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Relay labels
*/}}
{{- define "netbird.relay.labels" -}}
helm.sh/chart: {{ include "netbird.chart" . }}
{{ include "netbird.relay.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
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

**Step 2: Verify template parses**

Run: `helm lint charts/netbird`
Expected: No errors

**Step 3: Commit**

```bash
git add charts/netbird/templates/_helpers.tpl
git commit -m "feat: add relay helper functions"
```

---

## Task 5: Add Management Values

**Files:**
- Modify: `charts/netbird/values.yaml`

**Step 1: Add management section after global section**

Add after the `fullnameOverride` section (around line 14), before `## @section NetBird Server`:

```yaml
## @section NetBird Management (Microservice)

management:
  ## @param management.enabled Enable or disable NetBird management component.
  ##
  enabled: false

  ## @param management.configmap JSON configuration with {{ .VAR }} placeholders.
  ##
  configmap: |-
    {}

  ## @param management.replicaCount Number of management pod replicas.
  ##
  replicaCount: 1

  ## @param management.strategy Deployment strategy for the management component.
  ##
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%

  image:
    ## @param management.image.repository Docker image repository for the management component.
    ##
    repository: netbirdio/management

    ## @param management.image.pullPolicy Docker image pull policy.
    ##
    pullPolicy: IfNotPresent

    ## @param management.image.tag Docker image tag. Overrides the default tag.
    ##
    tag: ""

  ## @param management.imagePullSecrets Docker registry credentials for pulling the management image.
  ##
  imagePullSecrets: []

  serviceAccount:
    ## @param management.serviceAccount.create Whether to create a service account.
    ##
    create: true

    ## @param management.serviceAccount.annotations Annotations for the service account.
    ##
    annotations: {}

    ## @param management.serviceAccount.name Name of the service account to use.
    ##
    name: ""

  ## @param management.deploymentAnnotations Annotations for the management deployment.
  ##
  deploymentAnnotations: {}

  ## @param management.podAnnotations Annotations for the management pod(s).
  ##
  podAnnotations: {}

  ## @param management.podSecurityContext Security context for the management pod(s).
  ##
  podSecurityContext: {}

  ## @param management.securityContext Security context for the management container.
  ##
  securityContext: {}

  ## @param management.containerPort Container port for the management HTTP service.
  ##
  containerPort: 80

  ## @param management.grpcContainerPort Container port for the management gRPC service.
  ##
  grpcContainerPort: 33073

  metrics:
    ## @param management.metrics.enabled Enable metrics endpoint.
    ##
    enabled: false

    ## @param management.metrics.port Metrics port.
    ##
    port: 9090

  service:
    ## @param management.service.type Service type for the management HTTP service.
    ##
    type: ClusterIP

    ## @param management.service.port Port for the management HTTP service.
    ##
    port: 80

    ## @param management.service.name Name for the management HTTP service.
    ##
    name: http

  serviceGrpc:
    ## @param management.serviceGrpc.type Service type for the management gRPC service.
    ##
    type: ClusterIP

    ## @param management.serviceGrpc.port Port for the management gRPC service.
    ##
    port: 33073

    ## @param management.serviceGrpc.name Name for the management gRPC service.
    ##
    name: grpc

  ## @param management.useBackwardsGrpcService Use backwards-compatible gRPC service.
  ##
  useBackwardsGrpcService: false

  ingress:
    ## @param management.ingress.enabled Enable or disable ingress for HTTP paths.
    ##
    enabled: false

    ## @param management.ingress.className Ingress class name.
    ##
    className: ""

    ## @param management.ingress.annotations Annotations for the ingress resource.
    ##
    annotations: {}

    hosts:
      - host: netbird.example.com
        paths:
          - path: /api
            pathType: ImplementationSpecific

    ## @param management.ingress.tls TLS settings for the ingress.
    ##
    tls: []

  ingressGrpc:
    ## @param management.ingressGrpc.enabled Enable or disable ingress for gRPC paths.
    ##
    enabled: false

    ## @param management.ingressGrpc.className Ingress class name for gRPC.
    ##
    className: ""

    ## @param management.ingressGrpc.annotations Annotations for the gRPC ingress resource.
    ##
    annotations: {}

    hosts:
      - host: netbird.example.com
        paths:
          - path: /management.ManagementService/
            pathType: ImplementationSpecific

    ## @param management.ingressGrpc.tls TLS settings for gRPC ingress.
    ##
    tls: []

  ## @param management.resources Resource requests and limits for the management pod.
  ##
  resources: {}

  ## @param management.nodeSelector Node selector for scheduling the management pod.
  ##
  nodeSelector: {}

  ## @param management.tolerations Tolerations for scheduling the management pod.
  ##
  tolerations: []

  ## @param management.affinity Affinity rules for scheduling the management pod.
  ##
  affinity: {}

  persistentVolume:
    ## @param management.persistentVolume.enabled Enable or disable persistent volume.
    ##
    enabled: true

    ## @param management.persistentVolume.accessModes Access modes for the persistent volume.
    ##
    accessModes:
      - ReadWriteOnce

    ## @param management.persistentVolume.size Size of the persistent volume.
    ##
    size: 10Mi

    ## @param management.persistentVolume.storageClass Storage Class of the persistent volume.
    ##
    storageClass: null

    ## @param management.persistentVolume.existingPVName Name of an existing persistent volume.
    ##
    existingPVName: ""

    ## @param management.persistentVolume.annotations Annotations for the PVC.
    ##
    annotations: {}

  ## @param management.livenessProbe Liveness probe for the management component.
  ##
  livenessProbe:
    failureThreshold: 3
    initialDelaySeconds: 15
    periodSeconds: 10
    timeoutSeconds: 3
    tcpSocket:
      port: http

  ## @param management.readinessProbe Readiness probe for the management component.
  ##
  readinessProbe:
    failureThreshold: 3
    initialDelaySeconds: 15
    periodSeconds: 10
    timeoutSeconds: 3
    tcpSocket:
      port: http

  ## @param management.env Environment variables for the management pod.
  ##
  env: {}

  ## @param management.envRaw Raw environment variables for the management pod.
  ##
  envRaw: []

  ## @param management.envFromSecret Environment variables from secrets.
  ## Format: ENV_VAR: secretName/secretKey
  ##
  envFromSecret: {}

  ## @param management.volumeMounts Volume mounts for the management pod.
  ##
  volumeMounts: []

  ## @param management.volumes Volumes for the management pod.
  ##
  volumes: []

  ## @param management.gracefulShutdown Add delay before pod shutdown.
  ##
  gracefulShutdown: true

  ## @param management.initContainers Init containers for the management pod.
  ##
  initContainers: []
```

**Step 2: Verify values.yaml syntax**

Run: `helm lint charts/netbird`
Expected: No errors

**Step 3: Commit**

```bash
git add charts/netbird/values.yaml
git commit -m "feat: add management values configuration"
```

---

## Task 6: Add Signal Values

**Files:**
- Modify: `charts/netbird/values.yaml`

**Step 1: Add signal section after management section**

Add after the management section:

```yaml
## @section NetBird Signal (Microservice)

signal:
  ## @param signal.enabled Enable or disable NetBird signal component.
  ##
  enabled: false

  ## @param signal.logLevel Log level for the signal component.
  ##
  logLevel: info

  ## @param signal.replicaCount Number of signal pod replicas.
  ##
  replicaCount: 1

  image:
    ## @param signal.image.repository Docker image repository for the signal component.
    ##
    repository: netbirdio/signal

    ## @param signal.image.pullPolicy Docker image pull policy.
    ##
    pullPolicy: IfNotPresent

    ## @param signal.image.tag Docker image tag.
    ##
    tag: ""

  ## @param signal.imagePullSecrets Docker registry credentials for pulling the signal image.
  ##
  imagePullSecrets: []

  serviceAccount:
    ## @param signal.serviceAccount.create Whether to create a service account.
    ##
    create: true

    ## @param signal.serviceAccount.annotations Annotations for the service account.
    ##
    annotations: {}

    ## @param signal.serviceAccount.name Name of the service account to use.
    ##
    name: ""

  ## @param signal.deploymentAnnotations Annotations for the signal deployment.
  ##
  deploymentAnnotations: {}

  ## @param signal.podAnnotations Annotations for the signal pod(s).
  ##
  podAnnotations: {}

  ## @param signal.podSecurityContext Security context for the signal pod(s).
  ##
  podSecurityContext: {}

  ## @param signal.securityContext Security context for the signal container.
  ##
  securityContext: {}

  ## @param signal.containerPort Container port for the signal service.
  ##
  containerPort: 80

  metrics:
    ## @param signal.metrics.enabled Enable metrics endpoint.
    ##
    enabled: false

    ## @param signal.metrics.port Metrics port.
    ##
    port: 9090

  service:
    ## @param signal.service.type Service type for the signal service.
    ##
    type: ClusterIP

    ## @param signal.service.port Port for the signal service.
    ##
    port: 80

    ## @param signal.service.name Name for the signal service.
    ##
    name: grpc

  ingress:
    ## @param signal.ingress.enabled Enable or disable ingress for the signal component.
    ##
    enabled: false

    ## @param signal.ingress.className Ingress class name.
    ##
    className: ""

    ## @param signal.ingress.annotations Annotations for the signal ingress resource.
    ##
    annotations: {}

    hosts:
      - host: netbird.example.com
        paths:
          - path: /signalexchange.SignalExchange/
            pathType: ImplementationSpecific

    ## @param signal.ingress.tls TLS settings for the signal ingress.
    ##
    tls: []

  ## @param signal.resources Resource requests and limits for the signal pod.
  ##
  resources: {}

  ## @param signal.nodeSelector Node selector for scheduling the signal pod.
  ##
  nodeSelector: {}

  ## @param signal.tolerations Tolerations for scheduling the signal pod.
  ##
  tolerations: []

  ## @param signal.affinity Affinity rules for scheduling the signal pod.
  ##
  affinity: {}

  ## @param signal.livenessProbe Liveness probe for the signal component.
  ##
  livenessProbe:
    initialDelaySeconds: 5
    periodSeconds: 5
    tcpSocket:
      port: grpc

  ## @param signal.readinessProbe Readiness probe for the signal component.
  ##
  readinessProbe:
    initialDelaySeconds: 5
    periodSeconds: 5
    tcpSocket:
      port: grpc

  ## @param signal.env Environment variables for the signal pod.
  ##
  env: {}

  ## @param signal.envRaw Raw environment variables for the signal pod.
  ##
  envRaw: []

  ## @param signal.envFromSecret Environment variables from secrets.
  ##
  envFromSecret: {}

  ## @param signal.volumeMounts Volume mounts for the signal pod.
  ##
  volumeMounts: []

  ## @param signal.volumes Volumes for the signal pod.
  ##
  volumes: []

  ## @param signal.gracefulShutdown Add delay before pod shutdown.
  ##
  gracefulShutdown: true

  ## @param signal.initContainers Init containers for the signal pod.
  ##
  initContainers: []
```

**Step 2: Verify values.yaml syntax**

Run: `helm lint charts/netbird`
Expected: No errors

**Step 3: Commit**

```bash
git add charts/netbird/values.yaml
git commit -m "feat: add signal values configuration"
```

---

## Task 7: Add Relay Values with STUN

**Files:**
- Modify: `charts/netbird/values.yaml`

**Step 1: Add relay section after signal section**

Add after the signal section:

```yaml
## @section NetBird Relay (Microservice)

relay:
  ## @param relay.enabled Enable or disable NetBird relay component.
  ##
  enabled: false

  ## @param relay.logLevel Log level for the relay component.
  ##
  logLevel: info

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

  ## @param relay.deploymentAnnotations Annotations for the relay deployment.
  ##
  deploymentAnnotations: {}

  ## @param relay.podAnnotations Annotations for the relay pod(s).
  ##
  podAnnotations: {}

  ## @param relay.podSecurityContext Security context for the relay pod(s).
  ##
  podSecurityContext: {}

  ## @param relay.securityContext Security context for the relay container.
  ##
  securityContext: {}

  ## @param relay.containerPort Container port for the relay service.
  ##
  containerPort: 33080

  metrics:
    ## @param relay.metrics.enabled Enable metrics endpoint.
    ##
    enabled: false

    ## @param relay.metrics.port Metrics port.
    ##
    port: 9090

  service:
    ## @param relay.service.type Service type for the relay service.
    ##
    type: ClusterIP

    ## @param relay.service.port Port for the relay service.
    ##
    port: 33080

    ## @param relay.service.name Name for the relay service.
    ##
    name: http

  ## Embedded STUN server configuration
  stun:
    ## @param relay.stun.enabled Enable embedded STUN server.
    ##
    enabled: false

    ## @param relay.stun.ports STUN server ports (can be multiple).
    ##
    ports:
      - 3478

    service:
      ## @param relay.stun.service.type Service type for STUN (LoadBalancer or ClusterIP).
      ##
      type: LoadBalancer

      ## @param relay.stun.service.externalTrafficPolicy External traffic policy.
      ##
      externalTrafficPolicy: Local

  ingress:
    ## @param relay.ingress.enabled Enable or disable ingress for the relay component.
    ##
    enabled: false

    ## @param relay.ingress.className Ingress class name.
    ##
    className: ""

    ## @param relay.ingress.annotations Annotations for the relay ingress resource.
    ##
    annotations: {}

    hosts:
      - host: netbird.example.com
        paths:
          - path: /relay
            pathType: ImplementationSpecific

    ## @param relay.ingress.tls TLS settings for the relay ingress.
    ##
    tls: []

  ## @param relay.resources Resource requests and limits for the relay pod.
  ##
  resources: {}

  ## @param relay.nodeSelector Node selector for scheduling the relay pod.
  ##
  nodeSelector: {}

  ## @param relay.tolerations Tolerations for scheduling the relay pod.
  ##
  tolerations: []

  ## @param relay.affinity Affinity rules for scheduling the relay pod.
  ##
  affinity: {}

  ## @param relay.livenessProbe Liveness probe for the relay component.
  ##
  livenessProbe:
    initialDelaySeconds: 5
    periodSeconds: 5
    tcpSocket:
      port: http

  ## @param relay.readinessProbe Readiness probe for the relay component.
  ##
  readinessProbe:
    initialDelaySeconds: 5
    periodSeconds: 5
    tcpSocket:
      port: http

  ## @param relay.env Environment variables for the relay pod.
  ##
  env: {}

  ## @param relay.envRaw Raw environment variables for the relay pod.
  ##
  envRaw: []

  ## @param relay.envFromSecret Environment variables from secrets.
  ##
  envFromSecret: {}

  ## @param relay.volumeMounts Volume mounts for the relay pod.
  ##
  volumeMounts: []

  ## @param relay.volumes Volumes for the relay pod.
  ##
  volumes: []

  ## @param relay.gracefulShutdown Add delay before pod shutdown.
  ##
  gracefulShutdown: true

  ## @param relay.initContainers Init containers for the relay pod.
  ##
  initContainers: []
```

**Step 2: Verify values.yaml syntax**

Run: `helm lint charts/netbird`
Expected: No errors

**Step 3: Commit**

```bash
git add charts/netbird/values.yaml
git commit -m "feat: add relay values configuration with STUN support"
```

---

## Task 8: Create Management ServiceAccount Template

**Files:**
- Create: `charts/netbird/templates/management-serviceaccount.yaml`

**Step 1: Create the template file**

```yaml
{{- if .Values.management.enabled -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "netbird.management.serviceAccountName" . }}
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.management.labels" . | nindent 4 }}
  {{- with .Values.management.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set management.enabled=true | grep -A10 "kind: ServiceAccount" | head -15`
Expected: ServiceAccount resource for management

**Step 3: Commit**

```bash
git add charts/netbird/templates/management-serviceaccount.yaml
git commit -m "feat: add management serviceaccount template"
```

---

## Task 9: Create Management ConfigMap Template

**Files:**
- Create: `charts/netbird/templates/management-cm.yaml`

**Step 1: Create the template file**

```yaml
{{- if .Values.management.enabled -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "netbird.fullname" . }}-management
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.management.labels" . | nindent 4 }}
data:
  config.json: |
    {{- .Values.management.configmap | nindent 4 }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set management.enabled=true --set management.configmap='{"test":"value"}' | grep -A10 "kind: ConfigMap"`
Expected: ConfigMap with config.json data

**Step 3: Commit**

```bash
git add charts/netbird/templates/management-cm.yaml
git commit -m "feat: add management configmap template"
```

---

## Task 10: Create Management PVC Template

**Files:**
- Create: `charts/netbird/templates/management-pvc.yaml`

**Step 1: Create the template file**

```yaml
{{- if and .Values.management.enabled .Values.management.persistentVolume.enabled -}}
{{- if not .Values.management.persistentVolume.existingPVName -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "netbird.fullname" . }}-management
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.management.labels" . | nindent 4 }}
  {{- with .Values.management.persistentVolume.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  accessModes:
    {{- toYaml .Values.management.persistentVolume.accessModes | nindent 4 }}
  {{- if .Values.management.persistentVolume.storageClass }}
  storageClassName: {{ .Values.management.persistentVolume.storageClass | quote }}
  {{- end }}
  resources:
    requests:
      storage: {{ .Values.management.persistentVolume.size }}
{{- end -}}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set management.enabled=true --set management.persistentVolume.enabled=true | grep -A15 "kind: PersistentVolumeClaim"`
Expected: PVC resource for management

**Step 3: Commit**

```bash
git add charts/netbird/templates/management-pvc.yaml
git commit -m "feat: add management pvc template"
```

---

## Task 11: Create Management HTTP Service Template

**Files:**
- Create: `charts/netbird/templates/management-service.yaml`

**Step 1: Create the template file**

```yaml
{{- if .Values.management.enabled -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "netbird.fullname" . }}-management
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.management.labels" . | nindent 4 }}
spec:
  type: {{ .Values.management.service.type }}
  ports:
    - port: {{ .Values.management.service.port }}
      targetPort: {{ .Values.management.service.name }}
      protocol: TCP
      name: {{ .Values.management.service.name }}
    {{- if .Values.management.metrics.enabled }}
    - port: {{ .Values.management.metrics.port }}
      targetPort: metrics
      protocol: TCP
      name: metrics
    {{- end }}
  selector:
    {{- include "netbird.management.selectorLabels" . | nindent 4 }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set management.enabled=true | grep -A15 "kind: Service" | head -20`
Expected: Service resource for management HTTP

**Step 3: Commit**

```bash
git add charts/netbird/templates/management-service.yaml
git commit -m "feat: add management http service template"
```

---

## Task 12: Create Management gRPC Service Template

**Files:**
- Create: `charts/netbird/templates/management-service-grpc.yaml`

**Step 1: Create the template file**

```yaml
{{- if .Values.management.enabled -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "netbird.fullname" . }}-management-grpc
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.management.labels" . | nindent 4 }}
spec:
  type: {{ .Values.management.serviceGrpc.type }}
  ports:
    - port: {{ .Values.management.serviceGrpc.port }}
      targetPort: {{ .Values.management.serviceGrpc.name }}
      protocol: TCP
      name: {{ .Values.management.serviceGrpc.name }}
  selector:
    {{- include "netbird.management.selectorLabels" . | nindent 4 }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set management.enabled=true | grep -A15 "name:.*-management-grpc"`
Expected: Service resource for management gRPC

**Step 3: Commit**

```bash
git add charts/netbird/templates/management-service-grpc.yaml
git commit -m "feat: add management grpc service template"
```

---

## Task 13: Create Management HTTP Ingress Template

**Files:**
- Create: `charts/netbird/templates/management-ingress.yaml`

**Step 1: Create the template file**

```yaml
{{- if and .Values.management.enabled .Values.management.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "netbird.fullname" . }}-management
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.management.labels" . | nindent 4 }}
  {{- with .Values.management.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.management.ingress.className }}
  ingressClassName: {{ .Values.management.ingress.className | quote }}
  {{- end }}
  {{- if .Values.management.ingress.tls }}
  tls:
    {{- toYaml .Values.management.ingress.tls | nindent 4 }}
  {{- end }}
  rules:
    {{- range .Values.management.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "netbird.fullname" $ }}-management
                port:
                  number: {{ $.Values.management.service.port }}
          {{- end }}
    {{- end }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set management.enabled=true --set management.ingress.enabled=true | grep -A25 "kind: Ingress"`
Expected: Ingress resource for management HTTP

**Step 3: Commit**

```bash
git add charts/netbird/templates/management-ingress.yaml
git commit -m "feat: add management http ingress template"
```

---

## Task 14: Create Management gRPC Ingress Template

**Files:**
- Create: `charts/netbird/templates/management-ingress-grpc.yaml`

**Step 1: Create the template file**

```yaml
{{- if and .Values.management.enabled .Values.management.ingressGrpc.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "netbird.fullname" . }}-management-grpc
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.management.labels" . | nindent 4 }}
  {{- with .Values.management.ingressGrpc.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.management.ingressGrpc.className }}
  ingressClassName: {{ .Values.management.ingressGrpc.className | quote }}
  {{- end }}
  {{- if .Values.management.ingressGrpc.tls }}
  tls:
    {{- toYaml .Values.management.ingressGrpc.tls | nindent 4 }}
  {{- end }}
  rules:
    {{- range .Values.management.ingressGrpc.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                {{- if $.Values.management.useBackwardsGrpcService }}
                name: {{ include "netbird.fullname" $ }}-management-grpc
                port:
                  number: {{ $.Values.management.serviceGrpc.port }}
                {{- else }}
                name: {{ include "netbird.fullname" $ }}-management
                port:
                  number: {{ $.Values.management.service.port }}
                {{- end }}
          {{- end }}
    {{- end }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set management.enabled=true --set management.ingressGrpc.enabled=true | grep -A25 "name:.*-management-grpc"`
Expected: Ingress resource for management gRPC

**Step 3: Commit**

```bash
git add charts/netbird/templates/management-ingress-grpc.yaml
git commit -m "feat: add management grpc ingress template"
```

---

## Task 15: Create Management Deployment Template

**Files:**
- Create: `charts/netbird/templates/management-deployment.yaml`

**Step 1: Create the template file**

```yaml
{{- if .Values.management.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "netbird.fullname" . }}-management
  namespace: {{ include "netbird.namespace" . }}
  {{- with .Values.management.deploymentAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "netbird.management.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.management.replicaCount }}
  selector:
    matchLabels:
      {{- include "netbird.management.selectorLabels" . | nindent 6 }}
  strategy:
    type: {{ .Values.management.strategy.type }}
    {{- if eq .Values.management.strategy.type "RollingUpdate" }}
    rollingUpdate:
      {{- if .Values.management.strategy.rollingUpdate }}
      maxSurge: {{ .Values.management.strategy.rollingUpdate.maxSurge | default "25%" }}
      maxUnavailable: {{ .Values.management.strategy.rollingUpdate.maxUnavailable | default "25%" }}
      {{- end }}
    {{- end }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print .Template.BasePath "/management-cm.yaml") . | sha256sum }}
        {{- with .Values.management.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "netbird.management.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.management.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "netbird.management.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.management.podSecurityContext | nindent 8 }}
      {{- with .Values.management.initContainers }}
      initContainers:
        {{- tpl (toYaml .) $ | nindent 6 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}-management
          securityContext:
            {{- toYaml .Values.management.securityContext | nindent 12 }}
          image: "{{ .Values.management.image.repository }}:{{ .Values.management.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.management.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.management.containerPort }}
              protocol: TCP
            - name: grpc
              containerPort: {{ .Values.management.grpcContainerPort }}
              protocol: TCP
            {{- if .Values.management.metrics.enabled }}
            - name: metrics
              containerPort: {{ .Values.management.metrics.port }}
              protocol: TCP
            {{- end }}
          {{- if .Values.management.livenessProbe }}
          livenessProbe:
            {{- toYaml .Values.management.livenessProbe | nindent 12 }}
          {{- end }}
          {{- if .Values.management.readinessProbe }}
          readinessProbe:
            {{- toYaml .Values.management.readinessProbe | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.management.resources | nindent 12 }}
          volumeMounts:
            - name: config
              mountPath: /etc/netbird
              readOnly: true
            - name: management-data
              mountPath: /var/lib/netbird
          {{- if .Values.management.volumeMounts }}
          {{- .Values.management.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
          {{- if or .Values.management.gracefulShutdown .Values.management.lifecycle }}
          lifecycle:
            {{- if .Values.management.gracefulShutdown }}
            preStop:
              exec:
                command: ["sh", "-c", "echo Waiting 5 seconds to allow terminating current connections >/proc/1/fd/1; sleep 5"]
            {{- end }}
            {{- with .Values.management.lifecycle }}
            {{- if .postStart }}
            postStart:
              {{- toYaml .postStart | nindent 14 }}
            {{- end }}
            {{- end }}
          {{- end }}
          {{- if or (.Values.management.env) (.Values.management.envRaw) (.Values.management.envFromSecret) }}
          env:
          {{- range $key, $val := .Values.management.env }}
            - name: {{ $key }}
              value: {{ $val | quote }}
          {{- end }}
          {{- if .Values.management.envRaw }}
            {{- with .Values.management.envRaw }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
          {{- range $key, $val := .Values.management.envFromSecret }}
            - name: {{ $key }}
              valueFrom:
                secretKeyRef:
                  name: {{ (split "/" $val)._0 }}
                  key: {{ (split "/" $val)._1 }}
          {{- end }}
          {{- end }}
      {{- with .Values.management.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.management.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.management.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumes:
        - name: config
          configMap:
            name: {{ include "netbird.fullname" . }}-management
        - name: management-data
          {{- if .Values.management.persistentVolume.enabled }}
          {{- if .Values.management.persistentVolume.existingPVName }}
          persistentVolumeClaim:
            claimName: {{ .Values.management.persistentVolume.existingPVName }}
          {{- else }}
          persistentVolumeClaim:
            claimName: {{ include "netbird.fullname" . }}-management
          {{- end }}
          {{- else }}
          emptyDir: {}
          {{- end }}
        {{- if .Values.management.volumes }}
        {{- .Values.management.volumes | toYaml | nindent 8 }}
        {{- end }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set management.enabled=true | grep -A10 "kind: Deployment"`
Expected: Deployment resource for management

**Step 3: Commit**

```bash
git add charts/netbird/templates/management-deployment.yaml
git commit -m "feat: add management deployment template"
```

---

## Task 16: Create Signal ServiceAccount Template

**Files:**
- Create: `charts/netbird/templates/signal-serviceaccount.yaml`

**Step 1: Create the template file**

```yaml
{{- if .Values.signal.enabled -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "netbird.signal.serviceAccountName" . }}
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.signal.labels" . | nindent 4 }}
  {{- with .Values.signal.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set signal.enabled=true | grep -A10 "kind: ServiceAccount"`
Expected: ServiceAccount resource for signal

**Step 3: Commit**

```bash
git add charts/netbird/templates/signal-serviceaccount.yaml
git commit -m "feat: add signal serviceaccount template"
```

---

## Task 17: Create Signal Service Template

**Files:**
- Create: `charts/netbird/templates/signal-service.yaml`

**Step 1: Create the template file**

```yaml
{{- if .Values.signal.enabled -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "netbird.fullname" . }}-signal
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.signal.labels" . | nindent 4 }}
spec:
  type: {{ .Values.signal.service.type }}
  ports:
    - port: {{ .Values.signal.service.port }}
      targetPort: {{ .Values.signal.service.name }}
      protocol: TCP
      name: {{ .Values.signal.service.name }}
    {{- if .Values.signal.metrics.enabled }}
    - port: {{ .Values.signal.metrics.port }}
      targetPort: metrics
      protocol: TCP
      name: metrics
    {{- end }}
  selector:
    {{- include "netbird.signal.selectorLabels" . | nindent 4 }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set signal.enabled=true | grep -A15 "name:.*-signal"`
Expected: Service resource for signal

**Step 3: Commit**

```bash
git add charts/netbird/templates/signal-service.yaml
git commit -m "feat: add signal service template"
```

---

## Task 18: Create Signal Ingress Template

**Files:**
- Create: `charts/netbird/templates/signal-ingress.yaml`

**Step 1: Create the template file**

```yaml
{{- if and .Values.signal.enabled .Values.signal.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "netbird.fullname" . }}-signal
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.signal.labels" . | nindent 4 }}
  {{- with .Values.signal.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.signal.ingress.className }}
  ingressClassName: {{ .Values.signal.ingress.className | quote }}
  {{- end }}
  {{- if .Values.signal.ingress.tls }}
  tls:
    {{- toYaml .Values.signal.ingress.tls | nindent 4 }}
  {{- end }}
  rules:
    {{- range .Values.signal.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "netbird.fullname" $ }}-signal
                port:
                  number: {{ $.Values.signal.service.port }}
          {{- end }}
    {{- end }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set signal.enabled=true --set signal.ingress.enabled=true | grep -A25 "kind: Ingress"`
Expected: Ingress resource for signal

**Step 3: Commit**

```bash
git add charts/netbird/templates/signal-ingress.yaml
git commit -m "feat: add signal ingress template"
```

---

## Task 19: Create Signal Deployment Template

**Files:**
- Create: `charts/netbird/templates/signal-deployment.yaml`

**Step 1: Create the template file**

```yaml
{{- if .Values.signal.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "netbird.fullname" . }}-signal
  namespace: {{ include "netbird.namespace" . }}
  {{- with .Values.signal.deploymentAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "netbird.signal.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.signal.replicaCount }}
  selector:
    matchLabels:
      {{- include "netbird.signal.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.signal.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "netbird.signal.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.signal.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "netbird.signal.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.signal.podSecurityContext | nindent 8 }}
      {{- with .Values.signal.initContainers }}
      initContainers:
        {{- tpl (toYaml .) $ | nindent 6 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}-signal
          securityContext:
            {{- toYaml .Values.signal.securityContext | nindent 12 }}
          image: "{{ .Values.signal.image.repository }}:{{ .Values.signal.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.signal.image.pullPolicy }}
          ports:
            - name: grpc
              containerPort: {{ .Values.signal.containerPort }}
              protocol: TCP
            {{- if .Values.signal.metrics.enabled }}
            - name: metrics
              containerPort: {{ .Values.signal.metrics.port }}
              protocol: TCP
            {{- end }}
          {{- if .Values.signal.livenessProbe }}
          livenessProbe:
            {{- toYaml .Values.signal.livenessProbe | nindent 12 }}
          {{- end }}
          {{- if .Values.signal.readinessProbe }}
          readinessProbe:
            {{- toYaml .Values.signal.readinessProbe | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.signal.resources | nindent 12 }}
          {{- if .Values.signal.volumeMounts }}
          volumeMounts:
          {{- .Values.signal.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
          {{- if or .Values.signal.gracefulShutdown .Values.signal.lifecycle }}
          lifecycle:
            {{- if .Values.signal.gracefulShutdown }}
            preStop:
              exec:
                command: ["sh", "-c", "echo Waiting 5 seconds to allow terminating current connections >/proc/1/fd/1; sleep 5"]
            {{- end }}
            {{- with .Values.signal.lifecycle }}
            {{- if .postStart }}
            postStart:
              {{- toYaml .postStart | nindent 14 }}
            {{- end }}
            {{- end }}
          {{- end }}
          {{- if or (.Values.signal.env) (.Values.signal.envRaw) (.Values.signal.envFromSecret) }}
          env:
          {{- range $key, $val := .Values.signal.env }}
            - name: {{ $key }}
              value: {{ $val | quote }}
          {{- end }}
          {{- if .Values.signal.envRaw }}
            {{- with .Values.signal.envRaw }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
          {{- range $key, $val := .Values.signal.envFromSecret }}
            - name: {{ $key }}
              valueFrom:
                secretKeyRef:
                  name: {{ (split "/" $val)._0 }}
                  key: {{ (split "/" $val)._1 }}
          {{- end }}
          {{- end }}
      {{- if .Values.signal.volumes }}
      volumes:
      {{- .Values.signal.volumes | toYaml | nindent 8 }}
      {{- end }}
      {{- with .Values.signal.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.signal.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.signal.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set signal.enabled=true | grep -A10 "kind: Deployment"`
Expected: Deployment resource for signal

**Step 3: Commit**

```bash
git add charts/netbird/templates/signal-deployment.yaml
git commit -m "feat: add signal deployment template"
```

---

## Task 20: Create Relay ServiceAccount Template

**Files:**
- Create: `charts/netbird/templates/relay-serviceaccount.yaml`

**Step 1: Create the template file**

```yaml
{{- if .Values.relay.enabled -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "netbird.relay.serviceAccountName" . }}
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.relay.labels" . | nindent 4 }}
  {{- with .Values.relay.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set relay.enabled=true | grep -A10 "kind: ServiceAccount"`
Expected: ServiceAccount resource for relay

**Step 3: Commit**

```bash
git add charts/netbird/templates/relay-serviceaccount.yaml
git commit -m "feat: add relay serviceaccount template"
```

---

## Task 21: Create Relay HTTP Service Template

**Files:**
- Create: `charts/netbird/templates/relay-service.yaml`

**Step 1: Create the template file**

```yaml
{{- if .Values.relay.enabled -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "netbird.fullname" . }}-relay
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.relay.labels" . | nindent 4 }}
spec:
  type: {{ .Values.relay.service.type }}
  ports:
    - port: {{ .Values.relay.service.port }}
      targetPort: {{ .Values.relay.service.name }}
      protocol: TCP
      name: {{ .Values.relay.service.name }}
    {{- if .Values.relay.metrics.enabled }}
    - port: {{ .Values.relay.metrics.port }}
      targetPort: metrics
      protocol: TCP
      name: metrics
    {{- end }}
  selector:
    {{- include "netbird.relay.selectorLabels" . | nindent 4 }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set relay.enabled=true | grep -A15 "name:.*-relay"`
Expected: Service resource for relay HTTP

**Step 3: Commit**

```bash
git add charts/netbird/templates/relay-service.yaml
git commit -m "feat: add relay http service template"
```

---

## Task 22: Create Relay STUN Service Template

**Files:**
- Create: `charts/netbird/templates/relay-service-stun.yaml`

**Step 1: Create the template file**

```yaml
{{- if and .Values.relay.enabled .Values.relay.stun.enabled -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "netbird.fullname" . }}-relay-stun
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.relay.labels" . | nindent 4 }}
spec:
  type: {{ .Values.relay.stun.service.type }}
  {{- if and (eq .Values.relay.stun.service.type "LoadBalancer") .Values.relay.stun.service.externalTrafficPolicy }}
  externalTrafficPolicy: {{ .Values.relay.stun.service.externalTrafficPolicy }}
  {{- end }}
  ports:
    {{- range $port := .Values.relay.stun.ports }}
    - port: {{ $port }}
      targetPort: {{ $port }}
      protocol: UDP
      name: stun-{{ $port }}
    {{- end }}
  selector:
    {{- include "netbird.relay.selectorLabels" . | nindent 4 }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set relay.enabled=true --set relay.stun.enabled=true --set relay.stun.ports[0]=3478 | grep -A15 "name:.*-relay-stun"`
Expected: UDP Service resource for STUN

**Step 3: Commit**

```bash
git add charts/netbird/templates/relay-service-stun.yaml
git commit -m "feat: add relay stun service template"
```

---

## Task 23: Create Relay Ingress Template

**Files:**
- Create: `charts/netbird/templates/relay-ingress.yaml`

**Step 1: Create the template file**

```yaml
{{- if and .Values.relay.enabled .Values.relay.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "netbird.fullname" . }}-relay
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.relay.labels" . | nindent 4 }}
  {{- with .Values.relay.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.relay.ingress.className }}
  ingressClassName: {{ .Values.relay.ingress.className | quote }}
  {{- end }}
  {{- if .Values.relay.ingress.tls }}
  tls:
    {{- toYaml .Values.relay.ingress.tls | nindent 4 }}
  {{- end }}
  rules:
    {{- range .Values.relay.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "netbird.fullname" $ }}-relay
                port:
                  number: {{ $.Values.relay.service.port }}
          {{- end }}
    {{- end }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set relay.enabled=true --set relay.ingress.enabled=true | grep -A25 "kind: Ingress"`
Expected: Ingress resource for relay

**Step 3: Commit**

```bash
git add charts/netbird/templates/relay-ingress.yaml
git commit -m "feat: add relay ingress template"
```

---

## Task 24: Create Relay Deployment Template

**Files:**
- Create: `charts/netbird/templates/relay-deployment.yaml`

**Step 1: Create the template file**

```yaml
{{- if .Values.relay.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "netbird.fullname" . }}-relay
  namespace: {{ include "netbird.namespace" . }}
  {{- with .Values.relay.deploymentAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "netbird.relay.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.relay.replicaCount }}
  selector:
    matchLabels:
      {{- include "netbird.relay.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.relay.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "netbird.relay.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.relay.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "netbird.relay.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.relay.podSecurityContext | nindent 8 }}
      {{- with .Values.relay.initContainers }}
      initContainers:
        {{- tpl (toYaml .) $ | nindent 6 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}-relay
          securityContext:
            {{- toYaml .Values.relay.securityContext | nindent 12 }}
          image: "{{ .Values.relay.image.repository }}:{{ .Values.relay.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.relay.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.relay.containerPort }}
              protocol: TCP
            {{- if .Values.relay.metrics.enabled }}
            - name: metrics
              containerPort: {{ .Values.relay.metrics.port }}
              protocol: TCP
            {{- end }}
            {{- if .Values.relay.stun.enabled }}
            {{- range $port := .Values.relay.stun.ports }}
            - name: stun-{{ $port }}
              containerPort: {{ $port }}
              protocol: UDP
            {{- end }}
            {{- end }}
          {{- if .Values.relay.livenessProbe }}
          livenessProbe:
            {{- toYaml .Values.relay.livenessProbe | nindent 12 }}
          {{- end }}
          {{- if .Values.relay.readinessProbe }}
          readinessProbe:
            {{- toYaml .Values.relay.readinessProbe | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.relay.resources | nindent 12 }}
          {{- if .Values.relay.volumeMounts }}
          volumeMounts:
          {{- .Values.relay.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
          {{- if or .Values.relay.gracefulShutdown .Values.relay.lifecycle }}
          lifecycle:
            {{- if .Values.relay.gracefulShutdown }}
            preStop:
              exec:
                command: ["sh", "-c", "echo Waiting 5 seconds to allow terminating current connections >/proc/1/fd/1; sleep 5"]
            {{- end }}
            {{- with .Values.relay.lifecycle }}
            {{- if .postStart }}
            postStart:
              {{- toYaml .postStart | nindent 14 }}
            {{- end }}
            {{- end }}
          {{- end }}
          env:
          {{- if or (.Values.relay.env) (.Values.relay.envRaw) (.Values.relay.envFromSecret) }}
          {{- range $key, $val := .Values.relay.env }}
            - name: {{ $key }}
              value: {{ $val | quote }}
          {{- end }}
          {{- if .Values.relay.envRaw }}
            {{- with .Values.relay.envRaw }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
          {{- range $key, $val := .Values.relay.envFromSecret }}
            - name: {{ $key }}
              valueFrom:
                secretKeyRef:
                  name: {{ (split "/" $val)._0 }}
                  key: {{ (split "/" $val)._1 }}
          {{- end }}
          {{- end }}
          {{- if .Values.relay.stun.enabled }}
            - name: NB_ENABLE_STUN
              value: "true"
            - name: NB_STUN_PORTS
              value: {{ join "," .Values.relay.stun.ports | quote }}
          {{- end }}
      {{- if .Values.relay.volumes }}
      volumes:
      {{- .Values.relay.volumes | toYaml | nindent 8 }}
      {{- end }}
      {{- with .Values.relay.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.relay.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.relay.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}
```

**Step 2: Verify template renders**

Run: `helm template x charts/netbird --set relay.enabled=true | grep -A10 "kind: Deployment"`
Expected: Deployment resource for relay

**Step 3: Commit**

```bash
git add charts/netbird/templates/relay-deployment.yaml
git commit -m "feat: add relay deployment template with STUN support"
```

---

## Task 25: Run Full Validation

**Files:**
- None (validation only)

**Step 1: Run helm lint**

Run: `helm lint charts/netbird`
Expected: No errors

**Step 2: Run kubeconform validation**

Run: `helm dep up charts/netbird && helm template x charts/netbird --include-crds | kubeconform -summary -strict -ignore-missing-schemas -kubernetes-version=1.30.0`
Expected: All resources pass validation

**Step 3: Test microservice mode rendering**

Run: `helm template x charts/netbird --set server.enabled=false --set management.enabled=true --set signal.enabled=true --set relay.enabled=true --set relay.stun.enabled=true > /tmp/test.yaml && kubeconform -summary /tmp/test.yaml`
Expected: All microservice resources render and validate

**Step 4: Commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: resolve validation issues"
```

---

## Task 26: Create Microservice Example

**Files:**
- Create: `charts/netbird/examples/microservice/values.yaml`

**Step 1: Create the example file**

```yaml
fullnameOverride: netbird

server:
  enabled: false

management:
  enabled: true
  configmap: |-
    {
      "Stuns": [
        {
          "Proto": "udp",
          "URI": "{{ .STUN_SERVER }}",
          "Username": "",
          "Password": ""
        }
      ],
      "TURNConfig": {
        "TimeBasedCredentials": false,
        "CredentialsTTL": "12h0m0s",
        "Secret": "secret",
        "Turns": []
      },
      "Relay": {
        "Addresses": ["rels://netbird.example.com:443/relay"],
        "CredentialsTTL": "24h",
        "Secret": "{{ .RELAY_PASSWORD }}"
      },
      "Signal": {
        "Proto": "https",
        "URI": "netbird.example.com:443",
        "Username": "",
        "Password": ""
      },
      "Datadir": "/var/lib/netbird/",
      "DataStoreEncryptionKey": "{{ .DATASTORE_ENCRYPTION_KEY }}",
      "HttpConfig": {
        "AuthAudience": "{{ .IDP_CLIENT_ID }}",
        "AuthIssuer": "https://auth.example.com/application/o/netbird/",
        "AuthKeysLocation": "https://auth.example.com/application/o/netbird/jwks/"
      },
      "StoreConfig": {
        "Engine": "postgres"
      }
    }
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: netbird.example.com
        paths:
          - path: /api
            pathType: ImplementationSpecific
    tls:
      - secretName: wildcard-example-com-tls
        hosts:
          - netbird.example.com
  ingressGrpc:
    enabled: true
    className: nginx
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: GRPC
    hosts:
      - host: netbird.example.com
        paths:
          - path: /management.ManagementService/
            pathType: ImplementationSpecific
    tls:
      - secretName: wildcard-example-com-tls
        hosts:
          - netbird.example.com
  persistentVolume:
    enabled: false
  envFromSecret:
    NETBIRD_STORE_ENGINE_POSTGRES_DSN: netbird/postgresDSN
    STUN_SERVER: netbird/stunServer
    RELAY_PASSWORD: netbird/relayPassword
    DATASTORE_ENCRYPTION_KEY: netbird/datastoreEncryptionKey
    IDP_CLIENT_ID: netbird/idpClientID

signal:
  enabled: true
  ingress:
    enabled: true
    className: nginx
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: GRPC
    hosts:
      - host: netbird.example.com
        paths:
          - path: /signalexchange.SignalExchange/
            pathType: ImplementationSpecific
    tls:
      - secretName: wildcard-example-com-tls
        hosts:
          - netbird.example.com

relay:
  enabled: true
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

dashboard:
  enabled: true
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: netbird.example.com
        paths:
          - path: /
            pathType: ImplementationSpecific
    tls:
      - secretName: wildcard-example-com-tls
        hosts:
          - netbird.example.com
  env:
    NETBIRD_MGMT_API_ENDPOINT: https://netbird.example.com:443
    NETBIRD_MGMT_GRPC_API_ENDPOINT: https://netbird.example.com:443
    AUTH_AUTHORITY: https://auth.example.com/application/o/netbird/
    USE_AUTH0: false
    AUTH_SUPPORTED_SCOPES: openid profile email offline_access api
  envFromSecret:
    AUTH_CLIENT_ID: netbird/idpClientID
```

**Step 2: Verify example renders**

Run: `helm template x charts/netbird -f charts/netbird/examples/microservice/values.yaml | head -50`
Expected: All microservice components render without errors

**Step 3: Commit**

```bash
git add charts/netbird/examples/microservice/values.yaml
git commit -m "docs: add microservice deployment example"
```

---

## Task 27: Create Hybrid Example

**Files:**
- Create: `charts/netbird/examples/hybrid/values.yaml`

**Step 1: Create the example file**

```yaml
fullnameOverride: netbird

server:
  enabled: true
  config:
    exposedAddress: "https://netbird.example.com:443"
    authSecret: "${AUTH_SECRET}"
    auth:
      issuer: "https://auth.example.com/application/o/netbird/"
  initContainer:
    envFromSecret:
      AUTH_SECRET: netbird/relayPassword
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: netbird.example.com
        paths:
          - path: /api
            pathType: ImplementationSpecific
    tls:
      - secretName: wildcard-example-com-tls
        hosts:
          - netbird.example.com
  ingressGrpc:
    enabled: true
    className: nginx
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: GRPC
    hosts:
      - host: netbird.example.com
        paths:
          - path: /signalexchange.SignalExchange/
            pathType: ImplementationSpecific
          - path: /management.ManagementService/
            pathType: ImplementationSpecific
    tls:
      - secretName: wildcard-example-com-tls
        hosts:
          - netbird.example.com

relay:
  enabled: true
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

dashboard:
  enabled: true
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: netbird.example.com
        paths:
          - path: /
            pathType: ImplementationSpecific
    tls:
      - secretName: wildcard-example-com-tls
        hosts:
          - netbird.example.com
  env:
    NETBIRD_MGMT_API_ENDPOINT: https://netbird.example.com:443
    NETBIRD_MGMT_GRPC_API_ENDPOINT: https://netbird.example.com:443
    AUTH_AUTHORITY: https://auth.example.com/application/o/netbird/
    USE_AUTH0: false
  envFromSecret:
    AUTH_CLIENT_ID: netbird/idpClientID
```

**Step 2: Verify example renders**

Run: `helm template x charts/netbird -f charts/netbird/examples/hybrid/values.yaml | grep "kind:" | sort | uniq -c`
Expected: Server + relay + dashboard resources (not management)

**Step 3: Commit**

```bash
git add charts/netbird/examples/hybrid/values.yaml
git commit -m "docs: add hybrid deployment example (server + relay with STUN)"
```

---

## Task 28: Update README

**Files:**
- Modify: `charts/netbird/README.md`

**Step 1: Add microservice mode section after unified server section**

Add documentation for microservice mode including:
- Overview of components
- Mode selection (enable flags)
- Configuration examples
- STUN server setup
- Migration notes

**Step 2: Update values table**

Run: `helm-docs` (if available) or manually add new values to the table

**Step 3: Commit**

```bash
git add charts/netbird/README.md
git commit -m "docs: update README with microservice mode documentation"
```

---

## Task 29: Update Chart Version

**Files:**
- Modify: `charts/netbird/Chart.yaml`

**Step 1: Bump chart version**

Change `version: 2.0.0` to `version: 2.1.0`

**Step 2: Verify**

Run: `helm lint charts/netbird`
Expected: No errors

**Step 3: Commit**

```bash
git add charts/netbird/Chart.yaml
git commit -m "chore: bump chart version to 2.1.0"
```

---

## Task 30: Final Validation

**Files:**
- None (validation only)

**Step 1: Run full CI validation**

Run: `helm dep up charts/netbird && helm template x charts/netbird --include-crds > /tmp/output.yaml && kubeconform -summary -strict -ignore-missing-schemas -kubernetes-version=1.30.0 /tmp/output.yaml && kubeconform -summary -strict -ignore-missing-schemas -kubernetes-version=1.31.0 /tmp/output.yaml`
Expected: All resources pass for both K8s versions

**Step 2: Test conflict detection**

Run: `helm template x charts/netbird --set server.enabled=true --set management.enabled=true 2>&1`
Expected: Error message about conflicting modes

**Step 3: Final commit (if any fixes)**

```bash
git add -A
git commit -m "fix: final validation fixes"
```

---

## Summary

**Total Tasks:** 30
**New Files:** 17 templates + 2 examples = 19 files
**Modified Files:** _helpers.tpl, values.yaml, README.md, Chart.yaml

**Key Features Delivered:**
1. Management component with JSON configmap
2. Signal component with gRPC
3. Relay component with embedded STUN
4. Mode validation (server/management conflict)
5. Shared dashboard between modes
6. Two deployment examples (microservice, hybrid)
