# Extract only search module from valkey-bundle
FROM --platform=linux/amd64 valkey/valkey-bundle:9.0-bookworm AS modules

# Use clean valkey base image
FROM --platform=linux/amd64 valkey/valkey:9.0-bookworm

# Copy only the search module (and optionally json/bloom if needed)
RUN mkdir -p /usr/lib/valkey
COPY --from=modules /usr/lib/valkey/libsearch.so /usr/lib/valkey/libsearch.so
# Uncomment if you need JSON support:
# COPY --from=modules /usr/lib/valkey/libjson.so /usr/lib/valkey/libjson.so
# Uncomment if you need Bloom filters:
# COPY --from=modules /usr/lib/valkey/libvalkey_bloom.so /usr/lib/valkey/libvalkey_bloom.so

# Copy custom configuration with coordinator enabled
COPY valkey.conf /usr/local/etc/valkey/valkey.conf

EXPOSE 6379

CMD ["valkey-server", "/usr/local/etc/valkey/valkey.conf"]
