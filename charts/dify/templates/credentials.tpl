{{- define "dify.api.credentials" -}}
# A secret key that is used for securely signing the session cookie and encrypting sensitive information on the database. You can generate a strong key using `openssl rand -base64 42`.
SECRET_KEY: {{ .Values.api.secretKey | b64enc | quote }}
{{- if .Values.sandbox.enabled }}
CODE_EXECUTION_API_KEY: {{ .Values.sandbox.auth.apiKey | b64enc | quote }}
{{- end }}
{{- include "dify.db.credentials" . }}
# The configurations of redis connection.
# It is consistent with the configuration in the 'redis' service below.
{{- include "dify.redis.credentials" . }}
# The configurations of celery broker.
{{- include "dify.celery.credentials" . }}
{{ include "dify.storage.credentials" . }}
{{ include "dify.vectordb.credentials" . }}
{{ include "dify.mail.credentials" . }}
{{- if .Values.pluginDaemon.enabled }}
PLUGIN_DAEMON_KEY: {{ .Values.pluginDaemon.auth.serverKey | b64enc | quote }}
INNER_API_KEY_FOR_PLUGIN: {{ .Values.pluginDaemon.auth.difyApiKey | b64enc | quote }}
{{- end }}
{{- if and .Values.api.otel.enabled (not .Values.externalSecret.enabled) }}
OTLP_API_KEY: {{ .Values.api.otel.apiKey | b64enc | quote }}
{{- end }}
{{- end }}

{{- define "dify.worker.credentials" -}}
SECRET_KEY: {{ .Values.api.secretKey | b64enc | quote }}
# The configurations of postgres database connection.
# It is consistent with the configuration in the 'db' service below.
{{ include "dify.db.credentials" . }}

# The configurations of redis cache connection.
{{ include "dify.redis.credentials" . }}
# The configurations of celery broker.
{{ include "dify.celery.credentials" . }}

{{ include "dify.storage.credentials" . }}
# The Vector store configurations.
{{ include "dify.vectordb.credentials" . }}
{{ include "dify.mail.credentials" . }}
{{- if .Values.pluginDaemon.enabled }}
PLUGIN_DAEMON_KEY: {{ .Values.pluginDaemon.auth.serverKey | b64enc | quote }}
INNER_API_KEY_FOR_PLUGIN: {{ .Values.pluginDaemon.auth.difyApiKey | b64enc | quote }}
{{- end }}
{{- if and .Values.api.otel.enabled (not .Values.externalSecret.enabled) }}
OTLP_API_KEY: {{ .Values.api.otel.apiKey | b64enc | quote }}
{{- end }}
{{- end }}

{{- define "dify.web.credentials" -}}
{{- end }}

{{- define "dify.db.credentials" -}}
{{- if .Values.externalPostgres.enabled }}
DB_USERNAME: {{ .Values.externalPostgres.username | b64enc | quote }}
DB_PASSWORD: {{ .Values.externalPostgres.password | b64enc | quote }}
{{- else if .Values.externalMysql.enabled }}
DB_USERNAME: {{ .Values.externalMysql.username | b64enc | quote }}
DB_PASSWORD: {{ .Values.externalMysql.password | b64enc | quote }}
{{- else if .Values.postgresql.enabled }}
  {{ with .Values.postgresql.global.postgresql.auth }}
  {{- if empty .username }}
DB_USERNAME: {{ print "postgres" | b64enc | quote }}
DB_PASSWORD: {{ .postgresPassword | b64enc | quote }}
  {{- else }}
