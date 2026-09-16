; deepseek_c64_v7g.s
; Stable start + DEBUG heartbeat (ACME !if syntax) + richer sprite motion/colors
;
; Build:
;   acme -f cbm -o deepseek_c64_v7g.prg deepseek_c64_v7g.s
; Run (VICE):
;   x64sc -autostart deepseek_c64_v7g.prg
;
; Toggle a visible raster heartbeat in border each IRQ:
DEBUG = 1        ; 0=no heartbeat, 1=heartbeat

* = $0801
!word $080b
!word 10
!byte $9e
!text "4608"
!byte 0
!word 0

; ---------------- Hardware ----------------
BORDERCOL   = $d020
BGCOL       = $d021
RASTER      = $d012
CTRL1       = $d011
CTRL2       = $d016
MEMPTR      = $d018
VICIRQEN    = $d01a
VICIRQFLAG  = $d019
SPRITE_ENA  = $d015
SPRITE_MCOL = $d01c
SPRITE_XMSB = $d010
SPRITE_XEXP = $d01d
SPRITE_YEXP = $d017
SPRITE_COL0 = $d027
MCOL0       = $d025
MCOL1       = $d026
CIA1_ICR    = $dc0d
CIA2_PRA    = $dd00
CIA2_ICR    = $dd0d

SCREEN      = $0400
COLOR       = $d800
CHARSET     = $2000
SPRITE_DATA = $2800          ; -> pointers $A0/$A1
SPRITE_PTRS = SCREEN + 1016  ; $07F8

; ---------------- ZP ----------------
ZP_SrcLo = $fb
ZP_SrcHi = $fc
ZP_DstLo = $fd
ZP_DstHi = $fe
ZP_TmpA  = $ff               ; temp

; ---------------- State ----------------
FrameCount   = $033a
ScrollIdx    = $033b
SmoothScroll = $033c
TmpLen       = $033d
SpriteIndex  = $033e

; ---------------- Tables ----------------
* = $0900
RowScrLo:  !for i,0,24 { !byte <(SCREEN + i*40) }
RowScrHi:  !for i,0,24 { !byte >(SCREEN + i*40) }
RowColLo:  !for i,0,24 { !byte <(COLOR  + i*40) }
RowColHi:  !for i,0,24 { !byte >(COLOR  + i*40) }

; 64-step sine
Sine64:
!byte 128,140,152,164,175,185,194,201
!byte 207,211,213,214,212,209,204,198
!byte 190,181,171,161,150,139,128,117
!byte 106,95,85,75,66,58,51,45
!byte 41,39,38,40,43,47,53,60
!byte 68,77,87,98,109,120,131,142
!byte 152,162,171,179,186,191,195,197
!byte 198,196,193,189,183,176,168,159

SpritePhase8: !byte 0,8,16,24,32,40,48,56

Rainbow16: !byte 2,6,3,1,3,6,2,0,2,6,3,1,3,6,2,0
Fire16:    !byte 8,8,7,7,1,1,1,7,7,8,8,2,2,8,8,7
Ice16:     !byte 1,1,11,11,12,12,15,15,12,12,11,11,1,1,0,0
Pulse16:   !byte 0,6,2,10,8,7,13,5,3,6,14,4,12,11,15,1

ScrollText:
!scr " *** horizonwarp ultra - max eye candy *** "
!scr "  multicolor sprites + sine x/y + animated pointers  *** "
!byte 0

; ---------------- Code ----------------
* = $1200
Start:
    sei
    ; disable CIAs
    lda CIA1_ICR : lda CIA2_ICR
    lda #$7f
    sta CIA1_ICR : sta CIA2_ICR
    lda CIA1_ICR : lda CIA2_ICR

    ; colors
    lda #$00
    sta BORDERCOL
    sta BGCOL

    ; VIC bank 0, screen=$0400, charset=$2000
    lda CIA2_PRA
    and #%11111100
    ora #%00000011
    sta CIA2_PRA
    lda #$18
    sta MEMPTR

    ; standard video
    lda #$1b
    sta CTRL1
    lda #$08
    sta CTRL2

    jsr ClearScreen
    jsr ClearColor
    jsr CopyROMCharset
    jsr InitState
    jsr InitSprites
    jsr CreateSpriteFrames
    jsr DrawCenterText

    ; raster IRQ @ line 48
    lda VICIRQFLAG
    sta VICIRQFLAG
    lda CTRL1
    and #$7f
    sta CTRL1
    lda #48
    sta RASTER
    lda #$01
    sta VICIRQEN

    lda #<MainIRQ : sta $0314
    lda #>MainIRQ : sta $0315

    cli
