; -----------------------------------------------------------------------------
; ZX2 decoder by Einar Saukas, 6502 port by Vin Samuel (VinsCool)
; -----------------------------------------------------------------------------
; Parameters:
;	BufferFrom: source address (compressed data)
;	BufferTo: destination address (decompressing)
; -----------------------------------------------------------------------------

//-------------------------------------------//

DecompressZX2:
	ldx #8*2

DecompressZX2Continue:
	ldy ZPZX2.StatusCode,x
	bmi CopyFromLastOffset		; State = $FF -> Copy From Last Offset
	bne CopyFromLiteral		; State = $01 -> Copy From Literal
	jsr DecompressZX2Reset		; State = $00 -> Not Initialised, or End of File was reached

//-------------------------------------------//

CopyFromLiteral:
;	jsr GetByteFrom
	lda (ZPZX2.BufferFrom,x)
	inc ZPZX2.BufferFrom,x
	bne CopyFromLiteral_a
	inc ZPZX2.BufferFrom+1,x
CopyFromLiteral_a:
;	jsr WriteByteTo
	sta (ZPZX2.BufferTo,x)
	sta SDWPOK0,x
	inc ZPZX2.BufferTo,x
	dec ZPZX2.ByteCount,x
	bne ProcessNextIteration
	asl ZPZX2.BitByte,x
	bcs CopyFromNewOffset		;* Carry Set -> Copy From New Offset, Carry Not Set -> Copy From Last Offset
	jsr GetElias
	bcc SetBufferOffset		; Unconditional
	
//-------------------------------------------//

CopyFromLastOffset:
	lda (ZPZX2.BufferOffset,x)
	inc ZPZX2.BufferOffset,x
;	jsr WriteByteTo
	sta (ZPZX2.BufferTo,x)
	sta SDWPOK0,x
	inc ZPZX2.BufferTo,x
	dec ZPZX2.ByteCount,x
	bne ProcessNextIteration
	asl ZPZX2.BitByte,x
	bcs CopyFromNewOffset		;* Carry Set -> Copy From New Offset, Carry Not Set -> Copy From Literal
	jsr GetElias
	lda #$01			; Set state to Copy From Literal
	bcc SetNewState			; Unconditional
	
//-------------------------------------------//
	
CopyFromNewOffset:
;	jsr GetByteFrom
	lda (ZPZX2.BufferFrom,x)
	inc ZPZX2.BufferFrom,x
	bne CopyFromNewOffset_a
	inc ZPZX2.BufferFrom+1,x
CopyFromNewOffset_a:
	sta ZPZX2.LastOffset,x
	adc #0
	beq SetNewState			; End of File was reached
	jsr GetElias
	inc ZPZX2.ByteCount,x		; Add 1 to the byte count for every new offset
	
//-------------------------------------------//

SetBufferOffset:
	lda ZPZX2.BufferTo,x
	sbc ZPZX2.LastOffset,x
	sta ZPZX2.BufferOffset,x
	lda ZPZX2.BufferTo+1,x
	sta ZPZX2.BufferOffset+1,x
	lda #$FF			; Set state to Copy From Last Offset
	
//-------------------------------------------//

SetNewState:
	sta ZPZX2.StatusCode,x
ProcessNextIteration:
	dex
	dex
	bpl DecompressZX2Continue
	rts

//-------------------------------------------//

DecompressZX2Reset:
	sty ZPZX2.LastOffset,x		; Guaranteed to be 0 from StatusCode
	iny
	sty ZPZX2.StatusCode,x		; Set state to Copy From Literal
	sty ZPZX2.ByteCount,x		; Initialise ByteCount to 1
DecompressZX2Reset_a:
	lda ChunkSection,x		; Get the Channel's array of Chunks address
	sta ZPZX2.TMP0
	lda ChunkSection+1,x
	sta ZPZX2.TMP1
	ldy ZPZX2.ChunkIndex,x		; Get the Chunk Section offset
DecompressZX2Reset_b:
	lda (ZPZX2.TMP0),y
	iny
	cmp #$FF			; Is it the end of the Chunk Sequence?
	bne DecompressZX2Reset_c	; If not, process ahead like normal
	lda (ZPZX2.TMP0),y		; The next byte in the sequence will be used as a Loop Point
	tay
	bcs DecompressZX2Reset_b	; Unconditional
DecompressZX2Reset_c:
	sty ZPZX2.ChunkIndex,x		; Increment the Chunk Section offset for the next time
	tay
	lda ChunkIndexLSB,y		; Copy the Chunk address into BufferFrom to fully initialise it to load data from that Chunk
	sta ZPZX2.BufferFrom,x
	lda ChunkIndexMSB,y
	sta ZPZX2.BufferFrom+1,x
DecompressZX2Reset_d:
	sec				; Initial Bit is needed for GetElias
	bcs GetEliasSkip		; Unconditional

//-------------------------------------------//

GetElias:
	inc ZPZX2.ByteCount,x		; Guaranteed to be 0
	bne GetEliasLoop_a
GetEliasLoop:
	asl ZPZX2.BitByte,x
	rol ZPZX2.ByteCount,x
GetEliasLoop_a:
	asl ZPZX2.BitByte,x
	bne GetEliasLoop_c
GetEliasSkip:
;	jsr GetByteFrom
	lda (ZPZX2.BufferFrom,x)
	inc ZPZX2.BufferFrom,x
	bne GetEliasLoop_b
	inc ZPZX2.BufferFrom+1,x
GetEliasLoop_b:
	rol @
	sta ZPZX2.BitByte,x
GetEliasLoop_c:	
	bcs GetEliasLoop
GetEliasDone:
	rts

//-------------------------------------------//

/*
GetByteFrom:
	lda (ZPZX2.BufferFrom,x)
	inc ZPZX2.BufferFrom,x
	bne GetByteFromDone
	inc ZPZX2.BufferFrom+1,x
GetByteFromDone:
	rts
*/

//-------------------------------------------//

/*
WriteByteTo:
	sta (ZPZX2.BufferTo,x)
	sta SDWPOK0,x
	inc ZPZX2.BufferTo,x
	dec ZPZX2.ByteCount,x
WriteByteToDone:
	rts
*/

//-------------------------------------------//

