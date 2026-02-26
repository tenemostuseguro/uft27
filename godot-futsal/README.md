# Juego de Fútbol Sala 3D (Godot 4)

Prototipo de fútbol sala 3D con menús 2D, online por IP, IA de compañeros/rivales y más sistemas de partido.

## Novedades importantes
- ✅ Pelota corregida para juego de futsal (no cae): movimiento en plano + fricción realista.
- ✅ Campo ampliado a proporciones de futsal realistas (**40 x 20 m** aprox en unidades de juego).
- ✅ IA para el resto de jugadores del equipo y del rival (presión, posicionamiento y remate).
- ✅ Más funciones de partido: stamina del jugador, reinicio tras gol, fuera de campo, descanso con cambio de lados, eventos en HUD.
- ✅ Creador de plantilla estilo **Squad**: debés elegir un jugador para cada posición del campo.

## Menús 2D
- **MainMenu2D**: entrar al partido, abrir creador de plantilla, salir.
- **TemplateMenu2D**: editor visual de plantilla con 5 posiciones (GK, Cierre, Ala Izq, Ala Der, Pivot), tarjetas visibles sobre la cancha, rating, chemistry y progreso de posiciones completadas.

## Sistema de plantilla (nuevo)
- Hay una base de muchos jugadores disponibles (ratings y stats básicos).
- Cada posición tiene su selector propio (como en juegos tipo FUT/Squad Builder).
- Si falta una posición sin jugador, la plantilla **no se puede guardar como completa**.
- Se muestra vista de banca rápida con jugadores no usados.

## Partidos 3D (online por IP)
- Host/Join por ENet en puerto `7777`.
- Host autoritativo para física y marcador.
- Sincronización de pelota y jugadores en red.

## Flujo recomendado
1. Abrir proyecto (entra al menú principal 2D).
2. Entrar en creador de plantilla.
3. Seleccionar un jugador por cada posición.
4. Guardar plantilla y volver.
5. Iniciar partido y elegir Host o Join.

## Controles
- **Moverse:** `WASD` o flechas
- **Sprint:** `Shift` (consume stamina)
- **Patear:** `Espacio`

## Cómo ejecutar
1. Abrí **Godot 4.x**.
2. Importá la carpeta `godot-futsal`.
3. Ejecutá el proyecto (`res://scenes/MainMenu2D.tscn`).