Forever: jmp Forever

; ---------------- IRQ ----------------
MainIRQ:
    lda VICIRQFLAG
    and #$01
    beq IRQChain

    pha
    txa : pha
    tya : pha

    ; ack & rearm
    lda VICIRQFLAG
    sta VICIRQFLAG
    lda CTRL1
    and #$7f
    sta CTRL1
    lda #48
    sta RASTER

    inc FrameCount

!if DEBUG = 1 {
    ; heartbeat: flicker border quickly to prove IRQ cadence
    lda BORDERCOL
    clc
    adc #1
    and #$0f
    sta BORDERCOL
}

    jsr UpdateScroll
    jsr UpdateSprites
    jsr UpdateBorder

    pla : tay
    pla : tax
    pla
IRQChain:
    jmp $ea31

; ---------------- Scroller ----------------
UpdateScroll:
    lda SmoothScroll
    beq @doShift
    dec SmoothScroll
    lda SmoothScroll
    ora #$08
    sta CTRL2
    rts
@doShift:
    lda #$07
    sta SmoothScroll
    lda #$0f
    sta CTRL2

    ; shift row 21
    ldx #0
@shift:
    lda SCREEN+21*40+1,x
    sta SCREEN+21*40+0,x
    inx
    cpx #39
    bne @shift

    ; next char at end
    ldx ScrollIdx
    lda ScrollText,x
    bne @ok
    ldx #0
    lda ScrollText,x
@ok:
    sta SCREEN+21*40+39

    ; color
    lda FrameCount
    lsr : lsr
    and #$0f
    tay
    lda Pulse16,y
    sta COLOR+21*40+39

    inc ScrollIdx
    ldx ScrollIdx
    lda ScrollText,x
    bne @noloop
    lda #0
    sta ScrollIdx
@noloop:
    rts

; ---------------- Sprites (multicolor, animated) ----------------
UpdateSprites:
    ; enable all
    lda #$ff
    sta SPRITE_ENA
    ; multicolor on
    lda #$ff
    sta SPRITE_MCOL
    ; MC colors
    lda #$0b
    sta MCOL0
    lda #$08
    sta MCOL1
    ; expansions pattern (breathing)
    lda FrameCount
    and #%00000100
    beq @noexp
    lda #%01010101
    bne @setexp
@noexp:
    lda #$00
@setexp:
    sta SPRITE_XEXP
    lda #$00
    sta SPRITE_YEXP

    ldx #0                      ; sprite index 0..7
@loop:
    stx SpriteIndex

    ; ---- X position (kept inside the 8-bit VIC range) ----
    lda FrameCount
    clc
    adc SpritePhase8,x
    and #$3f
    tax
    lda Sine64,x
    clc
    adc #24
    ldy SpriteIndex
    tya
    asl
    tay
    sta $d000,y         ; S# X

    ; ---- Y position (slower, also kept inside 8 bits) ----
    ldx SpriteIndex
    lda FrameCount
    lsr
    clc
    adc SpritePhase8,x
    and #$3f
    tax
    lda Sine64,x
    clc
    adc #40
    ldy SpriteIndex
    tya
    asl
    tay
    sta $d001,y         ; S# Y

    ; ---- per-sprite color (Fire palette) ----
    lda FrameCount
    lsr : lsr
    and #$0f
    tay
    lda Fire16,y
    ldx SpriteIndex
    sta SPRITE_COL0,x

    ; ---- animated pointer A0/A1 ----
    lda FrameCount
    clc
    adc SpritePhase8,x
    and #$08
    beq @f0
    lda #$a1
    bne @poke
