; -------------------------------------------------------------------------------------------------------------------------------
; DWRead / DWWrite - One ROM DriveWire plugin edition, for DW42 built with --define onerom=1
;
; These are toolshed's hdbdos/dwoneread.asm and dwonewrite.asm (the onerom-hdb branch), the CoCo's HDB-DOS
; routines for One ROM's drivewire plugin, carried over instruction for instruction in asm6809's syntax.  The label
; names differ, the plugin bring-up test pattern, which never applies here, is left out, and DWWrite's ack poll is
; timed with Y rather than D - see dwoWPoll.  A fix there belongs here too.
;
; The plugin sits in the cartridge's One ROM, on CTS* ($C000-$FEFF), and the Dragon's cartridge port is the
; CoCo's, so the same plugin build serves both.  It watches every address read from its ROM, and these routines
; signal by reading addresses: each byte to the plugin is a read of $C100 plus the byte, and a reply comes back
; through a 256-byte window at $E000 that the plugin fills.  Both are live DOSplus and extender code, which the
; plugin puts back as each exchange ends - see plugins/user/drivewire in the One ROM repository.  So each routine
; copies its body onto the stack and runs it there, where its own instruction fetches don't reach the plugin.
;
; The CoCo 3 handling is the CoCo's own and never runs on a Dragon: it keys on a CoCo 3's interrupt vectors
; pointing into page $FE, and a Dragon's point into page $01.  The SAM writes it leaves in place are to $FFDE,
; map type 0, which the Dragon is already in while DOSplus runs from the cartridge.
;
; DWRead keeps X for DW42's callers, as its bit-banger and Becker DWReads do; the CoCo routine returns it past the
; buffer.  It also sets carry on a timeout, as the Becker one does, where the CoCo routine reports a timeout in Z
; alone.  Otherwise the entry and exit conditions are the ones DW42's callers already use, given at each routine.
; -------------------------------------------------------------------------------------------------------------------------------

; -------------------------------------------------------------------------------------------------------------------------------
; DWRead
;    Receive a response from the DriveWire server.
; Entry:
;    X  = storage address for incoming data
;    Y  = number of bytes requested, 1-256 - the plugin's whole-response buffer is 256 bytes
; Exit:
;    CC = Z set on success; on timeout Z clear and C set, as DW42's Becker DWRead has it
;    X  = starting address of data received
;    Y  = checksum, a 16-bit sum of the bytes received
;    U is preserved.  A, B and DP are clobbered
;
; The plugin collects the whole response from the server, lays it out in the window and only then sets the status
; byte at $C100 to DWRREADY.  This polls for that, copies the window into the buffer at full bus speed and reads
; DWRACK to acknowledge it.  Until the response is ready, the plugin flips $C100 between $03 and $01 as a heartbeat,
; and the timeout below restarts at every change - so this waits as long as the plugin is visibly working, and
; gives up ~1.4s after it isn't.
;
; The copy is a stack blast: PULU A,B,DP,X,Y / PSHS A,B,DP,X,Y moves 7 bytes in 24 cycles, with S as the destination
; pointer.  PSHS fills downwards while PULU reads upwards, so the plugin stores the 7-byte chunks in reverse order:
; with R = count mod 7, the window holds the first R bytes, then the buffer's last 7, then the 7 before those, and
; so on back to byte R.
; -------------------------------------------------------------------------------------------------------------------------------
DWRTIMEOUT	equ	56820							; passes of the 22-cycle poll loop, ~1.25M cycles
DWRREADY		equ	$02							; status value: response laid out
DWRACK		equ	$C100+DWRREADY				; read to acknowledge the response
DWRWINDOW	equ	$E000							; the response, laid out as above

DWRead	pshs	x								; DW42's callers expect X kept
			bsr	dwoRead
			puls	x								; PULS leaves CC alone
			beq	dwoROK
			orcc	#$01							; timed out: carry as well, as DW42's Becker DWRead reports it -
												; DWLOAD's request (reqobj) tests carry alone
