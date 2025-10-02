; -----------------------------------------------------------------------------
; ZX2 decoder by Einar Saukas, 6502 port by Vin Samuel (VinsCool)
; -----------------------------------------------------------------------------
; Parameters:
;	BufferFrom: source address (compressed data)
;	BufferTo: destination address (decompressing)
; -----------------------------------------------------------------------------

//-------------------------------------------//

;* Song index initialisation subroutine, load pointers using index number, as well as loop point when it exists
;* If the routine is called from this label, index and loop are restarted

SetNewSongPtrsFull:
	lda ZPZX2.SongIndex
	asl @
	tax
	mwa ZX2DATA+4,x ZPZX2.SongPointer
	ldy #0
	mva (ZPZX2.SongPointer),y ZPZX2.SongRegion
	iny
	mva (ZPZX2.SongPointer),y ZPZX2.SongSpeed
	iny
	mva (ZPZX2.SongPointer),y ZPZX2.AdjustSpeed
	iny
	mva (ZPZX2.SongPointer),y ZPZX2.SongStereo
	iny
	mva (ZPZX2.SongPointer),y ZPZX2.SongTimer+0
	iny
	mva (ZPZX2.SongPointer),y ZPZX2.SongTimer+1
	iny
	mva (ZPZX2.SongPointer),y ZPZX2.SongTimer+2
	iny
	mva (ZPZX2.SongPointer),y ZPZX2.SongTimer+3
	iny
	mwa (ZPZX2.SongPointer),y ZPZX2.Chunk[0].SongSection
	iny
	mwa (ZPZX2.SongPointer),y ZPZX2.Chunk[1].SongSection
	iny
	mwa (ZPZX2.SongPointer),y ZPZX2.Chunk[2].SongSection
	iny
	mwa (ZPZX2.SongPointer),y ZPZX2.Chunk[3].SongSection
	iny
	mwa (ZPZX2.SongPointer),y ZPZX2.Chunk[4].SongSection
	iny
	mwa (ZPZX2.SongPointer),y ZPZX2.Chunk[5].SongSection
	iny
	mwa (ZPZX2.SongPointer),y ZPZX2.Chunk[6].SongSection
	iny
	mwa (ZPZX2.SongPointer),y ZPZX2.Chunk[7].SongSection
	iny
	mwa (ZPZX2.SongPointer),y ZPZX2.Chunk[8].SongSection
	iny
	tya
	clc
	adc ZPZX2.SongPointer+0
	sta ZPZX2.SongPointer+0
	lda ZPZX2.SongPointer+1
	adc #0
	sta ZPZX2.SongPointer+1
	
//-------------------------------------------//

;* If the routine is called from this label, it will use the current parameters instead

SetNewSongPtrs:
	ldx #.len ZX2Chunk*(9-1)
	
SetNewSongPtrs_a:
	lda (ZPZX2.Chunk[0].SongSection,x)
	inw ZPZX2.Chunk[0].SongSection,x
;	bpl SetNewSongPtrs_b
	cmp #SEQCMD.GOTO
	bcc SetNewSongPtrs_b
	eor #%01111111
	clc
	adc ZPZX2.Chunk[0].SongSection+0,x
	sta ZPZX2.Chunk[0].SongSection+0,x
	lda ZPZX2.Chunk[0].SongSection+1,x
	sbc #0
	sta ZPZX2.Chunk[0].SongSection+1,x
	bcs SetNewSongPtrs_a			; Unconditional
	
SetNewSongPtrs_b:
;	inw ZPZX2.Chunk[0].SongSection,x
	asl @
	tay
	mwa (ZPZX2.SongPointer),y ZPZX2.Chunk[0].BufferFrom,x
	
SetNewSongPtrs_c:	
	ldy #0
	sty ZPZX2.Chunk[0].LastOffset,x		; Reset Last Offset to 0
	sty ZPZX2.Chunk[0].StatusCode,x		; Set state to Copy From Literal
	iny
	sec
	jsr GetEliasSkip
	txa:sbx #.len ZX2Chunk
	bpl SetNewSongPtrs_a
	sta ZPZX2.SongUpdate
	rts
	
//-------------------------------------------//

GetElias:
	lda #%00000001
	asl ZPZX2.Chunk[0].BitByte,x
	beq GetEliasByte
	bcc GetEliasDone
	
