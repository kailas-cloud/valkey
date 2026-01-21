# Extract only search module from valkey-bundle
FROM --platform=linux/amd64 valkey/valkey-bundle:9.0-trixie AS modules

# Use clean valkey base image
FROM --platform=linux/amd64 valkey/valkey:9.0-trixie

# Copy only the search module (and optionally json/bloom if needed)
RUN mkdir -p /usr/lib/valkey
COPY --from=modules /usr/lib/valkey/libsearch.so /usr/lib/valkey/libsearch.so
# Uncomment if you need JSON support:
# COPY --from=modules /usr/lib/valkey/libjson.so /usr/lib/valkey/libjson.so
# Uncomment if you need Bloom filters:
# COPY --from=modules /usr/lib/valkey/libvalkey_bloom.so /usr/lib/valkey/libvalkey_bloom.so

# Move original valkey-server and create wrapper that injects module loading
# This allows operators (like hyperspike/valkey-operator) to call valkey-server
# directly while still loading our search module with coordinator
RUN mv /usr/bin/valkey-server /usr/bin/valkey-server-original

COPY valkey-server-wrapper.sh /usr/bin/valkey-server
RUN chmod +x /usr/bin/valkey-server

EXPOSE 6379

CMD ["valkey-server"]
