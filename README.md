# dify-helm
[![Github All Releases](https://img.shields.io/github/downloads/borispolonsky/dify-helm/total.svg)]()

Deploy [langgenius/dify](https://github.com/langgenius/dify), an LLM based chat bot app on kubernetes with helm chart.

## Installation
```
helm repo add dify https://borispolonsky.github.io/dify-helm
helm repo update
helm install my-release dify/dify
```

## Supported Component 
### Components that could be deployed on kubernetes in current version
- [x] core (api, worker, proxy)
- [x] redis
- [x] postgresql
- [x] persistent storage
- [ ] object storage
- [x] weaviate
- [ ] qdrant
- [ ] milvus
### External components that can be used by this app with proper configuration
- [x] redis
- [x] postgresql
- [x] object storage
- [x] weaviate
- [x] qdrant
- [X] milvus