@f0:
    lda #$a0
@poke:
    sta SPRITE_PTRS,x

    ldx SpriteIndex
    inx
    cpx #8
    bne @loop
    rts

; ---------------- Border ----------------
UpdateBorder:
    lda FrameCount
    lsr
    and #$0f
    tay
    lda Ice16,y
    sta BORDERCOL
    lda #0
    sta BGCOL
    rts

; ---------------- Charset ROM copy ----------------
CopyROMCharset:
    lda $01
    pha
    ; Show Char ROM at $D000-$D7FF: CHAREN=0, keep LORAM/HIRAM=1 -> $31
    lda #$31
    sta $01

    lda #$00
    sta ZP_SrcLo
    lda #$d0
    sta ZP_SrcHi
    lda #<CHARSET
    sta ZP_DstLo
    lda #>CHARSET
    sta ZP_DstHi

    ldx #8
@page:
    ldy #0
@cpy:
    lda (ZP_SrcLo),y
    sta (ZP_DstLo),y
    iny
    bne @cpy
    inc ZP_SrcHi
    inc ZP_DstHi
    dex
    bne @page

    pla
    sta $01
    rts

; ---------------- Center Text ----------------
CenterMsg:
!scr "horizonwarp ultra"
!byte 0

DrawCenterText:
    ldx #0
@l:
    lda CenterMsg,x
    beq @got
    inx
    bne @l
@got:
    stx TmpLen
    txa
    eor #$ff
    clc
    adc #41
    lsr
    tax
    lda RowScrLo+12 : sta ZP_SrcLo
    lda RowScrHi+12 : sta ZP_SrcHi
    txa
    beq @write
    clc
    adc ZP_SrcLo
    sta ZP_SrcLo
    bcc @write
    inc ZP_SrcHi
@write:
    ldy #0
@w:
    lda CenterMsg,y
    beq @color
    sta (ZP_SrcLo),y
    iny
    bne @w
@color:
    lda RowColLo+12 : sta ZP_SrcLo
    lda RowColHi+12 : sta ZP_SrcHi
    txa
    beq @cwrite
    clc
    adc ZP_SrcLo
    sta ZP_SrcLo
    bcc @cwrite
    inc ZP_SrcHi
@cwrite:
    ldy #0
    lda #1
@cw:
    cpy TmpLen
    beq @done
    sta (ZP_SrcLo),y
    iny
    bne @cw
@done:
    rts

; ---------------- Sprite frames ----------------
CreateSpriteFrames:
    ; wipe 512 bytes at $2800..$29ff
    lda #<SPRITE_DATA
    sta ZP_DstLo
    lda #>SPRITE_DATA
    sta ZP_DstHi
    ldy #0
    lda #0
@w0:
    sta (ZP_DstLo),y
    iny
    bne @w0
    inc ZP_DstHi
    ldy #0
@w1:
    sta (ZP_DstLo),y
    iny
    bne @w1

    ; frame 0 at SPRITE_DATA
    lda #<SPRITE_DATA
    sta ZP_DstLo
    lda #>SPRITE_DATA
    sta ZP_DstHi

    ldx #0
@rows:
    lda OrbRowsLo,x : sta (ZP_DstLo),y : iny
    lda OrbRowsMi,x : sta (ZP_DstLo),y : iny
    lda OrbRowsHi,x : sta (ZP_DstLo),y : iny
    inx
    cpx #21
    bne @rows

    ; frame 1 = inverse at SPRITE_DATA+$40
    lda #<SPRITE_DATA
    sta ZP_SrcLo
    lda #>SPRITE_DATA
    sta ZP_SrcHi
    lda #<SPRITE_DATA+$40
    sta ZP_DstLo
    lda #>SPRITE_DATA+$40
    sta ZP_DstHi
    ldy #0
@inv:
    lda (ZP_SrcLo),y
    eor #$ff
    sta (ZP_DstLo),y
    iny
    cpy #64
    bne @inv
    rts

