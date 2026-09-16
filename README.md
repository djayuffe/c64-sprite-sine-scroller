# DeepSeek v7g graphics boost

PAL C64 demo with multicolor sprites, sine-wave motion, animated pointers,
raster heartbeat, and a scrolling message.

## Build and run

```sh
acme --strict-segments -f cbm -o v7g_gfxboost.prg \
  deepseek_asm_20251009_fixed_v7g_gfxboost.s
x64sc -autostart v7g_gfxboost.prg
```

The audit corrected the character-ROM mapping value, protected sprite indices
from sine-table indexing, kept coordinates within the VIC's 8-bit range, and
fixed scroller wrap detection.
