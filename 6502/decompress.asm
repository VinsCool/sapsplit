;*********************************************************************************
;* DUMB ZX2 Decompressor or whatever this will become later...                   *
;*                                                                               *
;* To build: 'mads decompress.asm -l:ASSEMBLED/build.lst -o:ASSEMBLED/build.xex' *
;*********************************************************************************

;* ----------------------------------------------------------------------------

;* Few definitions needed for building executable Atari binaries

	icl "atari.def"

ZPG	= $80
ZX2BUF	= $700
DZX2	= ZX2BUF + ($100 * 9)

.MACRO GOTOCHUNK CHUNK
;	.byte :CHUNK + $80
	.byte $FF, :CHUNK
.ENDM


;* ----------------------------------------------------------------------------

;* Zeropage variables for quick access, also used for Indirect Addressing Mode

	org ZPG

.LOCAL ZPZX2
TMP0		.ds 1
TMP1		.ds 1
BufferFrom	.ds 2*9
BufferTo	.ds 2*9
BufferOffset	.ds 2*9
ByteLookup	.ds 2*9
ByteStatus	.ds 2*9
ByteChunk	.ds 2*9
LastOffset = ByteLookup
ByteCount = ByteLookup+1
StatusCode = ByteStatus
BitByte = ByteStatus+1
ChunkIndex = ByteChunk
Unused = ByteChunk+1
.ENDL

;* ----------------------------------------------------------------------------

;* ZX2-based SAP-R playback music driver, with very rudimentary functionalities

	org DZX2
	icl "dzx2.asm"

;* ----------------------------------------------------------------------------

;* Set POKEY registers at least once per VBI using the last buffered values

SetPokey
	lda POKSKC0 
	sta $D20F 
	ldy POKCTL0
	lda POKF0
	ldx POKC0
	sta $D200
	stx $D201
	lda POKF1
	ldx POKC1
	sta $D202
	stx $D203
	lda POKF2
	ldx POKC2
	sta $D204
	stx $D205
	lda POKF3
	ldx POKC3
	sta $D206
	stx $D207
	sty $D208
	rts

;* Left and Right POKEY buffer

SDWPOK0
SDWPOK1 = SDWPOK0+1
POKF0	.byte $00, $00
POKC0	.byte $00, $00
POKF1	.byte $00, $00
POKC1	.byte $00, $00
POKF2	.byte $00, $00
POKC2	.byte $00, $00
POKF3	.byte $00, $00
POKC3	.byte $00, $00
POKCTL0	.byte $00, $00
POKSKC0 .byte $03, $03

;* ----------------------------------------------------------------------------

;* Main program will start executing from here, and will loop infinitely

Start:
	ldx #.len ZPZX2-1
	ldy #0
Clear:
	sty ZPZX2,x
	dex
	bpl Clear
	ldx #8*2
Initialise:
	txa
	lsr @
	adc #>ZX2BUF
	sta ZPZX2.BufferTo+1,x
	sty ZPZX2.BufferTo,x
	dex
	dex
	bpl Initialise
	
