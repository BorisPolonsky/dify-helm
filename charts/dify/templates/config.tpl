{{- define "dify.api.config" -}}
# Startup mode, 'api' starts the API server.
MODE: api
# The log level for the application. Supported values are `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
LOG_LEVEL: {{ .Values.api.logLevel }}
# A secret key that is used for securely signing the session cookie and encrypting sensitive information on the database. You can generate a strong key using `openssl rand -base64 42`.
# SECRET_KEY: {{ .Values.api.secretKey }}
# The base URL of console application web frontend, refers to the Console base URL of WEB service if console domain is
# different from api or web app domain.
# example: http://cloud.dify.ai
CONSOLE_WEB_URL: {{ .Values.api.url.consoleWeb | quote }}
# The base URL of console application api server, refers to the Console base URL of WEB service if console domain is
# different from api or web app domain.
# example: http://cloud.dify.ai
CONSOLE_API_URL: {{ .Values.api.url.consoleApi | quote }}
# The URL prefix for Service API endpoints, refers to the base URL of the current API service if api domain is
# different from console domain.
# example: http://api.dify.ai
SERVICE_API_URL: {{ .Values.api.url.serviceApi | quote }}
# The URL prefix for Web APP frontend, refers to the Web App base URL of WEB service if web app domain is different from
# console or api domain.
# example: http://udify.app
APP_WEB_URL: {{ .Values.api.url.appWeb | quote }}
# File preview or download Url prefix.
# used to display File preview or download Url to the front-end or as Multi-model inputs;
# Url is signed and has expiration time.
FILES_URL: {{ .Values.api.url.files | quote }}
# When enabled, migrations will be executed prior to application startup and the application will start after the migrations have completed.
MIGRATION_ENABLED: {{ .Values.api.migration | toString | quote }}

# The configurations of postgres database connection.
# It is consistent with the configuration in the 'db' service below.
{{- include "dify.db.config" . }}

# The configurations of redis connection.
# It is consistent with the configuration in the 'redis' service below.
{{- include "dify.redis.config" . }}

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

{{ include "dify.storage.config" . }}
{{ include "dify.vectordb.config" . }}
{{ include "dify.mail.config" . }}
# The DSN for Sentry error reporting. If not set, Sentry error reporting will be disabled.
SENTRY_DSN: ''
# The sample rate for Sentry events. Default: `1.0`
SENTRY_TRACES_SAMPLE_RATE: "1.0"
# The sample rate for Sentry profiles. Default: `1.0`
SENTRY_PROFILES_SAMPLE_RATE: "1.0"

{{- if .Values.sandbox.enabled }}
CODE_EXECUTION_ENDPOINT: http://{{ template "dify.sandbox.fullname" .}}:{{ .Values.sandbox.service.port }}
{{- end }}

{{- if .Values.ssrfProxy.enabled }}
SSRF_PROXY_HTTP_URL: http://{{ template "dify.ssrfProxy.fullname" .}}:{{ .Values.ssrfProxy.service.port }}
SSRF_PROXY_HTTPS_URL: http://{{ template "dify.ssrfProxy.fullname" .}}:{{ .Values.ssrfProxy.service.port }}
{{- end }}
{{- end }}

{{- define "dify.worker.config" -}}
# worker service
# The Celery worker for processing the queue.
# Startup mode, 'worker' starts the Celery worker for processing the queue.
MODE: worker

# The base URL of console application web frontend, refers to the Console base URL of WEB service if console domain is
# different from api or web app domain.
# example: http://cloud.dify.ai
CONSOLE_WEB_URL: {{ .Values.api.url.consoleWeb | quote }}
# --- All the configurations below are the same as those in the 'api' service. ---

# The log level for the application. Supported values are `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
LOG_LEVEL: {{ .Values.worker.logLevel | quote }}
# A secret key that is used for securely signing the session cookie and encrypting sensitive information on the database. You can generate a strong key using `openssl rand -base64 42`.
# same as the API service
# SECRET_KEY: {{ .Values.api.secretKey }}
# The configurations of postgres database connection.
# It is consistent with the configuration in the 'db' service below.
{{ include "dify.db.config" . }}

