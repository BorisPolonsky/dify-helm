{{/*
Expand the name of the chart.
*/}}
{{- define "dify.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dify.fullname" -}}
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
Create a default fully qualified api name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "dify.api.fullname" -}}
{{ template "dify.fullname" . }}-api
{{- end -}}

{{/*
Create a default fully qualified worker name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "dify.worker.fullname" -}}
{{ template "dify.fullname" . }}-worker
{{- end -}}

{{/*
Create a default fully qualified web name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "dify.web.fullname" -}}
{{ template "dify.fullname" . }}-web
{{- end -}}

{{/*
Create a default fully qualified web name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "dify.sandbox.fullname" -}}
{{ template "dify.fullname" . }}-sandbox
{{- end -}}

{{/*
Create a default fully qualified web name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "dify.ssrfProxy.fullname" -}}
{{ template "dify.fullname" . }}-ssrf-proxy
{{- end -}}

{{/*
Create a default fully qualified nginx name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "dify.nginx.fullname" -}}
{{ template "dify.fullname" . }}-proxy
{{- end -}}

{{/*
Create a default fully qualified plugin-daemon name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "dify.pluginDaemon.fullname" -}}
{{ template "dify.fullname" . }}-plugin-daemon
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dify.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dify.labels" -}}
helm.sh/chart: {{ include "dify.chart" . }}
{{ include "dify.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* labels defiend by user*/}}
{{- define "dify.ud.labels" -}}
{{- if .Values.labels }}
{{- toYaml .Values.labels }}
{{- end -}}
{{- end -}}

{{/* annotations defiend by user*/}}
{{- define "dify.ud.annotations" -}}
{{- if .Values.annotations }}
{{- toYaml .Values.annotations }}
{{- end -}}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "dify.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dify.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use for the Dify API
*/}}
{{- define "dify.api.serviceAccountName" -}}
{{- if .Values.api.serviceAccount.create -}}
    {{ default (include "dify.api.fullname" .) .Values.api.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.api.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the Proxy
*/}}
{{- define "dify.proxy.serviceAccountName" -}}
{{- if .Values.proxy.serviceAccount.create -}}
    {{ default (include "dify.nginx.fullname" .) .Values.proxy.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.proxy.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the Sandbox
*/}}
{{- define "dify.sandbox.serviceAccountName" -}}
{{- if .Values.sandbox.serviceAccount.create -}}
    {{ default (include "dify.sandbox.fullname" .) .Values.sandbox.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.sandbox.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the ssrfProxy
*/}}
{{- define "dify.ssrfProxy.serviceAccountName" -}}
{{- if .Values.ssrfProxy.serviceAccount.create -}}
    {{ default (include "dify.ssrfProxy.fullname" .) .Values.ssrfProxy.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.ssrfProxy.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the Web
*/}}
{{- define "dify.web.serviceAccountName" -}}
{{- if .Values.web.serviceAccount.create -}}
    {{ default (include "dify.web.fullname" .) .Values.web.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.web.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the Dify Worker
*/}}
{{- define "dify.worker.serviceAccountName" -}}
{{- if .Values.worker.serviceAccount.create -}}
    {{ default (include "dify.worker.fullname" .) .Values.worker.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.worker.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use for the Dify Plugin Daemon
*/}}
{{- define "dify.pluginDaemon.serviceAccountName" -}}
{{- if .Values.pluginDaemon.serviceAccount.create -}}
    {{ default (include "dify.pluginDaemon.fullname" .) .Values.pluginDaemon.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.pluginDaemon.serviceAccount.name }}
{{- end -}}
{{- end -}}
