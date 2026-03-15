# Security Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Apply security hardening to all NetBird chart components with non-root execution, read-only filesystems, and unprivileged ports.

**Architecture:** Explicit security context defaults in values.yaml for each component. Add tmpfs volumes for /tmp. Update container ports to >1024.

**Tech Stack:** Helm, Kubernetes security contexts

---

### Task 1: Update values.yaml - Security Contexts for All Components

**Files:**
- Modify: `charts/netbird/values.yaml`

**Step 1: Add security contexts to management component**

Find line ~78-84 (management.podSecurityContext and management.securityContext). Replace empty `{}` with:

```yaml
  ## @param management.podSecurityContext Security context for the management pod(s).
  ##
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 2222
    runAsGroup: 2222
    fsGroup: 2222
    seccompProfile:
      type: RuntimeDefault

  ## @param management.securityContext Security context for the management container.
  ##
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```

**Step 2: Add security contexts to signal component**

Find line ~334-340 (signal.podSecurityContext and signal.securityContext). Replace empty `{}` with:

```yaml
  ## @param signal.podSecurityContext Security context for the signal pod(s).
  ##
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 2222
    runAsGroup: 2222
    fsGroup: 2222
    seccompProfile:
      type: RuntimeDefault

  ## @param signal.securityContext Security context for the signal container.
  ##
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```

**Step 3: Add security contexts to relay component**

Find line ~504-510 (relay.podSecurityContext and relay.securityContext). Replace empty `{}` with:

```yaml
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
```

**Step 4: Add security contexts to server component**

Find line ~698-704 (server.podSecurityContext and server.securityContext). Replace empty `{}` with:

```yaml
  ## @param server.podSecurityContext Security context for the server pod(s).
  ##
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 2222
    runAsGroup: 2222
    fsGroup: 2222
    seccompProfile:
      type: RuntimeDefault

  ## @param server.securityContext Security context for the server container.
  ##
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```

**Step 5: Add security contexts to dashboard component**

Find line ~1107-1111 (dashboard.podSecurityContext and dashboard.securityContext). Replace empty `{}` with:

```yaml
  ## @param dashboard.podSecurityContext Pod security context
  ##
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 2222
    runAsGroup: 2222
    fsGroup: 2222
    seccompProfile:
      type: RuntimeDefault

  ## @param dashboard.securityContext Container security context
  ##
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```

**Step 6: Commit**

```bash
git add charts/netbird/values.yaml
git commit -m "feat: add security context defaults to all components"
```

---

### Task 2: Update values.yaml - Port Changes

**Files:**
- Modify: `charts/netbird/values.yaml`

**Step 1: Update management ports**

Find and update:
- Line ~88: `containerPort: 80` → `containerPort: 8080`

**Step 2: Update signal ports**

Find and update:
- Line ~344: `containerPort: 80` → `containerPort: 8080`

**Step 3: Update server ports**

Find and update:
- Line ~708: `containerPort: 80` → `containerPort: 8080`
- Line ~928: `port: 3478` → `port: 53478` (server.serviceStun.port)

**Step 4: Update dashboard ports**

Find and update:
- Line ~1114: `containerPort: 80` → `containerPort: 8080`

**Step 5: Update relay STUN ports**

Find and update:
- Line ~546-548: `ports: - 3478` → `ports: - 53478`

**Step 6: Commit**

```bash
git add charts/netbird/values.yaml
git commit -m "feat: update container ports to unprivileged (>1024)"
```

---

### Task 3: Update management-deployment.yaml

**Files:**
- Modify: `charts/netbird/templates/management-deployment.yaml`

**Step 1: Add tmpfs volume**

After line 152 (`{{- if .Values.management.volumes }}`), before the volumes block, add tmpfs volume:

Find the volumes section (around line 136). Add tmpfs volume after the existing volumes but before user volumes:

```yaml
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
        - name: tmp
          emptyDir:
            medium: Memory
        {{- if .Values.management.volumes }}
        {{- .Values.management.volumes | toYaml | nindent 8 }}
        {{- end }}
```

**Step 2: Add tmpfs volumeMount**

Find the volumeMounts section (around line 82). Add tmp mount:

```yaml
          volumeMounts:
            - name: config
              mountPath: /etc/netbird
              readOnly: true
            - name: management-data
              mountPath: /var/lib/netbird
            - name: tmp
              mountPath: /tmp
          {{- if .Values.management.volumeMounts }}
          {{- .Values.management.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
```

**Step 3: Commit**

```bash
git add charts/netbird/templates/management-deployment.yaml
git commit -m "feat(management): add tmpfs volume for security hardening"
```

---

### Task 4: Update signal-deployment.yaml

**Files:**
- Modify: `charts/netbird/templates/signal-deployment.yaml`

**Step 1: Add tmpfs volume**

The signal component has optional volumes. Add tmpfs as a default volume. Find line ~100-103:

Replace:
```yaml
      {{- if .Values.signal.volumes }}
      volumes:
      {{- .Values.signal.volumes | toYaml | nindent 8 }}
      {{- end }}
```

With:
```yaml
      volumes:
        - name: tmp
          emptyDir:
            medium: Memory
        {{- if .Values.signal.volumes }}
        {{- .Values.signal.volumes | toYaml | nindent 8 }}
        {{- end }}
```

**Step 2: Add tmpfs volumeMount**

Find the volumeMounts section (around line 63-66). Add tmp mount unconditionally:

Replace:
```yaml
          {{- if .Values.signal.volumeMounts }}
          volumeMounts:
          {{- .Values.signal.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
```

