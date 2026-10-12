FROM alpine:3.23

RUN apk add --no-cache openssl rsync

# The image contains only public, versioned Mailcow configuration and web files.
# Runtime credentials and certificates are created on the persistent host bind.
COPY data/assets /seed/assets
COPY data/conf /seed/conf
COPY data/hooks /seed/hooks
COPY data/web /seed/web
COPY easypanel/init.sh /usr/local/bin/mailcow-init

RUN chmod 0755 /usr/local/bin/mailcow-init

ENTRYPOINT ["/usr/local/bin/mailcow-init"]
