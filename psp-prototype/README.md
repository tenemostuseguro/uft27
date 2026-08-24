# UFT 11 Portable Prototype v0.2

Prototype of an 11-a-side Ultimate Team-style game for PSP / PPSSPP.

## Included
- 4-3-3 eleven-player squad screen.
- Coins and a small pack-opening loop.
- Playable top-down ASCII 11v11 match prototype.
- D-pad player movement.
- X for pass / tackle.
- Circle for shooting.
- Triangle to switch player.
- Accelerated 90-minute match and reward screen.

This is a technical prototype. Graphics, real player data, cards, animations, physics and a full AI/gameplay layer are intentionally not implemented yet.

## Build with PSPDEV

```bash
export PSPDEV="$HOME/pspdev"
export PATH="$PATH:$PSPDEV/bin"
make clean
make
```

The result is `EBOOT.PBP`.

## PPSSPP
Create `PSP/GAME/UFT11/` inside the PPSSPP memstick folder and copy `EBOOT.PBP` into it.
