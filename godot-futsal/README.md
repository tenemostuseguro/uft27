# UFT 27 (Ultimate Futsal Team) - Prealpha

Prototipo prealpha de fútbol sala 3D con menús 2D, online por IP, IA de compañeros/rivales y sistema de partidos en evolución.

## Versionado y changelog
- Versión actual: **0.0.21-prealpha**
- Archivo oficial de cambios: `CHANGELOG.md`

## Novedades importantes
- ✅ Pelota corregida para juego de futsal (no cae): movimiento en plano + fricción realista.
- ✅ Campo ampliado a proporciones de futsal realistas (**40 x 20 m** aprox en unidades de juego).
- ✅ IA mejorada por roles (GK, Cierre, Ala Izq, Ala Der, Pivot) con decisiones más coherentes.
- ✅ Modo **Vs IA** para jugar en solitario contra la máquina.
- ✅ HUD repensado: panel compacto con marcador, reloj, stamina, posesión, faltas, modo y eventos.
- ✅ Reglas básicas añadidas: límites de campo, faltas, saques de banda, córners y saques de meta.
- ✅ Regla de **doble penalti** (desde la 6ª falta de equipo en cada tiempo).
- ✅ Sistema de **cambios** con banca dinámica y contador en HUD.
- ✅ Controles móviles en pantalla (D-Pad + Patear + Sprint).

## Menús 2D
- **LoginMenu2D**: acceso con cuenta Supabase (usuario + contraseña) o modo offline.
- **MainMenu2D**: jugar con plantilla, partido rápido, abrir ayuda, ajustes o salir.
- **MatchModeMenu2D**: selector exclusivo de modo (Host, Join, Vs IA) antes de entrar al partido.
- **TemplateMenu2D**: editor visual de plantilla con 5 posiciones, rating, chemistry y progreso.
- **ProfileMenu2D**: foto de perfil + selector de escudo filtrando por país y liga.
- **HelpMenu2D**: guía rápida de controles y reglas activas.
- **SettingsMenu2D**: ajustes básicos de pantalla completa y volumen master.

## Sistema de plantilla
- Base de muchos jugadores disponibles con stats.
- Selección obligatoria por posición para plantilla completa.
- Vista rápida de banca y detalle de jugador.

## Partidos 3D (online por IP y vs IA)
- Host/Join por ENet en puerto `7777` desde menú de modo.
- Opción **Vs IA** desde menú de modo, separada del HUD del partido.
- Host autoritativo para física y marcador en online.
- Sincronización de pelota y jugadores por RPC.

## IA mejorada de compañeros y rivales
- Cada bot tiene rol táctico.
- Roles y comportamientos diferenciados para atacar y defender.
- Portero despeja y protege arco; cierre corrige coberturas; alas abren cancha; pivot fija y define.

## Flujo recomendado
1. Abrir proyecto (entra al menú principal 2D).
2. Entrar en creador de plantilla.
3. Seleccionar un jugador por cada posición.
4. Guardar plantilla y volver.
5. Iniciar partido y elegir Host, Join o Vs IA.

## Controles PC
- **Moverse:** `WASD` o flechas
- **Sprint:** `Shift`
- **Patear:** `Espacio`
- **Pedir cambio:** `C`
- **Pausa:** `Esc` (reanudar, reiniciar o volver al menú)

## Controles móvil
- **D-Pad izquierdo:** movimiento
- **Botón SPRINT:** correr
- **Botón PATEAR:** disparar/pasar
- **Botón CAMBIO:** pedir sustitución

## Cómo ejecutar
1. Abrí **Godot 4.x**.
2. Importá la carpeta `godot-futsal`.
3. Ejecutá el proyecto (`res://scenes/MainMenu2D.tscn`).




## Arranque, intro y loading screen
- El juego ahora arranca con una intro reproducida desde `res://assets/intro.mp4`.
- La intro se puede saltar con un toque, click o confirmación de teclado/gamepad.
- Después se muestra una pantalla de carga usando `res://assets/loading.png` con barra de progreso visible.
- La carpeta `godot-futsal/assets/` queda versionada con `.gitkeep` para que siempre exista en el repo.
- Resolución recomendada para ambos recursos: **16:9**.
  - Mínimo recomendado: **1280x720**.
  - Ideal para mejor nitidez: **1920x1080**.

## Perfil visual (logos de evento/equipo)
- Cada perfil usa un logo/avatar que puede ser de **evento**, **equipo** o personalizado por URL.
- Formatos esperados: `.png`, `.jpg`, `.jpeg` o `.webp`. Si la URL remota termina en `.gif`, el cliente intentará una variante estática compatible y, si no existe, caerá al logo por defecto.
- Todos los perfiles tienen por defecto el mismo logo base: `UFT Default` (`res://assets/default_profile_logo.png`).
- El logo del perfil se muestra también en `MainMenu2D` (panel derecho).
- SQL y RPC incluidos en `supabase/schema.sql`:
  - `profile_logos`
  - `player_profile_logo`
  - `list_profile_logos()`
  - `get_player_profile_logo(uuid)`
  - `set_player_profile_logo(uuid, uuid, text)`
