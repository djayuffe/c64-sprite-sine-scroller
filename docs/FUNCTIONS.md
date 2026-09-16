# Function reference

This build focuses on multicolor sprites, sine motion, and a scrolling message.

| Function | Responsibility |
|---|---|
| Start / InitState | Establishes VIC, CIA, sprite, and color state. |
| MainIRQ / IRQChain | Services the chained frame interrupt. |
| UpdateSprites | Uses a separate sprite index and VIC register offset. |
| UpdateScroll | Advances the message and wraps at its terminator. |
| UpdateBorder | Produces the animated border heartbeat. |
| CopyROMCharset | Copies the character ROM into writable memory. |
| CreateSpriteFrames | Builds the animated sprite data. |

Coordinates are constrained to the VIC 8-bit range.
