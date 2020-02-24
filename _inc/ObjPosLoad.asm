; ---------------------------------------------------------------------------
; Subroutine to	load a level's objects
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


ObjPosLoad:
		moveq	#0,d0
		move.b	(v_opl_routine).w,d0
		move.w	OPL_Index(pc,d0.w),d0
		jmp	OPL_Index(pc,d0.w)
; End of function ObjPosLoad

; ===========================================================================
OPL_Index:	dc.w OPL_Init-OPL_Index
		dc.w OPL_Load-OPL_Index
; ===========================================================================

OPL_Init:
		addq.b	#2,(v_opl_routine).w
		move.w	(v_zone).w,d0		; get zone & act zzzz zzzz 0000 00aa
		lsl.b	#6,d0				; zzzz zzzz aa00 0000
		lsr.w	#4,d0				; 0000 zzzz zzzz aa00
		lea	(ObjPos_Index).l,a0		; get object placement addresses
		movea.l	a0,a1
		adda.w	(a0,d0.w),a0		; get object placement address
		move.l	a0,(v_opl_right_addr).w	; set load addresses for objects
		move.l	a0,(v_opl_left_addr).w
		adda.w	2(a1,d0.w),a1		; get secondary object placement address (usually empty)
		move.l	a1,(v_opl_right_addr2).w		; set secondary load addresses for objects (unused)
		move.l	a1,(v_opl_left_addr2).w
		lea	(v_objstate).w,a2		; load object respawn table
		move.w	#$101,(a2)+			; setup some data for objects without "remember state"
		move.w	#$5E,d0		; clear $17C bytes (overflows to stack, but probably safe)

	@clearLoop:
		clr.l	(a2)+
		dbf	d0,@clearLoop	; clear	object respawn table

		lea	(v_objstate).w,a2
		moveq	#0,d2
		move.w	(v_screenposx).w,d6		; get camera x-position - 128px
		subi.w	#$80,d6
		bhs.s	@noLeftClamp
		moveq	#0,d6		; cap at 0px to prevent crossing left bound

	@noLeftClamp:
		andi.w	#$FF80,d6		; round x-position to units of 128px is load position
		movea.l	(v_opl_right_addr).w,a0		; get left object entry address

	@findRightObj:
		cmp.w	(a0),d6		; is object x > load position?
		bls.s	@saveRightObj	; if yes, branch
		tst.b	4(a0)		; check "remember state" flag
		bpl.s	@noRemember
		move.b	(a2),d2
		addq.b	#1,(a2)		; increment respawn index of right entry

	@noRemember:
		addq.w	#6,a0		; go to next object entry
		bra.s	@findRightObj
; ===========================================================================

@saveRightObj:
		move.l	a0,(v_opl_right_addr).w	; save address of right object entry
		movea.l	(v_opl_left_addr).w,a0	; load address of left object entry
		subi.w	#$80,d6		; rounded x - 256px is the load position
		blo.s	@saveLeftObj

	@findLeftObj:
		cmp.w	(a0),d6		; is object x > load position?
		bls.s	@saveLeftObj	; if yes, branch
		tst.b	4(a0)		; check "remember state flag"
		bpl.s	@noRemember2
		addq.b	#1,1(a2)	; increment respawn index of left entry

	@noRemember2:
		addq.w	#6,a0		; go to next object entry
		bra.s	@findLeftObj
; ===========================================================================

@saveLeftObj:
		move.l	a0,(v_opl_left_addr).w		; save address of left object entry
		move.w	#-1,(v_opl_x_rounded).w		; make OPL load objects from right

OPL_Load:
		lea	(v_objstate).w,a2
		moveq	#0,d2
		move.w	(v_screenposx).w,d6		; get current rounded x position
		andi.w	#$FF80,d6
		cmp.w	(v_opl_x_rounded).w,d6	; compare with last rounded x
		beq.w	OPL_Return			; if current = last, return
		bge.s	OPL_MovedRight			; if current >= last, branch
; OPL_MovedLeft:					if current < last, follow the code here
		move.w	d6,(v_opl_x_rounded).w		; set last rounded x for next frame
		; load address of entry that was previously closest to rounded x - 128px
		movea.l	(v_opl_left_addr).w,a0
		subi.w	#$80,d6			; rounded x - 128px is load position
		bcs.s	@saveLeftObj	; don't load if x - 128 < 0
	; find entry whose X is < rounded X - 128, and spawn while finding
	@findLeftObj:
		cmp.w	-6(a0),d6	; check x-position of previous object
		bge.s	@saveLeftObj	; branch if it's < load position
		subq.w	#6,a0		; go to previous object
		tst.b	4(a0)		; check "remember state" flag
		bpl.s	@noRemember
		subq.b	#1,1(a2)	; decrement respawn index of left entry
		move.b	1(a2),d2	; save it for later

	@noRemember:
		bsr.w	OPL_CheckSpawn	; check if object should be spawned
		bne.s	@noSpawn		; if it didn't spawn, branch
		subq.w	#6,a0			; go to previous entry after CPU going to current entry
		bra.s	@findLeftObj
