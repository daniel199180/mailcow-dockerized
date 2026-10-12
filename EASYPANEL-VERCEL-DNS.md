# DNS de Vercel para Mailcow (notificaciones.ya.com.bo)

> Guía de preparación; no contiene secretos ni implica un despliegue.

## Confirmar que Vercel es DNS autoritativo

Que la web esté en Vercel no garantiza que su DNS esté allí. El 11 de octubre de 2026, `dig +short NS ya.com.bo` devolvió `ns1.vercel-dns.com` y `ns2.vercel-dns.com`. Volver a comprobarlo antes del despliegue.

## Registro A (panel Mailcow en VPS Contabo)

En Vercel > Domains > ya.com.bo > DNS Records:

| Type | Name | Value |
| --- | --- | --- |
| A | notificaciones | 94.72.119.78 |

No borrar MX ni TXT existentes del dominio. No agregar MX del dominio raíz hasta tener decidido el dominio remitente y la recepción de mensajes. El registro A solo resuelve el subdominio, no habilita automáticamente SMTP ni certificados.

El 11 de octubre de 2026, `dig +short A notificaciones.ya.com.bo` devolvió `94.72.119.78`; volver a comprobarlo antes del despliegue.

## Certificados SMTP/IMAP por DNS-01 usando Vercel

Mailcow soporta DNS-01 mediante acme.sh, y acme.sh dispone del plugin `dns_vercel`. En `easypanel-compose.yml` las opciones DNS-01 ya están fijadas. Añadir al entorno privado de EasyPanel:

```dotenv
MAILCOW_HOSTNAME=notificaciones.ya.com.bo
ACME_ACCOUNT_EMAIL=REEMPLAZAR_CON_CORREO_DE_CONTACTO
VERCEL_TOKEN=REEMPLAZAR_TOKEN_PRIVADO
```

El token se entrega solo al contenedor `acme-mailcow` como variable de entorno de EasyPanel. **No** subirlo a Git ni escribirlo en un archivo público. Confirmar que la cuenta y alcance del token permiten crear y eliminar TXT en `ya.com.bo`. acme.sh puede persistir credenciales en el volumen de certificados; proteger su copia de seguridad. Si el dominio pertenece a un Team de Vercel, comprobar una emisión real antes de confiar en la renovación automática.

El inicializador del Compose de EasyPanel prepara los archivos y un certificado temporal. La emisión real debe verificarse después de un despliegue autorizado. No desplegar el Compose oficial de Mailcow en este VPS porque publicaría 80/443.

## DNS para envíos y recepción

Para enviar correo, configurar SPF, DKIM y DMARC en el **dominio exacto del remitente**. El hostname del servidor no siempre coincide con el dominio del correo (ejemplo: `no-reply@ya.com.bo` frente a `no-reply@notificaciones.ya.com.bo`). El registro MX es necesario para recibir mensajes en un dominio concreto; no reemplazar registros MX existentes de `ya.com.bo` sin planificar una migración.

El PTR/rDNS de `94.72.119.78` devolvió `vmi2704252.contaboserver.net` el 11 de octubre de 2026. Solicitar en Contabo que apunte a `notificaciones.ya.com.bo` y verificar la resolución directa e inversa antes de usar el servidor para entregas externas.

## Referencias
- [Vercel DNS records](https://vercel.com/docs/domains/managing-dns-records)
- [Vercel subdominio apuntando fuera](https://vercel.com/kb/guide/pointing-subdomains-to-external-services)
- [Mailcow DNS-01](https://docs.mailcow.email/post_installation/firststeps-ssl-dns/)
- [acme.sh Vercel](https://github.com/acmesh-official/acme.sh/blob/master/dnsapi/dns_vercel.sh)
