# Apolo Dify.ai deployment

Currently, we only support deployment with:
Database:
- [x] external PostgreSQL (running as an app, see https://github.com/neuro-inc/app-crunchy-postgres)

Objects persistance:
- platform object storage with
  - [x] S3-compatible backend (AWS S3 / MinIO)

Vector store:
- [x] external PGVector (running as an app, see https://github.com/neuro-inc/app-crunchy-postgres)

Other system components like LLM inference, reranker, embeddings services are deployed as platform apps too and integrated via web interface of Dify. However, automation for those integrations is planned too.


## Platform deploymet example:
```yaml
apolo run --pass-config ghcr.io/neuro-inc/app-deployment -- install https://github.com/neuro-inc/dify-helm \
  dify mydifyinstance charts/dify \
  --timeout=600s \
  --dependency-update \
  --set "api.replicas=1" \  # optional
  --set "api.preset_name=cpu-small" \ # required
  --set "worker.replicas=1" \ # optional
  --set "worker.preset_name=cpu-small" \  # required
  --set "proxy.replicas=1" \        # TODO: implement ingress replacement for proxy
  --set "proxy.preset_name=cpu-small" \ # required
  --set "web.replicas=1" \  # optional
  --set "web.preset_name=cpu-small" \ # required
  --set "redis.master.preset_name=cpu-small" \  # required
  --set "externalPostgres.username=PGUsername" \    # optional, user within PGVector app to use for integration. otherwise, the first one in a list will be used
  --set "externalPostgres.dbName=PGDBName" \  # optional: database to use, otherwise the first one of user's DBs will be used
  --set "externalPostgres.platformAppName=myappname" \ # required: PGVector app name to integrate with
  --set "externalPgvector.username=PGUsername" \    # optional, user within PGVector app to use for integration. otherwise, the first one in a list will be used
  --set "externalPgvector.dbName=PGDBName" \    # optional: database to use, otherwise the first one of user's DBs will be used
  --set "externalPgvector.platformAppName=myappname" # Required: PGVector app name to integrate with
```