/*
Loop:
;	lda #0
;	sta COLPF0
;	sta COLPF1
;	sta COLPF2
;	sta COLPF3
;	sta COLBK
Loop0:
	lda VCOUNT
	bne Loop0
;	sta WSYNC
;	lda #$69
	lda POKF0
	sta COLPF2
;	lda POKCTL0
	sta COLBK
	jsr SetPokey
	jsr DecompressZX2
	lda #0
	sta COLPF2
	sta COLBK
;	sta WSYNC
Loop1:
	lda VCOUNT
	cmp #16*1	;+1
	bcc Loop1
;	sta WSYNC
;	lda #$69-1
	lda POKC0
	sta COLPF2
;	lda POKCTL0
	sta COLBK
	jsr SetPokey
	jsr DecompressZX2
	lda #0
	sta COLPF2
	sta COLBK
;	sta WSYNC
Loop2:
	lda VCOUNT
	cmp #16*2	;+1
	bcc Loop2
;	sta WSYNC
;	lda #$69-2
	lda POKF1
	sta COLPF2
;	lda POKCTL0
	sta COLBK
	jsr SetPokey
	jsr DecompressZX2
	lda #0
	sta COLPF2
	sta COLBK
;	sta WSYNC
Loop3:
	lda VCOUNT
	cmp #16*3	;+1
	bcc Loop3
;	sta WSYNC
;	lda #$69-3
	lda POKC1
	sta COLPF2
;	lda POKCTL0
	sta COLBK
	jsr SetPokey
	jsr DecompressZX2
	lda #0
	sta COLPF2
	sta COLBK
;	sta WSYNC
Loop4:
	lda VCOUNT
	cmp #16*4	;+1
	bcc Loop4
;	sta WSYNC
;	lda #$69-4
	lda POKF2
	sta COLPF2
;	lda POKCTL0
	sta COLBK
	jsr SetPokey
	jsr DecompressZX2
	lda #0
	sta COLPF2
	sta COLBK
;	sta WSYNC
Loop5:
	lda VCOUNT
	cmp #16*5	;+1
	bcc Loop5
;	sta WSYNC
;	lda #$69-5
	lda POKC2
	sta COLPF2
;	lda POKCTL0
	sta COLBK
	jsr SetPokey
	jsr DecompressZX2
	lda #0
	sta COLPF2
	sta COLBK
;	sta WSYNC
Loop6:
	lda VCOUNT
	cmp #16*6	;+1
	bcc Loop6
;	sta WSYNC
;	lda #$69-6
	lda POKF3
	sta COLPF2
;	lda POKCTL0
	sta COLBK
	jsr SetPokey
	jsr DecompressZX2
	lda #0
	sta COLPF2
	sta COLBK
;	sta WSYNC
Loop7:
	lda VCOUNT
	cmp #16*7	;+1
	bcc Loop7
;	sta WSYNC
;	lda #$69-7
	lda POKC3
	sta COLPF2
;	lda POKCTL0
	sta COLBK
	jsr SetPokey
	jsr DecompressZX2
	lda #0
	sta COLPF2
	sta COLBK
;	sta WSYNC
	jmp Loop
	run Start
*/

Loop:
	lda VCOUNT
	bne Loop
	lda #$69
	sta COLPF2
	sta COLBK
	jsr SetPokey
	jsr DecompressZX2
	lda #0
	sta COLPF2
	sta COLBK
	beq Loop
	run Start

;* ----------------------------------------------------------------------------

;* Compressed ZX2 data chunks used for streaming POKEY register values at regular intervals
;* Chunks will make use of a few ByteCodes for Detecting Loops and Indexing data cleanly
;* If the ChunkSection table holds a value of $80 and higher, be used as a Loop Point within itself
;* Otherwise, it will be an offset to the ChunkIndex table, where up to 127 values may be used
;* This effectively allows using Chunks of different sizes, assuming that all channels are synced

