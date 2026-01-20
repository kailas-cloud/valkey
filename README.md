# Valkey with Search Module and Coordinator

Custom Valkey 9.0 Docker image with valkey-search module and **coordinator enabled** for cluster mode.

## Why This Image?

The official `valkey/valkey-bundle` image includes valkey-search module, but the coordinator is **disabled by default** (`search.use-coordinator no`). This custom image enables the coordinator for cluster deployments.

## What's Included

- **Valkey 9.0** (latest stable)
- **valkey-search** - Vector similarity search engine with coordinator enabled
- **valkey-json** - Native JSON data structure support
- **valkey-bloom** - Probabilistic data structures (Bloom filters)

## Key Differences from valkey-bundle

| Feature | valkey-bundle | This Image |
|---------|---------------|------------|
| Search Coordinator | ❌ Disabled | ✅ Enabled |
| Cluster Mode | Limited | Full support |
| Cross-shard search | ❌ No | ✅ Yes |
| Configuration | Default | Optimized |

## Configuration

### Search Module Settings

```conf
# Enable coordinator for cluster mode
search.use-coordinator yes

# Thread configuration
search.reader-threads 8
search.writer-threads 4

# HNSW graph configuration
search.hnsw-block-size 10000
```

## Quick Start

### Docker Run

```bash
docker run -d \
  --name valkey-search \
  -p 6379:6379 \
  -v $(pwd)/data:/data \
  ghcr.io/kailas-cloud/valkey:latest
```

### Docker Compose

```yaml
services:
  valkey:
    image: ghcr.io/kailas-cloud/valkey:latest
    ports:
      - "6379:6379"
    volumes:
      - valkey-data:/data
    restart: unless-stopped

volumes:
  valkey-data:
```

## Kubernetes Deployment

See [k8s/](k8s/) directory for Kubernetes manifests:

```bash
kubectl apply -k k8s/
```

## Using Search Module

```bash
# Connect to Valkey
valkey-cli

# Create a vector index
FT.CREATE idx ON HASH PREFIX 1 doc: SCHEMA vector VECTOR HNSW 6 DIM 128 DISTANCE_METRIC COSINE

# Add a document with vector
HSET doc:1 vector "\x00\x00\x80?\x00\x00\x00@..."

# Search for similar vectors
FT.SEARCH idx "*=>[KNN 10 @vector $vec]" PARAMS 2 vec "\x00\x00\x80?..." DIALECT 2
```

## Build Locally

⚠️ **Note**: Building on macOS ARM requires GitHub Actions for correct AMD64 architecture.

The image uses multi-stage build to extract modules from `valkey-bundle`:

```dockerfile
FROM --platform=linux/amd64 valkey/valkey-bundle:9.0-bookworm AS modules
FROM --platform=linux/amd64 valkey/valkey:9.0-bookworm
COPY --from=modules /usr/lib/valkey/ /usr/lib/valkey/
```

## Architecture

```
valkey-bundle (source) → Extract .so modules → valkey:9.0 + custom config
                         ├─ libsearch.so
                         ├─ libjson.so
                         └─ libvalkey_bloom.so
```

## Environment Variables

You can override configuration using `VALKEY_EXTRA_FLAGS`:

```bash
docker run -e VALKEY_EXTRA_FLAGS="--maxmemory 2gb --maxmemory-policy allkeys-lru" \
  ghcr.io/kailas-cloud/valkey:latest
```

## Persistence

By default, the image uses:
- **RDB snapshots**: Every 60 seconds if 10000+ keys changed
- **AOF**: Append-only file enabled for durability

Mount `/data` volume for persistent storage.

## License

BSD-3-Clause (same as Valkey)

## Links

- [Valkey](https://valkey.io/)
- [Valkey Search Documentation](https://valkey.io/topics/search/)
- [Valkey Bundle](https://github.com/valkey-io/valkey-bundle)
- [Source Repository](https://github.com/kailas-cloud/valkey)
