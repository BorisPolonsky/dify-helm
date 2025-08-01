# dify-helm

[![Github All Releases](https://img.shields.io/github/downloads/borispolonsky/dify-helm/total.svg)]()
[![Release Charts](https://github.com/BorisPolonsky/dify-helm/actions/workflows/release.yml/badge.svg)](https://github.com/BorisPolonsky/dify-helm/actions/workflows/release.yml)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/dify-helm)](https://artifacthub.io/packages/search?repo=dify-helm)

Deploy [langgenius/dify](https://github.com/langgenius/dify), an LLM based chat bot app on kubernetes with helm chart.

## Installation

```shell
helm repo add dify https://borispolonsky.github.io/dify-helm
helm repo update
helm install my-release dify/dify
```

## Supported Component

### Components that could be deployed on kubernetes in current version

- [x] core (`api`, `worker`, `sandbox`)
- [x] ssrf_proxy
- [x] proxy (via built-in `nginx` or `ingress`)
- [x] redis
- [x] postgresql
- [x] persistent storage
- [ ] object storage
- [x] weaviate
- [ ] qdrant
- [ ] milvus

### External components that can be used by this app with proper configuration

- [x] Redis
- [x] PostgreSQL
- Object Storage:
  - [x] Amazon S3
  - [x] Microsoft Azure Blob Storage
  - [x] Alibaba Cloud OSS
  - [x] Google Cloud Storage
  - [x] Tencent Cloud COS
  - [x] Huawei Cloud OBS
  - [x] Volcengine TOS
- External Vector DB:
  - [x] Weaviate
  - [x] Qdrant
  - [x] Milvus
  - [x] PGVector
  - [x] Tencent Vector DB
  - [x] MyScaleDB
  - [x] TableStore

## ExternalSecret Support

### Background

In Kubernetes production environments, storing sensitive information (such as database passwords, API keys, etc.) directly in values.yaml is insecure. The ExternalSecret feature solves this problem through the [External Secrets Operator](https://external-secrets.io/), which can securely retrieve sensitive information from external secret management systems (such as AWS Secrets Manager, HashiCorp Vault, Azure Key Vault, etc.) and automatically create Kubernetes Secret resources.

Why ExternalSecret is needed:

- **Security**: Avoid storing plain text passwords in Git repositories or configuration files
- **Centralized Management**: Unified management of all sensitive information
- **Automatic Rotation**: Support for automatic key updates and rotation
- **Compliance**: Meet enterprise security and compliance requirements

### Currently Supported External Components

When ExternalSecret is enabled, sensitive information for the following components can be retrieved from external secret stores:

#### Database Connections

- **PostgreSQL**: Database username, password
- **Redis**: Authentication password, username
- **Elasticsearch**: Username, password

#### Object Storage

- **AWS S3**: Access Key ID, Secret Access Key

#### Vector Databases

- **ElasticSearch**: Username, Password

#### Email Services

- **Resend**: API Key, sender email
- **SendGrid**: API Key, sender email

#### Other Services

- **Code Execution Service**: API Key
- **Plugin System**: Daemon Key, internal API Key
- **Application Core**: Secret Key

Usage: Set `externalSecret.enabled: true` in values.yaml and configure the corresponding secretStore and remoteRefs parameters.

## Contributors

<a href="https://github.com/borispolonsky/dify-helm/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=borispolonsky/dify-helm" />
</a>