/*
ChunkIndexLSB:
	.byte <Chunk_0_00, <Chunk_0_04, <Chunk_0_08, <Chunk_0_18, <Chunk_1_00, <Chunk_1_04, <Chunk_1_08, <Chunk_1_18, <Chunk_2_00, <Chunk_2_04, <Chunk_2_08, <Chunk_2_09, <Chunk_2_18, <Chunk_2_19, <Chunk_3_04, <Chunk_3_08, <Chunk_3_18, <Chunk_4_00, <Chunk_4_18, <Chunk_6_00, <Chunk_6_01, <Chunk_6_18, <Chunk_7_10, <Chunk_8_00, <Chunk_8_04, <Chunk_8_08, <Chunk_8_18
ChunkIndexMSB:
	.byte >Chunk_0_00, >Chunk_0_04, >Chunk_0_08, >Chunk_0_18, >Chunk_1_00, >Chunk_1_04, >Chunk_1_08, >Chunk_1_18, >Chunk_2_00, >Chunk_2_04, >Chunk_2_08, >Chunk_2_09, >Chunk_2_18, >Chunk_2_19, >Chunk_3_04, >Chunk_3_08, >Chunk_3_18, >Chunk_4_00, >Chunk_4_18, >Chunk_6_00, >Chunk_6_01, >Chunk_6_18, >Chunk_7_10, >Chunk_8_00, >Chunk_8_04, >Chunk_8_08, >Chunk_8_18
ChunkSection:
	.word Section_0, Section_1, Section_2, Section_3, Section_4, Section_5, Section_6, Section_7, Section_8
Section_0:
	.byte $00, $00, $00, $00, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $02, $02, $02, $02, $03, $03, $03, $03, $03, $03, $03, $03
	GOTOCHUNK 8
Section_1:
	.byte $04, $04, $04, $04, $05, $05, $05, $05, $06, $06, $06, $06, $06, $06, $06, $06, $05, $05, $05, $05, $06, $06, $06, $06, $07, $07, $07, $07, $07, $07, $07, $07
	GOTOCHUNK 4
Section_2:
	.byte $08, $08, $08, $08, $09, $09, $09, $09, $0A, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $09, $09, $09, $09, $0B, $0B, $0B, $0B, $0C, $0D, $0D, $0D, $0D, $0D, $0D, $0D
	GOTOCHUNK 12
Section_3:
	.byte $08, $08, $08, $08, $0E, $0E, $0E, $0E, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0E, $0E, $0E, $0E, $0F, $0F, $0F, $0F, $10, $10, $10, $10, $10, $10, $10, $10
	GOTOCHUNK 4
Section_4:
	.byte $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $11, $12, $12, $12, $12, $12, $12, $12, $12
	GOTOCHUNK 8
Section_5:
	.byte $08	;, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08
	GOTOCHUNK 0
Section_6:
	.byte $13, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $14, $15, $15, $15, $15, $15, $15, $15, $15
	GOTOCHUNK 12
Section_7:
	.byte $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16
	GOTOCHUNK 8
Section_8:
	.byte $17, $17, $17, $17, $18, $18, $18, $18, $19, $19, $19, $19, $19, $19, $19, $19, $18, $18, $18, $18, $19, $19, $19, $19, $1A, $1A, $1A, $1A, $1A, $1A, $1A, $1A
	GOTOCHUNK 4
Chunk_0_00:
	ins "/chunks/Sketch 44.0_00"
Chunk_0_04:
	ins "/chunks/Sketch 44.0_04"
Chunk_0_08:
	ins "/chunks/Sketch 44.0_08"
Chunk_0_18:
	ins "/chunks/Sketch 44.0_18"
Chunk_1_00:
	ins "/chunks/Sketch 44.1_00"
Chunk_1_04:
	ins "/chunks/Sketch 44.1_04"
Chunk_1_08:
	ins "/chunks/Sketch 44.1_08"
Chunk_1_18:
	ins "/chunks/Sketch 44.1_18"
Chunk_2_00:
	ins "/chunks/Sketch 44.2_00"
Chunk_2_04:
	ins "/chunks/Sketch 44.2_04"
Chunk_2_08:
	ins "/chunks/Sketch 44.2_08"
Chunk_2_09:
	ins "/chunks/Sketch 44.2_09"
Chunk_2_18:
	ins "/chunks/Sketch 44.2_18"
Chunk_2_19:
	ins "/chunks/Sketch 44.2_19"
Chunk_3_04:
	ins "/chunks/Sketch 44.3_04"
Chunk_3_08:
	ins "/chunks/Sketch 44.3_08"
Chunk_3_18:
	ins "/chunks/Sketch 44.3_18"
Chunk_4_00:
	ins "/chunks/Sketch 44.4_00"
Chunk_4_18:
	ins "/chunks/Sketch 44.4_18"
Chunk_6_00:
	ins "/chunks/Sketch 44.6_00"
Chunk_6_01:
	ins "/chunks/Sketch 44.6_01"
Chunk_6_18:
	ins "/chunks/Sketch 44.6_18"
Chunk_7_10:
	ins "/chunks/Sketch 44.7_10"
Chunk_8_00:
	ins "/chunks/Sketch 44.8_00"
Chunk_8_04:
	ins "/chunks/Sketch 44.8_04"
Chunk_8_08:
	ins "/chunks/Sketch 44.8_08"
Chunk_8_18:
	ins "/chunks/Sketch 44.8_18"
*/

