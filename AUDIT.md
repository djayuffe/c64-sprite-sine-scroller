# Audit record

The source assembled, but runtime review found three correctness defects. The
character-ROM mapping wrote `$35` to the CPU port even though CHAREN=0 requires
`$31`; the sprite loop reused `X` for sine-table indices and then addressed
colors/pointers with that wrong index; and X/Y coordinates could wrap past 255.
Scroller wrap checked the old index after incrementing it.

Repairs:

- use `$31` for character ROM;
- preserve the sprite index in `SpriteIndex` and use a separate VIC register
  offset;
- constrain coordinates to the 8-bit VIC range;
- reload the incremented scroll index before testing for the terminator.

Validation: ACME `--strict-segments` succeeds. Corrected build SHA-256:
`d6594446dddaf6f439b967aa3720fbdebc71a89a79f5c22c6520663c8ff07866`.
