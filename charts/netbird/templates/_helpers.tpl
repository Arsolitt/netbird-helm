{{/*
Expand the name of the chart.
*/}}
{{- define "netbird.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "netbird.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "netbird.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "netbird.common.labels" -}}
helm.sh/chart: {{ include "netbird.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

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

{{/*
Common dashboard labels
*/}}
{{- define "netbird.dashboard.labels" -}}
helm.sh/chart: {{ include "netbird.chart" . }}
{{ include "netbird.dashboard.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Dashboard selector labels
*/}}
{{- define "netbird.dashboard.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netbird.name" . }}-dashboard
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the dashboard service account to use
*/}}
{{- define "netbird.dashboard.serviceAccountName" -}}
{{- if .Values.dashboard.serviceAccount.create }}
{{- default (printf "%s-dashboard" (include "netbird.fullname" .)) .Values.dashboard.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.dashboard.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Allow the release namespace to be overridden
*/}}
{{- define "netbird.namespace" -}}
{{- default .Release.Namespace .Values.global.namespace -}}
{{- end -}}

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