/*
ChunkIndexLSB:
	.byte <Chunk_0_00, <Chunk_0_01, <Chunk_0_02, <Chunk_0_03, <Chunk_0_04, <Chunk_0_05, <Chunk_0_06, <Chunk_1_00, <Chunk_1_01, <Chunk_1_02, <Chunk_1_03, <Chunk_1_04, <Chunk_1_05, <Chunk_1_06, <Chunk_2_00, <Chunk_2_01, <Chunk_2_02, <Chunk_2_03, <Chunk_2_04, <Chunk_2_05, <Chunk_2_06, <Chunk_3_00, <Chunk_3_01, <Chunk_3_02, <Chunk_3_03, <Chunk_3_05, <Chunk_4_00, <Chunk_4_01, <Chunk_4_05, <Chunk_4_06, <Chunk_5_00, <Chunk_5_01, <Chunk_5_05, <Chunk_5_06, <Chunk_6_00, <Chunk_6_01, <Chunk_6_02, <Chunk_6_03, <Chunk_6_04, <Chunk_6_05, <Chunk_7_00, <Chunk_7_01, <Chunk_7_02, <Chunk_7_03, <Chunk_7_04, <Chunk_7_05, <Chunk_8_00, <Chunk_8_01, <Chunk_8_02, <Chunk_8_03, <Chunk_8_04, <Chunk_8_05, <Chunk_8_06
ChunkIndexMSB:
	.byte >Chunk_0_00, >Chunk_0_01, >Chunk_0_02, >Chunk_0_03, >Chunk_0_04, >Chunk_0_05, >Chunk_0_06, >Chunk_1_00, >Chunk_1_01, >Chunk_1_02, >Chunk_1_03, >Chunk_1_04, >Chunk_1_05, >Chunk_1_06, >Chunk_2_00, >Chunk_2_01, >Chunk_2_02, >Chunk_2_03, >Chunk_2_04, >Chunk_2_05, >Chunk_2_06, >Chunk_3_00, >Chunk_3_01, >Chunk_3_02, >Chunk_3_03, >Chunk_3_05, >Chunk_4_00, >Chunk_4_01, >Chunk_4_05, >Chunk_4_06, >Chunk_5_00, >Chunk_5_01, >Chunk_5_05, >Chunk_5_06, >Chunk_6_00, >Chunk_6_01, >Chunk_6_02, >Chunk_6_03, >Chunk_6_04, >Chunk_6_05, >Chunk_7_00, >Chunk_7_01, >Chunk_7_02, >Chunk_7_03, >Chunk_7_04, >Chunk_7_05, >Chunk_8_00, >Chunk_8_01, >Chunk_8_02, >Chunk_8_03, >Chunk_8_04, >Chunk_8_05, >Chunk_8_06
ChunkSection:
	.word Section_0, Section_1, Section_2, Section_3, Section_4, Section_5, Section_6, Section_7, Section_8
Section_0:
	.byte $00, $01, $02, $03, $04, $05, $06
	GOTOCHUNK 1
Section_1:
	.byte $07, $08, $09, $0A, $0B, $0C, $0D
	GOTOCHUNK 1
Section_2:
	.byte $0E, $0F, $10, $11, $12, $13, $14
	GOTOCHUNK 1
Section_3:
	.byte $15, $16, $17, $18, $18, $19, $19
	GOTOCHUNK 1
Section_4:
	.byte $1A, $1B, $1B, $1B, $1B, $1C, $1D
	GOTOCHUNK 1
Section_5:
	.byte $1E, $1F, $1F, $1F, $1F, $20, $21
	GOTOCHUNK 1
Section_6:
	.byte $22, $23, $24, $25, $26, $27, $27
	GOTOCHUNK 1
Section_7:
	.byte $28, $29, $2A, $2B, $2C, $2D, $2D
	GOTOCHUNK 1
Section_8:
	.byte $2E, $2F, $30, $31, $32, $33, $34
	GOTOCHUNK 1
Chunk_0_00:
	ins "/chunks/Flourishing Falls.0_00"
Chunk_0_01:
	ins "/chunks/Flourishing Falls.0_01"
Chunk_0_02:
	ins "/chunks/Flourishing Falls.0_02"
Chunk_0_03:
	ins "/chunks/Flourishing Falls.0_03"
Chunk_0_04:
	ins "/chunks/Flourishing Falls.0_04"
Chunk_0_05:
	ins "/chunks/Flourishing Falls.0_05"
Chunk_0_06:
	ins "/chunks/Flourishing Falls.0_06"
Chunk_1_00:
	ins "/chunks/Flourishing Falls.1_00"
Chunk_1_01:
	ins "/chunks/Flourishing Falls.1_01"
Chunk_1_02:
	ins "/chunks/Flourishing Falls.1_02"
Chunk_1_03:
	ins "/chunks/Flourishing Falls.1_03"
Chunk_1_04:
	ins "/chunks/Flourishing Falls.1_04"
Chunk_1_05:
	ins "/chunks/Flourishing Falls.1_05"
Chunk_1_06:
	ins "/chunks/Flourishing Falls.1_06"
Chunk_2_00:
	ins "/chunks/Flourishing Falls.2_00"
Chunk_2_01:
	ins "/chunks/Flourishing Falls.2_01"
Chunk_2_02:
	ins "/chunks/Flourishing Falls.2_02"
Chunk_2_03:
	ins "/chunks/Flourishing Falls.2_03"
Chunk_2_04:
	ins "/chunks/Flourishing Falls.2_04"
Chunk_2_05:
	ins "/chunks/Flourishing Falls.2_05"
Chunk_2_06:
	ins "/chunks/Flourishing Falls.2_06"
Chunk_3_00:
	ins "/chunks/Flourishing Falls.3_00"
Chunk_3_01:
	ins "/chunks/Flourishing Falls.3_01"
Chunk_3_02:
	ins "/chunks/Flourishing Falls.3_02"
Chunk_3_03:
	ins "/chunks/Flourishing Falls.3_03"
Chunk_3_05:
	ins "/chunks/Flourishing Falls.3_05"
Chunk_4_00:
	ins "/chunks/Flourishing Falls.4_00"
Chunk_4_01:
	ins "/chunks/Flourishing Falls.4_01"
Chunk_4_05:
	ins "/chunks/Flourishing Falls.4_05"
Chunk_4_06:
	ins "/chunks/Flourishing Falls.4_06"
Chunk_5_00:
	ins "/chunks/Flourishing Falls.5_00"
Chunk_5_01:
	ins "/chunks/Flourishing Falls.5_01"
Chunk_5_05:
	ins "/chunks/Flourishing Falls.5_05"
Chunk_5_06:
	ins "/chunks/Flourishing Falls.5_06"
Chunk_6_00:
	ins "/chunks/Flourishing Falls.6_00"
Chunk_6_01:
	ins "/chunks/Flourishing Falls.6_01"
Chunk_6_02:
	ins "/chunks/Flourishing Falls.6_02"
Chunk_6_03:
	ins "/chunks/Flourishing Falls.6_03"
Chunk_6_04:
	ins "/chunks/Flourishing Falls.6_04"
Chunk_6_05:
	ins "/chunks/Flourishing Falls.6_05"
Chunk_7_00:
	ins "/chunks/Flourishing Falls.7_00"
Chunk_7_01:
	ins "/chunks/Flourishing Falls.7_01"
Chunk_7_02:
	ins "/chunks/Flourishing Falls.7_02"
Chunk_7_03:
	ins "/chunks/Flourishing Falls.7_03"
Chunk_7_04:
	ins "/chunks/Flourishing Falls.7_04"
Chunk_7_05:
	ins "/chunks/Flourishing Falls.7_05"
Chunk_8_00:
	ins "/chunks/Flourishing Falls.8_00"
Chunk_8_01:
	ins "/chunks/Flourishing Falls.8_01"
Chunk_8_02:
	ins "/chunks/Flourishing Falls.8_02"
Chunk_8_03:
	ins "/chunks/Flourishing Falls.8_03"
Chunk_8_04:
	ins "/chunks/Flourishing Falls.8_04"
Chunk_8_05:
	ins "/chunks/Flourishing Falls.8_05"
Chunk_8_06:
	ins "/chunks/Flourishing Falls.8_06"
*/