- Edición web incluida en `admin.php`:
  - crear logos (evento/equipo/default)
  - asignar logo a usuario

## Notificaciones in-game (Supabase)
- Panel de notificación grande en **menú principal** (ocupando gran parte de la pantalla), con estilo de anuncio oficial.
- Cada notificación puede tener: `header`, `title`, `body` e `image_url` (ruta local `res://...` o URL http/https).
- Flujo: al cerrar/aceptar se marca como leída en Supabase y pasa a la siguiente pendiente.
- SQL incluido en `supabase/schema.sql`:
  - `notifications`
  - `player_notification_reads`
  - RPC `list_player_notifications(...)`
  - RPC `mark_player_notification_read(...)`

## Cuenta y Supabase
- El login se usa únicamente con **username + contraseña** desde la UI.
- La conexión a Supabase queda fija en código (URL + anon key internas) y ya no es editable desde el juego.
- El esquema usa `player_accounts` con `password_hash` y `profiles` enlazado por `id` (sin depender de email de `auth.users`).
- Importá (o reejecutá) `supabase/schema.sql` en tu proyecto Supabase para crear/migrar tablas y funciones RPC de registro/login.


## Panel de administración (PHP)
- Archivo: `admin.php` (en la raíz del repo).
- Permite listar usuarios de `player_accounts`, resetear contraseña y eliminar cuentas.
- Incluye publicación de notificaciones in-game (`notifications`) con título, contenido e imagen URL.
- Variables de entorno requeridas:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `ADMIN_PANEL_PASSWORD`
- Ejemplo local:
  - `SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... ADMIN_PANEL_PASSWORD=admin123 php -S 127.0.0.1:8080`
  - Abrir `http://127.0.0.1:8080/admin.php`


## Importación manual del logo por defecto
- Nombre esperado del archivo: `default_profile_logo.png`.
- Ruta donde debes ponerlo: `godot-futsal/assets/default_profile_logo.png` (en Godot: `res://assets/default_profile_logo.png`).
- La misma carpeta también se usa para `intro.mp4` y `loading.png`.
- No se incluye ninguna imagen en el repo para evitar bloqueo por binarios.


## Bloqueo de imágenes en repo
- Este repo bloquea archivos de imagen para evitar rechazos de rama por binarios.
- Se agregó `.gitignore` con extensiones de imagen (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.bmp`, `.ico`, `.svg`).
- Si necesitás logo por defecto, importalo localmente sin trackearlo en git en `godot-futsal/assets/default_profile_logo.png`.


## Recuperación de rama rechazada por binarios
- Si el remoto sigue rechazando la rama por binarios, reconstruí la historia de la rama y forzá push con lease.
- Script incluido: `scripts/rebuild_branch_without_binaries.sh`
- Uso:
  - `bash scripts/rebuild_branch_without_binaries.sh <base_commit> [branch_name] [remote_name]`
  - Ejemplo (rama actual): `bash scripts/rebuild_branch_without_binaries.sh 7ab7ae8`
  - Ejemplo (rama explícita): `bash scripts/rebuild_branch_without_binaries.sh 7ab7ae8 work origin`
- Después ejecutá:
  - `git push --force-with-lease origin <tu-rama>`


## Validación anti-binarios
- `.gitattributes` fuerza archivos de código/escena como texto para evitar falsos positivos de binario.
- Script de comprobación incluido: `scripts/check_binary_history.sh`
- Ejemplo:
  - `bash scripts/check_binary_history.sh 7ab7ae8 HEAD`


## Compatibilidad Codex/GitHub (rechazo binarios)
- `.gitattributes` está configurado solo con reglas de texto (sin marcar extensiones como `binary`).
- `.gitignore` bloquea imágenes para que no se trackeen (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.bmp`, `.ico`, `.svg`).
- Validá antes de push con: `bash scripts/check_binary_history.sh 7ab7ae8 HEAD`.


- Validación extra de texto puro:
  - `python3 scripts/check_nontext_tracked_files.py`

- Diagnóstico ampliado (atributos + NUL + numstat):
  - `bash scripts/codex_binary_diagnostics.sh 7ab7ae8 HEAD`

- Último recurso (snapshot huérfano text-only para Codex→GitHub):
  - `git checkout <tu-rama>`
  - `bash scripts/codex_force_text_snapshot.sh`
  - (Opcional: `bash scripts/codex_force_text_snapshot.sh <branch> <remote>` para forzar rama/remoto)
