# UFT 27 (Ultimate Futsal Team) - Changelog

> Proyecto en **prealpha**. Cada cambio funcional importante incrementa versión.

## 0.0.9-prealpha
- Se movió el sistema de notificaciones para que aparezca en el **menú principal** (no durante el partido).
- El panel mantiene cola de mensajes, carga desde Supabase y marcado como leída al cerrar cada notificación.
- Se retiró el overlay de notificaciones de `Main3D` para no mezclar avisos con el motor de juego.

## 0.0.8-prealpha
- Se añadió sistema de notificaciones in-game conectado a Supabase en `Main3D`: panel grande estilo mensaje oficial con título, cuerpo e imagen.
- Al cerrar una notificación, se marca como leída en Supabase y se muestra la siguiente; si no hay más, el panel se cierra.
- Se amplió `supabase/schema.sql` con tablas y RPC para eventos/notificaciones: `notifications`, `player_notification_reads`, `list_player_notifications`, `mark_player_notification_read`.

## 0.0.7-prealpha
- Se añadió `admin.php` para moderación de usuarios en Supabase (`player_accounts`).
- Incluye login de admin por `ADMIN_PANEL_PASSWORD`, listado de usuarios, borrado de cuenta y reset de contraseña.

## 0.0.6-prealpha
- Se corrigió la migración de `profiles`: ahora el schema elimina el FK viejo y lo recrea apuntando a `player_accounts(id)`.
- Se limpian trigger/función legacy de `auth.users` para evitar altas conflictivas.
- El nuevo FK se crea como `NOT VALID` para no romper instalaciones con datos legacy, pero validar altas nuevas.

## 0.0.5-prealpha
- Se eliminaron los campos editables de conexión a Supabase del `LoginMenu2D` para evitar cambios de configuración desde la UI.
- Login y registro quedaron orientados sólo a `username + contraseña` en pantalla.
- Se eliminó la dependencia de email en auth: ahora el backend usa `player_accounts` con `password_hash` y funciones RPC para registrar/autenticar por username.
- Se endureció validación de username para evitar errores de alta/login.

## 0.0.4-prealpha
- Se preconfiguró Supabase con URL/anon key oficiales del entorno actual.
- Login/registro ahora cargan credenciales por defecto automáticamente en `LoginMenu2D`.
- Se añadió fallback para restaurar defaults de Supabase si inputs están vacíos.

## 0.0.3-prealpha
- Se añadió sistema de cuentas con Supabase (registro e inicio de sesión con usuario + contraseña).
- Se incorporó `LoginMenu2D` como pantalla inicial y opción de continuar offline.
- Se añadió `supabase/schema.sql` para bootstrap de tabla `profiles`, trigger de alta automática y políticas RLS.

## 0.0.2-prealpha
- Se rediseñó el menú principal con estilo dashboard tipo juego live-service.
- Se renombró branding del proyecto a **UFT 27 (Ultimate Futsal Team)**.
- Se añadió un apartado de **Changelog** navegable desde el menú principal.

## 0.0.1-prealpha
- Base del prototipo 3D de futsal: partidos, IA, networking ENet, menús, plantilla, perfil y HUD.
