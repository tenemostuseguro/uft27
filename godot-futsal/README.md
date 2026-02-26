# Juego de Fútbol Sala 3D (Godot 4)

Prototipo base de fútbol sala **3D** con flujo de menús **2D**, creador de plantilla y modo online por IP.

## Menús incluidos (2D)
- **Menú principal** (`MainMenu2D.tscn`): jugar, abrir creador de plantilla o salir.
- **Creador de plantilla** (`TemplateMenu2D.tscn`): nombre de equipo, colores y formación.

## Características
- Cancha 3D simple.
- Jugador 3D con movimiento, sprint y disparo.
- Pelota con física (`RigidBody3D`).
- Marcador + cronómetro.
- Modo online por IP (host/join) para 2 jugadores.

## Flujo recomendado
1. Abrir el juego (entra al **menú principal 2D**).
2. Ir a **Creador de plantilla** y guardar.
3. Volver y pulsar **Jugar partido**.
4. En la escena de partido, elegir Host o Join (IP del host).

## Online P2P (por ahora)
Se usa conexión directa por IP con ENet:
- Un jugador crea sala (**Host**) en puerto `7777`.
- El otro se conecta con la IP del host (**Join**).

> Nota: técnicamente usa arquitectura host-cliente con conexión directa IP, que para prototipo cumple el flujo P2P pedido.

## Cómo ejecutar
1. Abrí **Godot 4.x**.
2. Importá la carpeta `godot-futsal`.
3. Ejecutá el proyecto (escena principal: `res://scenes/MainMenu2D.tscn`).

## Controles en partido
- **Moverse:** `WASD` o flechas
- **Sprint:** `Shift`
- **Patear:** `Espacio`