dwoROK	rts

dwoRead	pshs	cc								; saved for its IRQ mask bits only - the returned CC comes from TSTA below
			pshs	u
			orcc	#$50							; mask interrupts - see DWWrite
			pshs	x,y							; buffer start and count, for the patching and checksum below
												; copy the body onto the stack by the same stack blast as the response, 7 bytes at a time,
												; last chunk first so PSHS lays it down in order (DWRCODELEN is a multiple of 7)
			pshs	dp								; PULU loads DP from code bytes
			ldu	#DWRCODEEND-7
dwoRCpy	pulu	a,b,dp,x,y
			pshs	a,b,dp,x,y
			leau	-14,u
			cmpu	#DWRCODE-7
			bne	dwoRCpy
			lda	DWRCODELEN,s				; DP back, from under the copy
			tfr	a,dp
												; patch the stack copy.  DP, X and Y were stacked above the copy, at DWRCODELEN,s,
												; DWRCODELEN+1,s and DWRCODELEN+3,s
			ldd	DWRCODELEN+3,s				; B = count mod 7 - at most 37 passes for a 256-byte count
dwoRMod	subd	#7
			bcc	dwoRMod
			addb	#7
			stb	DWRHEAD+1-DWRCODE,s
			ldd	DWRCODELEN+3,s
			addd	#DWRWINDOW
			std	DWRWEND+2-DWRCODE,s
			ldd	DWRCODELEN+1,s
			addd	DWRCODELEN+3,s
			std	DWRBEND+2-DWRCODE,s
			ldb	>$FFFC						; CoCo 3? - see the file header
			cmpb	#$FE
			bne	dwoRGo
			lda	#$DF							; leave = $FFDF (RAM mode); +2 is the low byte of each operand
			sta	DWRLEAVE+2-DWRCODE,s
			sta	DWRTOLEAVE+2-DWRCODE,s
			ldd	DWRBEND+2-DWRCODE,s
			cmpd	#$8000						; buffer ends at or below $8000?
			bls	dwoRGo
			lda	#$20							; no - BRN becomes BRA, the slow path
			sta	DWRPATH-DWRCODE,s
dwoRGo	ldx	DWRCODELEN+1,s				; the body's entry X and Y - the copy above clobbered both
			ldy	DWRCODELEN+3,s
			jsr	,s
			leas	DWRCODELEN+1,s				; the copy, and the DP saved above
			puls	x,y							; buffer start and count
			tsta									; timed out?
			bne	dwoROut						; yes - no checksum to make
												; checksum pass, over the buffer just filled, run in place: the exchange is over, so
												; instruction fetches can no longer confuse the plugin
			ldd	#0								; running checksum
dwoRSum	addb	,x+
			adca	#0
			leay	-1,y
			bne	dwoRSum
			tfr	d,y							; Y = checksum
			clra									; status = success
dwoROut	puls	u
			puls	cc								; restores the original IRQ mask bits; A, the status, is untouched by this
			tsta									; set Z from the status byte
			andcc	#$FE							; clear C - no framing error here
			rts

												; position-independent body - copied onto the stack and run from there.  Entered with X/Y
												; as DWRead's own, U free, and DWRHEAD, DWRBEND, DWRWEND, DWRPATH, DWRLEAVE and DWRTOLEAVE
												; patched.  Returns A = 0 on success, 1 on timeout
DWRCODE	sta	>$FFDE						; cartridge in - see the file header
			ldu	#$C100						; signalling page
												; the knock, each byte as a read of $C100 plus the byte, as a constant offset (every
												; knock byte is below $80)
			lda	'!',u
			lda	'D',u
			lda	'W',u
			lda	'R',u
			lda	'E',u
			lda	'C',u
			lda	'V',u
			lda	'!',u
			tfr	y,d							; D = count (A = high byte, B = low)
			pshs	b								; save low byte across the high byte's send below
			tfr	a,b
			lda	b,u							; send high byte of count
			puls	b								; restore low byte
			lda	b,u							; send low byte of count
												; wait for DWRREADY.  Y is the DWRTIMEOUT count, A the last status seen
			ldb	#DWRREADY
			ldy	#DWRTIMEOUT
			lda	,u								; status as first seen
