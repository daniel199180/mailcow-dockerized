FROM alpine:3.23

LABEL maintainer = "The Infrastructure Company GmbH <info@servercow.de>"

RUN apk upgrade --no-cache \
  && apk add --update --no-cache \
  bash \
  curl \
  openssl \
  bind-tools \
  jq \
  mariadb-client \
  redis \
  tini \
  tzdata \
  python3 \
  acme-tiny \
  git \
  socat \
  && git clone --depth 1 --branch 3.1.6 https://github.com/acmesh-official/acme.sh.git /opt/acme.sh \
  && test "$(git -C /opt/acme.sh rev-parse HEAD)" = 807da6498377ee5e0cf43a78091f46f12dc59a89 \
  && chmod +x /opt/acme.sh/acme.sh \
  && mkdir -p /var/lib/acme/acme-sh

ENV ACME_SH_BIN=/opt/acme.sh/acme.sh \
    ACME_SH_HOME=/opt/acme.sh \
    ACME_SH_CONFIG_HOME=/var/lib/acme/acme-sh

COPY acme.sh /srv/acme.sh
COPY functions.sh /srv/functions.sh
COPY obtain-certificate.sh /srv/obtain-certificate.sh
COPY obtain-certificate-dns.sh /srv/obtain-certificate-dns.sh
COPY load-dns-config.sh /srv/load-dns-config.sh
COPY reload-configurations.sh /srv/reload-configurations.sh
COPY expand6.sh /srv/expand6.sh
COPY dns_vercel.sh /opt/acme.sh/dnsapi/dns_vercel.sh

RUN chmod +x /srv/*.sh \
  && grep -q 'Mailcow EasyPanel scoped Vercel DNS-01 provider' /opt/acme.sh/dnsapi/dns_vercel.sh

CMD ["/sbin/tini", "-g", "--", "/srv/acme.sh"]
