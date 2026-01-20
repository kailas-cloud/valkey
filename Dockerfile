# Multi-stage build to extract modules from valkey-bundle
FROM --platform=linux/amd64 valkey/valkey-bundle:9.0-bookworm AS modules

# Final image based on Valkey 9.0
FROM --platform=linux/amd64 valkey/valkey:9.0-bookworm

# Copy all modules from valkey-bundle
COPY --from=modules /usr/lib/valkey/ /usr/lib/valkey/

# Copy custom configuration with coordinator enabled
COPY valkey.conf /usr/local/etc/valkey/valkey.conf

EXPOSE 6379

CMD ["valkey-server", "/usr/local/etc/valkey/valkey.conf"]
