{{/*
Expand the name of the chart.
*/}}
{{- define "difi.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "difi.fullname" -}}
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
{{- define "difi.difi.fullname" -}}
{{ template "difi.fullname" . }}-api
{{- end -}}

{{/*
Create a default fully qualified worker name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "difi.difi.fullname" -}}
{{ template "difi.fullname" . }}-api
{{- end -}}


{{/*
Create a default fully qualified nginx name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "difi.difi.fullname" -}}
{{ template "difi.fullname" . }}-proxy
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "difi.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "difi.labels" -}}
helm.sh/chart: {{ include "difi.chart" . }}
{{ include "difi.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* labels defiend by user*/}}
{{- define "difi.ud.labels" -}}
{{- if .Values.labels }}
{{- toYaml .Values.labels }}
{{- end -}}
{{- end -}}

{{/* annotations defiend by user*/}}
{{- define "difi.ud.annotations" -}}
{{- if .Values.annotations }}
{{- toYaml .Values.annotations }}
{{- end -}}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "difi.selectorLabels" -}}
app.kubernetes.io/name: {{ include "difi.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "difi.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "difi.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