dwoRPoll	cmpb	,u								; ready?
			beq	dwoRGot
			cmpa	,u								; changed since last seen? (the plugin's heartbeat)
			beq	dwoRSame
			lda	,u								; yes - note it, and restart the timeout
			ldy	#DWRTIMEOUT
dwoRSame	leay	-1,y
			bne	dwoRPoll
DWRTOLEAVE	sta	>$FFDE						; timed out - leave, patched like DWRLEAVE, and fail: status nonzero is
			lda	#1								; Z clear in DWRead's TSTA
			rts
												; copy the window into the buffer - see above.  X is the buffer start, U walks the window
dwoRGot	ldu	#DWRWINDOW
DWRHEAD	ldb	#0								; patched: count mod 7
DWRPATH	brn	dwoRSlow						; patched to BRA for the slow path
			beq	dwoRBlast					; (BRN leaves LDB's Z alone)
dwoRHead	lda	,u+							; the head bytes, upwards
			sta	,x+
			decb
			bne	dwoRHead
dwoRBlast	pshs	dp								; PULU loads DP from data
			sts	>dwoRRest+2,pcr			; S is the destination from here (16-bit offset, as lwasm assembles it)
DWRBEND	lds	#0								; patched: buffer end
DWRWEND	cmpu	#0								; patched: window end
			beq	dwoRRest
			pulu	a,b,dp,x,y
			pshs	a,b,dp,x,y
			bra	DWRWEND
dwoRRest	lds	#0								; the STS above fills this in
			puls	dp
dwoRAck	tst	>DWRACK						; acknowledge - the plugin restores $C100 and the window
DWRLEAVE	sta	>$FFDE						; leave - patched to $FFDF on a CoCo 3
			clra									; status = success
			rts
												; the slow path, CoCo 3 only: the same layout, a byte at a time with RAM mode around each
												; store.  B is still the head count, X the buffer start
dwoRSlow	bsr	dwoRCopy						; the head bytes, upwards
			ldx	DWRBEND+2,pcr				; then the chunks, downwards from the buffer end
dwoRSNext	cmpu	DWRWEND+2,pcr
			beq	dwoRAck
			leax	-7,x							; X = this chunk's start
			ldb	#7
			bsr	dwoRCopy
			leax	-7,x							; back to it, for the next LEAX
			bra	dwoRSNext
dwoRCopy	tstb									; copies B bytes from U to X
			beq	dwoRCRet
dwoRCByte	lda	,u+
			sta	>$FFDF						; RAM mode for the store
			sta	,x+
			sta	>$FFDE						; cartridge back in
			decb
			bne	dwoRCByte
dwoRCRet	rts
			fill	$12,(7-(*-DWRCODE)%7)%7	; NOP pad to a multiple of 7, for DWRead's 7-byte copy
DWRCODEEND	equ	*
DWRCODELEN	equ	DWRCODEEND-DWRCODE
			assert	DWRCODELEN%7==0,"DWRead's body must be a whole number of 7-byte chunks"

; -------------------------------------------------------------------------------------------------------------------------------
; DWWrite
;    Send a packet to the DriveWire server.
; Entry:
;    X  = starting address of data to send, in RAM - fetching it from the cartridge's own ROM is a read of an
;         address outside $C080-$C17F, which the plugin takes as the Dragon leaving the session, and nothing is sent
;    Y  = number of bytes to send (0-65535)
; Exit:
;    X  = address of last byte sent + 1
;    Y  = 0
;    All others preserved
;
; Sends the "!DWSEND!" knock, then polls $C200 for the plugin's ack, resending the whole knock if it doesn't come in
; time, then two count bytes, high byte first, then the data.  Every byte is a read of $C100 plus the byte, as
; LDA B,U, so the address's low byte is the value and the byte read back is unused.  The ack poll is the one read
; here whose value is checked, and $C200 is outside the $C080-$C17F the count and data bytes can land in.
; DWWACKRETRIES bounds the retries, so with no plugin there this falls through rather than hangs.
; -------------------------------------------------------------------------------------------------------------------------------
DWWACKTIMEOUT	equ	$4000
DWWACKRETRIES	equ	8

DWWrite	pshs	u,d,cc
			orcc	#$50							; mask interrupts - an interleaved ISR could desync the sequence
			ldu	#DWWCODEEND
dwoWCpy	lda	,-u
			pshs	a
			cmpu	#DWWCODE
			bne	dwoWCpy
			ldb	>$FFFC						; CoCo 3? - see the file header
			cmpb	#$FE
			bne	dwoWGo
			lda	#$DF							; leave = $FFDF (RAM mode); +2 is the low byte of each STA's operand
			sta	DWWLEAVE1+2-DWWCODE,s
			sta	DWWLEAVE2+2-DWWCODE,s
dwoWGo	jsr	,s
			leas	DWWCODELEN,s
			puls	cc,d,u,pc

												; position-independent body - copied onto the stack and run from there.  Entered with X/Y
												; as DWWrite's own, U free, and interrupts already masked
DWWCODE	sta	>$FFDE						; cartridge in - see the file header
			ldu	#$C100						; signalling page
			ldd	#DWWACKRETRIES
			pshs	d								; outer retry budget, held on the stack across every knock (re)send
dwoWKnock	ldu	#$C100
			ldb	#'!'
			lda	b,u
			ldb	#'D'
			lda	b,u
			ldb	#'W'
			lda	b,u
			ldb	#'S'
			lda	b,u
			ldb	#'E'
			lda	b,u
			ldb	#'N'
			lda	b,u
			ldb	#'D'
			lda	b,u
			ldb	#'!'
			lda	b,u
			ldu	#$C200						; the ack's page - not $C100-$C1FF, where the count and data land
												; Y times the poll, not D: the poll loads A, and the CoCo routine's
												; LDD #DWWACKTIMEOUT / SUBD #1 count had A reloaded with the ROM's own
												; byte at $C200 on every pass, so it never reached zero, the knock was
												; never resent, and a knock with no ack hung the machine for good
			pshs	y								; the count, for after the ack
			ldy	#DWWACKTIMEOUT
dwoWPoll	lda	,u								; poll the ack byte's value
			cmpa	#$A5
			beq	dwoWAcked
			leay	-1,y
			bne	dwoWPoll
			puls	y
			puls	d								; this attempt timed out - consume one retry
			subd	#1
			beq	dwoWGiveUp					; none left: stack already balanced, proceed anyway
			pshs	d								; save the decremented budget back
			bra	dwoWKnock					; resend the whole knock
dwoWAcked	puls	y
			puls	d								; discard the saved retry budget - balanced as on the exhausted path
dwoWGiveUp	ldu	#$C100						; back to the signalling page for the count and data
			tfr	y,d							; D = count (A = high byte, B = low)
			pshs	b								; save low byte across the high byte's send below
			tfr	a,b
			lda	b,u							; send high byte of count
			puls	b								; restore low byte
			lda	b,u							; send low byte of count
DWWLEAVE1	sta	>$FFDE						; leave - patched to $FFDF on a CoCo 3, so the buffer read sees RAM
dwoWLoop	lda	,x+							; fetch next data byte
			tfr	a,b
			sta	>$FFDE						; cartridge in
			lda	b,u							; send it
DWWLEAVE2	sta	>$FFDE						; leave - patched like DWWLEAVE1
			leay	-1,y
			bne	dwoWLoop
			rts
DWWCODEEND	equ	*
DWWCODELEN	equ	DWWCODEEND-DWWCODE
