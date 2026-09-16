# C64 - Sprite Sine Scroller

![C64 effect preview](docs/preview.png)

Visual preview asset for this effect; run the VICE command below for an emulator capture.

PAL C64 demo with multicolor sprites, sine-wave motion, animated pointers,
raster heartbeat, and a scrolling message.

## Build

Requires ACME 0.97 or newer:

```sh
make
```

Output: `build/c64_sprite_sine_scroller.prg`. Run with:

```sh
x64sc -autostart build/c64_sprite_sine_scroller.prg
```

## Repository layout

- `c64_sprite_sine_scroller.s` — corrected source.
- `Makefile`, `AUDIT.md`, and `SHA256SUMS.txt` — build, audit, and integrity data.

## Audit summary

The audit corrected character-ROM mapping, protected sprite indices from
sine-table indexing, constrained VIC coordinates, and fixed scroller wrapping.
## Documentation and license

Function-level documentation is in docs/FUNCTIONS.md. The project is released
under GPL-3.0; see LICENSE.
