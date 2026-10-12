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

ssl_dir=$data_dir/assets/ssl
mkdir -p "$ssl_dir"
if [ ! -e "$ssl_dir/cert.pem" ] && [ ! -e "$ssl_dir/key.pem" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 7 \
    -subj "/CN=$MAILCOW_HOSTNAME" \
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
