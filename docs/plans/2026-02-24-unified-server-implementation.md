# NetBird Unified Server Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the NetBird Helm chart to use a unified `netbird-server` deployment, replacing separate management/signal/relay components.

**Architecture:** Single server deployment with embedded signal/relay/STUN services, YAML config with envsubst for secret injection via init container, split ingress for gRPC and HTTP paths.

**Tech Stack:** Helm, Kubernetes, Go templating, envsubst, netbirdio/netbird-server image

---

## Task 1: Update _helpers.tpl

**Files:**
- Modify: `charts/netbird/templates/_helpers.tpl`

**Step 1: Add server selector labels helper**

Add after line 42 (after common labels):

```yaml
{{/*
Server selector labels
*/}}
{{- define "netbird.server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netbird.name" . }}-server
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common server labels
*/}}
{{- define "netbird.server.labels" -}}
helm.sh/chart: {{ include "netbird.chart" . }}
{{ include "netbird.server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Create the name of the server service account to use
*/}}
{{- define "netbird.server.serviceAccountName" -}}
{{- if .Values.server.serviceAccount.create }}
{{- default (printf "%s-server" (include "netbird.fullname" .)) .Values.server.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.server.serviceAccount.name }}
{{- end }}
{{- end }}
```

**Step 2: Remove old management/signal/relay helpers**

Delete the following helper definitions (lines 45-165):
- `netbird.management.labels`
- `netbird.signal.labels`
- `netbird.relay.labels`
- `netbird.management.selectorLabels`
- `netbird.signal.selectorLabels`
- `netbird.relay.selectorLabels`
- `netbird.management.serviceAccountName`
- `netbird.signal.serviceAccountName`
- `netbird.relay.serviceAccountName`

**Step 3: Commit**

```bash
git add charts/netbird/templates/_helpers.tpl
git commit -m "refactor(helpers): replace component helpers with unified server helpers"
```

---

## Task 2: Create server-cm.yaml (ConfigMap Template)

**Files:**
- Create: `charts/netbird/templates/server-cm.yaml`

**Step 1: Create the ConfigMap template**

```yaml
{{- if .Values.server.enabled -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "netbird.fullname" . }}-server
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.server.labels" . | nindent 4 }}
data:
  config.yaml.tmpl: |
    server:
      listenAddress: {{ .Values.server.config.listenAddress | quote }}
      exposedAddress: {{ .Values.server.config.exposedAddress | quote }}
      {{- if .Values.server.config.stunPorts }}
      stunPorts:
        {{- toYaml .Values.server.config.stunPorts | nindent 8 }}
      {{- end }}
      metricsPort: {{ .Values.server.config.metricsPort }}
      healthcheckAddress: {{ .Values.server.config.healthcheckAddress | quote }}
      logLevel: {{ .Values.server.config.logLevel | quote }}
      logFile: {{ .Values.server.config.logFile | quote }}
      {{- if .Values.server.config.tls.enabled }}
      tls:
        certFile: {{ .Values.server.config.tls.certFile | quote }}
        keyFile: {{ .Values.server.config.tls.keyFile | quote }}
        letsencrypt:
          enabled: {{ .Values.server.config.tls.letsencrypt.enabled }}
          dataDir: {{ .Values.server.config.tls.letsencrypt.dataDir | quote }}
          domains:
            {{- toYaml .Values.server.config.tls.letsencrypt.domains | nindent 12 }}
          email: {{ .Values.server.config.tls.letsencrypt.email | quote }}
          awsRoute53: {{ .Values.server.config.tls.letsencrypt.awsRoute53 }}
      {{- end }}
      authSecret: {{ .Values.server.config.authSecret | quote }}
      dataDir: {{ .Values.server.config.dataDir | quote }}
    disableAnonymousMetrics: {{ .Values.server.config.disableAnonymousMetrics }}
    disableGeoliteUpdate: {{ .Values.server.config.disableGeoliteUpdate }}
    auth:
      issuer: {{ .Values.server.config.auth.issuer | quote }}
      localAuthDisabled: {{ .Values.server.config.auth.localAuthDisabled }}
      signKeyRefreshEnabled: {{ .Values.server.config.auth.signKeyRefreshEnabled }}
      {{- if .Values.server.config.auth.dashboardRedirectURIs }}
      dashboardRedirectURIs:
        {{- toYaml .Values.server.config.auth.dashboardRedirectURIs | nindent 8 }}
      {{- end }}
      cliRedirectURIs:
        {{- toYaml .Values.server.config.auth.cliRedirectURIs | nindent 8 }}
      {{- if .Values.server.config.auth.owner }}
      owner:
        email: {{ .Values.server.config.auth.owner.email | quote }}
        password: {{ .Values.server.config.auth.owner.password | quote }}
      {{- end }}
    store:
      engine: {{ .Values.server.config.store.engine | quote }}
      dsn: {{ .Values.server.config.store.dsn | quote }}
      encryptionKey: {{ .Values.server.config.store.encryptionKey | quote }}
    {{- if .Values.server.config.reverseProxy }}
    reverseProxy:
      trustedHTTPProxies:
        {{- toYaml .Values.server.config.reverseProxy.trustedHTTPProxies | nindent 8 }}
      trustedHTTPProxiesCount: {{ .Values.server.config.reverseProxy.trustedHTTPProxiesCount }}
      trustedPeers:
        {{- toYaml .Values.server.config.reverseProxy.trustedPeers | nindent 8 }}
    {{- end }}
{{- end -}}
```

