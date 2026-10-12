# Mailcow en EasyPanel / Contabo

Esta rama prepara un **servicio Compose desde Git** para `notificaciones.ya.com.bo`. No ejecuta despliegues ni cambia el VPS. EasyPanel debe usar `easypanel-compose.yml`, no el Compose oficial. La primera puesta en marcha y la renovación ACME requieren comprobación en el servidor.

## Diseño

- EasyPanel/Traefik conserva los puertos 80 y 443. En **Dominios**, dirigir `notificaciones.ya.com.bo` por HTTPS a `nginx-mailcow`, puerto interno `8080`, protocolo HTTP. EasyPanel emite el certificado web.
- Mailcow usa ACME DNS-01 con Vercel para el certificado compartido por Postfix, Dovecot y Nginx. `mailcow-init` genera un certificado temporal único en el primer arranque. Este certificado no debe considerarse válido para clientes hasta que ACME termine.
- Solo se publican 25, 465, 587 y 993 del host. MySQL, Redis, Dovecot admin y la web no publican puertos de host. Si se necesitan 143, 110, 995 o 4190, habilitarlos después de verificar que estén libres.
- La red Compose usa `172.30.50.0/24` y el puente `br-mailcow`. Revisar ambos contra las redes y rutas reales antes del primer despliegue.
- Los datos de configuración, web y certificados se guardan en el bind mount absoluto `MAILCOW_DATA_PATH` (por defecto `/opt/mailcow-easypanel-data`). Los mensajes, índices y bases de datos usan los volúmenes nombrados en Compose. Mantener fijo el nombre del proyecto Compose para conservarlos.
- `netfilter-mailcow` se eliminó por completo del Compose de EasyPanel: no puede arrancar desde esta variante. Véase la sección de acceso a Docker y firewall.

## Preparación en EasyPanel

1. Confirmar en el VPS que la red `172.30.50.0/24`, el puente `br-mailcow` y los puertos TCP 25, 465, 587 y 993 estén libres. Comprobar también entrada TCP 25 desde Internet, salida SMTP, espacio, hora y copias de seguridad. Esto no se puede deducir de `docker compose config`.
2. Crear **Proyecto > Nuevo servicio > Compose > Git**. Repositorio: `https://github.com/daniel199180/mailcow-dockerized.git`; rama: `easypanel-contabo`; Build Path: `/`; archivo: `easypanel-compose.yml`.
3. En **Entorno**, activar **Create .env file** y definir las variables de `easypanel.env.example`, sustituyendo todos los marcadores por secretos distintos y aleatorios. El repo no contiene `.env`; el panel debe escribirlo para que Compose interpole las variables. No registrar contraseñas ni el token en Git, logs, capturas o texto de un PR.
4. Para la instalación existente, definir `COMPOSE_PROJECT_NAME=servicios_mailtiendaya` en el entorno, pues es el identificador real observado en las etiquetas y los volúmenes. Verificar en la configuración generada que el proyecto se llama `mailtiendaya`; Mailcow usa ese nombre para localizar sus contenedores durante la renovación de certificados y para las tareas de Ofelia. Si EasyPanel impone otro nombre, usar ese nombre real en `COMPOSE_PROJECT_NAME` antes de desplegar.
5. Usar `MAILCOW_DATA_PATH=/opt/mailcow-easypanel-data` o elegir otra ruta absoluta y persistente. El contenedor `mailcow-init` copia solo archivos ausentes desde la revisión Git y nunca reemplaza archivos existentes. No cambiar esta ruta ni el nombre Compose sin plan de migración de datos.
6. En **Dominios**, agregar `notificaciones.ya.com.bo` con TLS de EasyPanel, servicio interno `nginx-mailcow`, puerto `8080`, protocolo HTTP. No crear un segundo router Traefik por etiquetas Compose ni publicar 80/443 desde Mailcow.
7. Solo después de revisar la configuración y los avisos de compatibilidad de EasyPanel, usar **Deploy**. Esta guía no autoriza ni ejecuta ese paso.

## Variables imprescindibles