; 21 rows × 3 bytes
OrbRowsLo:
!byte %00000000,%00000000,%00000000
!byte %00000000,%00000000,%00000000
!byte %00000000,%00000000,%00000000
!byte %00000000,%00011000,%00000000
!byte %00000000,%00111100,%00000000
!byte %00000000,%01111110,%00000000
!byte %00000000,%11111111,%00000000
!byte %00000001,%11111111,%10000000
!byte %00000011,%11111111,%11000000
!byte %00000111,%11111111,%11100000
!byte %00001111,%11111111,%11110000
!byte %00000111,%11111111,%11100000
!byte %00000011,%11111111,%11000000
!byte %00000001,%11111111,%10000000
!byte %00000000,%11111111,%00000000
!byte %00000000,%01111110,%00000000
!byte %00000000,%00111100,%00000000
!byte %00000000,%00011000,%00000000
!byte %00000000,%00000000,%00000000
!byte %00000000,%00000000,%00000000
!byte %00000000,%00000000,%00000000

OrbRowsMi:
!byte %00000000,%00000000,%00000000
!byte %00000000,%00000000,%00000000
!byte %00000000,%00000000,%00000000
!byte %00000000,%00011000,%00000000
!byte %00000000,%00111100,%00000000
!byte %00000000,%01111110,%00000000
!byte %00000000,%11111111,%00000000
!byte %00000001,%11111111,%10000000
!byte %00000011,%11111111,%11000000
!byte %00000111,%11111111,%11100000
!byte %00001111,%11111111,%11110000
!byte %00000111,%11111111,%11100000
!byte %00000011,%11111111,%11000000
!byte %00000001,%11111111,%10000000
!byte %00000000,%11111111,%00000000
!byte %00000000,%01111110,%00000000
!byte %00000000,%00111100,%00000000
!byte %00000000,%00011000,%00000000
!byte %00000000,%00000000,%00000000
!byte %00000000,%00000000,%00000000
!byte %00000000,%00000000,%00000000

OrbRowsHi:
!byte %00000000,%00000000,%00000000
!byte %00000000,%00000000,%00000000
!byte %00000000,%00000000,%00000000
!byte %00000000,%00011000,%00000000
!byte %00000000,%00111100,%00000000
!byte %00000000,%01111110,%00000000
!byte %00000000,%11111111,%00000000
!byte %00000001,%11111111,%10000000
!byte %00000011,%11111111,%11000000
!byte %00000111,%11111111,%11100000
!byte %00001111,%11111111,%11110000
!byte %00000111,%11111111,%11100000
!byte %00000011,%11111111,%11000000
!byte %00000001,%11111111,%10000000
!byte %00000000,%11111111,%00000000
!byte %00000000,%01111110,%00000000
!byte %00000000,%00111100,%00000000
!byte %00000000,%00011000,%00000000
!byte %00000000,%00000000,%00000000
!byte %00000000,%00000000,%00000000
!byte %00000000,%00000000,%00000000

; ---------------- Init ----------------
InitState:
    lda #0
    sta FrameCount
    sta ScrollIdx
    lda #7
    sta SmoothScroll
    lda #1
    sta SpriteIndex

    lda #$ff
    sta $d40e
    sta $d40f
    lda #$80
    sta $d412
    rts

InitSprites:
    lda #$a0
    ldx #0
@ip:
    sta SPRITE_PTRS,x
    inx
    cpx #8
    bne @ip
    lda #0
    sta SPRITE_XMSB
    sta SPRITE_XEXP
    sta SPRITE_YEXP
    rts

; ---------------- Clear helpers ----------------
ClearScreen:
    lda #$20
    ldx #0
@cs1:
    sta $0400,x
    sta $0500,x
    sta $0600,x
    inx
    bne @cs1
    ldx #231
@cs2:
    sta $0700,x
    dex
    bpl @cs2
    rts

ClearColor:
    lda #$06
    ldx #0
@cc1:
    sta $d800,x
    sta $d900,x
    sta $da00,x
    inx
    bne @cc1
    ldx #231
@cc2:
    sta $db00,x
    dex
    bpl @cc2
    rts