**Step 2: Commit**

```bash
git add charts/netbird/templates/server-cm.yaml
git commit -m "feat(server): add ConfigMap template with envsubst placeholders"
```

---

## Task 3: Create server-pvc.yaml

**Files:**
- Create: `charts/netbird/templates/server-pvc.yaml`

**Step 1: Create the PVC template**

```yaml
{{- if and .Values.server.enabled .Values.server.persistentVolume.enabled -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "netbird.fullname" . }}-server
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.server.labels" . | nindent 4 }}
  {{- with .Values.server.persistentVolume.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  accessModes:
    {{- toYaml .Values.server.persistentVolume.accessModes | nindent 4 }}
  {{- if .Values.server.persistentVolume.storageClass }}
  {{- if (eq "-" .Values.server.persistentVolume.storageClass) }}
  storageClassName: ""
  {{- else }}
  storageClassName: {{ .Values.server.persistentVolume.storageClass | quote }}
  {{- end }}
  {{- end }}
  {{- if .Values.server.persistentVolume.existingPVName }}
  volumeName: {{ .Values.server.persistentVolume.existingPVName | quote }}
  {{- end }}
  resources:
    requests:
      storage: {{ .Values.server.persistentVolume.size | quote }}
{{- end -}}
```

**Step 2: Commit**

```bash
git add charts/netbird/templates/server-pvc.yaml
git commit -m "feat(server): add PersistentVolumeClaim template"
```

---

## Task 4: Create server-serviceaccount.yaml

**Files:**
- Create: `charts/netbird/templates/server-serviceaccount.yaml`

**Step 1: Create the ServiceAccount template**

```yaml
{{- if and .Values.server.enabled .Values.server.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "netbird.server.serviceAccountName" . }}
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.server.labels" . | nindent 4 }}
  {{- with .Values.server.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
```

**Step 2: Commit**

```bash
git add charts/netbird/templates/server-serviceaccount.yaml
git commit -m "feat(server): add ServiceAccount template"
```

---

## Task 5: Create server-service.yaml

**Files:**
- Create: `charts/netbird/templates/server-service.yaml`

**Step 1: Create the main Service template**

```yaml
{{- if .Values.server.enabled -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "netbird.fullname" . }}-server
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.server.labels" . | nindent 4 }}
spec:
  type: {{ .Values.server.service.type }}
  {{- if and (eq .Values.server.service.type "LoadBalancer") .Values.server.service.externalTrafficPolicy }}
  externalTrafficPolicy: {{ .Values.server.service.externalTrafficPolicy }}
  {{- end }}
  ports:
    - port: {{ .Values.server.service.port }}
      targetPort: http
      protocol: TCP
      name: {{ .Values.server.service.name }}
    {{- if .Values.server.metrics.enabled }}
    - port: {{ .Values.server.metrics.port }}
      targetPort: metrics
      protocol: TCP
      name: metrics
    {{- end }}
  selector:
    {{- include "netbird.server.selectorLabels" . | nindent 4 }}
{{- end -}}
```

**Step 2: Commit**

```bash
git add charts/netbird/templates/server-service.yaml
git commit -m "feat(server): add main Service template (HTTP/gRPC)"
```

---

## Task 6: Create server-service-stun.yaml

**Files:**
- Create: `charts/netbird/templates/server-service-stun.yaml`

**Step 1: Create the STUN Service template**

```yaml
{{- if and .Values.server.enabled .Values.server.serviceStun.enabled -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "netbird.fullname" . }}-server-stun
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.server.labels" . | nindent 4 }}
spec:
  type: {{ .Values.server.serviceStun.type }}
  {{- if and (eq .Values.server.serviceStun.type "LoadBalancer") .Values.server.serviceStun.externalTrafficPolicy }}
  externalTrafficPolicy: {{ .Values.server.serviceStun.externalTrafficPolicy }}
  {{- end }}
  ports:
    - port: {{ .Values.server.serviceStun.port }}
      targetPort: stun
      protocol: UDP
      name: stun
  selector:
    {{- include "netbird.server.selectorLabels" . | nindent 4 }}
{{- end -}}
```

**Step 2: Commit**

```bash
git add charts/netbird/templates/server-service-stun.yaml
git commit -m "feat(server): add STUN Service template (UDP 3478)"
```

---

## Task 7: Create server-ingress.yaml

**Files:**
- Create: `charts/netbird/templates/server-ingress.yaml`

**Step 1: Create the HTTP Ingress template**

```yaml
{{- if and .Values.server.enabled .Values.server.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "netbird.fullname" . }}-server
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.server.labels" . | nindent 4 }}
  {{- with .Values.server.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.server.ingress.className }}
  ingressClassName: {{ .Values.server.ingress.className }}
  {{- end }}
  {{- if .Values.server.ingress.tls }}
  tls:
    {{- toYaml .Values.server.ingress.tls | nindent 4 }}
  {{- end }}
  rules:
    {{- range .Values.server.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "netbird.fullname" $ }}-server
                port:
                  number: {{ $.Values.server.service.port }}
          {{- end }}
    {{- end }}
{{- end -}}
```

**Step 2: Commit**

```bash
git add charts/netbird/templates/server-ingress.yaml
git commit -m "feat(server): add HTTP Ingress template"
```

---

## Task 8: Create server-ingress-grpc.yaml