GetEliasLoop:
	asl ZPZX2.Chunk[0].BitByte,x
	rol @
	asl ZPZX2.Chunk[0].BitByte,x
	bne GetEliasNext
	
GetEliasByte:
	tay
	
GetEliasSkip:
	lda (ZPZX2.Chunk[0].BufferFrom,x)
	inw ZPZX2.Chunk[0].BufferFrom,x
	rol @
	sta ZPZX2.Chunk[0].BitByte,x
	tya
	
GetEliasNext:
	bcs GetEliasLoop
	
GetEliasDone:
	sta ZPZX2.Chunk[0].ByteCount,x
	rts
	
//-------------------------------------------//

DecompressZX2:
	bit ZPZX2.SongUpdate			; Was End Of File reached?
	spl:jsr SetNewSongPtrs			; Initialise new Chunks for the Next Iteration
	mva >ZX2BUF ZPZX2.BufferTo+1		; Set Channel Pointer
	dec ZPZX2.ChannelOffset			; Update Channel Offset
	ldx #.len ZX2Chunk*(9-1)
	
DecompressZX2Continue:
	lda ZPZX2.Chunk[0].StatusCode,x		;* Bit 7 Clear -> Copy From Literal, Bit 7 Set -> Copy From Last Offset
	bmi CopyFromLastOffset
	
//-------------------------------------------//

CopyFromLiteral:
	lda (ZPZX2.Chunk[0].BufferFrom,x)
	inw ZPZX2.Chunk[0].BufferFrom,x
	ldy ZPZX2.ChannelOffset
	sta (ZPZX2.BufferTo),y
	sta ZPZX2.Chunk[0].PokeyByte,x
	dec ZPZX2.Chunk[0].ByteCount,x
	bne ProcessNextIteration
	dec ZPZX2.Chunk[0].StatusCode,x		; Set state to Copy From Last Offset, it could never be Literal twice
	asl ZPZX2.Chunk[0].BitByte,x		;* Carry Set -> Copy From New Offset, Carry Clear -> Copy From Last Offset
	bcs CopyFromNewOffset
	jsr GetElias
	bcc SetLastOffset			; Unconditional
	
//-------------------------------------------//

CopyFromLastOffset:
	ldy ZPZX2.Chunk[0].BufferOffset,x
	dec ZPZX2.Chunk[0].BufferOffset,x
	lda (ZPZX2.BufferTo),y
	ldy ZPZX2.ChannelOffset
	sta (ZPZX2.BufferTo),y
	sta ZPZX2.Chunk[0].PokeyByte,x
	dec ZPZX2.Chunk[0].ByteCount,x
	bne ProcessNextIteration
	asl ZPZX2.Chunk[0].BitByte,x		;* Carry Set -> Copy From New Offset, Carry Clear -> Copy From Literal
	bcs CopyFromNewOffset
	inc ZPZX2.Chunk[0].StatusCode,x		; Set state to Copy From Literal
	jsr GetElias
	bcc ProcessNextIteration		; Unconditional
	
//-------------------------------------------//

CopyFromNewOffset:
	lda (ZPZX2.Chunk[0].BufferFrom,x)
	inw ZPZX2.Chunk[0].BufferFrom,x
	sta ZPZX2.Chunk[0].LastOffset,x
	cmp #$FF				; $FF == End of File
	bne SetNewOffset
	sta ZPZX2.SongUpdate			; End of File was reached if Equal
	beq ProcessNextIteration		; Unconditional
	
//-------------------------------------------//

SetNewOffset:
	jsr GetElias
	inc ZPZX2.Chunk[0].ByteCount,x		; Add 1 to the byte count for every new offset
	
SetLastOffset:
	lda ZPZX2.Chunk[0].LastOffset,x
	adc ZPZX2.ChannelOffset			; Carry guaranteed to be Clear
	sta ZPZX2.Chunk[0].BufferOffset,x
	
//-------------------------------------------//

ProcessNextIteration:
	inc ZPZX2.BufferTo+1
	txa:sbx #.len ZX2Chunk
	bpl DecompressZX2Continue
	rts					;* Guaranteed to Return with 0 in the Accumulator, Carry Clear and Negative Set
	
//-------------------------------------------//

