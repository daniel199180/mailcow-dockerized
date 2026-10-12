# DNS de Vercel para Mailcow (notificaciones.ya.com.bo)

> Documentación de preparación; no desplegar todavía. No contiene secretos.

## Confirmar que Vercel es DNS autoritativo

Que la web esté en Vercel no garantiza que su DNS esté allí. Comprobar en Vercel > Domains > ya.com.bo que figuren los registros DNS. Alternativamente, `dig +short NS ya.com.bo`; los nameservers oficiales de Vercel son `ns1.vercel-dns.com` y `ns2.vercel-dns.com`.

## Registro A (panel Mailcow en VPS Contabo)

En Vercel > Domains > ya.com.bo > DNS Records:

| Type | Name | Value |
| --- | --- | --- |
| A | notificaciones | 94.72.119.78 |

No borrar MX ni TXT existentes del dominio. No agregar MX del dominio raíz hasta tener decidido el dominio remitente y la recepción de mensajes. El registro A solo resuelve el subdominio, no habilita automáticamente SMTP ni certificados.

Comprobar propagación: `dig +short A notificaciones.ya.com.bo` debería devolver `94.72.119.78`.

## Certificados SMTP/IMAP por DNS-01 usando Vercel

Mailcow soporta DNS-01 mediante acme.sh, y acme.sh dispone del plugin `dns_vercel`. Variables de referencia para `mailcow.conf` o el entorno de EasyPanel:

```dotenv
MAILCOW_HOSTNAME=notificaciones.ya.com.bo
ACME_DNS_CHALLENGE=y
ACME_DNS_PROVIDER=dns_vercel
ACME_ACCOUNT_EMAIL=REEMPLAZAR_CON_CORREO_DE_CONTACTO
ONLY_MAILCOW_HOSTNAME=y
AUTODISCOVER_SAN=n
```

El plugin acme.sh usa `VERCEL_TOKEN`. **NO** subir el token a Git, ni escribirlo en un archivo público. El plugin de Mailcow carga `data/conf/acme/dns-01.conf` (archivo local protegido) con el token. Hay que confirmar que la cuenta/alcance del token tenga acceso a la zona. El plugin puede tener limitaciones con dominios propiedad de Teams: validar la solicitud real antes de confiar en la renovación automática.

Configurar `ACME_DNS_CHALLENGE=y` no sustituye la preparación previa de volúmenes, certificados temporales, `mailcow.conf`, ni la integración Traefik. **No desplegar** el Compose oficial sin estas etapas.

## DNS para envíos y recepción

Para enviar correo, configurar SPF, DKIM y DMARC en el **dominio exacto del remitente**. El hostname del servidor no siempre coincide con el dominio del correo (ejemplo: `no-reply@ya.com.bo` frente a `no-reply@notificaciones.ya.com.bo`). El registro MX es necesario para recibir mensajes en un dominio concreto; no reemplazar registros MX existentes de `ya.com.bo` sin planificar una migración.

## Referencias
- [Vercel DNS records](https://vercel.com/docs/domains/managing-dns-records)
- [Vercel subdominio apuntando fuera](https://vercel.com/kb/guide/pointing-subdomains-to-external-services)
- [Mailcow DNS-01](https://docs.mailcow.email/post_installation/firststeps-ssl-dns/)
- [acme.sh Vercel](https://github.com/acmesh-official/acme.sh/blob/master/dnsapi/dns_vercel.sh)