**Files:**
- Create: `charts/netbird/templates/server-ingress-grpc.yaml`

**Step 1: Create the gRPC Ingress template**

```yaml
{{- if and .Values.server.enabled .Values.server.ingressGrpc.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "netbird.fullname" . }}-server-grpc
  namespace: {{ include "netbird.namespace" . }}
  labels:
    {{- include "netbird.server.labels" . | nindent 4 }}
  {{- with .Values.server.ingressGrpc.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.server.ingressGrpc.className }}
  ingressClassName: {{ .Values.server.ingressGrpc.className }}
  {{- end }}
  {{- if .Values.server.ingressGrpc.tls }}
  tls:
    {{- toYaml .Values.server.ingressGrpc.tls | nindent 4 }}
  {{- end }}
  rules:
    {{- range .Values.server.ingressGrpc.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "netbird.fullname" $ }}-server
                port:
                  number: {{ $.Values.server.service.port }}
          {{- end }}
    {{- end }}
{{- end -}}
```

**Step 2: Commit**

```bash
git add charts/netbird/templates/server-ingress-grpc.yaml
git commit -m "feat(server): add gRPC Ingress template"
```

---

## Task 9: Create server-deployment.yaml

**Files:**
- Create: `charts/netbird/templates/server-deployment.yaml`

**Step 1: Create the Deployment template**

```yaml
{{- if .Values.server.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "netbird.fullname" . }}-server
  namespace: {{ include "netbird.namespace" . }}
  {{- with .Values.server.deploymentAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "netbird.server.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.server.replicaCount }}
  selector:
    matchLabels:
      {{- include "netbird.server.selectorLabels" . | nindent 6 }}
  strategy:
    type: {{ .Values.server.strategy.type }}
    {{- if eq .Values.server.strategy.type "RollingUpdate" }}
    rollingUpdate:
      {{- if .Values.server.strategy.rollingUpdate }}
      maxSurge: {{ .Values.server.strategy.rollingUpdate.maxSurge | default "25%" }}
      maxUnavailable: {{ .Values.server.strategy.rollingUpdate.maxUnavailable | default "25%" }}
      {{- end }}
    {{- end }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print .Template.BasePath "/server-cm.yaml") . | sha256sum }}
        {{- with .Values.server.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "netbird.server.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.server.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "netbird.server.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.server.podSecurityContext | nindent 8 }}
      {{- if .Values.server.initContainer.enabled }}
      initContainers:
        - name: config-processor
          image: "{{ .Values.server.initContainer.image.repository }}:{{ .Values.server.initContainer.image.tag }}"
          imagePullPolicy: {{ .Values.server.initContainer.image.pullPolicy }}
          command: ["/bin/sh", "-c"]
          args:
            - |
              apk add --no-cache gettext
              envsubst < /etc/netbird/config.yaml.tmpl > /etc/netbird/config.yaml
          {{- if or (.Values.server.initContainer.env) (.Values.server.initContainer.envRaw) (.Values.server.initContainer.envFromSecret) }}
          env:
          {{- range $key, $val := .Values.server.initContainer.env }}
            - name: {{ $key }}
              value: {{ $val | quote }}
          {{- end }}
          {{- if .Values.server.initContainer.envRaw }}
            {{- with .Values.server.initContainer.envRaw }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
          {{- range $key, $val := .Values.server.initContainer.envFromSecret }}
            - name: {{ $key }}
              valueFrom:
                secretKeyRef:
                  name: {{ (split "/" $val)._0 }}
                  key: {{ (split "/" $val)._1 }}
          {{- end }}
          {{- end }}
          volumeMounts:
            - name: config-template
              mountPath: /etc/netbird
              readOnly: true
            - name: config-rendered
              mountPath: /etc/netbird
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}-server
          securityContext:
            {{- toYaml .Values.server.securityContext | nindent 12 }}
          image: "{{ .Values.server.image.repository }}:{{ .Values.server.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.server.image.pullPolicy }}
          command: ["netbird-server"]
          args:
            - --config
            - /etc/netbird/config.yaml
          {{- if or (.Values.server.env) (.Values.server.envRaw) (.Values.server.envFromSecret) }}
          env:
          {{- range $key, $val := .Values.server.env }}
            - name: {{ $key }}
              value: {{ $val | quote }}
          {{- end }}
          {{- if .Values.server.envRaw }}
            {{- with .Values.server.envRaw }}
              {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
          {{- range $key, $val := .Values.server.envFromSecret }}
            - name: {{ $key }}
              valueFrom:
                secretKeyRef:
                  name: {{ (split "/" $val)._0 }}
                  key: {{ (split "/" $val)._1 }}
          {{- end }}
          {{- end }}
          {{- with .Values.server.lifecycle }}
          lifecycle: {{ toYaml . | nindent 12 }}
          {{- end }}
          ports:
            - name: http
              containerPort: {{ .Values.server.containerPort }}
              protocol: TCP
            - name: stun
              containerPort: {{ .Values.server.serviceStun.port }}
              protocol: UDP
            {{- if .Values.server.metrics.enabled }}
            - name: metrics
              containerPort: {{ .Values.server.metrics.port }}
              protocol: TCP
            {{- end }}
          {{- if .Values.server.livenessProbe }}
          livenessProbe:
            {{- toYaml .Values.server.livenessProbe | nindent 12 }}
          {{- end }}
          {{- if .Values.server.readinessProbe }}
          readinessProbe:
            {{- toYaml .Values.server.readinessProbe | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.server.resources | nindent 12 }}
          volumeMounts:
            - name: config-rendered
              mountPath: /etc/netbird
              readOnly: true
            - name: server-data
              mountPath: /var/lib/netbird
          {{- if .Values.server.volumeMounts }}
          {{- .Values.server.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
          {{- if .Values.server.gracefulShutdown }}
          lifecycle:
            preStop:
              exec:
                command: ["sh", "-c", "echo Waiting 5 seconds to allow terminating current connections >/proc/1/fd/1; sleep 5"]
          {{- end }}
      {{- with .Values.server.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.server.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.server.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumes:
        - name: config-template
          configMap:
            name: {{ include "netbird.fullname" . }}-server
        - name: config-rendered
          emptyDir: {}
        - name: server-data
          {{- if .Values.server.persistentVolume.enabled }}
          persistentVolumeClaim:
            claimName: {{ include "netbird.fullname" . }}-server
          {{- else }}
          emptyDir: {}
          {{- end }}
        {{- if .Values.server.volumes }}
        {{- .Values.server.volumes | toYaml | nindent 8 }}
        {{- end }}
{{- end -}}
```

