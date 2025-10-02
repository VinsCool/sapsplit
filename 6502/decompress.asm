;*********************************************************************************
;* DUMB ZX2 Decompressor or whatever this will become later...                   *
;*                                                                               *
;* To build: 'mads decompress.asm -l:ASSEMBLED/build.lst -o:ASSEMBLED/build.xex' *
;*********************************************************************************

;* ----------------------------------------------------------------------------

;* Few definitions needed for building executable Atari binaries

	opt r-
	icl "atari.def"

ZPG			= $80
ZX2BUF			= $C000
DZX2			= $2000		; $0300
ZX2DATA			= $3000		; DRIVEREND

VLINE			= 11
VBLANK_SCANLINE		= (248 / 2)
PAL_SCANLINE		= (312 / 2)
NTSC_SCANLINE		= (262 / 2)

.struct ZX2Chunk
	SongSection	.word
	BufferFrom	.word
	BufferOffset	.byte
	LastOffset	.byte
	BitByte		.byte
	ByteCount	.byte
	StatusCode	.byte
	PokeyByte	.byte
.ends

;* ----------------------------------------------------------------------------

;* Zeropage variables for quick access, also used for Indirect Addressing Mode

	org ZPG
	
.local ZPZX2
TMP0		.ds 1
TMP1		.ds 1

ChannelOffset	.ds 1
BufferTo	.ds 2
PlayerStatus	.ds 1
LastKeyPressed	.ds 1
StackPointer	.ds 1

RasterbarColour	.ds 1
RasterbarToggle	.ds 1

MachineRegion	.ds 1
MachineStereo	.ds 1
AdjustSpeed	.ds 1

SongPointer	.ds 2
SongUpdate	.ds 1
SongIndex	.ds 1
SongCount	.ds 1
SongSpeed	.ds 1
SongRegion	.ds 1
SongStereo	.ds 1

SongTimer	.ds 4

SyncStatus	.ds 1
LastCount	.ds 1
SyncCount	.ds 1
SyncOffset	.ds 1
SyncDelta	.ds 1
SyncDivision	.ds 1
PokeySkctl	.ds 1

Chunk dta ZX2Chunk[9-1]
.endl

TestByte	.ds 1

;* ----------------------------------------------------------------------------

;* Decompression Channel Buffers

	org ZX2BUF
	.ds (256 * 9)

;* ----------------------------------------------------------------------------

;* Main program will start executing from here, and will loop infinitely

	org DZX2
	
DList:
	.byte BLANK8
	.byte LMS|MODE4
	.word ZX2BUF
	:27 .byte MODE4
	.byte DLIJUMP
	.word DList
		
Start:
	sei
	cld
	mva #%11111110 PORTB
	mva #%00000000 NMIEN
	sta IRQEN
	sta DMACTL
;	mwa #DZX2 DLISTL
;	mva >ZX2BUF CHBASE
;	mva #%00100011 DMACTL
;	lda #0
	tax
	
Clear:
	sta.w ZPG,x
	dex
	bne Clear
	tsx:stx ZPZX2.StackPointer
	
Initialise:
	jsr ResetPokey
	jsr WaitForVBlank
	jsr DetectMachineRegion
	;jsr DetectMachineStereo
	ldx #100
	jsr WaitForSomeTime
	cli
	
Reload:
	mva ZX2DATA+0 ZPZX2.SongIndex
	mva ZX2DATA+1 ZPZX2.SongCount
	mva ZX2DATA+2 ZPZX2.RasterbarToggle
	mva ZX2DATA+3 ZPZX2.RasterbarColour
	
Reinit:
	jsr SetNewSongPtrsFull
	jsr SetPlaybackSpeed
	
Wait:
	jsr ResetPokey
	jsr WaitForVBlank
	jsr WaitForSync

Loop:
	mva #0 COLBK
	jsr HandleKeyboard
	bit ZPZX2.PlayerStatus
	bmi Reinit
	bvs Wait
	bit ZPZX2.SongUpdate
	bpl Continue
	lda ZPZX2.RasterbarColour
	clc
	adc #$10
	sta ZPZX2.RasterbarColour
	
Continue:
	sta WSYNC
	jsr WaitForScanline
	sta WSYNC
	mva ZPZX2.RasterbarColour COLBK
	jsr SetPokey
	jsr DecompressZX2
	jsr CheckForTwoToneBit
	jmp Loop
	
Stop:
	mva #%10000000 ZPZX2.PlayerStatus
	rts
	
Pause:
	bit ZPZX2.PlayerStatus
	bmi Play
	bvs Play
	mva #%01000000 ZPZX2.PlayerStatus
	rts
	
Play:
	mva #%00000000 ZPZX2.PlayerStatus
	rts
	
Exit:
	jsr ResetPokey
	jsr WaitForVBlank
	mva #%11000000 NMIEN
	mva #%11111111 PORTB
	ldx:txs ZPZX2.StackPointer
	ldy #1
	clc
	rts
	