/*
ChunkIndexLSB:
	.byte <Chunk_0_00, <Chunk_1_00, <Chunk_2_00, <Chunk_3_00, <Chunk_4_00, <Chunk_5_00, <Chunk_6_00, <Chunk_7_00, <Chunk_8_00
ChunkIndexMSB:
	.byte >Chunk_0_00, >Chunk_1_00, >Chunk_2_00, >Chunk_3_00, >Chunk_4_00, >Chunk_5_00, >Chunk_6_00, >Chunk_7_00, >Chunk_8_00
ChunkSection:
	.word Section_0, Section_1, Section_2, Section_3, Section_4, Section_5, Section_6, Section_7, Section_8
Section_0:
	.byte $00
	GOTOCHUNK 0
Section_1:
	.byte $01
	GOTOCHUNK 0
Section_2:
	.byte $02
	GOTOCHUNK 0
Section_3:
	.byte $03
	GOTOCHUNK 0
Section_4:
	.byte $04
	GOTOCHUNK 0
Section_5:
	.byte $05
	GOTOCHUNK 0
Section_6:
	.byte $06
	GOTOCHUNK 0
Section_7:
	.byte $07
	GOTOCHUNK 0
Section_8:
	.byte $08
	GOTOCHUNK 0
Chunk_0_00:
	ins "/chunks/stranded on io.0_00"
Chunk_1_00:
	ins "/chunks/stranded on io.1_00"
Chunk_2_00:
	ins "/chunks/stranded on io.2_00"
Chunk_3_00:
	ins "/chunks/stranded on io.3_00"
Chunk_4_00:
	ins "/chunks/stranded on io.4_00"
Chunk_5_00:
	ins "/chunks/stranded on io.5_00"
Chunk_6_00:
	ins "/chunks/stranded on io.6_00"
Chunk_7_00:
	ins "/chunks/stranded on io.7_00"
Chunk_8_00:
	ins "/chunks/stranded on io.8_00"
*/