**Step 2: Commit**

```bash
git add charts/netbird/templates/server-deployment.yaml
git commit -m "feat(server): add Deployment template with init container for envsubst"
```

---

## Task 10: Create New values.yaml

**Files:**
- Modify: `charts/netbird/values.yaml`

**Step 1: Replace entire values.yaml content**

```yaml
## @section NetBird Parameters

## @param global.namespace Kubernetes namespace for the NetBird components.
##
global:
  namespace: ""

## @param nameOverride Override the name of the chart.
##
nameOverride: ""

## @param fullnameOverride Override the full name of the chart.
##
fullnameOverride: ""

## @section NetBird Server (Unified)

server:
  ## @param server.enabled Enable or disable NetBird server component.
  ##
  enabled: true

  ## @param server.replicaCount Number of server pod replicas.
  ##
  replicaCount: 1

  ## @param server.strategy Deployment strategy for the server component.
  ##
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%

  image:
    ## @param server.image.repository Docker image repository for the server component.
    ##
    repository: netbirdio/netbird-server

    ## @param server.image.pullPolicy Docker image pull policy.
    ##
    pullPolicy: IfNotPresent

    ## @param server.image.tag Docker image tag. Overrides the default tag.
    ##
    tag: ""

  ## @param server.imagePullSecrets Docker registry credentials for pulling the server image.
  ##
  imagePullSecrets: []

  serviceAccount:
    ## @param server.serviceAccount.create Whether to create a service account.
    ##
    create: true

    ## @param server.serviceAccount.annotations Annotations for the service account.
    ##
    annotations: {}

    ## @param server.serviceAccount.name Name of the service account to use.
    ##
    name: ""

  ## @param server.deploymentAnnotations Annotations for the server deployment.
  ##
  deploymentAnnotations: {}

  ## @param server.podAnnotations Annotations for the server pod(s).
  ##
  podAnnotations: {}

  ## @param server.podSecurityContext Security context for the server pod(s).
  ##
  podSecurityContext: {}

  ## @param server.securityContext Security context for the server container.
  ##
  securityContext: {}

  ## @param server.containerPort Container port for the server service.
  ##
  containerPort: 80

  ## Server configuration (maps to config.yaml)
  config:
    ## @param server.config.listenAddress Address for the server to listen on.
    ##
    listenAddress: ":80"

    ## @param server.config.exposedAddress Public address that peers use to connect.
    ## Format: protocol://hostname:port (e.g., "https://netbird.example.com:443")
    ##
    exposedAddress: ""

    ## @param server.config.stunPorts STUN server ports (defaults to [3478] if not specified).
    ##
    stunPorts: []

    ## @param server.config.metricsPort Metrics endpoint port.
    ##
    metricsPort: 9090

    ## @param server.config.healthcheckAddress Healthcheck endpoint address.
    ##
    healthcheckAddress: ":9000"

    ## @param server.config.logLevel Log level: panic, fatal, error, warn, info, debug, trace.
    ##
    logLevel: "info"

    ## @param server.config.logFile Log file location ("console" or path).
    ##
    logFile: "console"

    ## TLS configuration
    tls:
      ## @param server.config.tls.enabled Enable TLS.
      ##
      enabled: false

      ## @param server.config.tls.certFile Path to TLS certificate file.
      ##
      certFile: ""

      ## @param server.config.tls.keyFile Path to TLS key file.
      ##
      keyFile: ""

      letsencrypt:
        ## @param server.config.tls.letsencrypt.enabled Enable Let's Encrypt.
        ##
        enabled: false

        ## @param server.config.tls.letsencrypt.dataDir Let's Encrypt data directory.
        ##
        dataDir: ""

        ## @param server.config.tls.letsencrypt.domains Domains for Let's Encrypt certificate.
        ##
        domains: []

        ## @param server.config.tls.letsencrypt.email Email for Let's Encrypt.
        ##
        email: ""

        ## @param server.config.tls.letsencrypt.awsRoute53 Use AWS Route53 for DNS validation.
        ##
        awsRoute53: false

    ## @param server.config.authSecret Shared secret for relay authentication. Use ${VAR} for envsubst.
    ##
    authSecret: "${NB_AUTH_SECRET}"

    ## @param server.config.dataDir Data directory for all services.
    ##
    dataDir: "/var/lib/netbird/"

    ## @param server.config.disableAnonymousMetrics Disable anonymous metrics collection.
    ##
    disableAnonymousMetrics: false

    ## @param server.config.disableGeoliteUpdate Disable GeoLite database updates.
    ##
    disableGeoliteUpdate: false

    ## Authentication configuration
    auth:
      ## @param server.config.auth.issuer OIDC issuer URL.
      ##
      issuer: ""

      ## @param server.config.auth.localAuthDisabled Disable local authentication.
      ##
      localAuthDisabled: false

      ## @param server.config.auth.signKeyRefreshEnabled Enable signing key refresh.
      ##
      signKeyRefreshEnabled: false

      ## @param server.config.auth.dashboardRedirectURIs OAuth2 redirect URIs for dashboard.
      ##
      dashboardRedirectURIs: []

      ## @param server.config.auth.cliRedirectURIs OAuth2 redirect URIs for CLI.
      ##
      cliRedirectURIs:
        - "http://localhost:53000/"

      ## Optional initial admin user
      owner: {}
      #  email: "admin@example.com"
      #  password: "initial-password"

    ## Store configuration
    store:
      ## @param server.config.store.engine Store engine: sqlite, postgres, or mysql.
      ##
      engine: "sqlite"

      ## @param server.config.store.dsn Connection string for postgres or mysql. Use ${VAR} for envsubst.
      ##
      dsn: ""

      ## @param server.config.store.encryptionKey Encryption key for data store. Use ${VAR} for envsubst.
      ##
      encryptionKey: "${NB_ENCRYPTION_KEY}"

    ## Reverse proxy settings
    reverseProxy: {}
    #  trustedHTTPProxies: []
    #  trustedHTTPProxiesCount: 0
    #  trustedPeers: []

  ## Init container for envsubst processing
  initContainer:
    ## @param server.initContainer.enabled Enable init container for config processing.
    ##
    enabled: true

    image:
      ## @param server.initContainer.image.repository Docker image repository for init container.
      ##
      repository: alpine

      ## @param server.initContainer.image.tag Docker image tag for init container.
      ##
      tag: "3.19"

      ## @param server.initContainer.image.pullPolicy Docker image pull policy.
      ##
      pullPolicy: IfNotPresent

    ## @param server.initContainer.env Environment variables for init container.
    ##
    env: {}

    ## @param server.initContainer.envRaw Raw environment variables for init container.
    ##
    envRaw: []

    ## @param server.initContainer.envFromSecret Environment variables from secrets for envsubst.
    ## Format: ENV_VAR: secretName/secretKey
    ##
    envFromSecret: {}
    #  NB_AUTH_SECRET: netbird-secrets/auth-secret
    #  NB_ENCRYPTION_KEY: netbird-secrets/encryption-key
    #  NB_STORE_DSN: netbird-secrets/store-dsn

  ## @param server.env Environment variables for the server pod.
  ##
  env: {}

  ## @param server.envRaw Raw environment variables for the server pod.
  ##
  envRaw: []

  ## @param server.envFromSecret Environment variables from secrets.
  ##
  envFromSecret: {}

  ## @param server.lifecycle Lifecycle hooks for the server pod.
  ##
  lifecycle: {}

  metrics:
    ## @param server.metrics.enabled Enable metrics endpoint.
    ##
    enabled: false

    ## @param server.metrics.port Metrics port.
    ##
    port: 9090

  service:
    ## @param server.service.type Service type for the server component.
    ##
    type: ClusterIP

    ## @param server.service.port Port for the server service.
    ##
    port: 80

    ## @param server.service.name Name for the server service.
    ##
    name: http

    ## @param server.service.externalTrafficPolicy External traffic policy for LoadBalancer type.
    ##
    externalTrafficPolicy: ""

  serviceStun:
    ## @param server.serviceStun.enabled Enable STUN service.
    ##
    enabled: true

    ## @param server.serviceStun.type Service type for STUN (ClusterIP or LoadBalancer).
    ##
    type: ClusterIP

    ## @param server.serviceStun.port Port for STUN service.
    ##
    port: 3478

    ## @param server.serviceStun.externalTrafficPolicy External traffic policy for LoadBalancer type.
    ##
    externalTrafficPolicy: ""

  ingress:
    ## @param server.ingress.enabled Enable or disable ingress for HTTP paths.
    ##
    enabled: false

    ## @param server.ingress.className Ingress class name.
    ##
    className: ""

    ## @param server.ingress.annotations Annotations for the ingress resource.
    ##
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

    ## @param server.ingress.tls TLS settings for the ingress.
    ##
    tls: []

  ingressGrpc:
    ## @param server.ingressGrpc.enabled Enable or disable ingress for gRPC paths.
    ##
    enabled: false

    ## @param server.ingressGrpc.className Ingress class name for gRPC.
    ##
    className: ""

    ## @param server.ingressGrpc.annotations Annotations for the gRPC ingress resource.
    ##
    annotations: {}

    hosts:
      - host: netbird.example.com
        paths:
          - path: /signalexchange.SignalExchange/
            pathType: ImplementationSpecific
          - path: /management.ManagementService/
            pathType: ImplementationSpecific
          - path: /management.ProxyService/
            pathType: ImplementationSpecific

    ## @param server.ingressGrpc.tls TLS settings for gRPC ingress.
    ##
    tls: []

  ## @param server.resources Resource requests and limits for the server pod.
  ##
  resources: {}

  ## @param server.nodeSelector Node selector for scheduling the server pod.
  ##
  nodeSelector: {}

  ## @param server.tolerations Tolerations for scheduling the server pod.
  ##
  tolerations: []

  ## @param server.affinity Affinity rules for scheduling the server pod.
  ##
  affinity: {}

  persistentVolume:
    ## @param server.persistentVolume.enabled Enable or disable persistent volume.
    ##
    enabled: true

    ## @param server.persistentVolume.accessModes Access modes for the persistent volume.
    ##
    accessModes:
      - ReadWriteOnce

    ## @param server.persistentVolume.size Size of the persistent volume.
    ##
    size: 10Mi

    ## @param server.persistentVolume.storageClass Storage Class of the persistent volume.
    ##
    storageClass: null

    ## @param server.persistentVolume.existingPVName Name of an existing persistent volume.
    ##
    existingPVName: ""

    ## @param server.persistentVolume.annotations Annotations for the PVC.
    ##
    annotations: {}

  ## @param server.livenessProbe Liveness probe for the server component.
  ##
  livenessProbe:
    failureThreshold: 3
    initialDelaySeconds: 15
    periodSeconds: 10
    timeoutSeconds: 3
    httpGet:
      path: /health
      port: 9000

  ## @param server.readinessProbe Readiness probe for the server component.
  ##
  readinessProbe:
    failureThreshold: 3
    initialDelaySeconds: 15
    periodSeconds: 10
    timeoutSeconds: 3
    httpGet:
      path: /health
      port: 9000

  ## @param server.volumeMounts Volume mounts for the server pod.
  ##
  volumeMounts: []

  ## @param server.volumes Volumes for the server pod.
  ##
  volumes: []

  ## @param server.gracefulShutdown Add delay before pod shutdown for graceful connection closing.
  ##
  gracefulShutdown: true

## @section NetBird Dashboard Parameters

dashboard:
  ## @param dashboard.enabled Enable or disable the NetBird dashboard component.
  ##
  enabled: true

  ## @param dashboard.podCommand Define the arguments for the dashboard pod.
  ##
  podCommand:
    args: []

  ## @param replicaCount Number of replicas to deploy
  replicaCount: 1

  image:
    ## @param image.repository image repository
    repository: netbirdio/dashboard

    ## @param image.pullPolicy image pull policy
    pullPolicy: IfNotPresent

    ## @param image.tag image tag (immutable tags are recommended)
    tag: "v2.22.2"

  ## @param imagePullSecrets image pull secrets
  imagePullSecrets: []

  serviceAccount:
    ## @param dashboard.serviceAccount.create Specifies whether to create a service account
    create: true

    ## @param dashboard.serviceAccount.annotations Annotations to add to the service account
    annotations: {}

    ## @param serviceAccount.name Name of the service account to use.
    name: ""

  ## @param dashboard.podAnnotations Annotations for pods
  podAnnotations: {}

  ## @param podSecurityContext Pod security context
  podSecurityContext: {}

  ## @param dashboard.securityContext Container security context
  securityContext: {}

  ## @param dashboard.containerPort Container port
  containerPort: 80

  service:
    ## @param dashboard.service.type Service type
    type: ClusterIP

    ## @param dashboard.service.port Service port
    port: 80

    ## @param dashboard.service.name Service name
    name: http

  ingress:
    ## @param dashboard.ingress.enabled Enable ingress
    enabled: false

    ## @param dashboard.ingress.className Ingress class name
    className: ""

    ## @param dashboard.ingress.annotations Ingress annotations
    annotations: {}

    hosts:
      - host: chart-example.local
        paths:
          - path: /
            pathType: ImplementationSpecific

    ## @param dashboard.ingress.tls TLS configuration
    tls: []

  ## @param dashboard.resources Resource limits and requests
  resources: {}

  ## @param dashboard.nodeSelector Node selector
  nodeSelector: {}

  ## @param dashboard.tolerations Tolerations
  tolerations: []

  ## @param dashboard.affinity Affinity rules
  affinity: {}

  ## @param dashboard.env Environment variables
  env: {}

  ## @param dashboard.envRaw Raw environment variables
  envRaw: []

  ## @param dashboard.envFromSecret Environment variables from secrets
  envFromSecret: {}

  ## @param dashboard.lifecycle Lifecycle hooks
  lifecycle: {}

  ## @param dashboard.livenessProbe Liveness probe
  livenessProbe:
    periodSeconds: 5
    httpGet:
      path: /
      port: http

  ## @param dashboard.readinessProbe Readiness probe
  readinessProbe:
    initialDelaySeconds: 5
    periodSeconds: 5
    httpGet:
      path: /
      port: http

  ## @param dashboard.volumeMounts Volume mounts
  volumeMounts: []

  ## @param dashboard.volumes Volumes
  volumes: []

  ## @param dashboard.initContainers Init containers
  initContainers: []

## @section Extra Manifests

extraManifests: {}

## @section Prometheus metrics

metrics:
  ## Prometheus Operator ServiceMonitor configuration
  serviceMonitor:
    ## @param metrics.serviceMonitor.enabled Create a Prometheus Operator ServiceMonitor
    enabled: false

    ## @param metrics.serviceMonitor.namespace Namespace for Prometheus
    namespace: ""

    ## @param metrics.serviceMonitor.annotations Annotations for ServiceMonitor
    annotations: {}

    ## @param metrics.serviceMonitor.labels Labels for ServiceMonitor
    labels: {}

    ## @param metrics.serviceMonitor.jobLabel Job label
    jobLabel: ""

    ## @param metrics.serviceMonitor.honorLabels Honor labels
    honorLabels: false

    ## @param metrics.serviceMonitor.interval Scrape interval
    interval: ""

    ## @param metrics.serviceMonitor.scrapeTimeout Scrape timeout
    scrapeTimeout: ""

    ## @param metrics.serviceMonitor.metricRelabelings Metric relabelings
    metricRelabelings: []

    ## @param metrics.serviceMonitor.relabelings Relabelings
    relabelings: []

    ## @param metrics.serviceMonitor.selector Prometheus selector
    selector: {}
```

