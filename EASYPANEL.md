# Mailcow en EasyPanel — Contabo / TiendaYa (BORRADOR NO DESPLEGABLE)
 
**Estado:** documentación preliminar. NO pulsar «Implementar» con el Compose oficial todavía.

## Infraestructura ya verificada
- Ubuntu 24.04, Docker 28.3.2, Compose 2.38.2.
- 23 GiB RAM, 2 GiB swap y espacio disponible.
- EasyPanel/Traefik ocupa 80 y 443.
- Puertos de correo 25, 465, 587 y 993 aparecen libres en escucha local; la salida TCP 25 hacia Gmail funciona.
- Red Docker Appwrite 172.22.0.0/16: choca con red predeterminada de Mailcow (172.22.1.0/24).
- Red propuesta 172.30.50.0/24, no presente en rutas recopiladas.
- Hostname deseado: notificaciones.ya.com.bo.

## Bloqueos reales del despliegue Git en EasyPanel
1. El `docker-compose.yml` depende de `mailcow.conf` (en la instalación oficial, `.env` enlaza a ese archivo). EasyPanel puede producir un .env, pero ello **no equivale** a ejecutar `generate_config.sh`.
2. `generate_config.sh` prepara certificados temporales iniciales y otros archivos. No es seguro confiar en que Git / EasyPanel ejecutará scripts interactivos.
3. Numerosos bind mounts `./data/...` requieren árbol de archivos persistente, idéntico al del repositorio. Comprobar qué ruta Git monta EasyPanel y qué sobrevive a redeploy.
4. `netfilter-mailcow` usa `privileged: true` y `network_mode: host`, por lo que hay que revisar su efecto en reglas firewall del VPS compartido.
5. Los puertos 80/443 están ocupados. Traefik en EasyPanel **no alcanza 127.0.0.1 de host por defecto**; requiere red Docker compartida, un proxy adecuado o publicación restringida de puertos.
6. Los certificados HTTPS web emitidos por Traefik no se pasan automáticamente a Postfix y Dovecot. Planificar ACME DNS-01 o sincronización de certificados.
7. Hay que configurar PTR/rDNS en Contabo, DNS A, SPF, DKIM, DMARC y política de salida; validar puerto 25 entrante de Internet.
8. El servicio `ofelia-mailcow` espera `COMPOSE_PROJECT_NAME` consistente con el nombre real del proyecto Compose.

## Configuración de referencia
Usar `easypanel.env.example` para las variables de *referencia*. Crear contraseñas diferentes y aleatorias fuera de Git, en EasyPanel, nunca copiar los marcadores a producción.

## Próxima validación
- Confirmar proveedor DNS de `ya.com.bo` y permisos para TXT DNS-01.
- Confirmar comportamiento de Git/Compose de la versión actual de EasyPanel: ruta de checkout, persistencia y soporte para override.
- Preparar bootstrap reproducible de certificados y archivos antes de redactar Compose definitivo.
- Evaluar separar el servidor de correo en un VPS dedicado si se utiliza para clientes externos, por disponibilidad y reputación.

Referencias: [Mailcow documentación](https://docs.mailcow.email/) y [Compose oficial](./docker-compose.yml).

**No se ha realizado ningún despliegue ni se ha modificado Contabo con este documento.**