SkipChunk:
	mva #%11111111 ZPZX2.SongUpdate
	rts
		
SeekNext:
	lda ZPZX2.SongCount
	isb ZPZX2.SongIndex
	beq SeekLoop
	bcs SeekSet
	
SeekPrevious:
	lda ZPZX2.SongCount
	dcp ZPZX2.SongIndex
	bcs SeekSet
	sbc #0
	
SeekLoop:
	sta ZPZX2.SongIndex
	
SeekSet:
	jsr ResetPokey
	jsr SetNewSongPtrsFull
	jsr SetPlaybackSpeed
	jsr WaitForVBlank
	jmp WaitForSync
	
HandleKeyboard:
	lda SKSTAT			; Serial Port Status
	and #%00000100			; Last Key still pressed?
	beq HandleKeyboardContinue	; If yes, process further below
	mva #$FF ZPZX2.LastKeyPressed	; Reset Last Key registered
	bmi HandleKeyboardDone		; Unconditional
	
HandleKeyboardContinue:
	lda KBCODE			; Keyboard Code
	and #%00111111			; Clear the SHIFT and CTRL bits out of the Key Identifier
	cmp ZPZX2.LastKeyPressed	; Last Key currently held down?
	sta ZPZX2.LastKeyPressed	; Update Last Key registered
	beq HandleKeyboardDone		; If yes, there is nothing else to do here
	cmp #8				; 'O' Key?
	beq Stop			; Yes -> Stop Playback and wait for new input
	cmp #10				; 'P' Key?
	beq Pause			; Yes -> Toggle Play or Pause and wait for new input
	cmp #12				; 'Enter' Key?
	beq SkipChunk			; Yes -> Skip Playback to Next Chunk
	cmp #28				; Escape Key?
	beq Exit			; Yes -> Stop Playback and Return to DOS
	cmp #30				; '2' Key?
	beq SeekNext			; Yes -> Seek Next Song
	cmp #31				; '1' Key?
	beq SeekPrevious		; Yes -> Seek Previous Song
	cmp #48				; '9' Key?
	beq SpeedDown			; Yes -> Set Speed Down
	cmp #50				; '0' Key?
	beq SpeedUp			; Yes -> Set Speed Up
	
HandleKeyboardDone:
	rts
	
SpeedDown:
	dec ZPZX2.SongSpeed
	bcs SetSpeed
SpeedUp:
	inc ZPZX2.SongSpeed
	bcs SetSpeed
SetSpeed:
	ldx #%00000111
	lda ZPZX2.SongSpeed
	sax ZPZX2.SongSpeed
	jsr ResetPokey
	jsr SetPlaybackSpeed
	jsr WaitForVBlank
	jmp WaitForSync
	
;* ----------------------------------------------------------------------------
	
;* Set POKEY registers at least once per VBI using the last buffered values

.proc SetPokey
	ldx #0
	lda ZPZX2.Chunk[0].PokeyByte,x
	ldy ZPZX2.Chunk[1].PokeyByte,x
	sta $D200
	lda ZPZX2.Chunk[2].PokeyByte,x
	sty $D201
	ldy ZPZX2.Chunk[3].PokeyByte,x
	sta $D202
	lda ZPZX2.Chunk[4].PokeyByte,x
	sty $D203
	ldy ZPZX2.Chunk[5].PokeyByte,x
	sta $D204
	lda ZPZX2.Chunk[6].PokeyByte,x
	sty $D205
	ldy ZPZX2.Chunk[7].PokeyByte,x
	sta $D206
	lda ZPZX2.Chunk[8].PokeyByte,x
	sty $D207
	ldy ZPZX2.PokeySkctl,x
	sta $D208
	#CYCLE #4
	sty $D20F
	rts
.endp
	
;* ----------------------------------------------------------------------------

