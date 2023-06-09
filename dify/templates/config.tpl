{{- define "dify.api.config" -}}
# Startup mode, 'api' starts the API server.
MODE: api
# The log level for the application. Supported values are `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
LOG_LEVEL: INFO
# A secret key that is used for securely signing the session cookie and encrypting sensitive information on the database. You can generate a strong key using `openssl rand -base64 42`.
SECRET_KEY: {{ .Values.api.secretKey }}
# The base URL of console application, refers to the Console base URL of WEB service if console domain is
# different from api or web app domain.
# example: http://cloud.dify.ai
CONSOLE_URL: {{ .Values.api.url.console }}
# The URL for Service API endpoints，refers to the base URL of the current API service if api domain is
# different from console domain.
# example: http://api.dify.ai
API_URL: {{ .Values.api.url.api }}
# The URL for Web APP, refers to the Web App base URL of WEB service if web app domain is different from
# console or api domain.
# example: http://udify.app
APP_URL: {{ .Values.api.url.app }}
# When enabled, migrations will be executed prior to application startup and the application will start after the migrations have completed.
MIGRATION_ENABLED: {{ .Values.api.migration }}

# The configurations of postgres database connection.
# It is consistent with the configuration in the 'db' service below.
{{- include "dify.db.config" . }}

# The configurations of redis connection.
# It is consistent with the configuration in the 'redis' service below.
{{- include "dify.redis.config" . }}
{{/* The configurations of session, Supported values are `sqlalchemy`. `redis`*/}}
{{- include "dify.api.session.config" . }}
# The configurations of celery broker.
{{- include "dify.celery.config" . }}
# Specifies the allowed origins for cross-origin requests to the Web API, e.g. https://dify.app or * for all origins.
WEB_API_CORS_ALLOW_ORIGINS: '*'
# Specifies the allowed origins for cross-origin requests to the console API, e.g. https://cloud.dify.ai or * for all origins.
CONSOLE_CORS_ALLOW_ORIGINS: '*'
# CSRF Cookie settings
# Controls whether a cookie is sent with cross-site requests,
# providing some protection against cross-site request forgery attacks
#
# Default: `SameSite=Lax, Secure=false, HttpOnly=true`
# This default configuration supports same-origin requests using either HTTP or HTTPS,
# but does not support cross-origin requests. It is suitable for local debugging purposes.
#
# If you want to enable cross-origin support,
# you must use the HTTPS protocol and set the configuration to `SameSite=None, Secure=true, HttpOnly=true`.
#
# For **production** purposes, please set `SameSite=Lax, Secure=true, HttpOnly=true`.
COOKIE_HTTPONLY: 'true'
COOKIE_SAMESITE: 'Lax'
COOKIE_SECURE: 'false'

{{- include "dify.storage.config" . }}
# The type of vector store to use. Supported values are `weaviate`, `qdrant`.
VECTOR_STORE: weaviate
# The Weaviate endpoint URL. Only available when VECTOR_STORE is `weaviate`.
WEAVIATE_ENDPOINT: http://weaviate:8080
# The Weaviate API key.
WEAVIATE_API_KEY: WVF5YThaHlkYwhGUSmCRgsX3tD5ngdN8pkih
# The Qdrant endpoint URL. Only available when VECTOR_STORE is `qdrant`.
QDRANT_URL: 'https://your-qdrant-cluster-url.qdrant.tech/'
# The Qdrant API key.
QDRANT_API_KEY: 'ak-difyai'
# The DSN for Sentry error reporting. If not set, Sentry error reporting will be disabled.
SENTRY_DSN: ''
# The sample rate for Sentry events. Default: `1.0`
SENTRY_TRACES_SAMPLE_RATE: 1.0
# The sample rate for Sentry profiles. Default: `1.0`
SENTRY_PROFILES_SAMPLE_RATE: 1.0
{{- end }}


{{- define "dify.worker.config" -}}
# worker service
# The Celery worker for processing the queue.
# Startup mode, 'worker' starts the Celery worker for processing the queue.
MODE: worker

# --- All the configurations below are the same as those in the 'api' service. ---

# The log level for the application. Supported values are `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
LOG_LEVEL: INFO
# A secret key that is used for securely signing the session cookie and encrypting sensitive information on the database. You can generate a strong key using `openssl rand -base64 42`.
# same as the API service
SECRET_KEY: {{ .Values.api.secretKey }}
# The configurations of postgres database connection.
# It is consistent with the configuration in the 'db' service below.
{{ include "dify.db.config" . }}

# The configurations of redis cache connection.
{{- include "dify.redis.config" . }}
# The configurations of celery broker.
{{- include "dify.celery.config" . }}

{{- include "dify.storage.config" . }}
# The Vector store configurations.
VECTOR_STORE: weaviate
WEAVIATE_ENDPOINT: http://weaviate:8080
WEAVIATE_API_KEY: WVF5YThaHlkYwhGUSmCRgsX3tD5ngdN8pkih
{{- end }}

