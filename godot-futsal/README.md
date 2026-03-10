# Juego de Fútbol Sala 3D (Godot 4)

Prototipo de fútbol sala 3D con menús 2D, online por IP, IA de compañeros/rivales y sistema de partidos más pulido.

## Novedades importantes
- ✅ Pelota corregida para juego de futsal (no cae): movimiento en plano + fricción realista.
- ✅ Campo ampliado a proporciones de futsal realistas (**40 x 20 m** aprox en unidades de juego).
- ✅ IA mejorada por roles (GK, Cierre, Ala Izq, Ala Der, Pivot) con decisiones más coherentes.
- ✅ Modo **Vs IA** para jugar en solitario contra la máquina.
- ✅ HUD repensado: panel compacto con marcador, reloj, stamina, posesión, modo y eventos.
- ✅ Controles móviles en pantalla (D-Pad + Patear + Sprint).

## Menús 2D
- **MainMenu2D**: entrar al partido, abrir creador de plantilla, salir.
- **TemplateMenu2D**: editor visual de plantilla con 5 posiciones, rating, chemistry y progreso.

## Sistema de plantilla
- Base de muchos jugadores disponibles con stats.
- Selección obligatoria por posición para plantilla completa.
- Vista rápida de banca y detalle de jugador.

## Partidos 3D (online por IP y vs IA)
- Host/Join por ENet en puerto `7777`.
- Botón **Vs IA** para jugar solo contra el equipo rival controlado por IA.
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

## Controles móvil
- **D-Pad izquierdo:** movimiento
- **Botón SPRINT:** correr
- **Botón PATEAR:** disparar/pasar

## Cómo ejecutar
1. Abrí **Godot 4.x**.
2. Importá la carpeta `godot-futsal`.
3. Ejecutá el proyecto (`res://scenes/MainMenu2D.tscn`).
