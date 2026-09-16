# DeepSeek C64 v7g

PAL C64 demo with multicolor sprites, sine-wave motion, animated pointers,
raster heartbeat, and a scrolling message.

## Build

Requires ACME 0.97 or newer:

```sh
make
```

Output: `build/deepseek_c64_v7g.prg`. Run with:

```sh
x64sc -autostart build/deepseek_c64_v7g.prg
```

## Repository layout

- `deepseek_c64_v7g.s` — corrected source.
- `Makefile`, `AUDIT.md`, and `SHA256SUMS.txt` — build, audit, and integrity data.

## Audit summary

The audit corrected character-ROM mapping, protected sprite indices from
sine-table indexing, constrained VIC coordinates, and fixed scroller wrapping.
