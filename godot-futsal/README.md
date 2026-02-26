# Juego de Fútbol Sala 3D (Godot 4)

Prototipo base de fútbol sala **3D** con modo online por IP.

## Características
- Cancha 3D simple.
- Jugador 3D con movimiento, sprint y disparo.
- Pelota con física (`RigidBody3D`).
- Marcador + cronómetro.
- Modo online por IP (host/join) para 2 jugadores.

## Online P2P (por ahora)
Se usa conexión directa por IP con ENet:
- Un jugador crea sala (**Host**) en puerto `7777`.
- El otro se conecta con la IP del host (**Join**).

> Nota: técnicamente usa arquitectura host-cliente con conexión directa IP, que para prototipo cumple el flujo P2P que pediste.

## Cómo ejecutar
1. Abrí **Godot 4.x**.
2. Importá la carpeta `godot-futsal`.
3. Ejecutá `res://scenes/Main3D.tscn`.

## Controles
- **Moverse:** `WASD` o flechas
- **Sprint:** `Shift`
- **Patear:** `Espacio`

## Flujo online
1. Jugador A pulsa **Host**.
2. Jugador B escribe la IP de A y pulsa **Join**.
3. Cada jugador controla su avatar.
4. El host mantiene estado autoritativo de pelota y marcador.