# The configurations of redis cache connection.
{{ include "dify.redis.config" . }}
# The configurations of celery broker.
{{ include "dify.celery.config" . }}

{{ include "dify.storage.config" . }}
# The Vector store configurations.
{{ include "dify.vectordb.config" . }}
{{ include "dify.mail.config" . }}
{{- end }}

{{- define "dify.web.config" -}}
# The base URL of console application api server, refers to the Console base URL of WEB service if console domain is
# different from api or web app domain.
# example: http://cloud.dify.ai
CONSOLE_API_URL: {{ .Values.api.url.consoleApi | quote }}
# The URL for Web APP api server, refers to the Web App base URL of WEB service if web app domain is different from
# console or api domain.
# example: http://udify.app
APP_API_URL: {{ .Values.api.url.appApi | quote }}
# The DSN for Sentry
{{- end }}

{{- define "dify.db.config" -}}
{{- if .Values.externalPostgres.enabled }}
# DB_USERNAME: {{ .Values.externalPostgres.username }}
# DB_PASSWORD: {{ .Values.externalPostgres.password }}
DB_HOST: {{ .Values.externalPostgres.address }}
DB_PORT: {{ .Values.externalPostgres.port | toString | quote }}
DB_DATABASE: {{ .Values.externalPostgres.dbName }}
{{- else if .Values.postgresql.enabled }}
  {{ with .Values.postgresql.global.postgresql.auth }}
  {{- if empty .username }}
# DB_USERNAME: postgres
# DB_PASSWORD: {{ .postgresPassword }}
  {{- else }}
# DB_USERNAME: {{ .username }}
# DB_PASSWORD: {{ .password }}
  {{- end }}
  {{- end }}
  {{- if eq .Values.postgresql.architecture "replication" }}
DB_HOST: {{ .Release.Name }}-postgresql-primary
  {{- else }}
DB_HOST: {{ .Release.Name }}-postgresql
  {{- end }}
DB_PORT: "5432"
DB_DATABASE: {{ .Values.postgresql.global.postgresql.auth.database }}
{{- end }}
{{- end }}

{{- define "dify.storage.config" -}}
{{- if .Values.externalS3.enabled }}
# The type of storage to use for storing user files. Supported values are `local`, `s3`, `azure-blob` and `aliyun-oss`, Default: `local`
STORAGE_TYPE: s3
# The S3 storage configurations, only available when STORAGE_TYPE is `s3`.
S3_ENDPOINT: {{ .Values.externalS3.endpoint }}
S3_BUCKET_NAME: {{ .Values.externalS3.bucketName }}
# S3_ACCESS_KEY: {{ .Values.externalS3.accessKey }}
# S3_SECRET_KEY: {{ .Values.externalS3.secretKey }}
S3_REGION: 'us-east-1'
{{- else if .Values.externalAzureBlobStorage.enabled }}
# The type of storage to use for storing user files. Supported values are `local`, `s3`, `azure-blob` and `aliyun-oss`, Default: `local`
STORAGE_TYPE: azure-blob
# The Azure Blob storage configurations, only available when STORAGE_TYPE is `azure-blob`.
AZURE_BLOB_ACCOUNT_NAME: {{ .Values.externalAzureBlobStorage.account | quote }}
# AZURE_BLOB_ACCOUNT_KEY: {{ .Values.externalAzureBlobStorage.key | quote }}
AZURE_BLOB_CONTAINER_NAME: {{ .Values.externalAzureBlobStorage.container | quote }}
AZURE_BLOB_ACCOUNT_URL: {{ .Values.externalAzureBlobStorage.url | quote }}
{{- else if .Values.externalOSS.enabled }}
# The type of storage to use for storing user files. Supported values are `local`, `s3`, `azure-blob` and `aliyun-oss`, Default: `local`
STORAGE_TYPE: aliyun-oss
# The OSS storage configurations, only available when STORAGE_TYPE is `aliyun-oss`.
ALIYUN_OSS_ENDPOINT: {{ .Values.externalOSS.endpoint }}
ALIYUN_OSS_BUCKET_NAME: {{ .Values.externalOSS.bucketName }}
# ALIYUN_OSS_ACCESS_KEY: {{ .Values.externalOSS.accessKey }}
# ALIYUN_OSS_SECRET_KEY: {{ .Values.externalOSS.secretKey }}
ALIYUN_OSS_REGION: {{ .Values.externalOSS.region }}
ALIYUN_OSS_AUTH_VERSION: {{ .Values.externalOSS.authVersion }}
{{- else }}
# The type of storage to use for storing user files. Supported values are `local` and `s3` and `azure-blob`, Default: `local`
STORAGE_TYPE: local
# The path to the local storage directory, the directory relative the root path of API service codes or absolute path. Default: `storage` or `/home/john/storage`.
# only available when STORAGE_TYPE is `local`.
STORAGE_LOCAL_PATH: {{ .Values.api.persistence.mountPath }}
{{- end }}
{{- end }}

