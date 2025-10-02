;* Compressed ZX2 data chunks used for streaming POKEY register values at regular intervals
;* Chunks will make use of a few ByteCodes for Detecting Loops and Indexing data cleanly
;* This format is Work in Progress, and the specs are likely to change often due to that!

;* ----------------------------------------------------------------------------

.enum SEQCMD
	CHUNK	= %00000000
	GOTO	= %10000000
	REPEAT	= %11000000
.ende

.macro SetCommand Command, Parameter
	.byte [:Command | :Parameter]
.endm

.macro AddSeq Chunk
	SetCommand SEQCMD.CHUNK, (:Chunk & 127)
.endm

.macro GotoSeq Offset
	SetCommand SEQCMD.GOTO, ((* - :Offset) & 63)
.endm

.macro RepeatSeq Count
	SetCommand SEQCMD.REPEAT, ((:Count - 1) & 63)
.endm

.macro EndSeq
;	GotoSeq *
.endm

.macro MakeSeq
	.def ?ArgNum = :0
	
	.if (?ArgNum > 256)
		.error "[MakeSeq] Too many arguments"
	.endif
	
	.echo "[MakeSeq] Begin: ", *
	
	.def ?MemIndex = 0
	PutBytes :1 \ PutBytes :2 \ PutBytes :3 \ PutBytes :4 \ PutBytes :5 \ PutBytes :6 \ PutBytes :7 \ PutBytes :8
	PutBytes :9 \ PutBytes :10 \ PutBytes :11 \ PutBytes :12 \ PutBytes :13 \ PutBytes :14 \ PutBytes :15 \ PutBytes :16
	PutBytes :17 \ PutBytes :18 \ PutBytes :19 \ PutBytes :20 \ PutBytes :21 \ PutBytes :22 \ PutBytes :23 \ PutBytes :24
	PutBytes :25 \ PutBytes :26 \ PutBytes :27 \ PutBytes :28 \ PutBytes :29 \ PutBytes :30 \ PutBytes :31 \ PutBytes :32
	.def ?MemIndex = 0
	
	.rept 256
		.if (?MemIndex < ?ArgNum)
			GetBytes ?ArgVal
			
			.if (?ArgVal == SEQCMD.REPEAT)
				GetBytes ?ArgVal \ RepeatSeq ?ArgVal
				.echo "[MakeSeq] Repeat: ", ?ArgVal
			.elseif (?ArgVal == SEQCMD.GOTO)
				GetBytes ?ArgVal \ GotoSeq ?ArgVal
				.echo "[MakeSeq] Goto: ", ?ArgVal
			.elseif (?ArgVal < 128)
				AddSeq ?ArgVal
				.echo "[MakeSeq] Chunk: ", ?ArgVal
			.else
				.echo "[MakeSeq] Warning: Invalid value ", ?ArgVal, " skipped"
			.endif
		.endif
	.endr
	
	.echo "[MakeSeq] End: ", *
.endm

;* Store Data as 32-bit Integer
.macro PutBytes Data
	.def ?MemOffset = (?MemIndex * 4)
	.put [?MemOffset + 0] = [:Data & $FF]
	.put [?MemOffset + 1] = [(:Data >> 8) & $FF]
	.put [?MemOffset + 2] = [(:Data >> 16) & $FF]
	.put [?MemOffset + 3] = [(:Data >> 24) & $FF]
	.def ?MemIndex += 1
.endm

;* Read Data as 32-bit Integer
.macro GetBytes Data
	.def ?MemOffset = (?MemIndex * 4)
	.def :Data = [[.get [?MemOffset + 0] & $FF] | [.get [?MemOffset + 1] << 8] | [.get [?MemOffset + 2] << 16] | [.get [?MemOffset + 3] << 24]]
	.def ?MemIndex += 1
.endm

;* ----------------------------------------------------------------------------

;* ZX2Chunk format

SongIndex:
;	.byte TUNE_DEF
	.byte 0
SongCount:
;	.byte ?SNG_Count
	.byte [(SongTableEnd - SongTable) / 2]
RasterbarToggle:
;	.byte RASTERBAR_TOGGLE
	.byte 0
RasterbarColour:
;	.byte RASTERBAR_COLOUR
	.byte $69
	
SongTable:
	.word SNG_06
SongTableEnd:

SNG_06:

;SongRegion:
	.byte 1
	
;SongSpeed:
	.byte 0
	
;SongAdjust:
	.byte %10000000
	
;SongStereo:
	.byte 0
	
;SongTimer:
	.byte 0, 0, 0, 0
	
;SongSection:
	.word SNG_06_0, SNG_06_1, SNG_06_2, SNG_06_3, SNG_06_4, SNG_06_5, SNG_06_6, SNG_06_7, SNG_06_8
	;* Add another 2*9 Bytes for Stereo Songs, if defined as such
	
;ChunkSection:
	.word Nowhere_8_04, Nowhere_0_01, Nowhere_0_06, Nowhere_0_07, Nowhere_1_00, Nowhere_1_01, Nowhere_1_06, Nowhere_2_00
	.word Nowhere_3_00, Nowhere_4_02, Nowhere_4_04, Nowhere_5_02, Nowhere_5_04, Nowhere_6_03, Nowhere_6_05, Nowhere_7_03
	.word Nowhere_7_05, Nowhere_8_02
	