With:
```yaml
          volumeMounts:
            - name: tmp
              mountPath: /tmp
          {{- if .Values.signal.volumeMounts }}
          {{- .Values.signal.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
```

**Step 3: Commit**

```bash
git add charts/netbird/templates/signal-deployment.yaml
git commit -m "feat(signal): add tmpfs volume for security hardening"
```

---

### Task 5: Update relay-deployment.yaml

**Files:**
- Modify: `charts/netbird/templates/relay-deployment.yaml`

**Step 1: Add tmpfs volume**

Find line ~113-116. Replace:
```yaml
      {{- if .Values.relay.volumes }}
      volumes:
      {{- .Values.relay.volumes | toYaml | nindent 8 }}
      {{- end }}
```

With:
```yaml
      volumes:
        - name: tmp
          emptyDir:
            medium: Memory
        {{- if .Values.relay.volumes }}
        {{- .Values.relay.volumes | toYaml | nindent 8 }}
        {{- end }}
```

**Step 2: Add tmpfs volumeMount**

Find line ~70-73. Replace:
```yaml
          {{- if .Values.relay.volumeMounts }}
          volumeMounts:
          {{- .Values.relay.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
```

With:
```yaml
          volumeMounts:
            - name: tmp
              mountPath: /tmp
          {{- if .Values.relay.volumeMounts }}
          {{- .Values.relay.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
```

**Step 3: Commit**

```bash
git add charts/netbird/templates/relay-deployment.yaml
git commit -m "feat(relay): add tmpfs volume for security hardening"
```

---

### Task 6: Update server-deployment.yaml

**Files:**
- Modify: `charts/netbird/templates/server-deployment.yaml`

**Step 1: Add securityContext to init container**

Find line ~46-78 (init container spec). Add securityContext after imagePullPolicy:

```yaml
      initContainers:
        - name: config-processor
          image: "{{ .Values.server.initContainer.image.repository }}:{{ .Values.server.initContainer.image.tag }}"
          imagePullPolicy: {{ .Values.server.initContainer.image.pullPolicy }}
          securityContext:
            runAsNonRoot: true
            runAsUser: 2222
            runAsGroup: 2222
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          command: ["/bin/sh", "-c"]
```

**Step 2: Add tmpfs volume**

Find the volumes section (around line 165-180). Add tmp volume:

```yaml
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
        - name: tmp
          emptyDir:
            medium: Memory
        {{- if .Values.server.volumes }}
        {{- .Values.server.volumes | toYaml | nindent 8 }}
        {{- end }}
```

**Step 3: Add tmpfs volumeMount to main container**

Find the volumeMounts section (around line 130-138). Add tmp mount:

```yaml
          volumeMounts:
            - name: config-rendered
              mountPath: /etc/netbird
              readOnly: true
            - name: server-data
              mountPath: /var/lib/netbird
            - name: tmp
              mountPath: /tmp
          {{- if .Values.server.volumeMounts }}
          {{- .Values.server.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
```

**Step 4: Commit**

```bash
git add charts/netbird/templates/server-deployment.yaml
git commit -m "feat(server): add tmpfs volume and security context to init container"
```

---

### Task 7: Update dashboard-deployment.yaml

**Files:**
- Modify: `charts/netbird/templates/dashboard-deployment.yaml`

**Step 1: Add tmpfs volume**

Find line ~92-95. Replace:
```yaml
      {{- if .Values.dashboard.volumes }}
      volumes:
      {{- .Values.dashboard.volumes | toYaml | nindent 8 }}
      {{- end }}
```

With:
```yaml
      volumes:
        - name: tmp
          emptyDir:
            medium: Memory
        {{- if .Values.dashboard.volumes }}
        {{- .Values.dashboard.volumes | toYaml | nindent 8 }}
        {{- end }}
```

**Step 2: Add tmpfs volumeMount**

Find line ~88-91. Replace:
```yaml
          {{- if .Values.dashboard.volumeMounts }}
          volumeMounts:
          {{- .Values.dashboard.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
```

With:
```yaml
          volumeMounts:
            - name: tmp
              mountPath: /tmp
          {{- if .Values.dashboard.volumeMounts }}
          {{- .Values.dashboard.volumeMounts | toYaml | nindent 12 }}
          {{- end }}
```

**Step 3: Commit**

```bash
git add charts/netbird/templates/dashboard-deployment.yaml
git commit -m "feat(dashboard): add tmpfs volume for security hardening"
```

---

### Task 8: Validation

**Files:**
- None (validation only)

**Step 1: Run helm lint**

```bash
helm lint charts/netbird
```

Expected: `1 chart(s) linted, 0 chart(s) failed`

**Step 2: Run full validation (same as CI)**

```bash
helm dep up charts/netbird && \
  helm template x charts/netbird --include-crds > helm_output.yaml && \
  cat helm_output.yaml | kubeconform -summary -strict -ignore-missing-schemas -kubernetes-version=1.30.0 -cache /tmp && \
  cat helm_output.yaml | kubeconform -summary -strict -ignore-missing-schemas -kubernetes-version=1.31.0 -cache /tmp
```

Expected: `Summary: ... valid, 0 invalid, 0 errors`

**Step 3: Verify security contexts in rendered output**

```bash
helm template x charts/netbird --include-crds | grep -A 20 "securityContext:" | head -50
```

Expected: See `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, etc.

**Step 4: Commit validation**

```bash
git add -A
git commit -m "chore: validate security hardening changes"
```