{{- define "dify.db.config" -}}
{{- if .Values.externalPostgres.enabled }}
DB_USERNAME: {{ .Values.externalPostgres.username }}
DB_PASSWORD: {{ .Values.externalPostgres.password }}
DB_HOST: {{ .Values.externalPostgres.address }}
DB_PORT: {{ .Values.externalPostgres.port }}
DB_DATABASE: {{ .Values.externalPostgres.dbName }}
{{- else if .Values.postgres.enabled }}
username: postgres
password: {{ .Values.postgres.auth.postgresPassword }}
{{- if contains .Values.postgres.name .Release.Name }}
  {{- if eq .Values.postgres.architecture "replication" }}
DB_HOST: {{ .Release.Name }}-primary
  {{- else }}
DB_HOST: {{ .Release.Name }}
  {{- end }}
{{- else }}
  {{- if eq .Values.postgres.architecture "replication" }}
DB_HOST: {{ .Release.Name }}-{{ .Values.postgres.name }}-primary
  {{- else }}
DB_HOST: {{ .Release.Name }}-{{ .Values.postgres.name }}
  {{- end }}
{{- end }}
DB_PORT: 5432
DB_DATABASE: {{ .Values.postgres.auth.database }}
{{- end }}
{{- end }}

{{- define "dify.storage.config" -}}
{{- if .Values.externalS3.enabled }}
# The type of storage to use for storing user files. Supported values are `local` and `s3`, Default: `local`
STORAGE_TYPE: s3
# The S3 storage configurations, only available when STORAGE_TYPE is `s3`.
S3_ENDPOINT: {{ .Values.externalS3.endpoint }}
S3_BUCKET_NAME: {{ .Values.externalS3.bucketName }}
S3_ACCESS_KEY: {{ .Values.externalS3.accessKey }}
S3_SECRET_KEY: {{ .Values.externalS3.secretKey }}
S3_REGION: 'us-east-1'
{{- else }}
# The type of storage to use for storing user files. Supported values are `local` and `s3`, Default: `local`
STORAGE_TYPE: local
# The path to the local storage directory, the directory relative the root path of API service codes or absolute path. Default: `storage` or `/home/john/storage`.
# only available when STORAGE_TYPE is `local`.
STORAGE_LOCAL_PATH: storage
{{- end }}
{{- end }}

{{- define "dify.redis.config" -}}
{{- if .Values.externalRedis.enabled }}
  {{- with .Values.externalRedis }}
REDIS_HOST: {{ .host | quote }}
REDIS_PORT: {{ .port | toString | quote }}
REDIS_USERNAME: {{ .username | quote }}
REDIS_PASSWORD: {{ .password | quote }}
REDIS_USE_SSL: {{ .useSSL | toString | quote }}
# use redis db 0 for redis cache
REDIS_DB: "0"
  {{- end }}
{{- else if .Values.redis.enabled }}
# Still WIP
{{- end }}
{{- end }}

{{- define "dify.celery.config" -}}
# Use redis as the broker, and redis db 1 for celery broker.
{{- if .Values.externalRedis.enabled }}
  {{- with .Values.externalRedis }}
CELERY_BROKER_URL: {{ printf "redis://:%s@%s:%v/1" .password .host .port }}
  {{- end }}
{{- else if .Values.redis.enabled }}
# Still WIP
{{- end }}
{{- end }}


{{- define "dify.api.session.config" -}}
{{/*No sqlalchemy support for now*/}}
# The configurations of session, Supported values are `sqlalchemy`. `redis`
SESSION_TYPE: redis
{{- if .Values.externalRedis.enabled }}
  {{- with .Values.externalRedis }}
SESSION_REDIS_HOST: {{ .host | quote }}
SESSION_REDIS_PORT: {{ .port | toString | quote }}
SESSION_REDIS_USERNAME: ""
SESSION_REDIS_PASSWORD: {{ .password | quote }}
SESSION_REDIS_USE_SSL: {{ .useSSL | toString | quote }}
  {{- end }}
{{- else if .Values.redis.enabled }}
# Still WIP
{{- end }}
# use redis db 2 for session store
SESSION_REDIS_DB: 2
{{- end }}

{{- define "dify.nginx.config.proxy" }}
proxy_set_header Host $host;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_http_version 1.1;
proxy_set_header Connection "";
proxy_buffering off;
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
{{- end }}

{{- define "dify.nginx.config.nginx" }}
user  nginx;
worker_processes  auto;
{{- if .Values.proxy.persistence.enabled }}
error_log  /var/log/nginx/error.log notice;
{{- end }}
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

{{- if .Values.proxy.persistence.enabled }}
    access_log  /var/log/nginx/access.log  main;
{{- end }}

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;
    client_max_body_size 15M;

    include /etc/nginx/conf.d/*.conf;
}
{{- end }}

{{- define "dify.nginx.config.default" }}
server {
    listen 80;
    server_name _;

    location /console/api {
      proxy_pass http://{{ template "dify.api.fullname" .}}:{{ .Values.api.service.port }};
      include proxy.conf;
    }

    location /api {
      proxy_pass http://{{ template "dify.api.fullname" .}}:5001;
      include proxy.conf;
    }

    location /v1 {
      proxy_pass http://{{ template "dify.api.fullname" .}}:5001;
      include proxy.conf;
    }

    location / {
      proxy_pass http://{{ template "dify.web.fullname" .}}:3000;
      include proxy.conf;
    }
}
{{- end }}
