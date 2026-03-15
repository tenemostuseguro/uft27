# UFT 27 (Ultimate Futsal Team) - Changelog

> Proyecto en **prealpha**. Cada cambio funcional importante incrementa versión.

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
