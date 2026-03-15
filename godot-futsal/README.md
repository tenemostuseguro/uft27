# UFT 27 (Ultimate Futsal Team) - Prealpha

Prototipo prealpha de fútbol sala 3D con menús 2D, online por IP, IA de compañeros/rivales y sistema de partidos en evolución.

## Versionado y changelog
- Versión actual: **0.0.5-prealpha**
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


## Cuenta y Supabase
- El login se usa únicamente con **username + contraseña** desde la UI.
- La conexión a Supabase queda fija en código (URL + anon key internas) y ya no es editable desde el juego.
- El esquema usa `player_accounts` con `password_hash` y `profiles` enlazado por `id` (sin depender de email de `auth.users`).
- Importá `supabase/schema.sql` en tu proyecto Supabase para crear tablas y funciones RPC de registro/login.