{{- define "dify.redis.config" -}}
{{- if .Values.externalRedis.enabled }}
  {{- with .Values.externalRedis }}
REDIS_HOST: {{ .host | quote }}
REDIS_PORT: {{ .port | toString | quote }}
# REDIS_USERNAME: {{ .username | quote }}
# REDIS_PASSWORD: {{ .password | quote }}
REDIS_USE_SSL: {{ .useSSL | toString | quote }}
# use redis db 0 for redis cache
REDIS_DB: "0"
  {{- end }}
{{- else if .Values.redis.enabled }}
{{- $redisHost := printf "%s-redis-master" .Release.Name -}}
  {{- with .Values.redis }}
REDIS_HOST: {{ $redisHost }}
REDIS_PORT: {{ .master.service.ports.redis | toString | quote }}
# REDIS_USERNAME: ""
# REDIS_PASSWORD: {{ .auth.password | quote }}
REDIS_USE_SSL: {{ .tls.enabled | toString | quote }}
# use redis db 0 for redis cache
REDIS_DB: "0"
  {{- end }}
{{- end }}
{{- end }}

{{- define "dify.celery.config" -}}
# Use redis as the broker, and redis db 1 for celery broker.
{{- if .Values.externalRedis.enabled }}
  {{- with .Values.externalRedis }}
# CELERY_BROKER_URL: {{ printf "redis://%s:%s@%s:%v/1" .username .password .host .port }}
  {{- end }}
{{- else if .Values.redis.enabled }}
{{- $redisHost := printf "%s-redis-master" .Release.Name -}}
  {{- with .Values.redis }}