`MAILCOW_HOSTNAME`, `TZ`, `DBNAME`, `DBUSER`, `DBPASS`, `DBROOT`, `REDISPASS`, `SOGO_URL_ENCRYPTION_KEY`, `ACME_ACCOUNT_EMAIL`, `VERCEL_TOKEN`, `VERCEL_TEAM_ID` y `COMPOSE_PROJECT_NAME` deben tener valores reales. Generar contraseñas de al menos 24 caracteres aleatorios; usar valores diferentes. `VERCEL_TOKEN` debe poder editar TXT de la zona DNS de `ya.com.bo` dentro del Team indicado por `VERCEL_TEAM_ID` (formato `team_` seguido de caracteres alfanuméricos). El token y el Team ID entran solo a `acme-mailcow`, no al inicializador. El cliente acme.sh puede guardar el token en el estado ACME persistente: proteger y cifrar sus copias de seguridad.

`ACME_DNS_CHALLENGE=y`, `ACME_DNS_PROVIDER=dns_vercel`, `ONLY_MAILCOW_HOSTNAME=y` y `AUTODISCOVER_SAN=n` están fijados en este Compose. No incluir otros SAN hasta comprobar que Vercel controla sus zonas. La configuración de DNS está en [EASYPANEL-VERCEL-DNS.md](EASYPANEL-VERCEL-DNS.md).

## Persistencia y actualizaciones

Respaldar **juntos** `/opt/mailcow-easypanel-data` (o el bind configurado) y todos los volúmenes nombrados, en particular `mysql-vol-1`, `vmail-vol-1`, `vmail-index-vol-1`, `crypt-vol-1`, `redis-vol-1` y `postfix-vol-1`. Incluir permisos y llaves de `assets/ssl`; comprobar una restauración fuera de producción. No usar `down -v` ni borrar el servicio sin una copia verificada.

El inicializador conserva cambios y secretos existentes, pero **no actualiza archivos ya copiados** en `web`, `conf`, `hooks` o `assets`. Antes de actualizar Mailcow o sus imágenes, comparar esos archivos con la nueva revisión y aplicar la migración de la versión en una ventana controlada. No habilitar actualizaciones automáticas de imágenes para este stack.

## Firewall y acceso a Docker

`netfilter-mailcow` está fuera de este Compose para evitar cambios de firewall del VPS compartido. No activar ni reintroducirlo sin auditoría específica. El valor `DISABLE_NETFILTER_ISOLATION_RULE=y` evita su regla de aislamiento específica, pero **no** impide las reglas de bloqueo de IP. Sin Netfilter, las prohibiciones de IP de Mailcow no se aplican en el firewall del host; usar controles externos adecuados.

`dockerapi-mailcow` y `ofelia-mailcow` montan `/var/run/docker.sock:ro`. El `:ro` protege el archivo de socket, pero **no convierte la API Docker en solo lectura**: dockerapi puede iniciar, detener y reiniciar contenedores y Ofelia ejecuta tareas mediante la API. El código de dockerapi acepta IDs/nombres de contenedor; no está limitado al proyecto Compose. Mantener estos servicios sin puertos publicados, restringir acceso al panel y considerar un VPS dedicado si se necesita aislamiento fuerte frente a otros proyectos.

## Comprobación posterior a un despliegue autorizado

Revisar en EasyPanel que `mailcow-init` termine con código 0 y que Unbound, MariaDB, Redis, Postfix, Dovecot, Nginx y ACME estén sanos. Comprobar que `acme-mailcow` obtuvo un certificado válido para `notificaciones.ya.com.bo` y que Postfix y Dovecot lo sirven en 465/587 y 993. Confirmar HTTPS web a través de Traefik y probar un envío autenticado y la recepción de correo en un dominio configurado. Verificar A, PTR/rDNS, MX (si se recibirá), SPF, DKIM y DMARC para el dominio remitente real. Cambiar inmediatamente la contraseña inicial de administrador de Mailcow.

## Validación local sin desplegar

Con Docker Compose 2.38.2 y un archivo de entorno **local no versionado** con valores ficticios:

```sh
docker compose --env-file /ruta/segura/mailcow-check.env -f easypanel-compose.yml config --quiet
```

Esta validación comprueba interpolación y estructura, pero no construye imágenes, no comprueba credenciales Vercel ni demuestra conectividad o compatibilidad con el VPS. EasyPanel también debe revisar sus avisos de Compose antes de cualquier despliegue.

Referencias: [servicios Compose de EasyPanel](https://easypanel.io/docs/services/compose), [reverse proxy de Mailcow](https://docs.mailcow.email/post_installation/reverse-proxy/r_p/), [DNS-01 de Mailcow](https://docs.mailcow.email/post_installation/firststeps-ssl-dns/).