.proc ResetPokey
	mva #%00000011 ZPZX2.PokeySkctl	; Default SKCTL value, needed for handling Keyboard
	lda #0				; Default POKEY values
	:9 sta ZPZX2.Chunk[#].PokeyByte	; Clear all POKEY values in memory
	sta WSYNC
	sta $D20F
	sta WSYNC
	sta STIMER
	jmp SetPokey
.endp

;* ----------------------------------------------------------------------------

.proc WaitForSync
	lda VCOUNT		; Get Current Scanline / 2
	cmp #VLINE		; Is it time for Sync yet?
	bne WaitForSync		; Not Equal -> Keep waiting
	rts
.endp

;* ----------------------------------------------------------------------------

.proc WaitForVBlank
	lda VCOUNT		; Get Current Scanline / 2
	cmp #VBLANK_SCANLINE	; Is it time for VBlank yet?
	bne WaitForVBlank	; Not Equal -> Keep waiting
	rts
.endp

;* ----------------------------------------------------------------------------

;* Wait for a specific number of Frames, ranging from 1 and 256
;* Set the parameter in the X Register before calling this routine

.proc WaitForSomeTime
	:2 sta WSYNC		; Forcefully increment VCOUNT at least once
	jsr WaitForVBlank	; Wait until the end of the current Frame
	dex:bne WaitForSomeTime	; if (--X != 0) -> Keep waiting
	rts
.endp

;* ----------------------------------------------------------------------------
	
;* Detect the actual Machine Region in order to adjust Playback Speed among other things
;* PAL -> 0, NTSC -> 1

.proc DetectMachineRegion
	lda VCOUNT
	beq DetectMachineRegion_a
	tax
	bne DetectMachineRegion
	
DetectMachineRegion_a:
	sta ZPZX2.MachineRegion
	cpx #PAL_SCANLINE-1
	spl:inc ZPZX2.MachineRegion
	rts
.endp

;* ----------------------------------------------------------------------------

;* Set Playback speed using precalculated lookup tables, depending on the Machine Region
;* Cross-region adjustments are also supported, with few compatibility compromises

.proc SetPlaybackSpeed
	lda ZPZX2.MachineRegion
	bit ZPZX2.AdjustSpeed
	bpl SetPlaybackSpeed_b
	cmp ZPZX2.SongRegion
	beq SetPlaybackSpeed_b

SetPlaybackSpeed_a:
	clc
	adc #2
	
SetPlaybackSpeed_b:
	asl @
	asl @
	asl @
	adc ZPZX2.SongSpeed
	tay
	lda ScanlineDivisionTable,y
	sta ZPZX2.SyncDivision
	lda ScanlineCountTable,y
	sta ZPZX2.SyncCount
	
SetPlaybackSpeed_c:
	lda #VLINE
	sta ZPZX2.LastCount
	ldy #0
	sty ZPZX2.SyncOffset
	dey
	sty ZPZX2.SyncStatus
	rts
	
ScanlineDivisionTable:
DivPAL	.byte $9C,$4E,$34,$27,$1F,$1A,$16,$13
DivNTSC	.byte $83,$42,$2C,$21,$1A,$16,$13,$10
OffPAL	.byte $82,$41,$2D,$23,$1A,$14,$14,$0F
OffNTSC	.byte $9C,$4E,$34,$27,$1E,$1A,$18,$15

ScanlineCountTable:
NumPAL	.byte $9C,$9C,$9C,$9C,$9B,$9C,$9A,$98
NumNTSC	.byte $83,$84,$84,$84,$82,$84,$85,$80
FixPAL	.byte $9C,$9C,$A2,$A8,$9C,$90,$A8,$90
FixNTSC	.byte $82,$82,$82,$82,$7D,$82,$8C,$8C
.endp

;* ----------------------------------------------------------------------------

.proc WaitForScanline
	lda ZPZX2.SyncOffset
	asl ZPZX2.SyncStatus
	bcc WaitForScanlineSkip
	
WaitForScanlineContinue:
	lda VCOUNT
	tax
	sbc ZPZX2.LastCount
	scs:adc ZPZX2.SyncCount
	bcs WaitForScanlineNext
	adc #-1
	eor #-1
	adc ZPZX2.SyncOffset
	sta ZPZX2.SyncOffset
	lda #0
	
WaitForScanlineNext:
	sta ZPZX2.SyncDelta
	stx ZPZX2.LastCount
	lda ZPZX2.SyncOffset
	sbc ZPZX2.SyncDelta
	sta ZPZX2.SyncOffset
	bcs WaitForScanlineContinue
	
WaitForScanlineSkip:
	adc ZPZX2.SyncDivision
	sta ZPZX2.SyncOffset
	ror ZPZX2.SyncStatus
	
WaitForScanlineDone:
	rts
.endp

;* ----------------------------------------------------------------------------

.proc CheckForTwoToneBit
CheckForTwoToneBitLeft:
	ldx #$03
	lda ZPZX2.Chunk[1].PokeyByte	; AUDC0
	cmp #$F0
	bcs CheckForTwoToneBitLeft_a
	tay
	and #$10
	beq CheckForTwoToneBitLeft_a
	tya
	eor #$10
	sta ZPZX2.Chunk[1].PokeyByte
	ldx #$8B
	
CheckForTwoToneBitLeft_a:
	stx ZPZX2.PokeySkctl

CheckForTwoToneBitDone:
	rts
.endp

;* ----------------------------------------------------------------------------

;* ZX2-based SAP-R playback music driver, with very rudimentary functionalities

	icl "dzx2.asm"	
	run Start
	
;* ----------------------------------------------------------------------------

;* ZX2-Chunk data and lookup tables

	org ZX2DATA
	icl "SongIndex.asm"
	.echo "> ZX2DATA size of ", * - ZX2DATA, ", from ", ZX2DATA, " to ", *
	
;* ----------------------------------------------------------------------------