# CELERY_BROKER_URL: {{ printf "redis://:%s@%s:%v/1" .auth.password $redisHost .master.service.ports.redis }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "dify.vectordb.config" -}}
{{- if .Values.externalWeaviate.enabled }}
# The type of vector store to use. Supported values are `weaviate`, `qdrant`, `milvus`.
VECTOR_STORE: weaviate
# The Weaviate endpoint URL. Only available when VECTOR_STORE is `weaviate`.
WEAVIATE_ENDPOINT: {{ .Values.externalWeaviate.endpoint | quote }}
# The Weaviate API key.
# WEAVIATE_API_KEY: {{ .Values.externalWeaviate.apiKey }}
{{- else if .Values.externalQdrant.enabled }}
VECTOR_STORE: qdrant
# The Qdrant endpoint URL. Only available when VECTOR_STORE is `qdrant`.
QDRANT_URL: {{ .Values.externalQdrant.endpoint }}
# The Qdrant API key.
# QDRANT_API_KEY: {{ .Values.externalQdrant.apiKey }}
# The Qdrant clinet timeout setting.
QDRANT_CLIENT_TIMEOUT: {{ .Values.externalQdrant.timeout | quote }}
# The Qdrant client enable gRPC mode.
QDRANT_GRPC_ENABLED: {{ .Values.externalQdrant.grpc.enabled | toString | quote }}
# The Qdrant server gRPC mode PORT.
QDRANT_GRPC_PORT: {{ .Values.externalQdrant.grpc.port | quote }}
# The DSN for Sentry error reporting. If not set, Sentry error reporting will be disabled.
{{- else if .Values.externalMilvus.enabled}}
# Milvus configuration Only available when VECTOR_STORE is `milvus`.
VECTOR_STORE: milvus
# The milvus host.
MILVUS_HOST: {{ .Values.externalMilvus.host | quote }}
# The milvus host.
MILVUS_PORT: {{ .Values.externalMilvus.port | toString | quote }}
# The milvus username.
# MILVUS_USER: {{ .Values.externalMilvus.user | quote }}
# The milvus password.
# MILVUS_PASSWORD: {{ .Values.externalMilvus.password | quote }}
# The milvus tls switch.
MILVUS_SECURE: {{ .Values.externalMilvus.useTLS | toString | quote }}
{{- else if .Values.externalPgvector.enabled}}
# pgvector configurations, only available when VECTOR_STORE is `pgvecto-rs or pgvector`
VECTOR_STORE: pgvector
PGVECTOR_HOST: {{ .Values.externalPgvector.address }}
PGVECTOR_PORT: {{ .Values.externalPgvector.port | toString | quote }}
PGVECTOR_DATABASE: {{ .Values.externalPgvector.dbName }}
# DB_USERNAME: {{ .Values.externalPgvector.username }}
# DB_PASSWORD: {{ .Values.externalPgvector.password }}
{{- else if .Values.weaviate.enabled }}
# The type of vector store to use. Supported values are `weaviate`, `qdrant`, `milvus`.
VECTOR_STORE: weaviate
  {{- with .Values.weaviate.service }}
    {{- if and (eq .type "ClusterIP") (not (eq .clusterIP "None"))}}
# The Weaviate endpoint URL. Only available when VECTOR_STORE is `weaviate`.
{{/*
Pitfall: scheme (i.e.) must be supecified, or weviate client won't function as
it depends on `hostname` from urllib.parse.urlparse will be empty if schema is not specified.
*/}}
WEAVIATE_ENDPOINT: {{ printf "http://%s" .name | quote }}
    {{- end }}
  {{- end }}
# The Weaviate API key.
  {{- if .Values.weaviate.authentication.apikey }}
# WEAVIATE_API_KEY: {{ first .Values.weaviate.authentication.apikey.allowed_keys }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "dify.mail.config" -}}
{{- if eq .Values.api.mail.type "resend" }}
# Mail configuration for resend
MAIL_TYPE: {{ .Values.api.mail.type | quote }}
MAIL_DEFAULT_SEND_FROM: {{ .Values.api.mail.defaultSender | quote }}
# RESEND_API_KEY: {{ .Values.api.mail.resend.apiKey | quote }}
RESEND_API_URL: {{ .Values.api.mail.resend.apiUrl | quote }}
{{- else if eq .Values.api.mail.type "smtp" }}
# Mail configuration for SMTP
MAIL_TYPE: {{ .Values.api.mail.type | quote }}
MAIL_DEFAULT_SEND_FROM: {{ .Values.api.mail.defaultSender | quote }}
SMTP_SERVER: {{ .Values.api.mail.smtp.server | quote }}
SMTP_PORT: {{ .Values.api.mail.smtp.port | quote }}
# SMTP_USERNAME: {{ .Values.api.mail.smtp.username | quote }}
# SMTP_PASSWORD: {{ .Values.api.mail.smtp.password | quote }}
SMTP_USE_TLS: {{ .Values.api.mail.smtp.tls.enabled | toString | quote }}
SMTP_OPPORTUNISTIC_TLS: {{ .Values.api.mail.smtp.tls.optimistic | toString | quote }}
{{- end }}
{{- end }}