DB_USERNAME: {{ .username | b64enc | quote }}
DB_PASSWORD: {{ .password | b64enc | quote }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "dify.storage.credentials" -}}
{{- if and .Values.externalS3.enabled (not .Values.externalSecret.enabled)}}
S3_ACCESS_KEY: {{ .Values.externalS3.accessKey | b64enc | quote }}
S3_SECRET_KEY: {{ .Values.externalS3.secretKey | b64enc | quote }}
{{- else if .Values.externalAzureBlobStorage.enabled }}
# The Azure Blob storage configurations, only available when STORAGE_TYPE is `azure-blob`.
AZURE_BLOB_ACCOUNT_KEY: {{ .Values.externalAzureBlobStorage.key | b64enc | quote }}
{{- else if .Values.externalOSS.enabled }}
ALIYUN_OSS_ACCESS_KEY: {{ .Values.externalOSS.accessKey | b64enc | quote }}
ALIYUN_OSS_SECRET_KEY: {{ .Values.externalOSS.secretKey | b64enc | quote }}
{{- else if .Values.externalGCS.enabled }}
GOOGLE_STORAGE_SERVICE_ACCOUNT_JSON_BASE64: {{ .Values.externalGCS.serviceAccountJsonBase64 | b64enc | quote }}
{{- else if .Values.externalCOS.enabled }}
TENCENT_COS_SECRET_KEY: {{ .Values.externalCOS.secretKey| b64enc | quote }}
{{- else if .Values.externalOBS.enabled }}
HUAWEI_OBS_ACCESS_KEY: {{ .Values.externalOBS.accessKey | b64enc | quote }}
HUAWEI_OBS_SECRET_KEY: {{ .Values.externalOBS.secretKey | b64enc | quote }}
{{- else if .Values.externalTOS.enabled }}
VOLCENGINE_TOS_SECRET_KEY: {{ .Values.externalTOS.secretKey | b64enc | quote }}
{{- else }}
{{- end }}
{{- end }}

{{- define "dify.redis.credentials" -}}
{{- if .Values.externalRedis.enabled }}
  {{- with .Values.externalRedis }}
REDIS_USERNAME: {{ .username | b64enc | quote }}
REDIS_PASSWORD: {{ .password | b64enc | quote }}
    {{- if .sentinel.enabled }}
REDIS_SENTINEL_PASSWORD: {{ .sentinel.password | b64enc | quote }}
    {{- end }}
  {{- end }}
{{- else if .Values.redis.enabled }}
{{- with .Values.redis }}
REDIS_USERNAME: {{ print "" | b64enc | quote }}
REDIS_PASSWORD: {{ .auth.password | b64enc | quote }}
  {{- if .sentinel.enabled }}
REDIS_SENTINEL_PASSWORD: {{ .auth.password | b64enc | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- define "dify.celery.credentials" -}}
# Use redis as the broker, and redis db 1 for celery broker.
{{- if .Values.externalRedis.enabled }}
  {{- with .Values.externalRedis }}
    {{- if .sentinel.enabled }}
# If use Redis Sentinel, format as follows: `sentinel://<redis_username>:<redis_password>@<sentinel_host1>:<sentinel_port>/<redis_database>`
# For high availability, you can configure multiple Sentinel nodes (if provided) separated by semicolons like below example:
# Example: sentinel://:difyai123456@localhost:26379/1;sentinel://:difyai12345@localhost:26379/1;sentinel://:difyai12345@localhost:26379/1
{{- $redisPassword := .password }}
{{- $redisCeleryDB := .db.celery}}
{{- $sentinelUrls := list }}
{{- range $sentinel := .sentinel.sentinels }}
{{- $sentinelUrls = append $sentinelUrls (printf "sentinel://:%s@%s/%v" $redisPassword $sentinel $redisCeleryDB) }}
{{- end }}
CELERY_BROKER_URL: {{ join ";" $sentinelUrls | b64enc | quote }}
CELERY_SENTINEL_PASSWORD: {{ .sentinel.password | b64enc | quote }}
    {{- else }}
      {{- $scheme := "redis" }}
      {{- if .useSSL }}
        {{- $scheme = "rediss" }}
      {{- end }}
