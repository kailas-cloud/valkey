# Valkey with Search Module and Coordinator

Custom Valkey 9.0 Docker image with **valkey-search** module and **coordinator enabled** for cluster mode.

## Why This Image?

The official `valkey/valkey-bundle` includes valkey-search, but the coordinator is **disabled by default** (`search.use-coordinator no`). This image enables the coordinator for full cluster support with cross-shard search.

## What's Included

- **Valkey 9.0** (latest stable)
- **valkey-search** - Vector similarity search engine with coordinator enabled
- Minimal footprint - only search module (JSON/Bloom available via uncommenting)

## Key Differences from valkey-bundle

| Feature | valkey-bundle | This Image |
|---------|---------------|------------|
| Search Coordinator | ❌ Disabled | ✅ Enabled |
| Cluster Mode | Limited | Full support |
| Cross-shard search | ❌ No | ✅ Yes |
| Extra modules | All (json, bloom, ldap) | Only search (configurable) |
| Image size | Larger | Minimal |

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

### Adding More Modules

To enable JSON or Bloom modules, uncomment in both `Dockerfile` and `valkey.conf`:

**Dockerfile:**
```dockerfile
COPY --from=modules /usr/lib/valkey/libjson.so /usr/lib/valkey/libjson.so
COPY --from=modules /usr/lib/valkey/libvalkey_bloom.so /usr/lib/valkey/libvalkey_bloom.so
```

**valkey.conf:**
```conf
loadmodule /usr/lib/valkey/libjson.so
loadmodule /usr/lib/valkey/libvalkey_bloom.so
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

## Architecture

```
valkey-bundle:9.0 (extract) → libsearch.so → valkey:9.0 + custom config
                                              ↓
                                       search.use-coordinator yes
```

We use multi-stage build to extract only the search module from the official valkey-bundle image, keeping the final image minimal while leveraging their build infrastructure.

## Build Process

The image is automatically built on GitHub Actions for `linux/amd64` platform:

1. Extract `libsearch.so` from `valkey/valkey-bundle:9.0-bookworm`
2. Copy into clean `valkey/valkey:9.0-bookworm` base
3. Add custom configuration with coordinator enabled
4. Push to `ghcr.io/kailas-cloud/valkey`

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
