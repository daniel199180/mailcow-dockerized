#!/bin/sh
set -eu

umask 077
: "${MAILCOW_HOSTNAME:?MAILCOW_HOSTNAME is required}"

case "$MAILCOW_HOSTNAME" in
  *[!a-zA-Z0-9.-]*|.*|*..*|*.)
    echo 'Invalid MAILCOW_HOSTNAME' >&2
    exit 1
    ;;
esac
case "$MAILCOW_HOSTNAME" in
  *.*) ;;
  *) echo 'MAILCOW_HOSTNAME must be a FQDN' >&2; exit 1 ;;
esac

# Never replace existing bind-mounted config, web customization, or ACME state.
seed_dir=${MAILCOW_SEED_DIR:-/seed}
data_dir=${MAILCOW_DATA_DIR:-/mailcow-data}
mkdir -p "$data_dir"
rsync -a --ignore-existing "$seed_dir/" "$data_dir/"
mkdir -p "$data_dir/web/.well-known/acme-challenge"
chmod 0755 "$data_dir/web/.well-known" "$data_dir/web/.well-known/acme-challenge"

# Twig compiles templates at runtime; PHP-FPM runs as www-data.
# The seeded Git tree is owned by root, so grant ownership only to Twig cache.
twig_cache="$data_dir/web/templates/cache"
mkdir -p "$twig_cache"
chown -R "$(id -u www-data):$(id -g www-data)" "$twig_cache"
chmod 0755 "$twig_cache"

ssl_dir=$data_dir/assets/ssl
mkdir -p "$ssl_dir"
chmod 0755 "$ssl_dir"
# Dovecot requires a DH parameter file in the same persistent SSL directory.
# Seed it only when missing; never replace an existing Mailcow-generated file.
dh_source="$data_dir/assets/ssl-example/dhparams.pem"
dh_target="$ssl_dir/dhparams.pem"
if [ ! -e "$dh_target" ]; then
  if [ ! -s "$dh_source" ]; then
    echo 'Missing Mailcow bundled dhparams.pem; refusing to start.' >&2
    exit 1
  fi
  cp "$dh_source" "$dh_target"
  chmod 0644 "$dh_target"
fi
if [ ! -s "$dh_target" ]; then
  echo 'Empty dhparams.pem in persistent SSL directory.' >&2
  exit 1
fi
if [ ! -e "$ssl_dir/cert.pem" ] && [ ! -e "$ssl_dir/key.pem" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 7 \
    -subj "/O=mailcow/CN=$MAILCOW_HOSTNAME" \
    -addext "subjectAltName=DNS:$MAILCOW_HOSTNAME" \
    -keyout "$ssl_dir/key.pem" -out "$ssl_dir/cert.pem" >/dev/null 2>&1
  chmod 0600 "$ssl_dir/key.pem"
  echo 'Generated temporary certificate for Mailcow services.'
elif [ ! -s "$ssl_dir/cert.pem" ] || [ ! -s "$ssl_dir/key.pem" ]; then
  echo 'Incomplete SSL certificate pair in persistent data directory' >&2
  exit 1
fi

test -s "$data_dir/conf/unbound/unbound.conf"
test -s "$data_dir/web/index.php"
echo 'Persistent Mailcow files are ready.'