; ===========================================================================

	@noSpawn:
		tst.b	4(a0)	; check "remember state" flag
		bpl.s	@noRemember2
		addq.b	#1,1(a2)	; undo decrement of respawn index

	@noRemember2:
		addq.w	#6,a0		; disable loading

@saveLeftObj:
		move.l	a0,(v_opl_left_addr).w	; save new entry address
		movea.l	(v_opl_right_addr).w,a0
		addi.w	#$300,d6	; load position = rounded X + 640px
	; find entry whose X is < rounded X + 640
	@findRightObj:
		cmp.w	-6(a0),d6	; check x-position of previous object
		bgt.s	@saveRightObj	; branch if it's <= load position
		tst.b	-2(a0)		; check "remember state" flag
		bpl.s	@noRemember3
		subq.b	#1,(a2)		; decrement respawn index of right entry

	@noRemember3:
		subq.w	#6,a0		; go to previous entry
		bra.s	@findRightObj
; ===========================================================================

	@saveRightObj:
		move.l	a0,(v_opl_right_addr).w	; save new entry address
		rts	
; ===========================================================================

OPL_MovedRight:
		move.w	d6,(v_opl_x_rounded).w	; save last rounded X for next frame
		; load address of entry that was previously closest to rounded x + 640px
		movea.l	(v_opl_right_addr).w,a0
		addi.w	#$280,d6		; load position = rounded camera X + 640px
	; find entry whose X is < rounded X + 640, and spawn while finding
	@findRightObj:
		cmp.w	(a0),d6		; is object X > load position?
		bls.s	@saveRightObj	; if yes, branch
		tst.b	4(a0)		; check "remember state" flag
		bpl.s	@noRemember
		move.b	(a2),d2		; get respawn index of current object
		addq.b	#1,(a2)		; increment its value for next object

	@noRemember:
		bsr.w	OPL_CheckSpawn	; try to spawn object
		beq.s	@findRightObj	; continue finding if it's spawned/already loaded
		; looks like somebody forgot to undo incrementing respawn index,
		; when object didn't spawn, resulting in some objects that don't
		; respawn sometimes

@saveRightObj:
		move.l	a0,(v_opl_right_addr).w		; save new address of right entry
		movea.l	(v_opl_left_addr).w,a0	; load previous address of right entry
		subi.w	#$300,d6		; load position = rounded camera X - 128px
		blo.s	@saveLeftObj
	; find entry whose X is < rounded X - 128
	@findLeftObj:
		cmp.w	(a0),d6		; is object X > load position?
		bls.s	@saveLeftObj	; if yes, branch
		tst.b	4(a0)		; check "remember state" flag
		bpl.s	@noRemember2
		addq.b	#1,1(a2)	; increment respawn index for left entry

	@noRemember2:
		addq.w	#6,a0		; go to next entry
		bra.s	@findLeftObj
; ===========================================================================

@saveLeftObj:
		move.l	a0,(v_opl_left_addr).w	; save address of left object entry

OPL_Return:
		rts	
; ===========================================================================

OPL_CheckSpawn:
		tst.b	4(a0)		; check "remember state" flag
		bpl.s	OPL_MakeItem	; always spawn the object if flag is off
		bset	#7,2(a2,d2.w)	; mark object as loaded
		beq.s	OPL_MakeItem	; spawn object if it wasn't previously loaded
		addq.w	#6,a0		; go to next entry for consistency with (a0)+
		moveq	#0,d0		; mark as spawned/already loaded
		rts	
; ===========================================================================

OPL_MakeItem:
		bsr.w	FindFreeObj		; find an object slot
		bne.s	@return
		move.w	(a0)+,obX(a1)	; copy x-position to SST
		move.w	(a0)+,d0		; load y-position and orientation
		move.w	d0,d1
		andi.w	#$FFF,d0		; lower 12 bits are y-positions
		move.w	d0,obY(a1)		; write y-position to SST
		rol.w	#2,d1			; upper 2 bits are orientation
		andi.b	#3,d1			; get only orientation bits
		move.b	d1,obRender(a1)		; copy to render & status flags
		move.b	d1,obStatus(a1)
		move.b	(a0)+,d0		; load object type ID
		bpl.s	@noRemember		; bit 7 - "remember state" flag
		andi.b	#$7F,d0			; load lower 7 bits for ID
		move.b	d2,obRespawnNo(a1)	; write respawn index to SST

@noRemember:
		move.b	d0,0(a1)		; write object ID to SST
		move.b	(a0)+,obSubtype(a1)	; copy subtype to SST
		moveq	#0,d0			; mark as successfully spawned

	@return:
		rts	