**Step 2: Commit**

```bash
git add charts/netbird/values.yaml
git commit -m "refactor(values): replace component values with unified server schema"
```

---

## Task 11: Update service-monitor.yaml

**Files:**
- Modify: `charts/netbird/templates/service-monitor.yaml`

**Step 1: Update selector labels**

Replace management selector with server selector:

```yaml
{{- if and .Values.server.metrics.enabled .Values.metrics.serviceMonitor.enabled -}}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "netbird.fullname" . }}
  namespace: {{ .Values.metrics.serviceMonitor.namespace | default (include "netbird.namespace" .) }}
  labels:
    {{- include "netbird.server.labels" . | nindent 4 }}
    {{- with .Values.metrics.serviceMonitor.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.metrics.serviceMonitor.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  endpoints:
    - port: metrics
      {{- with .Values.metrics.serviceMonitor.interval }}
      interval: {{ . }}
      {{- end }}
      {{- with .Values.metrics.serviceMonitor.scrapeTimeout }}
      scrapeTimeout: {{ . }}
      {{- end }}
      {{- with .Values.metrics.serviceMonitor.metricRelabelings }}
      metricRelabelings:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.metrics.serviceMonitor.relabelings }}
      relabelings:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      path: /metrics
  namespaceSelector:
    matchNames:
      - {{ include "netbird.namespace" . }}
  selector:
    matchLabels:
      {{- include "netbird.server.selectorLabels" . | nindent 6 }}
{{- end -}}
```