ChunkIndexLSB:
	.byte <Chunk_0_00, <Chunk_1_00, <Chunk_2_00, <Chunk_3_00, <Chunk_4_00, <Chunk_5_00, <Chunk_6_00, <Chunk_7_00, <Chunk_8_00
	.byte <Chunk_9_00, <Chunk_A_00, <Chunk_B_00, <Chunk_C_00, <Chunk_D_00, <Chunk_E_00, <Chunk_F_00, <Chunk_G_00, <Chunk_H_00
ChunkIndexMSB:
	.byte >Chunk_0_00, >Chunk_1_00, >Chunk_2_00, >Chunk_3_00, >Chunk_4_00, >Chunk_5_00, >Chunk_6_00, >Chunk_7_00, >Chunk_8_00
	.byte >Chunk_9_00, >Chunk_A_00, >Chunk_B_00, >Chunk_C_00, >Chunk_D_00, >Chunk_E_00, >Chunk_F_00, >Chunk_G_00, >Chunk_H_00
ChunkSection:
	.word Section_0, Section_1, Section_2, Section_3, Section_4, Section_5, Section_6, Section_7, Section_8
Section_0:
	.byte $00, $09
	GOTOCHUNK 1
Section_1:
	.byte $01, $0A
	GOTOCHUNK 1
Section_2:
	.byte $02, $0B
	GOTOCHUNK 1
Section_3:
	.byte $03, $0C
	GOTOCHUNK 1
Section_4:
	.byte $04, $0D
	GOTOCHUNK 1
Section_5:
	.byte $05, $0E
	GOTOCHUNK 1
Section_6:
	.byte $06, $0F
	GOTOCHUNK 1
Section_7:
	.byte $07, $10
	GOTOCHUNK 1
Section_8:
	.byte $08, $11
	GOTOCHUNK 1
Chunk_0_00:
	ins "/chunks/io intro.0_00"
Chunk_1_00:
	ins "/chunks/io intro.1_00"
Chunk_2_00:
	ins "/chunks/io intro.2_00"
Chunk_3_00:
	ins "/chunks/io intro.3_00"
Chunk_4_00:
	ins "/chunks/io intro.4_00"
Chunk_5_00:
	ins "/chunks/io intro.5_00"
Chunk_6_00:
	ins "/chunks/io intro.6_00"
Chunk_7_00:
	ins "/chunks/io intro.7_00"
Chunk_8_00:
	ins "/chunks/io intro.8_00"
Chunk_9_00:
	ins "/chunks/io loop.0_00"
Chunk_A_00:
	ins "/chunks/io loop.1_00"
Chunk_B_00:
	ins "/chunks/io loop.2_00"
Chunk_C_00:
	ins "/chunks/io loop.3_00"
Chunk_D_00:
	ins "/chunks/io loop.4_00"
Chunk_E_00:
	ins "/chunks/io loop.5_00"
Chunk_F_00:
	ins "/chunks/io loop.6_00"
Chunk_G_00:
	ins "/chunks/io loop.7_00"
Chunk_H_00:
	ins "/chunks/io loop.8_00"