SNG_06_0:
	MakeSeq \
		SEQCMD.REPEAT 1, $04 \
		SEQCMD.REPEAT 3, $01
	EndSeq
	
SNG_06_0_Loop:
	MakeSeq \
		SEQCMD.REPEAT, 2, $01 \
		SEQCMD.REPEAT 1, $02, $03 \
		SEQCMD.GOTO SNG_06_0_Loop
	EndSeq
	
SNG_06_1:
	.byte $04, $05, $05, $05
SNG_06_1_Loop:
	.byte $05, $05, $06, $06
	GotoSeq SNG_06_1_Loop
	
SNG_06_2:
	.byte $07, $07, $07, $07
SNG_06_2_Loop:
	.byte $07, $07, $07, $07
	GotoSeq SNG_06_2_Loop
	
SNG_06_3:
	.byte $08, $08, $08, $08
SNG_06_3_Loop:
	.byte $08, $08, $08, $08
	GotoSeq SNG_06_3_Loop
	
SNG_06_4:
	.byte $04, $04, $09, $09
SNG_06_4_Loop:
	.byte $0A, $0A, $0A, $0A
	GotoSeq SNG_06_4_Loop
	
SNG_06_5:
	.byte $04, $04, $0B, $0B
SNG_06_5_Loop:
	.byte $0C, $0C, $0C, $0C
	GotoSeq SNG_06_5_Loop
	
SNG_06_6:
	.byte $04, $04, $04, $0D
SNG_06_6_Loop:
	.byte $0D, $0E, $0E, $0E
	GotoSeq SNG_06_6_Loop
	
SNG_06_7:
	.byte $04, $04, $04, $0F
SNG_06_7_Loop:
	.byte $0F, $10, $10, $10
	GotoSeq SNG_06_7_Loop
	
SNG_06_8:
	.byte $04, $04, $11, $11
SNG_06_8_Loop:
	.byte $00, $00, $00 ,$00
	GotoSeq SNG_06_8_Loop



/*
SNG_06_0:
	.byte $04, $01, $01, $01
SNG_06_0_Loop:
	.byte $01, $01, $02, $03
	GotoSeq SNG_06_0_Loop
SNG_06_1:
	.byte $04, $05, $05, $05
SNG_06_1_Loop:
	.byte $05, $05, $06, $06
	GotoSeq SNG_06_1_Loop
	
SNG_06_2:
	.byte $07, $07, $07, $07
SNG_06_2_Loop:
	.byte $07, $07, $07, $07
	GotoSeq SNG_06_2_Loop
SNG_06_3:
	.byte $08, $08, $08, $08
SNG_06_3_Loop:
	.byte $08, $08, $08, $08
	GotoSeq SNG_06_3_Loop
	
SNG_06_4:
	.byte $04, $04, $09, $09
SNG_06_4_Loop:
	.byte $0A, $0A, $0A, $0A
	GotoSeq SNG_06_4_Loop
SNG_06_5:
	.byte $04, $04, $0B, $0B
SNG_06_5_Loop:
	.byte $0C, $0C, $0C, $0C
	GotoSeq SNG_06_5_Loop
	
SNG_06_6:
	.byte $04, $04, $04, $0D
SNG_06_6_Loop:
	.byte $0D, $0E, $0E, $0E
	GotoSeq SNG_06_6_Loop
SNG_06_7:
	.byte $04, $04, $04, $0F
SNG_06_7_Loop:
	.byte $0F, $10, $10, $10
	GotoSeq SNG_06_7_Loop
	
SNG_06_8:
	.byte $04, $04, $11, $11
SNG_06_8_Loop:
	.byte $00, $00, $00 ,$00
	GotoSeq SNG_06_8_Loop
*/
	
Nowhere_0_01: ins "./Nowhere/Nowhere Is Forever v4.0_01"
Nowhere_0_06: ins "./Nowhere/Nowhere Is Forever v4.0_06"
Nowhere_0_07: ins "./Nowhere/Nowhere Is Forever v4.0_07"
Nowhere_1_00: ins "./Nowhere/Nowhere Is Forever v4.1_00"
Nowhere_1_01: ins "./Nowhere/Nowhere Is Forever v4.1_01"
Nowhere_1_06: ins "./Nowhere/Nowhere Is Forever v4.1_06"
Nowhere_2_00: ins "./Nowhere/Nowhere Is Forever v4.2_00"
Nowhere_3_00: ins "./Nowhere/Nowhere Is Forever v4.3_00"
Nowhere_4_02: ins "./Nowhere/Nowhere Is Forever v4.4_02"
Nowhere_4_04: ins "./Nowhere/Nowhere Is Forever v4.4_04"
Nowhere_5_02: ins "./Nowhere/Nowhere Is Forever v4.5_02"
Nowhere_5_04: ins "./Nowhere/Nowhere Is Forever v4.5_04"
Nowhere_6_03: ins "./Nowhere/Nowhere Is Forever v4.6_03"
Nowhere_6_05: ins "./Nowhere/Nowhere Is Forever v4.6_05"
Nowhere_7_03: ins "./Nowhere/Nowhere Is Forever v4.7_03"
Nowhere_7_05: ins "./Nowhere/Nowhere Is Forever v4.7_05"
Nowhere_8_02: ins "./Nowhere/Nowhere Is Forever v4.8_02"
Nowhere_8_04: ins "./Nowhere/Nowhere Is Forever v4.8_04"