CELERY_BROKER_URL: {{ printf "%s://%s:%s@%s:%v/%v" $scheme .username .password .host .port .db.celery | b64enc | quote }}
    {{- end }}
  {{- end }}
{{- else if .Values.redis.enabled }}
{{- $releaseName := printf "%s" .Release.Name -}}
{{- $namespace := .Release.Namespace -}}
{{- with .Values.redis }}
  {{- if .sentinel.enabled }}
    {{- $sentinelPort := .sentinel.service.ports.sentinel | int -}}
    {{- $masterSet := .sentinel.masterSet -}}
    {{- $password := .auth.password -}}
# If use Redis Sentinel, format as follows: `sentinel://<redis_username>:<redis_password>@<sentinel_host1>:<sentinel_port>/<redis_database>`
# For high availability, you can configure multiple Sentinel nodes (if provided) separated by semicolons like below example:
# Example: sentinel://:difyai123456@localhost:26379/1;sentinel://:difyai12345@localhost:26379/1;sentinel://:difyai12345@localhost:26379/1
{{- $sentinelUrls := list }}
{{- range $i, $e := until (.replica.replicaCount | int) }}
{{- $sentinelUrls = append $sentinelUrls (printf "sentinel://:%s@%s-redis-node-%d.%s-redis-headless.%s.svc.cluster.local:%d/1" $password $releaseName $i $releaseName $namespace $sentinelPort) }}
{{- end }}
CELERY_BROKER_URL: {{ join ";" $sentinelUrls | b64enc | quote }}
CELERY_SENTINEL_PASSWORD: {{ .auth.password | b64enc | quote }}
  {{- else }}
# Use standalone redis as the broker, and redis db 1 for celery broker. (redis_username is usually set by defualt as empty)
# Format as follows: `redis://<redis_username>:<redis_password>@<redis_host>:<redis_port>/<redis_database>`.
# Example: redis://:difyai123456@redis:6379/1
    {{- $redisHost := printf "%s-redis-master" $releaseName -}}
    {{- $redisPort := .master.service.ports.redis }}
CELERY_BROKER_URL: {{ printf "redis://:%s@%s:%v/1" .auth.password $redisHost $redisPort | b64enc | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- define "dify.vectordb.credentials" -}}
{{- if .Values.externalWeaviate.enabled }}
WEAVIATE_API_KEY: {{ .Values.externalWeaviate.apiKey | b64enc | quote }}
{{- else if .Values.externalQdrant.enabled }}
QDRANT_API_KEY: {{ .Values.externalQdrant.apiKey | b64enc | quote }}
{{- else if .Values.externalMilvus.enabled}}
# the milvus token
MILVUS_TOKEN: {{ .Values.externalMilvus.token | b64enc | quote }}
# the milvus username
MILVUS_USER: {{ .Values.externalMilvus.user | b64enc | quote }}
# the milvus password
MILVUS_PASSWORD: {{ .Values.externalMilvus.password | b64enc | quote }}
{{- else if .Values.externalPgvector.enabled}}
PGVECTOR_USER: {{ .Values.externalPgvector.username | b64enc | quote }}
# The pgvector password.
PGVECTOR_PASSWORD: {{ .Values.externalPgvector.password | b64enc | quote }}
{{- else if .Values.externalTencentVectorDB.enabled}}
TENCENT_VECTOR_DB_USERNAME: {{ .Values.externalTencentVectorDB.username | b64enc | quote }}
TENCENT_VECTOR_DB_API_KEY: {{ .Values.externalTencentVectorDB.apiKey | b64enc | quote }}
{{- else if .Values.externalMyScaleDB.enabled}}
MYSCALE_USER: {{ .Values.externalMyScaleDB.username | b64enc | quote }}
MYSCALE_PASSWORD: {{ .Values.externalMyScaleDB.password | b64enc | quote }}
{{- else if .Values.externalTableStore.enabled}}
TABLESTORE_ACCESS_KEY_ID: {{ .Values.externalTableStore.accessKeyId | b64enc | quote }}
TABLESTORE_ACCESS_KEY_SECRET: {{ .Values.externalTableStore.accessKeySecret | b64enc | quote }}
{{- else if .Values.externalElasticsearch.enabled}}
# The Elasticsearch credentials
ELASTICSEARCH_USERNAME: {{ .Values.externalElasticsearch.username | b64enc | quote }}
ELASTICSEARCH_PASSWORD: {{ .Values.externalElasticsearch.password | b64enc | quote }}
{{- else if .Values.weaviate.enabled }}
# The Weaviate API key.
  {{- if .Values.weaviate.authentication.apikey }}