{{- define "dify.sandbox.config" -}}
GIN_MODE: release
SANDBOX_PORT: '8194'
{{- if .Values.ssrfProxy.enabled }}
HTTP_PROXY: http://{{ template "dify.ssrfProxy.fullname" .}}:{{ .Values.ssrfProxy.service.port }}
HTTPS_PROXY: http://{{ template "dify.ssrfProxy.fullname" .}}:{{ .Values.ssrfProxy.service.port }}
{{- end }}
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
{{- if .Values.proxy.log.persistence.enabled }}
error_log  {{ .Values.proxy.log.persistence.mountPath }}/error.log notice;
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

{{- if .Values.proxy.log.persistence.enabled }}
    access_log  {{ .Values.proxy.log.persistence.mountPath }}/access.log  main;
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
      proxy_pass http://{{ template "dify.api.fullname" .}}:{{ .Values.api.service.port }};
      include proxy.conf;
    }

    location /v1 {
      proxy_pass http://{{ template "dify.api.fullname" .}}:{{ .Values.api.service.port }};
      include proxy.conf;
    }

    location /files {
      proxy_pass http://{{ template "dify.api.fullname" .}}:{{ .Values.api.service.port }};
      include proxy.conf;
    }

    location / {
      proxy_pass http://{{ template "dify.web.fullname" .}}:{{ .Values.web.service.port }};
      include proxy.conf;
    }
}
{{- end }}

{{- define "dify.ssrfProxy.config.squid" }}
acl localnet src 0.0.0.1-0.255.255.255	# RFC 1122 "this" network (LAN)
acl localnet src 10.0.0.0/8		# RFC 1918 local private network (LAN)
acl localnet src 100.64.0.0/10		# RFC 6598 shared address space (CGN)
acl localnet src 169.254.0.0/16 	# RFC 3927 link-local (directly plugged) machines
acl localnet src 172.16.0.0/12		# RFC 1918 local private network (LAN)
acl localnet src 192.168.0.0/16		# RFC 1918 local private network (LAN)
acl localnet src fc00::/7       	# RFC 4193 local private network range
acl localnet src fe80::/10      	# RFC 4291 link-local (directly plugged) machines
acl SSL_ports port 443
acl Safe_ports port 80		# http
acl Safe_ports port 21		# ftp
acl Safe_ports port 443		# https
acl Safe_ports port 70		# gopher
acl Safe_ports port 210		# wais
acl Safe_ports port 1025-65535	# unregistered ports
acl Safe_ports port 280		# http-mgmt
acl Safe_ports port 488		# gss-http
acl Safe_ports port 591		# filemaker
acl Safe_ports port 777		# multiling http
acl CONNECT method CONNECT
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localhost
include /etc/squid/conf.d/*.conf
http_access deny all

################################## Proxy Server ################################
http_port 3128
coredump_dir /var/spool/squid
refresh_pattern ^ftp:		1440	20%	10080
refresh_pattern ^gopher:	1440	0%	1440
refresh_pattern -i (/cgi-bin/|\?) 0	0%	0
refresh_pattern \/(Packages|Sources)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
refresh_pattern \/Release(|\.gpg)$ 0 0% 0 refresh-ims
refresh_pattern \/InRelease$ 0 0% 0 refresh-ims
refresh_pattern \/(Translation-.*)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
refresh_pattern .		0	20%	4320

# upstream proxy, set to your own upstream proxy IP to avoid SSRF attacks
# cache_peer 172.1.1.1 parent 3128 0 no-query no-digest no-netdb-exchange default


################################## Reverse Proxy To Sandbox ################################
http_port {{ .Values.sandbox.service.port }} accel vhost
cache_peer {{ template "dify.sandbox.fullname" .}} parent {{ .Values.sandbox.service.port }} 0 no-query originserver
acl src_all src all
http_access allow src_all

{{/*Dump logs to stdout only when log persistence is not enabled*/}}
{{- if not .Values.ssrfProxy.log.persistence.enabled }}
cache_log none
access_log none
cache_store_log none
{{- end }}
{{- end }}