**Step 2: Commit**

```bash
git add charts/netbird/templates/service-monitor.yaml
git commit -m "refactor(service-monitor): update selector for unified server"
```

---

## Task 12: Delete Old Templates

**Files:**
- Delete: `charts/netbird/templates/management-*.yaml`
- Delete: `charts/netbird/templates/signal-*.yaml`
- Delete: `charts/netbird/templates/relay-*.yaml`

**Step 1: Delete old templates**

```bash
rm charts/netbird/templates/management-deployment.yaml
rm charts/netbird/templates/management-service.yaml
rm charts/netbird/templates/management-service-grpc.yaml
rm charts/netbird/templates/management-ingress.yaml
rm charts/netbird/templates/management-ingress-grpc.yaml
rm charts/netbird/templates/management-cm.yaml
rm charts/netbird/templates/management-pvc.yaml
rm charts/netbird/templates/management-serviceaccount.yaml
rm charts/netbird/templates/signal-deployment.yaml
rm charts/netbird/templates/signal-service.yaml
rm charts/netbird/templates/signal-ingress.yaml
rm charts/netbird/templates/signal-serviceaccount.yaml
rm charts/netbird/templates/relay-deployment.yaml
rm charts/netbird/templates/relay-service.yaml
rm charts/netbird/templates/relay-ingress.yaml
rm charts/netbird/templates/relay-serviceaccount.yaml
```

