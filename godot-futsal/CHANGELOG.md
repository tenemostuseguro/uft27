# UFT 27 (Ultimate Futsal Team) - Changelog

> Proyecto en **prealpha**. Cada cambio funcional importante incrementa versión.

## 0.0.23-prealpha
- Se evitó el intento inválido de `load_gif_from_buffer` en `MainMenu2D` y se añadió detección de formato remoto (MIME/firma) para no parsear GIF como PNG/JPG/WEBP.
- Para URLs `.gif` de logo de perfil, ahora se prueban variantes estáticas (`.png/.webp/.jpg/.jpeg`) sin generar warnings de parseo por formato incorrecto.
- Se incrementó versión a `0.0.23-prealpha`.

## 0.0.22-prealpha
- Se corrigió la carga de foto de perfil remota cuando `resolved_image_url` apunta a `.gif`: ahora se intenta decodificar GIF y, si no es posible, se prueban variantes estáticas (`.png/.webp/.jpg/.jpeg`) antes del fallback.
- Se incrementó versión a `0.0.22-prealpha`.

## 0.0.21-prealpha
- Se añadió flujo de arranque con intro (`res://assets/intro.mp4`) saltable y pantalla de carga con barra usando `res://assets/loading.png`.
- `AuthService` ahora persiste la sesión en `user://auth_session.cfg` para restaurar usuario automáticamente al reabrir el juego.
- Se dejó `godot-futsal/assets/` versionada con `.gitkeep` para evitar faltantes de carpeta en el repo.
- `MainMenu2D` dejó de intentar abrir URLs remotas con `Image.load_from_file()` y ahora hace fallback seguro para logos remotos incompatibles, incluyendo `.gif`.

## 0.0.20-prealpha
- Se ajustaron `scripts/codex_force_text_snapshot.sh` y `scripts/rebuild_branch_without_binaries.sh` para usar la rama actual por defecto cuando no se pasa parámetro.
- Se añadió protección para evitar reescritura accidental de `main/master` salvo override explícito con `ALLOW_MAIN=1`.
- Se actualizó documentación en `README.md` para reflejar uso branch-aware en terminales que no arrancan siempre en `work`.

## 0.0.19-prealpha
- Se añadió `scripts/codex_force_text_snapshot.sh` como último recurso para generar un commit huérfano text-only y resetear la rama antes de push (`--force-with-lease`).
- Orientado al caso de rechazo persistente por “archivos binarios no admitidos” durante sync Codex→GitHub.

## 0.0.18-prealpha
- Se quitaron permisos ejecutables de scripts utilitarios para evitar validaciones remotas agresivas de tipo de archivo.
- Se añadió `scripts/codex_binary_diagnostics.sh` para depurar rechazos de binarios en integración Codex→GitHub (numstat, atributos git y escaneo NUL).

## 0.0.17-prealpha
- Se añadió `scripts/check_nontext_tracked_files.py` para validar que todos los archivos trackeados cumplan política text-only (UTF-8, sin NUL, extensiones permitidas).
- Se documentó su uso para diagnosticar rechazos de rama por “archivos binarios no admitidos”.

## 0.0.16-prealpha
- Se simplificó `.gitattributes` para dejar solo atributos de texto y eliminar cualquier marcación de binario que pudiera gatillar rechazos en integración Codex/GitHub.
- Se documentó el flujo específico para error de rechazo binario durante actualización de rama desde Codex.

## 0.0.15-prealpha
- Se añadió `.gitattributes` para forzar tratamiento textual de `.gd`, `.tscn`, `.godot`, `.php`, `.sql`, etc., y reducir falsos positivos de binario.
- Se añadió `scripts/check_binary_history.sh` para validar que no haya marcadores binarios (`- -`) ni blobs con NUL bytes en el rango de commits.

## 0.0.14-prealpha
- Se añadió script de recuperación `scripts/rebuild_branch_without_binaries.sh` para reconstruir la rama sin historial problemático de binarios.
- Se documentó el flujo recomendado con `--force-with-lease` cuando el remoto rechaza la actualización por binarios.

## 0.0.13-prealpha
- Se añadió `.gitignore` para bloquear el trackeo de imágenes y evitar rechazos por binarios en la rama.
- Se mantiene el fallback de ruta `res://assets/default_profile_logo.png` solo como referencia local (sin archivo versionado).

## 0.0.12-prealpha
- Se quitó por completo cualquier imagen del repositorio para evitar bloqueo de ramas por archivos binarios.
- Se mantiene el path por defecto `res://assets/default_profile_logo.png`, pero el archivo debe importarse manualmente por el equipo.

## 0.0.11-prealpha
- Se eliminó el asset binario del logo por defecto y se reemplazó por `default_profile_logo.svg` (texto/SVG) para compatibilidad con repos que bloquean binarios.
- Se actualizaron referencias de logo por defecto en scripts y SQL para usar el SVG.

## 0.0.10-prealpha
- Se añadió sistema de logo/avatar de perfil con backend Supabase (`profile_logos`, `player_profile_logo`) y RPCs para listar/leer/guardar.
- Todos los perfiles usan por defecto el mismo logo base (`UFT Default`) si no tienen uno asignado.
- Se amplió `admin.php` para crear logos (evento/equipo/default) y asignarlos a usuarios.
- El logo de perfil ahora se muestra en el menú principal (`MainMenu2D`).

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
