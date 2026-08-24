# UFT FUT15 Card Lab v0.5 — PSP / PPSSPP

Visual prototype focused on FIFA 15-style Ultimate Team cards and pack opening. No matches are included.

## v0.5 visual changes

- Card faces now use a separate fallback portrait layer (`placeholder_mini` / `placeholder_full`).
- Mini-card layout calibrated from the supplied 336x420 reference.
- Full-card layout calibrated from the supplied 540x810 reference.
- Knul ExtraBold rasterized for player name, overall rating and attribute values.
- Knul Regular rasterized for position and PAC/SHO/PAS/DRI/DEF/PHY labels.
- All UI text is rendered through PSP bitmap font atlases instead of the PSP debug font.
- Original OTF font files are not shipped in the game; only rasterized glyph atlases are included.
- 21 supplied card designs remain available.

## Runtime asset layout

`EBOOT.PBP` expects these folders next to it:

- `assets/cards/mini/*.c4`
- `assets/cards/full/*.c4`
- `assets/faces/placeholder_mini.c4`
- `assets/faces/placeholder_full.c4`
- `assets/fonts/*.kfa`

The GitHub Actions artifact contains the correct folder structure once `card_assets_psp.zip` has been updated to the v0.5 asset pack.

## Controls

### Menu
- D-Pad Up/Down: move
- X: select
- START: exit

### Pack
- Left/Right: select card
- X: reveal selected card; X again opens full card
- Triangle: reveal all
- Circle: back

### Database
- Left/Right: previous/next
- Up/Down: jump 50
- Triangle: random
- Circle: back

## FIFA 15 data

The build downloads the historical FIFA15.csv and the FIFA 15 special-card catalogue, then compiles the resulting database into the EBOOT.
