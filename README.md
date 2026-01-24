# Futsal Arcade Mobile - Prototipo 1 (Godot)

Este repositorio contiene una vertical slice base en Godot para el prototipo de futsal arcade con evento semanal y mercado P2P.

## Estructura

- `project.godot`: configuracion principal del proyecto Godot.
- `scenes/Main.tscn`: escena principal con UI de estado y navegacion.
- `scenes/views/*.tscn`: pantallas Home, Evento, Mercado y Match.
- `scripts/Main.gd`: flujo principal, navegacion y simulacion de loops.
- `scripts/views/*.gd`: controladores de vistas para rellenar datos.
- `scripts/data/PrototypeData.gd`: datos y helpers del prototipo (match, evento, mercado).

## Uso rapido

1. Abre el proyecto en Godot 4.x.
2. Ejecuta la escena `Main.tscn`.
3. Explora el panel HUD para ver energia, tokens, estrellas, y ejemplos de acciones.

## Nota

Esta vertical slice es una base de simulacion para el loop del evento y el mercado. El gameplay real de futsal se integraria en escenas futuras.