**Step 2: Commit**

```bash
git add -A charts/netbird/templates/
git commit -m "refactor: remove separate management/signal/relay templates"
```

---

## Task 13: Update Chart.yaml

**Files:**
- Modify: `charts/netbird/Chart.yaml`

**Step 1: Bump version to 2.0.0**

```yaml
---
apiVersion: v2
name: netbird
description: NetBird VPN management platform
type: application
version: 2.0.0
appVersion: "0.60.2"
icon: https://images.crunchbase.com/image/upload/c_pad,h_256,w_256,f_auto,q_auto:eco,dpr_1/kuu5tm1wt09ztp6ctlag
```

**Step 2: Commit**

```bash
git add charts/netbird/Chart.yaml
git commit -m "chore: bump chart version to 2.0.0 for unified server architecture"
```

---

## Task 14: Create Minimal Example

**Files:**
- Create: `charts/netbird/examples/minimal/values.yaml`

**Step 1: Create minimal example**

```yaml
fullnameOverride: netbird

server:
  enabled: true
  config:
    exposedAddress: "https://netbird.example.com:443"
    auth:
      issuer: "https://idp.example.com/oauth2"
      dashboardRedirectURIs:
        - "https://app.example.com/nb-auth"
        - "https://app.example.com/nb-silent-auth"
  initContainer:
    envFromSecret:
      NB_AUTH_SECRET: netbird-secrets/auth-secret
      NB_ENCRYPTION_KEY: netbird-secrets/encryption-key

dashboard:
  enabled: true
  env:
    NETBIRD_MGMT_API_ENDPOINT: https://netbird.example.com
    NETBIRD_MGMT_GRPC_API_ENDPOINT: https://netbird.example.com
    AUTH_AUTHORITY: https://idp.example.com/oauth2
    USE_AUTH0: false
    AUTH_SUPPORTED_SCOPES: "openid profile email offline_access"
  envFromSecret:
    AUTH_CLIENT_ID: netbird-secrets/idp-client-id
```

