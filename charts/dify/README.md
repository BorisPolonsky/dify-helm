# dify-helm-custom

## Customized Installation

Apply the `-f` option upon `helm install`/`helm upgrade` with your own `values.yaml`.
Fear not its extensive content as they are arranged in sections below:

1. Image: Adjust images of all Dify components
2. Cloud-specific Custom Images: Azure ACR, AWS ECR, GCP GCR integration guides
3. Dify Service: Customize configurations of each Dify components
4. Middleware: Specifies the configuration of built-in middlewares
5. External services: Substitute external services for built-in data persistence

### 1. Adjust Images

You can specify custom images for different components:

```yaml
# values.yaml
images:
  api:
    repository: your-registry/dify-api
    tag: your-tag
    pullPolicy: IfNotPresent
  worker:
    repository: your-registry/dify-worker
    tag: your-tag
    pullPolicy: IfNotPresent
  sandbox:
    repository: your-registry/dify-sandbox
```

### 2. 클라우드별 커스텀 이미지 가이드

#### Azure Container Registry (ACR) 커스텀 이미지

Azure 환경에서 ACR의 커스텀 이미지를 사용하는 경우:

```yaml
# values-azure.yaml
image:
  api:
    repository: "yourregistry.azurecr.io/dify/api"
    tag: "v1.0.0"
    pullPolicy: "Always"
  web:
    repository: "yourregistry.azurecr.io/dify/web"
    tag: "v1.0.0"
    pullPolicy: "Always"
  # worker는 api와 같은 이미지 사용
  worker:
    repository: "yourregistry.azurecr.io/dify/api"
    tag: "v1.0.0"
    pullPolicy: "Always"

# ACR 인증 설정 (필요시)
imagePullSecrets:
  - name: acr-secret
```

#### ACR 인증 설정 방법

**방법 1: AKS-ACR 통합 (권장)**

```bash
az aks update -n your-cluster -g your-resource-group --attach-acr yourregistry
```

**방법 2: Docker Registry Secret 생성**

```bash
kubectl create secret docker-registry acr-secret \
  --docker-server=yourregistry.azurecr.io \
  --docker-username=<service-principal-id> \
  --docker-password=<service-principal-password> \
  --namespace=dify
```

#### 커스텀 이미지 요구사항

1. **API 이미지**:
   - 기존 Dify API와 호환되는 Flask/FastAPI 애플리케이션
   - 포트 5001에서 서비스 제공
   - 환경변수 기반 설정 지원

2. **Web 이미지**:
   - 기존 Dify Web과 호환되는 Next.js 애플리케이션
   - 포트 3000에서 서비스 제공
   - API 엔드포인트 연결 설정

3. **환경변수 호환성**:
   - 데이터베이스 연결 정보 (POSTGRES_*, REDIS_*)
   - Dify 설정 변수 (SECRET_KEY, CHECK_UPDATE_URL 등)
   - 스토리지 설정 (S3_*, AZURE_STORAGE_* 등)

#### 배포 및 롤백

**커스텀 이미지로 배포:**

```bash
helm upgrade dify ./charts/dify --namespace dify -f charts/dify/values-azure.yaml
```

**원본 이미지로 롤백:**

```bash
# values-azure.yaml에서 image 섹션 주석 처리 후
helm upgrade dify ./charts/dify --namespace dify -f charts/dify/values-azure.yaml
```

#### AWS Elastic Container Registry (ECR) 커스텀 이미지

```yaml
# values-aws.yaml
image:
  api:
    repository: "123456789012.dkr.ecr.us-west-2.amazonaws.com/dify/api"
    tag: "v1.0.0"
    pullPolicy: "Always"
  web:
    repository: "123456789012.dkr.ecr.us-west-2.amazonaws.com/dify/web"
    tag: "v1.0.0"
    pullPolicy: "Always"

# ECR 인증 설정 (EKS에서 자동 처리되지만 필요시)
imagePullSecrets:
  - name: ecr-secret
```

**ECR 인증 설정:**

```bash
# AWS CLI 설정 후
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-west-2.amazonaws.com

# EKS에서는 보통 자동으로 처리됨 (IAM 역할 기반)
```

#### Google Container Registry (GCR) 커스텀 이미지

```yaml
# values-gcp.yaml
image:
  api:
    repository: "gcr.io/your-project-id/dify/api"
    tag: "v1.0.0"
    pullPolicy: "Always"
  web:
    repository: "gcr.io/your-project-id/dify/web"
    tag: "v1.0.0"
    pullPolicy: "Always"

# GCR 인증 설정
imagePullSecrets:
  - name: gcr-secret
```

**GCR 인증 설정:**

```bash
# Service Account Key 사용
kubectl create secret docker-registry gcr-secret \
  --docker-server=gcr.io \
  --docker-username=_json_key \
  --docker-password="$(cat key.json)" \
  --namespace=dify

# 또는 GKE Workload Identity 사용 (권장)
```

### 3. Customize Dify Components

#### Data persistence

To customize built-in data persistence, set `enabled: true` in the `persistence` section of `values.yaml` and specify the storage class and size, for instance:

```yaml
# values.yaml
api:
  persistence:
    enabled: true
    storageClass: your-storage-class
    accessMode: ReadWriteMany
    size: 10Gi

```

or desginate an existing `PersistentVolumeClaim`:

```yaml
# values.yaml
api:
  persistence:
    enabled: true
    persistentVolumeClaim:
      existingClaim: "your-pvc-name"
```

#### Environment Variables

This chart automatically manages envrionment variables for data persistence, service discovery and database connection etc. under the hood. To apply additional environment variables or override existing ones, refer to `extraEnv` section for each component:

```yaml
# values.yaml
...
api:
  extraEnv:
  # The direct approach
  - name: LANG
    value: "C.UTF-8"
  # Use existing configmaps
  - name: MY_CONFIG
    valueFrom:
      configMapKeyRef:
        name: my-config
        key: MY_CONFIG
  # Use existing secrets
  - name: MY_SECRET
    valueFrom:
      secretKeyRef:
        name: my-secret
        key: MY_SECRET
```

### 4. Working with Built-in Middlewares

Built-in `Redis` and `PostgreSQL` and `weaviate` allows users to spool up a self-contained `Dify` enviroment for a quick start. These components are supplied by third party helm charts. To customize built-in middlewares, refer to the section name and the official documents:

| Section | Document |
----- | --- |
`redis` | [bitnami/redis](https://github.com/bitnami/charts/tree/main/bitnami/redis)
`postgresql` |[bitnami/postgresql](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
`weaviate`| [weaviate](https://github.com/weaviate/weaviate-helm)

To disable them, set `enabled: false` in the corresponding section of `values.yaml` and apply external service providers:

```yaml
# values.yaml
redis:
  enabled: false  # Disable built-in Redis
```

### 5. Opt in External Services

It's advised to utilize services from enterprise level providers over the built-in middlewares for production use. To take over built-in `Redis` for instance:

```yaml
# values.yaml
externalRedis:
  enabled: true
  host: "redis.example"
  port: 6379
  username: ""
  password: "difyai123456"
  useSSL: false
```

Refer to `external<Service>` sections for more details.