WEAVIATE_API_KEY: {{ first .Values.weaviate.authentication.apikey.allowed_keys | b64enc | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "dify.mail.credentials" -}}
{{- if eq .Values.api.mail.type "resend" }}
RESEND_API_KEY: {{ .Values.api.mail.resend.apiKey | b64enc | quote }}
{{- else if eq .Values.api.mail.type "smtp" }}
# Mail configuration for SMTP
SMTP_USERNAME: {{ .Values.api.mail.smtp.username | b64enc | quote }}
SMTP_PASSWORD: {{ .Values.api.mail.smtp.password | b64enc | quote }}
{{- end }}
{{- end }}

{{- define "dify.sandbox.credentials" -}}
API_KEY: {{ .Values.sandbox.auth.apiKey | b64enc | quote }}
{{- end }}

{{- define "dify.pluginDaemon.credentials" -}}
{{ include "dify.db.credentials" . }}
{{ include "dify.redis.credentials" . }}
{{ include "dify.pluginDaemon.storage.credentials" . }}
SERVER_KEY: {{ .Values.pluginDaemon.auth.serverKey | b64enc | quote }}
DIFY_INNER_API_KEY: {{ .Values.pluginDaemon.auth.difyApiKey | b64enc | quote }}
{{- end }}

{{- define "dify.pluginDaemon.storage.credentials" -}}
{{- if and .Values.externalS3.enabled .Values.externalS3.bucketName.pluginDaemon }}
AWS_ACCESS_KEY: {{ .Values.externalS3.accessKey | b64enc | quote }}
AWS_SECRET_KEY: {{ .Values.externalS3.secretKey | b64enc | quote }}
{{- else if .Values.externalAzureBlobStorage.enabled }}
  {{- with .Values.externalAzureBlobStorage }}
    {{- $protocol := "" }}
    {{- if hasPrefix "https://" .url }}
      {{- $protocol = "https" }}
    {{- else if hasPrefix "http://" .url }}
      {{- $protocol = "http" }}
    {{- else }}
      {{- fail "Error: externalAzureBlobStorage.url must start with either 'http://' or 'https://'" }}
    {{- end }}
AZURE_BLOB_STORAGE_CONNECTION_STRING: {{ printf "DefaultEndpointsProtocol=%s;AccountName=%s;AccountKey=%s;BlobEndpoint=%s;" $protocol .account .key .url | b64enc | quote }}
  {{- end }}
{{- else if and .Values.externalOSS.enabled .Values.externalOSS.bucketName.pluginDaemon }}
ALIYUN_OSS_ACCESS_KEY_SECRET: {{ .Values.externalOSS.secretKey | b64enc | quote }}
{{- else if and .Values.externalGCS.enabled .Values.externalGCS.bucketName.pluginDaemon }}
GCS_CREDENTIALS: {{ .Values.externalGCS.serviceAccountJsonBase64 | b64enc | quote }}
{{- else if and .Values.externalCOS.enabled .Values.externalCOS.bucketName.pluginDaemon }}
TENCENT_COS_SECRET_KEY: {{ .Values.externalCOS.secretKey | b64enc | quote }}
{{- else if and .Values.externalOBS.enabled .Values.externalOBS.bucketName.pluginDaemon }}
HUAWEI_OBS_SECRET_KEY: {{ .Values.externalOBS.secretKey | b64enc | quote }}
{{- else if and .Values.externalTOS.enabled .Values.externalTOS.bucketName.pluginDaemon }}
VOLCENGINE_TOS_SECRET_KEY: {{ .Values.externalTOS.secretKey | b64enc | quote }}
{{- end }}
{{- end }}