**Step 2: Commit**

```bash
git add charts/netbird/examples/minimal/values.yaml
git commit -m "docs(examples): add minimal configuration example"
```

---

## Task 15: Create Traefik Example

**Files:**
- Create: `charts/netbird/examples/traefik-ingress/authentik/values.yaml`
- Delete: `charts/netbird/examples/nginx-ingress/`
- Delete: `charts/netbird/examples/istio/`
- Delete: `charts/netbird/examples/traefik-ingress/` (existing)

**Step 1: Delete old examples**

```bash
rm -rf charts/netbird/examples/nginx-ingress
rm -rf charts/netbird/examples/istio
rm -rf charts/netbird/examples/traefik-ingress
```

**Step 2: Create Traefik example**

```yaml
fullnameOverride: netbird

server:
  enabled: true
  config:
    exposedAddress: "https://netbird.example.com:443"
    auth:
      issuer: "https://idp.example.com/application/o/netbird/"
      dashboardRedirectURIs:
        - "https://app.example.com/nb-auth"
        - "https://app.example.com/nb-silent-auth"
    store:
      engine: "postgres"
      dsn: "${NB_STORE_DSN}"
  initContainer:
    envFromSecret:
      NB_AUTH_SECRET: netbird-secrets/auth-secret
      NB_ENCRYPTION_KEY: netbird-secrets/encryption-key
      NB_STORE_DSN: netbird-secrets/store-dsn
  ingress:
    enabled: true
    className: traefik
    annotations:
      traefik.ingress.kubernetes.io/router.entrypoints: websecure
      traefik.ingress.kubernetes.io/router.tls: "true"
      traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt
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
    tls:
      - secretName: netbird-tls
        hosts:
          - netbird.example.com
  ingressGrpc:
    enabled: true
    className: traefik
    annotations:
      traefik.ingress.kubernetes.io/router.entrypoints: websecure
      traefik.ingress.kubernetes.io/router.tls: "true"
      traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt
      traefik.ingress.kubernetes.io/backend.protocol: h2c
    hosts:
      - host: netbird.example.com
        paths:
          - path: /signalexchange.SignalExchange/
            pathType: ImplementationSpecific
          - path: /management.ManagementService/
            pathType: ImplementationSpecific
          - path: /management.ProxyService/
            pathType: ImplementationSpecific
    tls:
      - secretName: netbird-tls
        hosts:
          - netbird.example.com

dashboard:
  enabled: true
  env:
    NETBIRD_MGMT_API_ENDPOINT: https://netbird.example.com
    NETBIRD_MGMT_GRPC_API_ENDPOINT: https://netbird.example.com
    AUTH_AUTHORITY: https://idp.example.com/application/o/netbird/
    USE_AUTH0: false
    AUTH_SUPPORTED_SCOPES: "openid profile email offline_access api"
  envFromSecret:
    AUTH_CLIENT_ID: netbird-secrets/idp-client-id
    AUTH_AUDIENCE: netbird-secrets/idp-client-id
```

**Step 3: Commit**

```bash
git add charts/netbird/examples/
git commit -m "docs(examples): update examples for unified server architecture"
```

---

## Task 16: Validate Chart

**Files:**
- N/A (validation only)

**Step 1: Run helm lint**

```bash
helm lint charts/netbird
```

Expected: `1 chart(s) linted, 0 chart(s) failed`

**Step 2: Run kubeconform validation**

```bash
helm template x charts/netbird --include-crds > helm_output.yaml && \
  cat helm_output.yaml | kubeconform -summary -strict -ignore-missing-schemas -kubernetes-version=1.30.0 -cache /tmp
```

Expected: All resources pass validation

**Step 3: Fix any issues**

If validation fails, fix the issues in the relevant templates and commit fixes.

---

## Task 17: Update README

**Files:**
- Modify: `charts/netbird/README.md`

**Step 1: Update README with new values structure**

Update the README to reflect the new unified server architecture, including:
- New `server` section replacing `management`, `signal`, `relay`
- Config YAML structure
- Init container for envsubst
- Migration notes from 1.x to 2.x

(Exact README content depends on existing structure - update accordingly)

**Step 2: Commit**

```bash
git add charts/netbird/README.md
git commit -m "docs: update README for unified server architecture"
```

---

## Summary

**Files Changed:**
- Modified: `_helpers.tpl`, `values.yaml`, `Chart.yaml`, `service-monitor.yaml`, `README.md`
- Created: `server-cm.yaml`, `server-pvc.yaml`, `server-serviceaccount.yaml`, `server-service.yaml`, `server-service-stun.yaml`, `server-ingress.yaml`, `server-ingress-grpc.yaml`, `server-deployment.yaml`
- Deleted: All `management-*.yaml`, `signal-*.yaml`, `relay-*.yaml`
- Examples: Updated for new architecture

**Breaking Changes:**
- `management`, `signal`, `relay` sections replaced with single `server` section
- Configuration format changed from JSON to YAML with envsubst placeholders
- Requires chart version 2.0.0
