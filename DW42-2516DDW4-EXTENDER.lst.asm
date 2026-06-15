                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; This is the ROM-add-on that acts depending upon the drive number, via DW4 or via DOS as usual
                      ; Verified 43 commands of the DosPlus49b, all of them worked flawlessly with drive / VDK of any size (180-360-360-720)
                      ; I have left BOOT apart because it seems that only drive1 can be booted
                      ; To BOOT an OS-9 or NitrOS-9 disk it should be mounted on DriveWire slot 0
                      ;    and it has to be a special boot disk to communicate with the DW server via parallel adapter or Becker Port
                      ; NOTE: The commands that modify directory sectors (T20), don't update backup T16 (by these DOS design)
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; From $fc to $ff will contain a slot number for units 1-2-3-4
                      ; if they are greater than 4, then they must be pointing to a reserved DW4 slot, else they are actual floppy drives (1 to 4)
                      ; last modification: slot 0 is also considered to be Drivewire (for booting OS-9 or NitrOS-9)
                      ; numbers from 1 to 4 are ONLY accepted at the UNIT with the SAME number and just for physical drives
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; This extender is intended for DPlus50
                      ; DW42-0.25.12 - 2021-05-28 by Pere Serrat (pser1)
                      ; DW42-0.25.13 - 2021-05-29 Mike Miller: Added multiboot BOOT command to allow RSDOS boot track disks
                      ;                                          Note - requires DOS repatch
                      ;                                                                        Mike Miller: Update size output to display large filesizes in SDIR, SDRIVE
                      ; DW42-0.25.14 - 2021-06-03 Pere Serrat: corrects RSboot upgrade
                      ; DW42-0.25.15 - 2021-06-04 Pere Serrat: adds cpyMPIcfg (copy of MPI config byte $ff7f)
                      ;                                                                                                         and modifies tstMPI to be fully compatible with mega-mini-MPI
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      
                                                                                                                              ; ROM routines
009F                  getNChr         equ     $9f                                                     ; get next char from input buffer
00A5                  redLChr         equ     $a5                                                     ; get last read char from input buffer
8000                  basini          equ     $8000                                                   ; basic rom beginning
8344                  syserr          equ   $8344                                                     ; system error
8371                  okprmpt         equ   $8371                                                     ; BASIC OK prompt, command loop
83ED                  basvect2        equ   $83ed                                                     ; initialize BASIC
841F                  basvect1        equ   $841f                                                     ; reset BASIC vectors, reset stack etc
849F                  runbasic        equ   $849f                                                     ; run_basic, enable IRQs etc
84ED                  romcmd          equ     $84ed                           ; rom entry to dispatch a tokenized command
89AA                  ckComma         equ     $89aa                                                   ; check for comma routine
89B4                  synerr          equ   $89b4                             ; rom entry to show syntax error
8B8D                  fcerr           equ   $8b8d                             ; entry to send message error
8E51                  asc2Num         equ     $8e51                                                   ; convert ASCII to number (1 byte)
8E83                  get16bN         equ   $8e83                                                     ; get a 16 bit number into x
90A5                  sendCR          equ     $90a5                                                   ; send a CR to screen
90E5                  outstr          equ   $90e5                                                     ; print string at X+1 to DEVNUM
957A                  outnum          equ   $957a                                     ; print number in d to devnum
9A89                  backspc         equ   $9a89                                                     ; print a backspace to DEVNUM
B3B4                  resetRt         equ     $b3b4                                                   ; reset routine
B44F                  wrmStrt         equ     $b44f                                                   ; warmStart routine
B54A                  outchr          equ   $b54a                                                     ; print char A to DEVNUM
B7AA                  getfnam         equ   $b7aa                                                     ; read file name and length into $1d1
B84B                  ioerror         equ   $b84b                                                     ; IO_error
BCAB                  outRegA         equ     $bcab                                                   ; output reg A to screen as number
C000                  romini          equ   $c000                                                     ; beginning of roms area 
C0F9                  gtbtsig                 equ     $c0f9                                                   ; get Boot signature
C14E                  rdbttrk                 equ     $c14e                                                   ; load disk track
0001                  NOINTMASK       equ 1
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      
                                                                                                                              ; VARIABLES
0003                  ErasCtr         equ   $03                                                       ; sector count in eraser
0010                  noexec          equ   $10                                                       ; inhibit exec after loading
0011                  bootflag        equ   $11                                                       ; zero if run from command line, $55 if autorun on boot
0012                  dnum            equ   $12                                                       ; assigned drive number by dw4 server
0012                  tokens          equ   #18                               ; to be incremented each time words are added  =  NEW COMMANDS
001A                  newtok          equ   $1a                               ; this works with dos cartridge plugged in!
0050                  FPA0                    equ     $50                                                     ; number of bytes to flash
0052                  oldSlot         equ     $52                                                     ; FPA2 (re-used)
0053                  oldBank         equ     $53                                                     ; FPA3 (re-used)
                      
0076                  bufPtr          equ     $76                                                     ; (re-used) pointer to buffer end for new name
0076                  chksum          equ   $76                                                       ; checksum of the sector to be sent to dw4 (2 bytes)
0076                  dsktyp          equ     $76                                                     ; (re-used) only for SDRIVE creating file. 0=DSK, 1=VDK
0076                  dSource         equ     $76                                                     ; 2 bytes (re-used)
0076                  endadr          equ   $76                                                       ; last loaded address - probably no conflict but collides with  chksum  equ   $76       
0076                  hdwFlo          equ     $76                                                     ; slot number where floppies are found (only for tstHDW)
                      
0077                  hdwSdc          equ     $77                                                     ; slot number where SDC is found (only for tstHDW)
0086                  TargBank        equ   $86                                                       ; bank to be flashed
0089                  curlow          equ   $89                                                       ; low byte of cursor position
00B0                  usrptr          equ   $b0                               ; pointer to usr vector base
00E6                  bigfil          equ   $e6                                                       ; too big file flag - probably no conflict but collides with internal use of $e6 in format by dplus
00E7                  retry                   equ     $e7                                                     ; to catch 1st acess to DW4 drives error
00EB                  DCDRV                   equ     $eb                                                     ; bank number
00EE                  DCBPT                   equ     $ee                                                     ; pointer to subroutines
                      
00F8                  cpyPtr          equ     $f8                                                     ; (re-used) pointer to buffer end for SDIR
00F8                  numUni          equ     $f8                                                     ; unit number for new Commands (link, mount, bank)
00F8                  oriNum          equ     $f8                                                     ; number of requested slot-bank (re-used)
                      
00F9                  cpyWhat         equ     $f9                                                     ; command that identifies BANK - SLOT (re-used)
00F9                  numDir          equ     $f9                                                     ; number of received dirs (re-used)
00F9                  sdcSlot         equ     $f9                                                     ; 1 byte (re-used)
00F9                  swMap1          equ     $f9                                                     ; flag to switch to map1 (re-used)
00F9                  trknum          equ     $f9                                                     ; tracknumber in process for DSKINIT 4th patch
                      
00FA                  dDest                   equ     $fa                                                     ; 2 bytes (re-used)
00FA                  geodat          equ     $fa                                                     ; numTracks - numSect x track (2 bytes)
00FA                  itsRead         equ     $fa                                                     ; number of received items in a dir page (re-used)
00FA                  valPar          equ     $fa                                                     ; (re-used) value for parameter to send into B
                      
00FB                  cmdNum          equ     $fb                                                     ; (re-used) command code to be sent
00FB                  itsDone         equ     $fb                                                     ; number of items shown of a page
00FB                  secxtrk         equ     $fb                                                     ; numSect x track (low byte of previous word)
                      
00FC                  drvtab          equ     $fc                                                     ; system table for linked numbers to the 4 units (fc-fd-fe-ff)
0114                  floSDC          equ     $114                                                    ; bit 0 for unit 1, bit 1 for unit 2. If 0 use Floppy, if 1 use SDC
                                                                                                                                      ; bit 2 is 1 if Floppies present else 0
                                                                                                                                      ; bit 3 is 1 if SDC present else 0
                                                                                                                                      ; bit 5-4 show the slot where floppies are connected (0-3)
                                                                                                                                      ; bit 7-6 show the slot where SDC is connected (0-3)
0115                  idxHD                   equ     $115                                                    ; index to a HD array (maximum 90 discs of 720+1 sectors DW4 VDK type) (values 1-90)
0134                  newstb          equ   $134                              ; base of new stub
015E                  hokini          equ   $15e                                                      ; first system hook
01A8                  hokend          equ   $1a8                                                      ; last system hook
01CD                  sstack          equ   $1cd                                                      ; backup of original stack
01CF                  sector          equ   $1cf                                                      ; counter, used when loading file contents, just below namebuf/DECB header
                      
01D1                  nambuf          equ   $1d1                                                      ; fixed by BASIC, read filename function which stores in $1d1
01D1                  namebuf         equ   $1d1                                                      ; fixed by BASIC read filename function
                      
01D1                  decbhdr         equ   namebuf                                           ; DECB headers get copied in here
01D9                  startbuf        equ   namebuf+8                                 ; dw input data buffer, can reuse buffer after DECB header slot
02D9                  endbuf          equ   startbuf+256                              ; end of buffer area
03D9                  fST16                   equ     $3d9                                                    ; first sector of Track 16 (backup DIR)
03EA                  newusr          equ     $3ea                                                    ; will use $3ea - $3fd = 20 bytes (New USR area)
03FF                  cpyMPIcfg       equ     $03ff                                                   ; candidate to be a copy in RAM of $ff7f byte ($3EB - $3FF seem safe places ...)
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      
                                                                                                                              ; RAM area
3000                  ramini          equ   $3000                                                     ; where to copy the rom
6EFF                  rammax          equ   $6eff                                                     ; ram limit to send to highram (16k - 256 bytes) as a rom program to be run
6FFF                  rmaxld          equ   $6fff                                                     ; ram limit to load into low memory (for basic roms)
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      
                                                                                                                              ; SAM area 
FFD8                  R1CLR                   equ     $ffd8                                                   ; to clear fast poke $ffd9
FFDE                  RAMROM          equ     $ffde                                                   ; to go MAP0, resetting $ffdf (MAP1)
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      
                                                                                                                              ; HDW related addresses
FF20                  BBOUT                   equ     $ff20                                                   ; used for DW4
FF20                  PIA1Base        equ   $ff20                                                     ; used by DWRead/DWWrite
FF22                  BBIN                    equ     $ff22                                                   ; used for DW4
FF40                  CMDREG          equ   $ff40                                             ; command register (write)
FF40                  STATREG         equ   $ff40                                             ; status register (read)
FF41                  PREG1           equ   $ff41                                             ; param register 1
FF42                  PREG2           equ   $ff42                                             ; param register 2
FF42                  DATREGA         equ     PREG2                              ; first data register
FF43                  PREG3           equ   $ff43                                                     ; param register 3
FF43                  DATREGB         equ   PREG3                                ; second data register
FF48                  CTRLATCH        equ   $ff48                                             ; controller latch (write)
FF4A                  FLSHREG         equ   $ff4a                                                     ; Flash Register in SDC
FF4B                  BANKREG         equ   $ff4b                                                     ; Bank select in SDC
                      ;                                                                                                       HIGH nibble = ROM        (/CTS)
                      ;                                                                                                       LOW  nibble = HARDWARE   (/SCS)
FF7F                  MPIcfg          equ     $ff7f                                                   ; value used in Tandy MultiPacks to save slots used (/CTS and /SCS)
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      
                                                                                                                              ; CONSTANTS 
                                                                                                                              ; Status Register Masks
0001                  BUSY            equ   %00000001                            ; set while a command is executing
0002                  READY           equ   %00000010                            ; set when ready for a data transfer
0080                  FAILsdc         equ   %10000000                            ; set on command failure
                                                                                                                              ; Mode and Command Values
0000                  destPtr         equ     0                                                               ; ofsset to get to the pointer to destination buffer (2 bytes)
000B                  CMDMODE         equ   $0b                                                       ; was $43 for CoCo - control latch value to enable command mode
0050                  dimask          equ   $50                                                       ; disable IRQ and FIRQ
0050                  IntMasks        equ   $50                                                       ; used by DWRead/DWWrite
0080                  CMDREAD         equ   $80                                  ; read logical sector
00A0                  CMDWRITE        equ   $a0                                  ; write logical sector
00AF                  eimask          equ   $af                                                       ; enable interrupts
00C0                  CMDEX           equ   $c0                                  ; extended command
00D2                  OP_READEX       equ   'R'+$80                                           ; $D2 - Read one sector (DW4 opcode)
00E0                  CMDEXD          equ   $e0                                  ; extended command with data block
00F2                  OP_REREADEX     equ   'r'+$80                                           ; $F2 - Re-read one sector (DW4 opcode)
00F3                  E_CRC           equ   $f3                               ; Same as NitrOS-9 E$CRC
                      ; ===============================================================================================================================
                      
                                                                                                                      ; CODE BEGINNING
                            IF drgbin > 0                                                     ; to create Patcher - Extender binaries
DFF7                           org   $e000-9                                          ; to create the BIN header
DFF7 55                                       fcb     #$55                                                    ; header values for a Dragon binary file. magic 1st byte
DFF8 02                                       fcb     #$02                                                    ; file type
DFF9 6000                                     fdb     #$6000                                          ; load
DFFB 1C3A                                     fdb     #absEnd-$e000                           ; length
DFFD 6002                                     fdb     #$6002                                          ; exec
DFFF AA                                       fcb     #$aa                                                    ; magic end byte
                                      ELSE
                                              org     $e000                                                   ; real program beginning
                               put   $e000                                                    ; allocated at $e000
                            ENDIF
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      
                                                                                                                      ; PROGRAM INIT
E000 4549             mark            fcb     $45,$49                                         ; "EI" mark to signal to the DOS that this extension wants to be called to initialize itself
E002 7EE5A3                                   jmp     initext                                         ; initialize extension
E005 161BD2                                   lbra    reptch                                          ; direct jump to DOSPlus patcher
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Entry point for DOS command dispatcher. 1st patch
                      ; Data received:
                      ;       A = track number
                      ;       B = command code  (2=READ - 3=Unknown - 4=WRITE - 7=VERIFY(dummy read)
                      ;       X = address of system variable "number of sectors x track" for this drive 
                      ;       Y = LSN
                      ;       U = sector counter (if not directory track) 
                      ; -------------------------------------------------------------------------------------------------------------------------------
E008 3402             entry    pshs  a                                                                ; save register 'A' (code overwritten. It's the first instruction in the DOS)
E00A 3401                                     pshs  cc                                                                ; save flags
E00C 8D0F                                     bsr     phyvir                                          ; detect physical or virtual drive
E00E 241E                                     bcc     dw4                                                     ; if greater than 4 is a DriveWire slot number
E010 4D                                       tsta                                                                    ; is linked value equal 0? - demanat per KenH
E011 271B                                     beq     dw4                                                     ; yes, so DriveWire slot 0
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; The DOS part respects the original code
                      ; -------------------------------------------------------------------------------------------------------------------------------
E013 3501             todos           puls    cc                                                              ; restore flags 
E015 170CB5                                   lbsr    flOrSd                                          ; control access to floppy or SDC
E018 8602                                     lda   #$02                                      ; get value #2 (number of retries). It's the second instruction in the DPlus49b
E01A 7EC10A                                   jmp     $c10a                                                   ; back to next sentence of DOS original code
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Detects if drive is physical or virtual (code in A)
                      ; returns Carry set if DW4 slot number detected (now any value greater than 4)
                      ; must use extended addressing because for DSKINIT, DP arrives here with $FF and if not virtual should return like that
                      ; -------------------------------------------------------------------------------------------------------------------------------
E01D 3410             phyvir  pshs    x                                                               ; save working register
E01F 8E00FB                                   ldx     #drvtab-1                                       ; point to 1 byte before the slots table
E022 B600EB                                   lda     >$00eb                                          ; get drive number
E025 A686                                     lda     a,x                                                     ; get slot number for that drive
E027 B70012                                   sta     >dnum                                                   ; put it into DW4 variable
E02A 8105                                     cmpa    #5                                                              ; is a DW4 number? - if not, Carry will be set
E02C 3590                                     puls    x,pc                                                    ; restore register and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; The dw4 part distinguishes between READ, VERIFY and WRITE opcodes
                      ; -------------------------------------------------------------------------------------------------------------------------------
E02E 3501             dw4     puls    cc                                                              ; get saved flags
                                                                                                                      ; to avoid problems created by SOUND and PLAY over DW4
E030 3402                                     pshs    a                                                               ; save register
E032 8602                                     lda     #2                                                              ; get value to mark output
E034 B7FF20                                   sta     BBOUT                                                   ; to DW4
E037 4F                                       clra                                                                    ; set counter
E038 4A               dw4L01  deca                                                                    ; decrement counter
E039 26FD                                     bne     dw4L01                                          ; not zero, loopback
E03B 3502                                     puls    a                                                               ; restore register
E03D 3474                                     pshs  b,x,y,u                                           ; save rest of registers (A was already onto stack) before recalculatimg Y
E03F 1A50                                     orcc  #dimask                                           ; disable interrupts to work with dw4                                                   
E041 8D4A                                     bsr     calcy                                                   ; do not relay on Y. Recalculate it from $eb-ec-ed
E043 8D68                                     bsr     ctrlHD                                          ; control index in HD if needed
E045 3021                                     leax  1,y                               ; X points now to the rigth dw4 sector (skipping the header) - [DW needs registers X-Y inverted!)
E047 109EEE                                   ldy   <$ee                                              ; Y points to RAM buffer address
E04A C102                     cmpb  #2                                                                ; is this a read command?
E04C 270F                                     beq   reddw4                                            ; yes, read sector from dw4
E04E C107                     cmpb  #7                                                                ; is this a verify command?
E050 2606                                     bne   wrtdw4                                            ; no, write sector to dw4
E052 108EFCFF                                 ldy     #$fcff                                          ; initial byte of 256 area to be overwritten while verifying
E056 2005                                     bra     reddw4                                          ; go read that sector
E058 BDE2C7           wrtdw4  jsr   dowrit                                            ; write a sector from buffer to dw4
E05B 2010                                     bra   verify                                            ; verify operation result
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; This part asks dw4 a sector to be read and dw4 log reflects it accordingly. It is as simple as possible.
                      ; -------------------------------------------------------------------------------------------------------------------------------
E05D BDFAD3           reddw4  jsr   DoRead                                            ; call dw4 to read one sector
E060 250B                                     bcs     verify                                          ; if operation error, give message
E062 2609                                     bne     verify                                          ; if incompleted, give message
E064 E6E4                                     ldb     ,s                                                              ; get pushed B (opcode / command)
E066 C102                                     cmpb    #2                                                              ; is it read?
E068 261F                                     bne     jstvfy                                          ; no, adapt flags and exit
E06A BDE20D                                   jsr     correct                                         ; correct LSN if needed
E06D 3574             verify  puls  b,x,y,u                                      ; restore received registers
E06F 3502                                     puls  a                                                         ; and first one pushed
E071 2506                                     bcs   failed                                            ; detect operation error
E073 2604                     bne   failed                                            ; detect incomplete read operation
E075 5F                                       clrb                                                                    ; operation succesful - no error code returned in B
E076 1CAF             outgo           andcc #eimask                                           ; enable interrupts
E078 39                                       rts                                                                     ; return to caller
E079 0DE7             failed   tst    <retry                                          ; is flag retry ON ($01)?
E07B 2706                                     beq     fail01                                          ; no, exit
E07D 2B04                                     bmi     fail01                                          ; if negative exit too
E07F 00E7                                     neg     <retry                                          ; to get value $FF
E081 2085                                     bra     entry                                                   ; try it again
E083 C6A6             fail01  ldb   #$a6                                                      ; set error code (unknown = ??)
E085 1A01                                     orcc    #%00000001                                      ; set Carry flag (error)
E087 20ED                                     bra   outgo                                                     ; return
E089 1A04             jstvfy  orcc    #%00000100                                      ; set flag Z=1          
E08B 20E0                                     bra     verify                                          ; exit via verify
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; This is used to calculate the LSN number from system variables $ec (track) and $ed (sector)
                      ; Controls the number of sides of the disks to change 18 s/t to 36
                      ; returns the calculated LSN in register Y
                      ; -------------------------------------------------------------------------------------------------------------------------------
E08D 3416             calcy           pshs    d,x                                                     ; save working registers
E08F 8E06A6                                   ldx     #$6a6                                                   ; point to byte before sectors x track table
E092 D6EB                                     ldb     <$eb                                                    ; get drive number
E094 A685                                     lda     b,x                                                     ; get number of sectors x track for this drive
E096 D6EC             calcy01 ldb     <$ec                                                    ; get track number
E098 3D                                       mul                                                                     ; calculate sectors amount
E099 1F01                                     tfr     d,x                                                     ; X gets this value
E09B 96ED                                     lda     <$ed                                                    ; get sector number
E09D 4A                                       deca                                                                    ; decrement
E09E 3186                                     leay    a,x                                                     ; add to X and pass result to Y
E0A0 3596                                     puls    d,x,pc                                          ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Aternative entry for DSKINIT that comes without data in $6a7-8-9-a. So this one relies on system variable $f4 (as numSides)
                      ; -------------------------------------------------------------------------------------------------------------------------------
E0A2 3416             caldi           pshs    d,x                                                     ; save working registers
E0A4 8612                                     lda     #$12                                                    ; sectors x track (single side)
E0A6 0DF4                                     tst     <$f4                                                    ; is disk single sided?
E0A8 2701                                     beq     ecaldi                                          ; yes, skip next
E0AA 48                                       asla                                                                    ; double number of sectors x track
E0AB 20E9             ecaldi  bra     calcy01                                         ; jump to calculation routine
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; to apply index to a DW4 HD on drive 4 if it is the case
                      ; -------------------------------------------------------------------------------------------------------------------------------
E0AD 3406             ctrlHD  pshs    a,b                                                     ; save register
E0AF D6EB                                     ldb     <$eb                                                    ; get drive number
E0B1 C104                                     cmpb    #4                                                              ; is it 4?
E0B3 2613                                     bne     eCtrl                                                   ; no, exit
E0B5 F60115                                   ldb     idxHD                                                   ; get index of disc to be accesed
E0B8 C101                                     cmpb    #1                                                              ; is index 0 or 1?
E0BA 230C                                     bls     eCtrl                                                   ; yes, no offset
E0BC 5A                                       decb                                                                    ; else deduct one
E0BD 31A5                                     leay    b,y                                                     ; Y = LSN + index
E0BF 86F0                                     lda     #240                                                    ; maximum acceptable value that can be used to multiply the index
E0C1 3D                                       mul                                                                     ; D = 240 * Index  (if index=90, result 21360 -> $5370) always will be positive
E0C2 31AB                                     leay    d,y                                                     ; Y = LSN + 241*index
E0C4 31AB                                     leay    d,y                                                     ; Y = LSN + 481*index
E0C6 31AB                                     leay    d,y                                                     ; Y = LSN + 721*index  now we have calculated the real LSN to be used, no loops!
E0C8 3586             eCtrl           puls    a,b,pc                                          ; restore register and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Process that substitutes the calls to "WriteTrack". It is used ONLY by DSKINIT
                      ; Writes the 18 sectors of one side in a loop
                      ; If sector number received is 0, will write to side 1, else ($ff) will do side 2 
                      ; -------------------------------------------------------------------------------------------------------------------------------
E0CA 3401             inidsk  pshs    cc                                                              ; save flags
E0CC BDE01D                                   jsr     phyvir                                          ; is drive physical or virtual?
E0CF 240B                                     bcc     virtual                                         ; virtual, process it
E0D1 4D                                       tsta                                                                    ; is linked value 0?
E0D2 2708                                     beq     virtual                                         ; yes, so DW4 slot 0
E0D4 3501                                     puls    cc                                                              ; get saved flags
E0D6 CC47F4                                   ldd   #$47f4                                            ; physical, do nothing. This was overwritten by the patch
E0D9 7EC328                                   jmp     $c328                                                   ; back to DOS
                                                                                                                      ; to avoid problems created by SOUND and PLAY over DW4
E0DC 0DEC             virtual tst     <$ec                                                    ; is track 0?
E0DE 260D                                     bne     iniD01                                          ; no, skip section
E0E0 3402                                     pshs    a                                                               ; save register
E0E2 8602                                     lda     #2                                                              ; get value to mark output
E0E4 B7FF20                                   sta     BBOUT                                                   ; to DW4
E0E7 4F                                       clra                                                                    ; set counter
E0E8 4A               iniL01  deca                                                                    ; decrement counter
E0E9 26FD                                     bne     iniL01                                          ; not zero, loopback
E0EB 3502                                     puls    a                                                               ; restore register
E0ED 3501             iniD01  puls    cc                                                              ; get saved flags
E0EF 1A50                                     orcc  #dimask                                           ; disable interrupts to work with dw4   
E0F1 4F                                       clra                                                                    ; value 0
E0F2 1F8B                                     tfr     a,dp                                                    ; set direct page to 0
E0F4                                          setdp   0                                                               ; notify compiler
E0F4 3476                                     pshs    d,x,y,u                                         ; save registers
E0F6 8D42                                     bsr     filbuf                                          ; fill buffer
E0F8 D6EC                                     ldb     <$ec                                                    ; get track number
E0FA C114                                     cmpb    #$14                                                    ; is this the directory (T20 track)?
E0FC 2607                                     bne     wrt00                                                   ; no, init the track
E0FE 0DF3                                     tst     <$f3                                                    ; yes, is it side 2? (0 means side 1)
E100 2603                                     bne     wrt00                                                   ; init side 2!
                                                                                                                      ; yes, don't waste time, it will be filled later
E102 4F                                       clra                                                                    ; mark no error
E103 2025                                     bra     eIni01                                          ; exit
E105 4C               wrt00           inca                                                                    ; 1st track of side 1
E106 0DF3                                     tst     <$f3                                                    ; is it side 1?
E108 2702                                     beq     wrt01                                                   ; yes, skip next one
E10A 8613                                     lda     #19                                                     ; get 1st track of side 2
E10C 97ED             wrt01           sta     <$ed                                                    ; update system variable
E10E 8D92                                     bsr     caldi                                                   ; calculate first LSN to write to (into Y)
E110 8D9B                                     bsr     ctrlHD                                          ; control index of HD if needed
E112 3021                                     leax  1,y                               ; X points to the rigth dw4 sector (skipping the header) - [DW needs them inverted!)
E114 109EEE                                   ldy   <$ee                                              ; Y points to RAM buffer address
E117 C612                                     ldb     #18                                                     ; number of sectors to be initialized
E119 E7E2                                     stb     ,-s                                                     ; put counter in stack
E11B BDE2C7           wrtmor  jsr     dowrit                                          ; write sector to DW4 
E11E 2510                                     bcs   failed2                                           ; detect operation error
E120 260E                     bne   failed2                                           ; detect incomplete read operation
E122 3001                                     leax    1,x                                                     ; point to next LSN
E124 6AE4                                     dec     ,s                                                              ; dec counter
E126 26F3                                     bne     wrtmor                                          ; if not yet 0, do next one
E128 3261                                     leas    1,s                                                     ; get rid of counter
E12A 3576             eIni01  puls    d,x,y,u                                    ; restore registers (0 will be pulled for A)
E12C 4D               eIniDsk tsta                                                                    ; update flags 
E12D 1CAF                                     andcc #eimask                                           ; enable interrupts
E12F 39                                       rts                                                                     ; return
E130 3261             failed2 leas    1,s                                                     ; get rid of counter
E132 3576                                     puls    d,x,y,u                                    ; restore registers
E134 86FF                                     lda     #$ff                                                    ; mark error for Dskinit function
E136 1A01                                orcc #$01                                                    ; set Carry flag (error)
E138 20F2                                     bra   eIniDsk                                           ; return to caller
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Fill the buffer pointed by $ee all with value $e5
                      ; -------------------------------------------------------------------------------------------------------------------------------
E13A 3454             filbuf  pshs    b,x,u                                                   ; save registers
E13C 9EEE                                     ldx     <$ee                                                    ; get buffer address
E13E CEE5E5                                   ldu     #$e5e5                                          ; value to put
E141 8D32                                     bsr     cpu2xb                                          ; put 128 times U at X
E143 35D4                                     puls    b,x,u,pc                                                ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Fill the directory track T20 for DW4 and floppy as well
                      ; Only used by DSKINIT, but to be sure, it controls a return address in the stack to work else returns
                      ; -------------------------------------------------------------------------------------------------------------------------------
E145 3446             fildir  pshs    d,u                                                     ; save working registers
E147 CCC9EF                                   ldd     #$c9ef                                          ; return address when called to write directory tracks by DSKINIT
E14A 10A364                                   cmpd    4,s                                                     ; is it the write track call?
E14D 2607                                     bne     efildir                                         ; not the write track command, skip fill subroutines
E14F 8D0D                                     bsr     fil16s                                          ; fill buffer for the 16 Dir sectors
E151 8D2A                                     bsr     ffat1                                                   ; fill buffer for FAT 1st sector
E153 BDE1D2                                   jsr     ffat2                                                   ; fill buffer for FAT 2nd sector
E156 3546             efildir puls    d,u                                                     ; restore registers
E158 8E0800                                   ldx     #$800                                                   ; overwritten line by interceptor
E15B 7EC9F6                                   jmp     $c9f6                                                   ; back to DOS
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Fill the buffer for the 16 directory sectors with 10 unused entries
                      ; -------------------------------------------------------------------------------------------------------------------------------
E15E 8E0A00           fil16s  ldx     #$a00                                                   ; point to third buffer
E161 DE8A                                     ldu     <$8a                                                    ; get 16 bits zero
E163 8D10                                     bsr     cpu2xb                                          ; put 128 times U at X
E165 8689                                     lda     #$89                                                    ; code to mark not used entry
E167 8E0A00                                   ldx     #$a00                                                   ; point to the beginning again
E16A A784             fild02  sta     ,x                                                              ; mark an entry
E16C 308819                                   leax    25,x                                                    ; point to next one
E16F 8C0AE8                                   cmpx    #$ae8                                                   ; done 10 entries?
E172 25F6                                     blo     fild02                                          ; no, loop back
E174 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Put value in U in bytes pointed by X, B times (each time a word)
                      ; -------------------------------------------------------------------------------------------------------------------------------
E175 C680             cpu2xb  ldb     #128                                                    ; number of words to write
E177 EF81             cp01            stu     ,x++                                                    ; write one
E179 5A                                       decb                                                                    ; decrement counter
E17A 26FB                                     bne     cp01                                                    ; if not 0, loopback
E17C 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Fill the first FAT sector. Must mark as used only the 18 sectors of Tracks 20 and 16 if applies
                      ; -------------------------------------------------------------------------------------------------------------------------------
E17D 8E0800           ffat1           ldx     #$800                                                   ; point to first buffer
E180 96F2                                     lda     <$f2                                                    ; get number of tracks  
E182 C612                                     ldb     #$12                                                    ; sectors x track (single side)
E184 0DF4                                     tst     <$f4                                                    ; is disk single sided?
E186 2701                                     beq     ffat100                                         ; yes, skip next
E188 58                                       aslb                                                                    ; double number of sectors x track
E189 DDFA             ffat100 std     <geodat                                         ; save geometry data for later use
E18B C65A                                     ldb     #90                                                     ; there are 180 FAT bytes, so 90 words, but 180k discs need only HALF that!
E18D DEFA                                     ldu     <geodat                                         ; get geometry data
E18F 11832812                                 cmpu    #$2812                                          ; is it a Single Sided Single Density disk (180k)?
E193 2601                                     bne     ffat101                                         ; no, skip next
E195 56                                       rorb                                                                    ; yes, divide by 2 to get 45 words
E196 CEFFFF           ffat101 ldu     #$ffff                                          ; code to mark 16 free sectors
E199 8DDC                                     bsr     cp01                                                    ; copy B times U at X
E19B 3341                                     leau    1,u                                                     ; create 0 value
E19D EF81             ffat102 stu     ,x++                                                    ; clear a word
E19F 8C08FC                                   cmpx    #$900-4                                         ; reached end of buffer minus 4 bytes to put geometry data there?
E1A2 25F9                                     blo     ffat102                                         ; no, loopback
E1A4 DCFA                                     ldd     <geodat                                         ; get geometry data
E1A6 ED81             ffat103 std     ,x++                                                    ; save it in 1st FAT sector
E1A8 43                                       coma                                                                    ; complement
E1A9 53                                       comb                                                                    ; both bytes
E1AA ED84                                     std     ,x                                                              ; store again in FAT
E1AC C624                                     ldb     #36                                                     ; This the FAT byte where dir T16 begins for single sided discs
E1AE 96FB                                     lda     <secxtrk                                                ; get sectors x track
E1B0 8112                                     cmpa    #$12                                                    ; is it single?
E1B2 2701                                     beq     ffat104                                         ; yes, skip next
E1B4 58                                       aslb                                                                    ; double to 72 (the same place for Double Side disks)
E1B5 3404             ffat104 pshs    b                                                               ; save value for later use
E1B7 86F0                                     lda     #$f0                                                    ; flag value for parameter '/' (leave T16 free for data storage)
E1B9 91E6                                     cmpa    <$e6                                                    ; has $e6 this value?
E1BB 2702                                     beq     ffat105                                         ; yes, don't mark sector T16 as used                                                            
E1BD 8D05                                     bsr     markfat                                         ; mark used sectors of T16
E1BF D6FB             ffat105 ldb     <secxtrk                                                ; get sectors x track
                                                                                                                      ; distance between T16 and T20 is 4 * tracks * N_Sxt / 8 bits = NSxt / 2
E1C1 56                                       rorb                                                                    ; convert distance to FAT bytes to add to
E1C2 EBE0                                     addb    ,s+                                                     ; the previously pushed FAT byte for T16, clear stack
E1C4 8E0800           markfat ldx     #$800                                                   ; point to the begining of the FAT
E1C7 3085                                     leax    b,x                                                     ; add offset to 1st DIR sector byte of that track
E1C9 4F                                       clra                                                                    ; 16 bit zero
E1CA 5F                                       clrb                                                                    ; to mark 16
E1CB ED81                                     std     ,x++                                                    ; used sectors by DIR track
E1CD 86FC                                     lda     #%11111100                                      ; and two zero bits more
E1CF A784                                     sta     ,x                                                              ; to complete the 18 reserved sectors for any directory Track
E1D1 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Fill the second FAT sector. This is only used for 720k discs
                      ; -------------------------------------------------------------------------------------------------------------------------------
E1D2 8E0900           ffat2           ldx     #$900                                                   ; point to second buffer
E1D5 DCFA                                     ldd     <geodat                                         ; get geometry data
E1D7 10835024                                 cmpd    #$5024                                          ; is it a 720K disc?
E1DB 2607                                     bne     ffat201                                         ; no, do not put $FFs
E1DD CEFFFF                                   ldu     #$ffff                                          ; to mark free sectors
E1E0 C65A                                     ldb     #90                                                     ; must mark 180 bytes
E1E2 8D93                                     bsr     cp01                                                    ; copy B times U at X
E1E4 DE8A             ffat201 ldu     <$8a                                                    ; get 16 bits zero
E1E6 EF81             ffat202 stu     ,x++                                                    ; put 2 zero bytes
E1E8 8C0A00                                   cmpx    #$a00                                                   ; reached end of buffer?
E1EB 25F9                                     blo     ffat202                                         ; no, loopback
E1ED 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Keep the good track number to avoid strange sequences. Called by DSKINIT and
                      ; called from other points, one of them the COPY routine and from SAVE as well ...
                      ; Has a control to detect that it is called from DSKINIT, else do nothing at all!
                      ; when applied to DW4 the track number suffers non lineal sequences. Here we correct that
                      ; -------------------------------------------------------------------------------------------------------------------------------
E1EE 3406             modtrk  pshs    d                                                               ; save register
E1F0 CCC9E1                                   ldd     #$c9e1                                          ; the return address that identifies DSKINIT
E1F3 10A367                                   cmpd    7,s                                                     ; is the one corresponding to DSKINIT?
E1F6 2610                                     bne     notdsk                                          ; no, do nothing
E1F8 96EC                                     lda     <$ec                                                    ; get track number
E1FA 97F9                                     sta     <trknum                                         ; save in variable
E1FC BDD36B                                   jsr     $d36b                                           ; (buf_read_sector) - this line was overwritten by patch
E1FF 96F9                                     lda     <trknum                                         ; get saved track number
E201 97EC                                     sta     <$ec                                                    ; back to its place
E203 3506             emodtrk puls    d                                                               ; restore register
E205 7ED1A7                                   jmp     $d1a7                                                   ; back to DOS
E208 BDD36B           notdsk  jsr     $d36b                                                   ; (buf_read_sector) - this line was overwritten by patch
E20B 20F6                                     bra     emodtrk                                         ; clean stack and back to DOS
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Part to detect a bigger than 180k disc and update tables accordingly. The same if disc was changed
                      ; If read sector has no geometry data, we go to the other possible localization for directory ($168 - $2D0) (+1 for DW4)
                      ; X is updated to the new LSN to be read, if necessary
                      ; must be avoided ONLY when working with an HD at unit 4 (idxHD $115 >1)
                      ; -------------------------------------------------------------------------------------------------------------------------------
E20D 3466             correct pshs    d,y,u                                                   ; save registers
E20F 96EB                                     lda     <$eb                                                    ; get unit number
E211 8104                                     cmpa    #4                                                              ; is it #4?
E213 2605                                     bne     cor00                                                   ; no, skip control
E215 7D0115                                   tst     idxHD                                                   ; working on a HD in a disk with index > 0?
E218 2639                                     bne     ecorok                                          ; yes, exit
E21A DCEC             cor00           ldd     <$ec                                                    ; get track-sector numbers
E21C 10831401                                 cmpd    #$1401                                          ; is it 1st FAT sector?
E220 2631                                     bne     ecorok                                          ; no, exit
E222 CCC869                                   ldd     #$c869                                          ; get return address from BACKUP command
E225 10A3E814                                 cmpd    20,s                                                    ; is this the case?
E229 2728                                     beq     ecorok                                          ; yes, exit
E22B DEEE                                     ldu     <$ee                                                    ; get read buffer address
E22D ECC900FE                                 ldd     $fe,u                                                   ; get complemented geodata bytes
E231 43                                       coma                                                                    ; complement both bytes
E232 53                                       comb                                                                    ; A=tracks; B=sectors x track ... possible values: 2812 - 2824 - 5012 - 5024
                                                                                                                              ; their 1st FAT sector will equal that one:        0169 - 02d1 - 0169 - 02d1 (+1 due to DW4) 
E233 10A3C900FC                               cmpd    $fc,u                                                   ; do they equal the not complemented ones?
E238 2717                                     beq     ecorok1                                         ; yes, we have a right FAT sector, update system tables and exit
                                                                                                                              ; Bad 1st FAT sector read, we must change single <--> double as required
E23A 8C0169                                   cmpx    #$0169                                          ; was sector read $0169 (single sided)
E23D 2605                                     bne     cor01                                                   ; no, change to single sided
E23F 8E02D1                                   ldx     #$02d1                                          ; yes, change to double sided
E242 2003                                     bra     cor02                                                   ; go save new 1st FAT LSN
E244 8E0169           cor01           ldx     #$0169                                          ; get single sided value
E247 8D10             cor02           bsr     updtab                                          ; update system tables (in some cases they are not yet filled)
E249 109EEE                                   ldy     <$ee                                                    ; get buffer address
E24C BDFAD3                                   jsr     DoRead                                          ; read newly calculated T20 1st FAT LSN
E24F 2006                                     bra     ecor                                                    ; exit
E251 8D06             ecorok1 bsr     updtab                                          ; update system tables
E253 1A04             ecorok  orcc    #%00000100                                      ; set flag Z=1, result OK
E255 1CFE                     andcc   #%11111110                                      ; clear Carry flag, no errors
E257 35E6             ecor            puls    d,y,u,pc                                                ; restore registers and return                  
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Updates system tables using param X as LSN for 1st DIR track (should get here with DW4 value)
                      ; Affects system tables at $61c (dir LSN) and $6a7 (sectors x track)
                      ; -------------------------------------------------------------------------------------------------------------------------------
E259 CE0616           updtab  ldu     #$616                                                   ; point 6 bytes before drives info table                        
E25C D6EB                                     ldb     <$eb                                                    ; get drive number
E25E 8606                                     lda     #6                                                              ; register length
E260 3D                                       mul                                                                     ; calculate offset
E261 311F                                     leay    -1,x                                                    ; system works with $0168 or $02d0 (DW4 adds one because of the header)
E263 10AFCB                                   sty     d,u                                                     ; put LSN at requested drive table
E266 8612                                     lda     #$12                                                    ; default value for single sided
E268 8C0169                                   cmpx    #$0169                                          ; is new value single sided?
E26B 2701                                     beq     cor03                                                   ; yes, skip next
E26D 48                                       asla                                                                    ; double value
E26E CE06A6           cor03           ldu     #$6a6                                                   ; point 1 byte before sectors x track table
E271 D6EB                                     ldb     <$eb                                                    ; get drive number
E273 A7C5                                     sta     b,u                                                     ; update value in table for that drive
E275 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Updates table $6a6 if drive is virtual. Uses data from stack (only BACKUP)
                      ; -------------------------------------------------------------------------------------------------------------------------------
E276 3416             patbck  pshs    d,x                                                     ; save registers
E278 8E00FB                                   ldx     #drvtab-1                                       ; point to 1 byte before the slots table
E27B A6C4                                     lda     ,u                                                              ; get source drive from stack hole
E27D 8D0C                                     bsr     updsxt                                          ; update sectors x track
E27F A649                                     lda     9,u                                                     ; get destination drive from stack hole
E281 8D08                                     bsr     updsxt                                          ; update sectors x track
E283 3516                                     puls    d,x                                                     ; restore registers
E285 A648                                     lda     8,u                                                     ; these 2 sentences were
E287 3D                                       mul                                                                     ; overwritten by patcher
E288 7EC839                                   jmp     $c839                                                   ; back to DOS
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Updates sectors x track of that drive (comes in A)
                      ; -------------------------------------------------------------------------------------------------------------------------------
E28B E686             updsxt  ldb     a,x                                                     ; get associated slot number in drives table
E28D 2704                                     beq     upds01                                          ; if cero is a special DW4 case, process it
E28F C104                                     cmpb    #4                                                              ; is it lower than 5?
E291 230B                                     bls     eupd                                                    ; yes, is a physicall drive, do not process it
E293 3410             upds01  pshs    x                                                               ; save register
E295 8E06A6                                   ldx     #$6a6                                                   ; point 1 byte before sectors x track table
E298 E648                                     ldb     8,u                                                     ; get number of sectors x track in stack hole
E29A E786                                     stb     a,x                                                     ; into table for that drive
E29C 3510                                     puls    x                                                               ; restore register
E29E 39               eupd            rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; This part avoids calling a hardware routine when the drive is virtual
                      ; and when floppies allow it, in order to avoid that the FDC floppy light stays on forever
                      ; -------------------------------------------------------------------------------------------------------------------------------
E29F 3403             noHdw           pshs    a,cc                                                    ; save A and flags
E2A1 BDE01D                                   jsr     phyvir                                          ; detect drive type
E2A4 240F                                     bcc     retHdw                                          ; if virtual, return
E2A6 4D                                       tsta                                                                    ; is linked value 0?
E2A7 270C                                     beq     retHdw                                          ; yes, so DW4 slot 0
E2A9 3503                                     puls    a,cc                                                    ; restore A and flags
                                                                                                                      ; so it goes for floppies or SDC
E2AB 170A1F                                   lbsr    flOrSd                                          ; will take care of destination hdw                     
E2AE 1A50                                     orcc  #dimask                                           ; first overwritten instruction
E2B0 66E4                                     ror     ,s                                                         ; second overwritten instruction
E2B2 7EC174                                   jmp     $c174                                                   ; back to DOS
E2B5 0DE7             retHdw  tst     <retry                                          ; is flag off (0)?
E2B7 2602                                     bne     ret01                                                   ; no, skip next
E2B9 0CE7                                     inc     <retry                                          ; turn flag ON ($01)
E2BB 3262             ret01           leas    2,s                                                     ; get rid of 2 pushed regs
E2BD 66E4                                     ror     ,s                                                              ; get rid of pushed carry value
E2BF 35FB                                     puls    a,cc,dp,x,y,u,pc                        ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; This intercepts the std DOS reset routine
                      ; -------------------------------------------------------------------------------------------------------------------------------
E2C1 17031C           dosReset lbsr   initask                                         ; put initial values
E2C4 7EB44F                                   jmp     wrmStrt                                         ; call basic warmstart
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; This part sends sectors to dw4 to be written. It is a block very similar to DoRead() but must work a bit different:
                      ; Must send three blocks of data: The dw4 command, the data and the checksum, all of them in just one chunk
                      ; -------------------------------------------------------------------------------------------------------------------------------
E2C7 9612             dowrit  lda   <dnum                                                     ; get drive number (real dw4 number)
E2C9 5F                       clrb                                                     ; LSN bits 23-16
E2CA 3436                     pshs  a,b,x,y                            ; save registers / data                                        STACK: RETADRS, YL, YH, SectorL, SectorH, $0, dnum
E2CC 8E0000                   ldx     #0                                                              ; zero to calculate Checksum for that sector
E2CF 4F                       clra                                                                    ; byte counter (256)
E2D0 E6A0             calc    ldb     ,Y+                                                     ; read a byte
E2D2 3A                       abx                                                                     ; add to checksum
E2D3 4A                       deca                                                                    ; decrement counter
E2D4 26FA                     bne   calc                                                      ; if not all 256, keep on
E2D6 9F76                     stx   <chksum                                           ; save checksum
E2D8 8657                                     lda   #$57                      ; dw4 OP_WRITE (write one sector)
E2DA 3402             rewrit  pshs  a                                          ; save command onto stack                              STACK: RETADRS, YL, YH, SectorL, SectorH, $0, dnum, OP_WRITE
E2DC 30E4                     leax  ,s                                                ; point X to top of stack
E2DE 108E0005                 ldy   #5                                ; 5 bytes
E2E2 BDFBA8                   jsr   DWWrite                           ; send 5 bytes to dw4:  OP_WRITE, dnum, $0, Sector(H-L)
E2E5 3502                     puls  a                                          ; discard command                                                      STACK: RETADRS, YL, YH, SectorL, SectorH, $0, dnum
E2E7 AE64                     ldx   4,s                                        ; get sector buffer pointer = received Y
E2E9 108E0100                 ldy   #$0100                             ; to write 256 bytes
E2ED BDFBA8                   jsr   DWWrite                           ; send sector (256 bytes)
E2F0 109E76                                   ldy   <chksum                                           ; get calculated checksum
E2F3 3420                     pshs  y                                          ; save it onto stack                                   STACK: RETADRS, YL, YH, SectorL, SectorH, $0, dnum, ChksumL, ChksumH
E2F5 30E4                     leax  ,s                                                ; point X to top of stack
E2F7 108E0002                 ldy   #2                                                ; 2 bytes
E2FB BDFBA8                   jsr   DWWrite                           ; send checksum to dw4
                                                                                                                      ; get answer from dw4 for the whole pack
E2FE 3121                                     leay  1,y                                        ; after a DWRITE Y returns zeroed, so this way it becomes equal to one
E300 BDFB21                   jsr   DWRead                            ; read dw4 answer       - this overwrites dnum byte
E303 3262                     leas  2,s                                        ; discard checksum                                             STACK: RETADRS, YL, YH, SectorL, SectorH, $0, Returnedvalue
E305 2513                     bcs   writex                             ; detected framing error
E307 2611                     bne   writex                             ; detected not all bytes received
E309 A6E4                     lda   ,s                                                ; get server answer (in old dnum position)
E30B 270D                     beq   writex                             ; zero=OK, go out
E30D 81F3                     cmpa  #$F3                                       ; error type = #E_CRC?
E30F 2608                     bne   writer                             ; not this one, go out signaling error
E311 9612                                     lda   <dnum                           ; get drive number
E313 A7E4                     sta   ,s                                                ; put again in stack                                            STACK: RETADRS, YL, YH, SectorL, SectorH, $0, dnum
E315 8677                     lda   #$77                                                      ; dw4 code for OP_REWRITE
E317 20C1                     bra   rewrit                             ; go to rewrite same sector again
E319 53               writer  comb                                                     ; sets the carry flag (ERROR)
E31A 35B6             writex  puls  a,b,x,y,pc                ; restore received registers and return      STACK: - - -
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E31C 0D44573426534443 psmsg           fcc     13,"DW4&SDC EXTENDER (V0.25.16)",13
     20455854454E4445
     52202856302E3235
     2E3136290D
E339 4259205045524520                         fcc        "BY PERE SERRAT (2021)",13
     5345525241542028
     32303231290D
E34F 46554A494E455420                         fcn    "FUJINET MODS (2026)",13,13
     4D4F445320283230
     3236290D0D00
                                              
                      
                      ; --------------------------------------------------------------------------------------------------------------------------------                      
E365 204C4F4144494E47 ldtextr         fcn   / LOADING ROM/,13                                         ; initial message to the user
     20524F4D0D00
E373 0D524F4D204C454E endtxt  fcn   $0d, /ROM LENGTH: /                                       ; message to show rom length
     4754483A2000
E381 0D524F4D20544F4F bigrom  fcn   $0d, /ROM TOO BIG/                                        ; message for roms greater than 16k-256bytes
     2042494700
E38E 4E4F542041204457 notdw4  fcn     /NOT A DW4 SLOT/,13                                     ; message for lrom without params and with default drive <> dw4
     3420534C4F540D00
E39E 544F4B454E20544F low     fcn   /TOKEN TOO LOW/,13                                        ; message for not recognized token
     4F204C4F570D00
E3AD 544F4B454E20544F high    fcn   /TOKEN TOO HIGH/,13                                       ; message for not recognized token
     4F20484947480D00
E3BD 4452495645204D55 drverr  fcn     /DRIVE MUST EQUAL UNIT/,13                      ; message for drive <> unit for physical drives
     535420455155414C
     20554E49540D00
E3D4 4953204C494E4B45 alrput  fcn     /IS LINKED TO ANOTHER UNIT/,13  ; message for trying to use an already linked disc
     4420544F20414E4F
     5448455220554E49
     540D00
E3EF 554E4954204C494E headlnk fcn     /UNIT LINK/,13                                                  ; header for LLINK
     4B0D00
E3FA 2020202000       spaces  fcn     /    /                                                                  ; text for detail line in LLINK
E3FF 4C4F4144494E4720 ldtext   fcn   /LOADING BOOT TRACK/                                     ; message for OS9boot
     424F4F5420545241
     434B00
E412 0D4E4F5420414E20 noostxt  fcn   $0d, /NOT AN OS BOOT TRACK/              ; errro message for os9boot
     4F5320424F4F5420
     545241434B00
E428 202300           xidxTxt fcn     / #/                                                                            ; text that precedes HD index number                    
E42B 535452494E472054 Str2Long        fcn     /STRING TOO LONG/,13                                    ; message for param string too long
     4F4F204C4F4E470D
     00
E43C 4E4F204D50492050 NotAnMPI fcn    /NO MPI PRESENT/,13                                     ; message for no NPI and  ... next message too
     524553454E540D00
E44C 4E4F205344432050 NotAnSDC        fcn     /NO SDC PRESENT/,13                                     ; message for no SDC present
     524553454E540D00
E45C                  NotActSDC
E45C 4E4F204143544956                         fcn     /NO ACTIVE SDC/,13                                      ; mmesage for not selected SDC
     45205344430D00
E46B                  BadFmtType
E46B 464F524D41542056                         fcn     /FORMAT VALUE NOT VALID/,13             ; message for parameter invalid
     414C5545204E4F54
     2056414C49440D00
E483 494E44455820544F idxHigh fcn     /INDEX TOO HIGH/,13                                     ; index higher than max allowed
     4F20484947480D00
E493 43555252454E5420 noCurDir        fcn   /CURRENT DIR IS ROOT/,13                  ; message to user
     4449522049532052
     4F4F540D00
E4A8 4E4F5420504F5353 canNot  fcn     /NOT POSSIBLE/,13                                               ; message for switching not possible
     49424C450D00
E4B6 3A2D2D4E4F204449 sdcNoDsc        fcn     /:--NO DISC--/,13                                               ; message for no disk in sdc drive
     53432D2D0D00
E4C4 3A544F54414C2053 totSect fcn     /:TOTAL SECTORS: /                                      ; text for detail in SDRIVE
     4543544F52533A20
     00
E4D5 5344462000       datSDF  fcn     /SDF /                                                                  ; text for SDRIVE
E4DA 4449522000       datDIR  fcn     /DIR /                                                                  ; text for SDRIVE
E4DF 2020202000       datNUL  fcn     /    /                                                                  ; text for SDRIVE
E4E4 2020634F4E5400   msgCont fcn     /  cONT/                                                                        ; message to user CONTinue
E4EB 20206558495400   msgExit fcn     /  eXIT/                                                                        ; message to user EXIT
E4F2 494E56414C494420 wrongPar        fcn     /INVALID PARAMETER VALUE/,13            ; message
     504152414D455445
     522056414C55450D
     00
E50B 535441434B20434F stackPrb        fcn     /STACK CONFLICTS/,13                                    ; error message 
     4E464C494354530D
     00
E51C 54494D454F55540D timeout         fcn     /TIMEOUT/,13                                                    ; error message for SDC access
     00
E525                  targetInUse
E525 5441524745542049                         fcn     /TARGET IN USE/,13                                      ; error message for SDC
     4E205553450D00
E534                  dirNotFound             
E534 4449524543544F52                         fcn     /DIRECTORY NOT FOUND/,13                        ; error message for SDC
     59204E4F5420464F
     554E440D00
E549                  pathNameInvalid         
E549 494E56414C494420                         fcn     /INVALID PATHNAME/,13                           ; error message for SDC
     504154484E414D45
     0D00
E55B                  miscHardware            
E55B 4D4953432E204841                         fcn     /MISC. HARDWARE ERROR/,13                       ; error message for SDC
     5244574152452045
     52524F520D00
E571 554E4B4E4F574E20 unknown         fcn     /UNKNOWN ERROR/,13                                      ; error message for SDC
     4552524F520D00
E580                  targetNotFound  
E580 544152474554204E                         fcn     /TARGET NOT FOUND/,13                           ; error message for SDC
     4F5420464F554E44
     0D00
E592 4E4F2036344B2043 not64K  fcn     /NO 64K COMPUTER/,13                                    ; error message for SDC
     4F4D50555445520D
     00
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; install new routines
                      ; Creates a new USR table and fills it with calls to 'FC ERROR'
                      ; usess the old USR table space to create a new STUB for the
                      ; new commands that will be added after the D.O.S. ones
                      ; -------------------------------------------------------------------------------------------------------------------------------
E5A3 1A50             initext orcc    #dimask                                         ; disable interrupts
E5A5 308D1E41                                 leax  newusr,pcr                        ; new address table for usr's
E5A9 9FB0                     stx   usrptr                            ; save at memory variable
E5AB 108E8B8D                 ldy   #fcerr                            ; address for error message
E5AF 860A                     lda   #10                               ; number of usr's
E5B1 10AF81           nxtvec  sty   ,X++                              ; fill element table
E5B4 4A                       deca                                    ; decrement counter
E5B5 26FA                     bne   nxtvec                            ; not finished, go back
E5B7 8612                     lda   #tokens                           ; get number of new tokens
E5B9 B70134                   sta   newstb                            ; store at stub base byte
E5BC 308C72                   leax  newrds,pcr                        ; base of new reserved words table
E5BF BF0135                   stx   newstb+1                          ; save on stub
E5C2 308C4C                   leax  newdsp,pcr                        ; address of dispatching routine
E5C5 BF0137                   stx   newstb+3                          ; save on stub
E5C8 8EE31B                                   ldx     #psmsg-1                                                ; point to message string
E5CB BD90E5                                   jsr     outstr                                          ; show to screen
E5CE B6FF7F                                   lda     MPIcfg                                          ; get received MPI config value for mega-mini-MPI compatibility
E5D1 8433                                     anda    #$33                                                    ; avoid using bits 7-6-3-2
E5D3 B703FF                                   sta     cpyMPIcfg                                       ; initialize copy
E5D6 B7FF7F                                   sta     MPIcfg                                          ; update config byte
E5D9 8D05                                     bsr     initask                                         ; put initial values
E5DB 1CAF                                     andcc   #eimask                                         ; enable interrupts
E5DD 7EFA84                                   jmp     expert                                          ; goto auto-start experiments
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E5E0 0FE7             initask clr     <retry                                          ; NO retry mark
E5E2 CC0102                                   ldd     #$0102                                          ; default values for the first two physical drives
E5E5 8E00FC                                   ldx     #$fc                                                    ; point to config area
E5E8 ED81                                     std     ,x++                                                    ; save these values
E5EA CCF6F5                                   ldd     #$f6f5                                          ; default values for Units 3-4 pointing to DW4 slots (245-246)
E5ED ED84                                     std     ,x                                                              ; save these values
E5EF DC8A                                     ldd     <$8a                                                    ; get 16 bits zero
E5F1 FD0114                                   std     floSDC                                          ; clear $114 and $115
                                                                                                                      ; pre-test on MPI                       
E5F4 1705F0                                   lbsr    tstMPI                                          ; is there an MPI?
E5F7 2604                                     bne     initsk01                                                ; no, go to individual checks
E5F9 170548                                   lbsr    tstHARD                                         ; yes, verify connected hardware
E5FC 39                                       rts                                                                     ; return
                                                                                                                      ; else verify individual elements (only one active)
E5FD 17060B           initsk01        lbsr    tstSDC                                          ; is SDC active?
E600 2709                                     beq     fndSDC                                          ; yes, skip next test
E602 17061D                                   lbsr    tstFLO                                          ; is FDC active instead?
E605 2609                                     bne     fndNthg                                         ; no, go out, no harware present at all
E607 8604             fndFDC  lda     #%00000100                                      ; set FDC present and let both SDC drives OFF
E609 2002                                     bra     savHdwF                                         ; go save it
E60B 860B             fndSDC  lda     #%00001011                                      ; mark SDC present and put both SDC drives ON
E60D B70114           savHdwF sta     floSDC                                          ; save result
E610 39               fndNthg rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command dispatcher called from BASIC
                      ; decodes the received token and passes it with the address
                      ; of the new dispatch table to the ROM command execution
                      ; -------------------------------------------------------------------------------------------------------------------------------
E611 811A             newdsp  cmpa  #newtok                           ; compare to first defined token
E613 250C                     blo   lowerr                            ; if lower show error
E615 812C                     cmpa  #newtok+tokens                    ; compare to last one
E617 240E                     bhs   higher                            ; if higher show error
E619 801A                     suba  #newtok                           ; first token converts to 0
E61B 308C68                   leax  nwtb01,pcr                        ; get new commands dispatch table base address
E61E 7E84ED                   jmp   romcmd                            ; pass to rom command execution
E621 308DFD79         lowerr  leax  low,pcr                           ; point to message
E625 2004                     bra   new1                                                      ; show error and return to interpreter
E627 308DFD82         higher  leax  high,pcr                          ; point to message
E62B BD90E5           new1    jsr   outstr                            ; show the selected error
E62E 7E89B4                   jmp   synerr                            ; rom will show syntax error message
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; new reserved words
                      ; -------------------------------------------------------------------------------------------------------------------------------
E631 44574C4F41C4     newrds  fcc   /DWLOA/,$C4                       ; char 'D' OR $80               dwload  = DLOAD (the new into this ROM)
E637 4D4F554ED4               fcc   /MOUN/,$D4                        ; char 'T' OR $80               mounT           = Associate a VDK to a Drive Number
E63C 4C494ECB                 fcc     /LIN/,$CB                                       ; char 'K' or $80               linK            = fill unit cell with received data
E640 4C4C494ECB               fcc     /LLIN/,$CB                                      ; char 'K' or $80               llinK           = show units links
E645 444FD3                   fcc     /DO/,$D3                                                ; char 'S' or $80               doS             = Boot a NitrOS-9 disc
E648 4C524FCD                 fcc     /LRO/,$CD               ; char 'M' or $80               lroM            = Load or Run a ROM image
E64C 42414ECB                 fcc     /BAN/,$CB                                       ; char 'K' or $80               banK            = change active SDC-bank
E650 534C4FD4                 fcc     /SLO/,$D4                                       ; char 'T' OR $80               sloT            = change to another MPI slot ($ef)
E654 5344524956C5             fcc     /SDRIV/,$C5                                     ; char 'E' or $80               sdrivE  = multipurpose for SDC-card
E65A 534449D2                 fcc     /SDI/,$D2                                       ; char 'R' or $80               sdiR            = multipurpose for SDC-card
E65E 48444944D8               fcc   /HDID/,$D8                                        ; char 'X' or $80               hdidX           = select the index disc in an HD array (max 90)
E663 534D4B4449D2             fcc     /SMKDI/,$D2                                     ; char 'R' or $80               smkdiR  = create a directory in the SDC-card
E669 534B494CCC                          fcc  /SKIL/,$CC                                      ; char 'L' or $80               skilL           = kill a file or an empty directory in a SDC-card
E66E 535245CE                                 fcc     /SRE/,$CE                                       ; char 'N' or $80               sreN            = rename a file in a SDC-card
E672 554E4C4F41C4                             fcc     /UNLOA/,$C4                     ; char 'D' OR $80               unloaD  = token to be used just as parameter ($f6)
E678 534348C4                                 fcc     /SCH/,$C4                               ; char 'D' OR $80               schD            = to change ACTUAL Directory
E67C 57524954C5                               fcc     /WRIT/,$C5                                      ; char 'E' or $80               writE           = write to a flash bank
E681 53434F50D9                               fcc     /SCOP/,$D9                                      ; char 'Y' or $80    scopY    = copy ROM from bank or slot to RAM
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Dispatch table. This is an indirect table
                      ; it contains the start address of every new command 
                      ; -------------------------------------------------------------------------------------------------------------------------------
E686 F8BC             nwtb01  fdb   dwload                                            ; routine for DWLOAD command
E688 E6B7                                     fdb   mount                                             ; routine for MOUNT command                
E68A E725                                     fdb     link                                                    ; routine for LINK command
E68C E7A2                                     fdb     llink                                                   ; routine for LLINK command
E68E E7FF                                     fdb     os9boot                                         ; routine to boot NitrOS-9
E690 E87F                                     fdb     xlrom                                                   ; routine to load - run a ROM image
E692 EA25                                     fdb     xbank                                                   ; routine to switch SDC active bank
E694 EC3F                                     fdb     xslot                                                   ; routine to change of MPI slot
E696 ED2F                                     fdb     xsdrive                                         ; routine for SDC-card DRIVE functions
E698 F323                                     fdb     xsdir                                                   ; routine for SDC-card DIR functions
E69A ED15                                     fdb     xHDidx                                          ; routine to select index of HD
E69C F220                                     fdb     xsmkdir                                         ; routine for SMKDIR command
E69E F24A                                     fdb     xskill                                          ; routine for SDELETE command
E6A0 F251                                     fdb     xsren                                                   ; routine for SRENAME command
E6A2 E789                                     fdb     snError                                         ; simply show syntax error
E6A4 F2E8                                     fdb     xschd                                                   ; routine for SCHD command
E6A6 F4C9                                     fdb     xwrite                                          ; routine for WRITE command
E6A8 F693                                     fdb     xscopy                                          ; routine for SCOPY command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Dispatch routines for the new added commands
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Routine to mark as invalid the four I/O buffers
                      ; -------------------------------------------------------------------------------------------------------------------------------
E6AA 4F               mrkmod  clra                                                                    ; get a 0
E6AB 8E0636                                   ldx     #$636                                                   ; point to 1st I/O buffer flags data
E6AE C615                                     ldb     #21                                                     ; offset to last I/O
E6B0 A785             mo01            sta     b,x                                                     ; mark as invalid
E6B2 C007                                     subb    #7                                                              ; offset to previous I/O
E6B4 2AFA                                     bpl     mo01                                                    ; if not negative, loopback
E6B6 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to ask DW4 to mount a VDK file and get the slot number back
                      ; -------------------------------------------------------------------------------------------------------------------------------
E6B7 1700BA           mount           lbsr    readunit                                                ; read unit number
E6BA D7F8                                     stb     <numUni                                         ; save it as number of Unit
E6BC BD89AA                                   jsr     ckComma                                         ; CkComma
E6BF BDB7AA                                   jsr     getfnam                                         ; GetNam into $1d1 (nambuf)
E6C2 8E01D0                   ldx   #nambuf-1                                 ; byte before packet buffer start
E6C5 6F84                     clr   ,x                                                                ; zero MSB to make a 16 bit value for Y
E6C7 10AE81                   ldy   ,x++                                                      ; length of file name (16 bit)
E6CA 2756                     beq   failvdk                                           ; if len=0 no file entered
E6CC E61F                     ldb   -1,x                                                      ; length of name (8 bit)
                                                                                                                      ; Adding .VDK if not termination entered, costs 31 bytes       
E6CE 3414                                     pshs  b,x                                                       ; save pointer to beginning of name and name length
E6D0 A680             isdot   lda   ,x+                                                       ; get a char from name
E6D2 812E                     cmpa  #'.'                                                      ; is it a dot?
E6D4 2718                     beq   alrdot                                            ; yes, stop search, quit loop
E6D6 5A                       decb                                                                    ; decrement counter
E6D7 26F7                     bne   isdot                                                     ; not end of string, get next char name
E6D9 CC2E56                   ldd   #$2e56                                            ; get chars ".V"
E6DC ED81                     std   ,x++                                                      ; add to end of name
E6DE CC444B                   ldd   #$444b                                            ; get chars "DK"
E6E1 ED81                     std   ,x++                                                      ; add to end of name
E6E3 E6E4                                     ldb   ,s                                                                ; get old name length
E6E5 CB04                                     addb  #4                                                                ; add 4 (because of .VDK added)
E6E7 E7E4                                     stb   ,s                                                                ; update new length in stack
E6E9 F701D1                   stb   nambuf                                            ; save new length in byte before string
E6EC 3124                     leay  4,y                                                       ; correction to name length - DW parameter
E6EE 3402             alrdot  pshs    a                                                               ; save register
E6F0 8602                                     lda     #2                                                              ; get value to mark output
E6F2 B7FF20                                   sta     BBOUT                                                   ; to DW4
E6F5 4F                                       clra                                                                    ; set counter
E6F6 4A               mount01 deca                                                                    ; decrement counter
E6F7 26FD                                     bne     mount01                                         ; not zero, loopback
E6F9 3502                                     puls    a                                                               ; restore register
E6FB 3514                                     puls  b,x                                               ; restore pointer and length
E6FD 6F85                                     clr   b,x                                                       ; zero terminate name string (for error)
E6FF 6C83                     inc   ,--x                                                      ; 1 = DriveWire OP_NAMEOBJ_MOUNT command
E701 3122                     leay  2,y                                                       ; length of DW packet = name length + 2
E703 1A50                     orcc    #dimask                                         ; disable interrupts to work with DW4
E705 BDFBA8                   jsr   DWWrite                                           ; send file request to server
E708 8E0012                   ldx   #dnum                                                     ; our drive number variable
E70B 6F84                     clr   ,x                                                                ; clear it
E70D 3121                     leay  1,y                                                       ; read one byte back
E70F BDFB21                   jsr   DWRead                                            ; get drive number
E712 1CAF                                     andcc #eimask                                           ; enable interrupts again 
E714 6D84                     tst   ,x                                                                ; verify received value
E716 2605                     bne   vdkok                                                     ; successful mount                                       
E718 C619                     ldb   #$19                                                      ; code for MO ERROR
E71A 7E8344                                   jmp   syserr                                            ; show error message (syserr)
E71D D612             vdkok           ldb     <dnum                                                   ; pass slot to B
E71F 8D25                                     bsr     stval                                                   ; verify / store new value
E721 39                                       rts                                                                     ; return
E722 7EB84B           failvdk jmp   ioerror                                           ; I/O error message
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to link a Unit with a drive number or a DW4 slot number
                      ; -------------------------------------------------------------------------------------------------------------------------------
E725 8D4D             link            bsr     readunit                                                ; read unit number
E727 D7F8                                     stb     <numUni                                         ; save it as number of Unit
E729 8D65                                     bsr     opt8bit                                         ; search another param 8 bit number
E72B 260E                                     bne     link01                                          ; if greater than 0, goto more tests
                                                                                                                      ; requested slot #0
E72D D6F8                                     ldb     <numUni                                         ; get unit number
E72F C101                                     cmpb    #1                                                              ; is it 1?
E731 2604                                     bne     notalw                                          ; no, error. Only unit 1 is allowed to be linked to slot #0
E733 0FFC                                     clr     <$fc                                                    ; put 0 value in first cell (unit 1, value 0)
E735 200E                                     bra     link03                                          ; exit
E737 C608             notalw  ldb     #$08                                                    ; code for FC error
E739 2045                                     bra     basyserr                                                ; show error message
E73B C104             link01  cmpb    #4                                                              ; is new value greater than 4 (DW4)?
E73D 2204                                     bhi     link02                                          ; yes, skip test
E73F D1F8                                     cmpb    <numUni                                         ; equals new drive number the unit number? (mandatory!)
E741 262B                                     bne     numError                                                ; no, show unit error
E743 8D01             link02  bsr     stval                                                   ; verify and store new value
E745 39               link03  rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Verifies that the new value (B) is not linked to another unit. If good, saves it
                      ; -------------------------------------------------------------------------------------------------------------------------------
E746 8E00FB           stval           ldx     #$00fb                                          ; point one byte before drive/slot table
E749 8604                                     lda     #4                                                              ; counter (number of units)
E74B E186             stv02           cmpb    a,x                                                     ; equals new value the contents of that slot?
E74D 2715                                     beq     stv04                                                   ; yes, see if it is the same unit
E74F 4A                                       deca                                                                    ; decrement counter
E750 26F9                                     bne     stv02                                                   ; if not 0, loopback
E752 8E00FB           estval  ldx     #$00fb                                          ; point to one byte before data table
E755 96F8                                     lda     <numUni                                         ; get unit number
E757 8104                                     cmpa    #4                                                              ; is unit 4?
E759 2603                                     bne     stv03                                                   ; no, skip next
E75B 7F0115                                   clr     idxHD                                                   ; set index to HD to 0
E75E E786             stv03           stb     a,x                                                     ; store slot into table
E760 17FF47                                   lbsr    mrkmod                                          ; modify data to flag drive changes to system   
E763 39                                       rts                                                                     ; everything alright, return
E764 91F8             stv04           cmpa    <numUni                                         ; is unit with this value the same as destination in LINK command?
E766 27EA                                     beq     estval                                          ; yes, acceptable, return
E768 3262                                     leas    2,s                                                     ; get rid of return address
                                                                                                                              ; show error. We do not admit the same slot number in two units!
                      ;                       bra     already                                 ; *** Fall Thru *** not needed 
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
E76A 8EE3D3           already ldx     #alrput-1                                       ; point to error message
E76D 10                                       fcb     #$10                                                    ; to jump over next one
E76E 8EE3BC           numError ldx    #drverr-1                                       ; point to error message
E771 7E90E5                                   jmp     outstr                                          ; show message and return to interpreter
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E774 0FF8             readunit        clr     <numUni                                         ; clear unit number
E776 8D0D                                     bsr     getunit                                         ; get a one digit number
E778 2704                                     beq     errNum                                          ; if zero jump to device error
E77A C104                                     cmpb    #4                                                              ; is it greater than 4?
E77C 2305                                     bls     OKnext                                          ; no, goto OK
E77E C628             errNum  ldb     #$28                                                    ; device number error (bas_err_DN)
E780 7E8344           basyserr        jmp     syserr                                          ; bas_system_error
E783 0EA5             OKnext  jmp     <redLChr                                                ; bas_poll_char                 
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E785 9DA5             getunit jsr     <redLChr                                                ; get a char (bas_poll_char)
E787 2603                                     bne     r8b01                                                   ; if there is something, skip next
E789 7E89B4           snError jmp     synerr                                          ; show error message (BAS-SN-Error)
E78C BDE79A           r8b01           jsr     get8bit                                         ; get a number (8bits)
E78F 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E790 9DA5             opt8bit jsr     <redLChr                                                ; get a char (bas_poll_char)
E792 2705                                     beq     eo8b                                                    ; if 0, return
E794 BD89AA                                   jsr     ckComma                                         ; check if there is a comma separator (CkComa)
E797 8D01                                     bsr     get8bit                                         ; get a 8 bits number
E799 39               eo8b            rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E79A 3460             get8bit pshs    y,u                                                     ; save working registers
E79C BD8E51                                   jsr     asc2Num                                         ; convert ASCII to number (1 byte)
E79F 5D                                       tstb                                                                    ; update flags upon result
E7A0 35E0                                     puls    y,u,pc                                          ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to show the links of every unit
                      ; -------------------------------------------------------------------------------------------------------------------------------
E7A2 8EE3EE           llink           ldx     #headlnk-1                                      ; point to message header
E7A5 BD90E5                                   jsr     outstr                                          ; show it
E7A8 8E00FB                                   ldx     #$00fb                                          ; point one byte before first data byte
E7AB C601                                     ldb     #1                                                              ; unit counter
E7AD A685             llink01 lda     b,x                                                     ; get linked value
E7AF 8D06                                     bsr     showLine                                                ; show data
E7B1 5C                                       incb                                                                    ; increment counter
E7B2 C104                                     cmpb    #4                                                              ; done all units?
E7B4 23F7                                     bls     llink01                                         ; no, loopback
E7B6 39                                       rts                                                                     ; return to caller
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E7B7 3416             showLine        pshs    d,x                                                     ; save working registers
E7B9 8EE3FB                                   ldx     #spaces+1                                       ; point to print 2 spaces
E7BC BD90E5                                   jsr     outstr                                          ; print them
E7BF E661                                     ldb     1,s                                                     ; get unit number
E7C1 4F                                       clra                                                                    ; clear high byte
E7C2 BD957A                                   jsr     outnum                                          ; print number
E7C5 E6E4                                     ldb     ,s                                                              ; get linked value
E7C7 4F                                       clra                                                                    ; clear high byte
E7C8 C10A                                     cmpb    #10                                                     ; is value lower than 10?
E7CA 2506                                     blo     sL01                                                    ; yes, goto print
E7CC 4C                                       inca                                                                    ; one space less
E7CD C164                                     cmpb    #100                                                    ; is value lower than 100?
E7CF 2501                                     blo     sL01                                                    ; yes, goto print
E7D1 4C                                       inca                                                                    ; one space less
E7D2 8EE3F9           sL01            ldx     #spaces-1                                       ; point to print 4 spaces
E7D5 3086                                     leax    a,x                                                     ; skip the calculated ones upon the value
E7D7 BD90E5                                   jsr     outstr                                          ; print required spaces
E7DA E6E4                                     ldb     ,s                                                              ; get linked value
E7DC 4F                                       clra                                                                    ; clear high byte                                                       
E7DD BD957A                                   jsr     outnum                                          ; print number
E7E0 E661                                     ldb     1,s                                                     ; get unit number
E7E2 C104                                     cmpb    #4                                                              ; is it 4?
E7E4 2612                                     bne     sL02                                                    ; no, stop printing
E7E6 F60115                                   ldb     idxHD                                                   ; get index for HD
E7E9 270D                                     beq     sL02                                                    ; if zero, skip printing it
E7EB 8EE427                                   ldx     #xidxTxt-1                                      ; point to text
E7EE BD90E5                                   jsr     outstr                                          ; show it
E7F1 F60115                                   ldb     idxHD                                                   ; get unit number
E7F4 4F                                       clra                                                                    ; zero to high byte
E7F5 BD957A                                   jsr     outnum                                          ; call ROM to print integer in D
E7F8 860D             sL02            lda     #$0d                                                    ; enter
E7FA BDBCAB                                   jsr     outRegA                                         ; print A 
E7FD 3596                                     puls    d,x,pc                                          ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to Boot a NitrOS-9 disc
                      ; -------------------------------------------------------------------------------------------------------------------------------
E7FF 5F               os9boot  clrb                                                                   ; default drive 0
E800 9DA5                      jsr   <redLChr                 ; peek at next char
E802 2703                      beq   defnum                                           ; not found, use default
E804 BD8E51                    jsr   asc2Num                                  ; Get 1 byte
E807 D712             defnum  stb   <dnum                                                     ; save drive number
E809 8EE3FE                                   ldx   #ldtext-1                                 ; point to 'loading' message
E80C BD90E5                    jsr   outstr                                           ; show it
E80F 1A50                                     orcc  #dimask                                           ; disable interrupts
E811 BDE86D                                   jsr     trick                                                   ; make sure DW4 connection is on
                                                                                                                              ; DriveWire bootstrap code. Get sectors 612-629 to $2600
E814 8E0264                         ldx   #612                                                        ; starting sector number to load
E817 108E2600                  ldy   #$2600                                           ; destination in memory
E81B BDFAD3           DOSLoop  jsr   DoRead                                           ; read sector (into Y)
E81E 252F                      bcs   fail2                                                    ; start all over
E820 262D                      bne   fail2                                                    ; show error
E822 8C0264                    cmpx  #612                                                     ; our first sector?
E825 2608                      bne   not1st                                           ; branch if not
E827 ECA4                      ldd   ,y                                                               ; else get 1st two bytes at $2600
E829 10834F53                  cmpd  #$4f53                                           ; OS?
E82D 261A                      bne   noos                                                     ; no, show error
E82F 866A             not1st   lda   #'*'+$40                                         ; print star
E831 31A90100                  leay  256,y                                                    ; move for next sector
E835 3001                      leax  1,x                                                      ; increment number of sector to be read
E837 A789023B                  sta   571,x                                                    ; print progress (1024+32*5-612-1)
E83B 8C0276                    cmpx  #630                                                     ; are we at last sector?
E83E 2DDB                      blt   DOSLoop                                          ; branch if not
E840 8661                      lda   #'!'+$40                                         ; print bang
E842 A789027B                  sta   635,x                                                    ; over last '*' (636-1)
E846 7E2602                    jmp   $2602                                                    ; jump into Boot code
E849 8EE411           noos     ldx   #noostxt-1                                       ; point to message
E84C BD90E5                    jsr   outstr                                           ; print string at x+1
E84F 7EB84B           fail2    jmp   ioerror                                          ; IO_error equ $b84b
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Patch to DosPlus Boot to allow RSDOS disks to boot too (Mike Miller 2021-05)
                      ; -------------------------------------------------------------------------------------------------------------------------------
E852 8C4F53           rsbtchk  cmpx   #$4F53                                          ; Check for signature
E855 2713                                     beq     rsbt01                                                  ; Boot DragonDOS style disk
E857 CC2201                                   ldd     #$2201                                                  ; Look instead RSDOS location track 34 first sector
E85A BDC0F9                                   jsr     gtbtsig                                    ; Read boot sig (enter after track and sector set)
E85D 2401                                     bcc     rsbt00                                          ; it's OK, skip next
                      ;                       jmp     $C166                                                   ; Failed to read then exit
E85F 39                                       rts                                                             ; Failed to read then exit
E860 9E4F             rsbt00  ldx     $4F                                                     ; Get first 2 bytes 
E862 8C4F53                                   cmpx    #$4F53                                          ; Check for signature 
E865 2703                                     beq     rsbt01                                          ; it is Bootable!
E867 7EC164                                   jmp     $C164                                              ; Not bootable RSDOS way either, exit with ?BT error 
E86A 7EC14E           rsbt01  jmp     $C14E                                                   ; Otherwise load the track
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Routine that marks on the DW4 line for a while, to avoid fails at 1st access
                      ; -------------------------------------------------------------------------------------------------------------------------------
E86D 3414             trick    pshs   b,x                                                     ; save working registers
E86F 8EFF20                                   ldx   #PIA1Base                         ; address of PIA1
E872 C602                      ldb   #$02                                                     ; put value #2 (bit1 to high level)
E874 E784                      stb   ,x                               ; make RS-232 output marking
                                                                                                                              ; Spin for a while so that the RS-232 bit stays hi for a time
E876 8EA000           waw             ldx   #$a000                                            ; wait counter
E879 301F             waw1     leax  -1,x                                                     ; decrement counter
E87B 26FC                      bne   waw1                                                     ; if not 0, loopback
E87D 3594                      puls   b,x,pc                                          ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to load - run a ROM image
                      ; -------------------------------------------------------------------------------------------------------------------------------
E87F 1A50             xlrom           orcc  #dimask                   ; disable firq, irq
E881 8DEA                                     bsr     trick                                                   ; make sure dw4 connection is on
E883 9DA5             lromrty         jsr   <redLChr                                          ; peek at next character (after "rom")
E885 804E                     suba  #'N'                                                      ; to detect if it was an 'n' - if so don't exec it after loading
E887 9710                     sta   <noexec                                           ; save difference. 0 = noexec
E889 2602                     bne   savvec                                            ; if not 'n' jump next instruccion
E88B 9D9F                     jsr   <getNChr                                          ; jump over that char (the 'n')
E88D 8EE364           savvec  ldx   #ldtextr-1                                        ; byte before message
E890 8D76                                     bsr   prtstr                                            ; print string
E892 BDB7AA                           jsr   getfnam                                           ; read rom file name and length into $1d1 = nambuf
E895 7D01D1                   tst     nambuf                                          ; is filename length equal 0?
E898 261D                     bne     rom01                                                   ; no, process it
E89A F6060A                   ldb     $60a                                                    ; get default drive number
E89D 8E00FB                   ldx     #$00fb                                          ; point to table of links x unit
E8A0 A685                     lda     b,x                                                     ; search slot number in table
E8A2 2604                     bne     ver01                                                   ; if not 0, do more tests
E8A4 C101                     cmpb    #1                                                              ; is slot 0 linked to unit 1? - to avoid tricks with poke unit's slot numbers
E8A6 2704                     beq     ver02                                                   ; yes, accept it and go on. the only legal one!
E8A8 8105             ver01           cmpa    #5                                                              ; is it a dw4 slot?
E8AA 2504                     blo     errdw4                                          ; no, show error
E8AC 9712             ver02           sta     <dnum                                                   ; save slot number at variable
E8AE 2064                     bra     rdecb                                                   ; go process rom at default drive
E8B0 8EE38D           errdw4  ldx     #notdw4-1                                       ; point to message error
E8B3 BD90E5                                   jsr   outstr                                            ; show message
E8B6 39                                       rts                                                                     ; return
E8B7 8E01D0           rom01           ldx   #nambuf-1                                 ; byte before packet buffer start
E8BA 6F84                     clr   ,x                                                                ; zero msb to make a 16bit value for y
E8BC 10AE81                   ldy   ,x++                                                      ; length of file name (16 bit)
E8BF 2742                     beq   failedr                                           ; if len=0 no file entered
E8C1 E61F                     ldb   -1,x                                                      ; length of name (8 bit)
                                                                                                                              ; adding .rom if not termination entered      
E8C3 3414                                     pshs  b,x                                                       ; save pointer to beginning of name and name length
E8C5 A680             isdotr          lda   ,x+                                                       ; get a char from name
E8C7 812E                     cmpa  #'.'                                                      ; is it a dot?
E8C9 2718                     beq   alrdotr                                           ; yes, stop search, quit loop
E8CB 5A                       decb                                                                    ; decrement counter
E8CC 26F7                     bne   isdotr                                            ; not end of string, get next char name
E8CE CC2E52                   ldd   #$2e52                                            ; get chars ".r"
E8D1 ED81                     std   ,X++                                                      ; add to end of name
E8D3 CC4F4D                   ldd   #$4f4d                                            ; get chars "om"
E8D6 ED81                     std   ,x++                                                      ; add to end of name
E8D8 E6E4                                     ldb   ,s                                                                ; get old name length
E8DA CB04                                     addb  #4                                                                ; add 4 (because of .rom added)
E8DC E7E4                                     stb   ,s                                                                ; update new length in stack
E8DE F701D1                   stb   nambuf                                            ; save new length in byte before string
E8E1 3124                     leay  4,y                       ; correction to name length - dw parameter
E8E3 3514             alrdotr         puls  b,x                                               ; restore pointer and length
E8E5 6F85                     clr   b,x                                                       ; zero terminate name string (for error)
E8E7 6C83                     inc   ,--x                                                      ; 1 = drivewire op_nameobj_mount command
E8E9 3122                     leay  2,y                                                       ; length of dw packet = name length + 2
E8EB BDFBA8                   jsr   DWWrite                                           ; send file request to server
E8EE 8E0012                   ldx   #dnum                                                     ; our drive number variable
E8F1 6F84                     clr   ,x                                                                ; clear it
E8F3 3121                     leay  1,y                                                       ; read one byte back
E8F5 BDFB21                   jsr   DWRead                                            ; get drive number
E8F8 6D84                     tst   ,x                                                                ; verify received value
E8FA 2618                     bne   rdecb                                                     ; successful mount. if z has not been set = error (coundn't mount). jump to readin
E8FC C619             moError         ldb   #$19                                                      ; errror code for mo error
E8FE 1CAF                     andcc #eimask                                   ; enable interrupts
E900 7E8344                   jmp   syserr                                            ; show error message
E903 1CAF             failedr         andcc #eimask                                   ; enable interrupts
E905 7EB84B                                   jmp   ioerror                                           ; i/o errror message
E908 D689             prtstr  ldb     <curlow                                                 ; get low byte of cursor position
E90A C41F                     andb  #$1f                                                      ; is column zero?
E90C 2602                     bne   shwmsg                                    ; no, print whith leading enter
E90E 3001                                     leax  1,x                                       ; jump leading enter 
E910 BD90E5           shwmsg  jsr   outstr                                       ; print string
E913 39                                       rts                                                                     ; return
E914 8E0000           rdecb   ldx   #0                                                                ; begin at sector zero
E917 108E3000                 ldy   #ramini                                           ; destination address
E91B 9F76                     stx   <endadr                                           ; set last load address to zero 
E91D 0FE6                     clr   <bigfil                                           ; flag for long file to false
E91F 1700AB           romlop  lbsr  doreadr                                   ; read sector (into y) 
E922 25DF                     bcs   failedr                                           ; detect frame error
E924 26DD                     bne   failedr                                           ; detect incomplete read
E926 2D15                     blt   nomore                    ; detect end of file. finish
E928 862A                     lda   #'*'                                                      ; get 'star' ascii code
E92A BDB54A                                   jsr   outchr                                            ; show on screen, we have read a sector
E92D 31A90100                 leay  256,y                                                     ; point to next sector address
E931 108C6FFF                 cmpy  #rmaxld                                           ; got to the ram limit?
E935 2404                     bhs   bigend                                            ; no, keep on copying
E937 3001                     leax  1,x                                                       ; increment sector number
E939 20E4                     bra   romlop                                            ; go read next sector
E93B 0CE6             bigend  inc   <bigfil                                           ; big file flag to true
E93D 109F76           nomore  sty   <endadr                                           ; save as last loaded address
E940 8608                     lda   #$08                                                      ; get backspace ascii code
E942 BDB54A                                   jsr      outchr                                         ; print on screen (go back one char)
E945 8621                     lda   #'!'                                                      ; get 'bang' ascii code
E947 BDB54A                                   jsr   outchr                                            ; put it on screen
E94A 0DE6                                     tst   <bigfil                                           ; is this a too long file?
E94C 2705                                     beq   final                                                     ; no, jump message
E94E 8EE380                                   ldx   #bigrom-1                                 ; message for rom greater than 16k-256bytes
E951 8DB5                                     bsr   prtstr                                            ; print message
E953 0D10             final   tst   <noexec                                           ; has to be run?
E955 2610                     bne   runit                                                     ; yes, do it
E957 8EE372                   ldx   #endtxt-1                                 ; point to end text
E95A 8DAC                                     bsr   prtstr                                            ; print message
E95C DC76                                     ldd   <endadr                                           ; get last loaded ram address
E95E 833000                                   subd  #ramini                                           ; subtract init ram address
E961 BD957A                                   jsr   outnum                                            ; print length 
E964 1CAF                             andcc #eimask                                           ; enable interrupts
E966 39                       rts                                                                     ; return to the caller
E967 FCC000           runit   ldd   >romini                                           ; get two bytes from rom area
E96A 8E9669                                   ldx   #$9669                                            ; create a pattern 1001 0110 0110 1001
E96D BFC000                                   stx   >romini                                           ; store into two dos-rom bytes
E970 BCC000                                   cmpx  >romini                                           ; have been modified?
E973 2603                                     bne   basicup                                           ; no, must switch to map1 and copy basic to upper ram
E975 FDC000                                   std   >romini                                           ; put back two saved bytes
E978 8EE98A           basicup  ldx    #basic                                          ; point to beginning of code to be moved
E97B CE2A00                                   ldu     #$2a00                                          ; destination in low ram
E97E EC81             basup01 ldd     ,x++                                                    ; get a word
E980 EDC1                                     std     ,u++                                                    ; put at destination
E982 8CE9CD                                   cmpx    #doreadr                                                ; got to the end?
E985 23F7                                     bls     basup01                                         ; no, loopback
E987 7E2A00                                   jmp     $2a00                                                   ; transfer control to copied code in ram
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E98A 8E8000           basic   ldx   #basini                                           ; get basic initial address
E98D B7FFDE           bas1    sta   $ffde                                                     ; go map0 (rom)
E990 EC84                     ldd   ,x                                                                ; get 2 bytes
E992 B7FFDF                   sta   $ffdf                                                     ; go map1 (ram)
E995 ED81                     std   ,x++                                                      ; store 2 bytes, incr. pointer
E997 8CC000                   cmpx  #romini                                           ; reached end of basic?
E99A 25F1                     blo   bas1                                                      ; no, keep on copying basic
E99C 8E3000           map1            ldx     #ramini                                         ; get rom origin address at ram area
E99F CEC000                   ldu   #romini                                           ; get rom destination address
E9A2 B7FFDF                   sta   $ffdf                                                     ; go map1 (ram) and stay there
E9A5 EC81             move    ldd   ,x++                                                      ; get two bytes, inc pointer
E9A7 EDC1                     std   ,u++                                                      ; store two bytes, inc pointer
E9A9 9C76                     cmpx  <endadr                                           ; reached last loaded address?
E9AB 2405                                     bhs   nohook                                            ; yes, quit loop
E9AD 8C6EFF                                   cmpx  #rammax                                           ; reached max rom possible (16k-256bytes)?
E9B0 25F3                                     blo      move                                                   ; no, keep on copying rom
E9B2 8639             nohook  lda   #$39                                                      ; opcode for rts
E9B4 8E015E                                   ldx   #hokini                                           ; get initial address of system hooks
E9B7 A780             hooks   sta   ,x+                                                       ; overwrite them
E9B9 8C01A8                   cmpx  #hokend                                           ; got hooks end?
E9BC 25F9                     blo   hooks                                                     ; no, keep on overwriting them
E9BE CC444B                                   ldd     #$444b                                          ; sign for dos roms
E9C1 8EC000                                   ldx     #romini                                         ; beginning of the rom
E9C4 10A384                                   cmpd    ,x                                                              ; is a dos what we have loaded?
E9C7 2602                                     bne     bas2                                                    ; no, execute it
E9C9 3002                                     leax    2,x                                                     ; skip over dos signature
E9CB 6E84             bas2            jmp   ,x                                                                ; start loaded rom
                      
                      ; -------------------------------------------------------------------------------------------
E9CD 9612             doreadr         lda   <dnum                                                     ; our drive number
E9CF 5F                       clrb                                                                    ; lsn bits 23-16
E9D0 3436                     pshs  a,b,x,y                                           ; save registers / data
E9D2 86D2                     lda   #$d2                                                      ; dw op_readex (read one sector)
E9D4 3402             rereadr         pshs  a                                                         ; save command to stack
E9D6 30E4                     leax  ,s                                                                ; point x to top of stack
E9D8 108E0005                 ldy   #5                                                                ; 5 bytes
E9DC BDFBA8                   jsr   DWWrite                                           ; send 5 bytes to dw      - readex, dnum, $0, sector
E9DF 3502                     puls  a                                                         ; discard command
E9E1 AE64                     ldx   4,s                                                       ; get read buffer pointer (old y)
E9E3 108E0100                 ldy   #256                                                      ; read 256 bytes
E9E7 CC0085                   ldd   #133                                                      ; 1 second timeout
E9EA BDFB21                   jsr   DWRead                                            ; receive 256 bytes
E9ED 2534                     bcs   readex2                                           ; detect framing error
E9EF 2632                     bne   readex2                                           ; detect not all bytes received
E9F1 3420                     pshs  y                                                         ; save checksum
E9F3 30E4                     leax  ,s                                                                ; point x to top of stack
E9F5 108E0002                 ldy   #2                                                                ; 2 bytes
E9F9 BDFBA8                   jsr   DWWrite                                           ; send checksum
E9FC 3121                     leay  1,y                                                       ; after a dwrite 'y' returns zeroed, so this way it becomes equal to one
E9FE CC0085                   ldd   #133                                                      ; 1 second timeout
EA01 BDFB21                   jsr   DWRead                                            ; read dw answer
EA04 3262                     leas  2,s                                                       ; discard checksum
EA06 251B                     bcs   readex2                                           ; detect framing error
EA08 2619                     bne   readex2                                           ; detect not all bytes received
EA0A A6E4                     lda   ,s                                                                ; get server answer
EA0C 2715                     beq   readex2                                           ; zero=ok, return
EA0E 81F3                     cmpa  #$f3                                                      ; error code is #e_crc?
EA10 2606                     bne   reader                                            ; not this one, go verify eof condition
EA12 86F2                     lda   #$f2                                                      ; command reread. #op_rereadex
EA14 6FE4                     clr   ,s                                                                ; clear received answer
EA16 20BC                     bra   rereadr                                           ; read again
EA18 81F4             reader  cmpa  #$f4                                      ; error code is 'read past end' (eof)?
EA1A 2606                                     bne   noteof                                            ; no, mark read error
EA1C 1CFC                     andcc #$fc                    ; unsets the 'c' and 'v' flags
EA1E 1A0C                     orcc  #$0c                                                      ; sets 'n' and 'z' flags. both prepare the flags to be positive at 'blt' test
EA20 2001                     bra   readex2                                           ; jump over next instruction, not a read error
EA22 53               noteof  comb                                                                    ; sets the carry flag (error)
EA23 35B6             readex2         puls  a,b,x,y,pc                                        ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to start a SDC-bank
                      ; -------------------------------------------------------------------------------------------------------------------------------
EA25 BDE785           xbank           jsr     getunit                                         ; read a number between 0-7
EA28 C107                                     cmpb    #7                                                              ; is it greater than 7?
EA2A 2305                                     bls     OKbank                                          ; no, OK
EA2C C611             badnum  ldb     #$11                                                    ; SD error
EA2E 7E8344                                   jmp     syserr                                          ; bas_system_error
EA31 1A50             OKbank  orcc    #dimask                                         ; disable interrupts
EA33 D7F8                                     stb     <numUni                                         ; save received number in first sentence (B)
EA35 0FF9                                     clr     swMap1                                          ; by default don't change map type
EA37 9DA5                                     jsr     <redLChr                                                ; see next char after BANK
EA39 274B                                     beq     seeSlot                                         ; no extra chars, skip extra param search
EA3B 812C                                     cmpa    #','                                                    ; is it a comma?
EA3D 1026FD48                                 lbne    snError                                         ; no, show error
EA41 9D9F                                     jsr     <getNChr                                                ; get next char
EA43 8152                                     cmpa    #'R'                                                    ; is it R (for RAM mode = MAP1)?
EA45 1026FD40                                 lbne    snError                                         ; no, show error
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; copy and execute from RAM the 64k tester
EA49 8EEA63                                   ldx     #tst64k                                         ; point to beginning of data to be copied
EA4C CE01DA                                   ldu     #$1da                                                   ; point to destination
EA4F EC81             xb001           ldd     ,x++                                                    ; get a wrod
EA51 EDC1                                     std     ,u++                                                    ; put at destination
EA53 8CEA84                                   cmpx    #emod1B+2                                       ; got to the end?
EA56 25F7                                     blo     xb001                                                   ; no, loopback
EA58 BD01DA                                   jsr     $1da                                                    ; jsr that copied code from RAM
EA5B 2627                                     bne     xb002                                                   ; if not zero, we have 64K
EA5D 8EE591                              ldx  #not64K-1                                       ; else show message NO 64K COMPUTER                     
EA60 7E90E5                                   jmp     outstr                                          ; show message
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; validate if there are 64k - This must be executed from RAM
EA63 8D0B             tst64k  bsr     mod1Byt                                         ; can modify rom area?
EA65 2608                                     bne     etst64k                                         ; yes, return result
EA67 B7FFDF                                   sta     $ffdf                                                   ; no, try switching to map1                     
EA6A 8D04                                     bsr     mod1Byt                                         ; can modify area?
EA6C F7FFDE                                   stb     $ffde                                                   ; back to map0 where it was
EA6F 39               etst64k rts                                                                     ; return result
EA70 5F               mod1Byt clrb                                                                    ; default 32K
EA71 B6C000                                   lda     $c000                                                   ; get first DOS ROM char 
EA74 43                                       coma                                                                    ; invert bits
EA75 B7C000                                   sta     $c000                                                   ; update value
EA78 B1C000                                   cmpa    $c000                                                   ; has been updated?
EA7B 2605                                     bne     emod1B                                          ; no, return
EA7D 43                                       coma                                                                    ; invert bits again
EA7E B7C000                                   sta     $c000                                                   ; restore value
EA81 5C                                       incb                                                                    ; found 64k
EA82 5D               emod1B  tstb                                                                    ; update flags
EA83 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
EA84 0CF9             xb002           inc     swMap1                                          ; mark flag to change to map1
                                                                                                                      ; see if we have a SDC
EA86 B60114           seeSlot lda     floSDC                                          ; get hdw control byte
EA89 8508                                     bita    #%00001000                                      ; is there an SDC?
EA8B 102700AC                                 lbeq    NotSDCPresent                           ; no, show error
EA8F 84C0                                     anda    #%11000000                                      ; use bits 7-6 (slot where it is)
EA91 44                                       lsra                                                                    ; move them to
EA92 44                                       lsra                                                                    ; bits 5-4 (lower bits of high nibble)
EA93 3402                                     pshs    a                                                               ; save high nibble
EA95 44                                       lsra                                                                    ; low nibble   
EA96 44                                       lsra                                                                    ; gets high nibble
EA97 44                                       lsra                                                                    ; that will end  
EA98 44                                       lsra                                                                    ; as zero
EA99 AAE0                                     ora     ,s+                                                     ; add high nibble (now they are the same value)
EA9B 0DF9                                     tst     swMap1                                          ; should it be run in MAP1?
EA9D 2616                                     bne     swMbank                                         ; yes, go to next section
EA9F 3402             swbank  pshs    a                                                               ; save SDC slot number
EAA1 8EEACB                                   ldx     #special                                                ; point to the beginning of code to execute from RAM
EAA4 CE01DA                                   ldu     #$1da                                                   ; point at destination
EAA7 EC81             swB01           ldd     ,x++                                                    ; get a word
EAA9 EDC1                                     std     ,u++                                                    ; copy at destination
EAAB 8CEAF2                                   cmpx    #exbank+3                                       ; got to the end?
EAAE 25F7                                     blo     swB01                                                   ; no, loopback
EAB0 3502                                     puls    a                                                               ; restore slot number
EAB2 7E01DA                                   jmp     $1da                                                    ; jumto to RAM copied code
EAB5 3402             swMbank pshs    a                                                               ; save SDC slot number
EAB7 8EEAF2                                   ldx     #allRAM                                         ; point to the beginning of code to execute from RAM
EABA CE01DA                                   ldu     #$1da                                                   ; point at destination
EABD EC81             swMB01  ldd     ,x++                                                    ; get a word
EABF EDC1                                     std     ,u++                                                    ; copy at destination
EAC1 8CEB2F                                   cmpx    #m1L03+3                                                ; got to the end?
EAC4 25F7                                     blo     swMB01                                          ; no, loopback
EAC6 3502                                     puls    a                                                               ; restore slot number
EAC8 7E01DA                                   jmp     $1da                                                    ; jumto to RAM copied code
                                                                                                                      ; this TWO parts MUST be run from RAM because we are going
                                                                                                                      ; to lose control when switching the ROM slot and/or the bank!
                                                                                                                      ; code to start the bank in ROM mode (MAP0)
                                                                                                                      ; SDC slot# comes onto stack 
EACB 1A50             special orcc    #dimask                                         ; disable interrupts
EACD 7FFFDE                                   clr     $ffde                                                   ; switch to MAP0 (ROM-RAM mode)
EAD0 B703FF                                   sta     cpyMPIcfg                                       ; update copy
EAD3 B7FF7F                                   sta     MPIcfg                                          ; switch to the slot where the SDC is
EAD6 D6F8                                     ldb     <numUni                                         ; get requested bank number
EAD8 F7FF4B                                   stb     $ff4b                                                   ; point to it
EADB 8E444B                                   ldx     #$444b                                          ; get mark for DOS system
EADE BCC000                                   cmpx    romini                                          ; is there a DOS ROM?
EAE1 270A                                     beq     spec01                                          ; yes, issue cold start
EAE3 8E7F37                                   ldx     #$7f37                                          ; get std value for stack
EAE6 3284                                     leas    ,x                                                              ; assign it
EAE8 C4AF                                     andb    #eimask                                         ; enable interrupts
EAEA 7EC000                                   jmp     romini                                          ; no, execute ROMPACK
EAED 0F71             spec01  clr     <$71                                                    ; force a cold boot
EAEF 7EB3B4           exbank  jmp     resetRt                                         ; execute the system reset routine
                                                                                                                      ; code to start the bank but having copied everything into MAP1
                                                                                                                      ; SDC slot# comes onto stack 
EAF2 1A50             allRAM  orcc  #dimask                           ; disable interrupts
EAF4 B703FF                                   sta     cpyMPIcfg                                       ; update copy
EAF7 B7FF7F                                   sta     MPIcfg                                          ; switch to the slot where the SDC is
EAFA D6F8                                     ldb     <numUni                                         ; get requested bank number
EAFC F7FF4B                                   stb     $ff4b                                                   ; point to it
                                                                                                                      ; copy ROM to RAM
EAFF 8E8000                                   ldx   #basini                           ; point to beginning of Basic
EB02 B7FFDE           m1L01           sta   $ffde                             ; switch to ROM map
EB05 EC84                                     ldd   ,x                                ; get a word
EB07 B7FFDF                                   sta   $ffdf                             ; switch to RAM map
EB0A ED81                                     std   ,x++                              ; copy at RAM destination
EB0C 8CFEFF                                   cmpx  #$feff                            ; end of ROM?
EB0F 25F1                                     bcs   m1L01                                     ; no, loopback
EB11 8639                                     lda   #$39                              ; get RTS opcode
EB13 8E015E                                   ldx   #$015e                            ; point to beginning of User vectors (hooks)
EB16 A780             m1L02           sta   ,x+                               ; put an RTS in each one
EB18 8C01A8                                   cmpx  #$01a8                            ; end of user vectors?
EB1B 25F9                                     bcs   m1L02                                             ; no, loopback
EB1D BDBA77                                   jsr     $ba77                                                   ; clear screen
EB20 CC444B                                   ldd     #$444b                                          ; get mark for O.S.
EB23 10B3C000                                 cmpd    romini                                          ; is there an O.S. in RAM now?
EB27 2703                                     beq     m1L03                                                   ; yes, start it
EB29 7EC000                                   jmp     romini                                          ; else start ROM from the beginning
EB2C 7EC002           m1L03           jmp   romini+2                          ; start ROM (copied into RAM)
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                              ; MESSAGES. They all will return with carry set.
EB2F                  BadFormat
EB2F 8EE46A                                   ldx     #BadFmtType-1                           ; point to message
EB32 10                                       fcb     #$10                                                    ; skip next ldx
EB33 8EE42A           TooLong ldx     #Str2Long-1                                     ; point to message
EB36 10                                       fcb     #$10                                                    ; skip next ldx
EB37                  NotMPIPresent
EB37 8EE43B                                   ldx     #NotAnMPI-1                                     ; point to message
EB3A 10                                       fcb     #$10                                                    ; skip next ldx
EB3B                  NotSDCPresent
EB3B 8EE44B                                   ldx     #NotAnSDC-1                                     ; point to message
EB3E BD90E5                                   jsr     outstr                                          ; show it
EB41 1A01                                     orcc    #%00000001                                      ; set carry flag
EB43 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; This routine will copy the hardware tests routines at $1da and jump there 
                      ; to avoid hanging the system while switching of MPI slot
                      ; -------------------------------------------------------------------------------------------------------------------------------
EB44 8EEB57           tstHARD ldx     #tstHDW                                         ; point to beginning of program to be copied
EB47 CE01DA                                   ldu     #$1da                                                   ; point to destination
EB4A EC81             tstL01  ldd     ,x++                                                    ; get a word
EB4C EDC1                                     std     ,u++                                                    ; put at destination
EB4E 8CEC3F                                   cmpx    #xslot                                          ; got to end of program?
EB51 25F7                                     blo     tstL01                                          ; no, loopback
EB53 BD01DA                                   jsr     $1da                                                    ; execute copied program in low RAM
EB56 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; test for the presence of MPI, floppies, SDC and update $114 accordingly
                      ; -------------------------------------------------------------------------------------------------------------------------------
EB57 5F               tstHDW  clrb                                                                    ; get zero value
EB58 F70114                                   stb     floSDC                                          ; control byte default value (no hdw found)
EB5B 170089                                   lbsr    tstMPI                                          ; is there an MPI present?
EB5E 10260084                                 lbne    etstHDW                                         ; no, exit
EB62 D776                                     stb     hdwFlo                                          ; no Floppies found
EB64 D777                                     stb     hdwSdc                                          ; no SDC found
                                                                                                                      ; search for SDC and/or floppies
EB66 B603FF                                   lda     cpyMPIcfg                                       ; get active MPI slot
EB69 C604                                     ldb     #4                                                              ; ready to check four slots
                                                                                                                      ; first look for SDC
EB6B 0D77             tst01           tst     hdwSdc                                          ; have we found it before?
EB6D 2611                                     bne     tst02                                                   ; yes, go to floppy test
EB6F 170099                                   lbsr    tstSDC                                          ; is there an SDC in this MPI slot?             
EB72 260C                                     bne     tst02                                                   ; no, go to floppy test
EB74 9777                                     sta     hdwSdc                                          ; save slot where SDC has been found
EB76 B60114                                   lda     floSDC                                          ; get hdw control byte
EB79 8A08                                     ora     #%00001000                                      ; add flag for SDC present
EB7B B70114                                   sta     floSDC                                          ; update it
EB7E 2013                                     bra     tst03                                                   ; go process another slot
                                                                                                                      ; if not SDC, then for floppy
EB80 0D76             tst02           tst     hdwFlo                                          ; have we found it before?
EB82 260F                                     bne     tst03                                                   ; go process another slot
EB84 17009B                                   lbsr    tstFLO                                          ; is there a floppy controller in this MPI slot?
EB87 260A                                     bne     tst03                                                   ; no, process another slot
EB89 9776                                     sta     hdwFlo                                          ; save slot where floppy has been found
EB8B B60114                                   lda     floSDC                                          ; get hdw control byte
EB8E 8A04                                     ora     #%00000100                                      ; add flag for Floppies present
EB90 B70114                                   sta     floSDC                                          ; update it
                                                                                                                      ; look at another slot
EB93 B603FF           tst03           lda     cpyMPIcfg                                       ; get analized slot                                                                                                                                             ---     A = $33/$22/$11/$00
EB96 8011                                     suba    #$11                                                    ; calculate previous slot                                                                                                                               ---   A = $22/$11/$00/$EF
EB98 2A02                                     bpl     tst04                                           ; if not negative, skip next
EB9A 8633                                     lda     #$33                                                    ; get upper value                                                                                                                                                       ---   A = $33
EB9C 3402             tst04           pshs    a                                                               ; save new calculated slot number                                                                                                       ---   pushed $22/$11/$00/$33
EB9E B603FF                                   lda     cpyMPIcfg                                       ; get last tested slot value                                                                                                                    ---        A = $33/$22/$11/$00
EBA1 84CC                                     anda    #$cc                                                    ; clean bits 0-1 in both nibbles                                                                                                                ---        A = $00/$00/$00/$00
EBA3 AAE0                                     ora     ,s+                                                     ; add new calculated slot number ($00-$11-$22-$33)                                                              ---        A = $22/$11/$00/$33
EBA5 B703FF                                   sta     cpyMPIcfg                                       ; update copy
EBA8 B7FF7F                                   sta     MPIcfg                                          ; change of I/O slot (not keeping the same ROM slot)                                                    ---  MPIcfg = $22/$11/$00/$33
EBAB 5A                                       decb                                                                    ; decrement slot counter                                                                                                                                ---      B =   3/  2/  1/  0
EBAC 26BD                                     bne     tst01                                                   ; if not zero, loopback
                                                                                                                      ; if zero: end of tests. MPIcfg must be restored to original value
EBAE B60114           tst05           lda     floSDC                                          ; get hdw control byte
EBB1 8508                                     bita    #%00001000                                      ; is bit3 ON (SDC present)?
EBB3 271C                                     beq     tst07                                                   ; no, look for floppies 
EBB5 9677                                     lda     hdwSdc                                          ; get SDC slot                                                                                                                                                          --- A = $00
EBB7 B103FF                                   cmpa    cpyMPIcfg                                       ; equals copy of MPIcfg? 
EBBA 2608                                     bne     tst06                                                   ; no, don't modify floSDC
EBBC F60114                                   ldb     floSDC                                          ; get hdw control byte                                                                                  
EBBF CA03                                     orb     #%00000011                                      ; set floSDC.bits1-0 to #%11 (SDC ON)
EBC1 F70114                                   stb     floSDC                                          ; update control byte
EBC4 8403             tst06           anda    #%00000011                                      ; use just slot number                                                                                                                                  --- A = $00
EBC6 5F                                       clrb                                                                    ; result = 0                                                                                                                                                            --- B = 0
EBC7 44                                       lsra                                                                    ; send bit 0 to carry                                                                                                                                   --- A = 0, C = 0
EBC8 56                                       rorb                                                                    ; receive bit0 from carry in bit7                                                                                                       --- B = 0
EBC9 44                                       lsra                                                                    ; send bit 1 (now 0) to carry                                                                                                                   --- A = 0, C = 0
EBCA 56                                       rorb                                                                    ; receive bit1 (now 0) from carry in bit7 and bit6 goes to bit7                 --- B = 0
EBCB FA0114                                   orb     floSDC                                          ; update bits 7-6 of $114 with slot used by SDC                                                                 --- floSDC.bits5-4 = %00
EBCE F70114                                   stb     floSDC                                          ; save new value
EBD1 B60114           tst07           lda     floSDC                                          ; get hdw control byte
EBD4 8504                                     bita    #%00000100                                      ; is bit2 ON (floppies present)?
EBD6 270E                                     beq     etstHDW                                         ; no, exit
EBD8 9676                                     lda     hdwFlo                                          ; get floppies slot                                                                                                                                             --- A = $33
EBDA 8403                                     anda    #%00000011                                      ; get just slot number                                                                                                                                  --- A = $03
EBDC 48                                       lsla                                                                    ; move bits 0-1                                                                                                                                                 --- A = $06
EBDD 48                                       lsla                                                                    ; to bits 5-4                                                                                                                                                           --- A = $0C
EBDE 48                                       lsla                                                                    ;                                                                                                                                                                                               --- A = $18
EBDF 48                                       lsla                                                                    ;                                                                                                                                                                                               --- A = $30
EBE0 BA0114                                   ora     floSDC                                          ; update bits 5-4 of $114 with slot used by Floppies                                                    --- floSDC.bits7-6 = %11
EBE3 B70114                                   sta     floSDC                                          ; save new value
EBE6 39               etstHDW rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Tests for the presence of an MPI
                      ; returns zero flag Z=1 if present else Z=0
                      ; by Darren Atkinson (2015)
                      ; modified to support mega-mini-MPI by Pere Serrat (2021)
                      ; -------------------------------------------------------------------------------------------------------------------------------
EBE7 3402             tstMPI  pshs    a                                                               ; save register
EBE9 B603FF                                   lda     cpyMPIcfg                               ; get MPI settings
EBEC 8803                                     eora  #$03                                              ; toggle two low used bits in /SCS nibble
EBEE B703FF                                   sta     cpyMPIcfg                                       ; update copy
EBF1 B7FF7F                                   sta   MPIcfg                                            ; update MPI settings
EBF4 B1FF7F                                   cmpa  MPIcfg                                            ; did it accept the change? MANDATORY. Do not CHANGE it!
EBF7 2704                                     beq   yesMPI                                            ; branch if yes (MPI present), will return with Z=1
EBF9 8601                                     lda     #1                                                              ; will return with Z=0
EBFB 200C                                     bra     noMPI                                                   ; exit
EBFD B603FF           yesMPI  lda     cpyMPIcfg                                       ; get old value
EC00 8803                                     eora    #$03                                                    ; recover modified bits in /SCS
EC02 B703FF                                   sta     cpyMPIcfg                                       ; update copy
EC05 B7FF7F                                   sta     MPIcfg                                          ; back to its old value
EC08 4F                                       clra                                                                    ; make Z=1
EC09 3582             noMPI           puls    a,pc                                                    ; restore register and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Tests for the presence of a CoCo SDC on active slot
                      ; returns zero flag Z=1 if present else to zero
                      ; by Darren Atkinson (2015)
                      ; -------------------------------------------------------------------------------------------------------------------------------
EC0B 3412             tstSDC  pshs    a,x                                                     ; save registers
EC0D 8EFF4A                           ldx   #$ff4a                                            ; point X at Flash registers (FF42 for CoCo)
EC10 861A                             lda   #$1a                                              ; test pattern
EC12 A784                             sta   ,x                                                ; store in data register
EC14 A601                             lda   1,x                                               ; get value from control register
EC16 6F84                             clr   ,x                                                ; clear data register
EC18 A801                             eora  1,x                                               ; get changed bits from control register
EC1A 8118                             cmpa  #$18                                              ; did the expected bits change?
EC1C 2702                             beq   yesSDC                                            ; branch if SDC present, will return with Z=1
EC1E 8601                                     lda     #1                                                              ; will return with Z=0
EC20 3592             yesSDC  puls    a,x,pc                                          ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Test for presence of FDC in active MPI slot.
                      ; Returns with Z=1 if FDC has been found
                      ; by Darren Atkinson (2015)
                      ; -------------------------------------------------------------------------------------------------------------------------------
EC22 3416             tstFLO   pshs  d,x                              ; save registers
EC24 8EFF40                    ldx   #$ff40                           ; address for Dragon DOS controller
EC27 86D0                      lda   #$d0                             ; FORCE INTERRUPT command
EC29 A784                      sta   ,x                               ; send to FDC command register
EC2B 8D0D                      bsr   fdcDelay                         ; delay time
EC2D A684                      lda   ,x                               ; read FDC status to clear INTRQ
EC2F EC02                      ldd   2,x                              ; get FDC sector and data registers
EC31 43                        coma                                   ; invert sector bits only
EC32 ED02                      std   2,x                              ; put both registers back
EC34 8D04                      bsr   fdcDelay                         ; delay time
EC36 A302                      subd  2,x                              ; set Z if read matches write
EC38 3596                      puls  d,x,pc                           ; restore registers and return
EC3A 3437             fdcDelay pshs  y,x,d,cc                         ; push registers
EC3C 3D                        mul                                    ; consume 11 CPU cycles
EC3D 35B7                      puls  cc,d,x,y,pc                      ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to change of MPI-slot and start it 
                      ; it could happen that the new slot has no FDC nor SDC
                      ; but if it had any of them, then floSDC must be adjusted accordingly
                      ; -------------------------------------------------------------------------------------------------------------------------------
EC3F 9DA5             xslot           jsr   <redLChr                                          ; peek at next character after "SLOT"
EC41 804E                     suba  #'N'                                                      ; to detect if it was an 'N' - if so do not switch to MAP0
EC43 9710                     sta   <noexec                                           ; save difference. 0 = do not switch
EC45 2602                     bne   xslot1                                            ; if not 'N' skip next
EC47 9D9F                     jsr   <getNChr                                          ; jump over char 'N'
EC49 BDE785           xslot1  jsr     getunit                                         ; read a number between 1-4
EC4C 2704                                     beq     nogood                                          ; if 0 error
EC4E C104                                     cmpb    #4                                                              ; is it greater than 4?
EC50 2305                                     bls     OKslot                                          ; no, OK
EC52 C60D             nogood  ldb     #$0d                                                    ; MU error
EC54 7E8344                                   jmp     syserr                                          ; bas_system_error
EC57 8D8E             OKslot  bsr     tstMPI                                          ; is there an MPI present?
EC59 2704                                     beq     OKslot01                                                ; yes, skip section
EC5B 17FED9                                   lbsr    NotMPIPresent                           ; no, show message
EC5E 39                                       rts                                                                     ; return
EC5F 5A               OKslot01        decb                                                                    ; slots range 0-3. We use reg B read at function getunit
EC60 D7F8                                     stb     <numUni                                         ; save low nibble --- $00 - $03 if command was SLOTN1 - SLOTN4
EC62 58                                       lslb                                                                    ; move it                       --- $00 - $06
EC63 58                                       lslb                                                                    ; to the                        --- $00 - $0c
EC64 58                                       lslb                                                                    ; high                          --- $00 - $18
EC65 58                                       lslb                                                                    ; nibble                                --- $00 - $30
EC66 DAF8                                     orb     <numUni                                         ; add low nibble ($nn)          --- $00 - $33
EC68 D7F8                                     stb     <numUni                                         ; save calculated code          --- $00 - $33
                                                                                                                      ; now must compare the new slot with the one for FDC and SDC and modify floSDC accordingly
                                                                                                                      ; by definition, switching the slot MUST enable the drives of that slot, so $114 must vary
EC6A C430                                     andb    #%00110000                                      ; get just low bits of high nibble = new slot number    --- $00 - $30
EC6C 3404                                     pshs    b                                                               ; save value                                                                                                            --- $00 - $30
EC6E B60114                                   lda     floSDC                                          ; get hdw control byte                                                                                  --- $3C - $3C if we are in the FDC
EC71 8430                                     anda    #%00110000                                      ; get the slot where the Floppies are                                           --- $30 - $30
EC73 A1E0                                     cmpa    ,s+                                                     ; is new slot where the floppies are?                                           --- NO  - YES
EC75 2607                                     bne     xslot2                                          ; no, compare SDC                                                                                                       --- jmp - mod
EC77 B60114                                   lda     floSDC                                          ; get control value
EC7A 84FC                                     anda    #%11111100                                      ; set both floppies ON
EC7C 2016                                     bra     xslot3                                          ; skip section - no need to verify SDC
EC7E 96F8             xslot2  lda     <numUni                                         ; get new slot number                                                                                   --- $00 - $33
EC80 8430                                     anda    #%00110000                                      ; get just low bits of high nibble = new slot number    --- $00 - $30
EC82 48                                       asla                                                                    ; move 2 bits to 
EC83 48                                       asla                                                                    ; the left                                                                                                                      --- $00 - $00
EC84 3402                                     pshs    a                                                               ; save value                                                                                                            --- $00 - $00
EC86 B60114                                   lda     floSDC                                          ; get control bte
EC89 84C0                                     anda    #%11000000                                      ; get the slot where SD is                                                                              --- $00 - $00
EC8B A1E0                                     cmpa    ,s+                                                     ; is the select one?                                                                                            --- YES - NO
EC8D 2608                                     bne     xslot4                                          ; no, skip two next                                                                                             --- mod - jump
EC8F B60114                                   lda     floSDC                                          ; get control value
EC92 8A03                                     ora     #%00000011                                      ; set both floppies OFF
EC94 B70114           xslot3  sta     floSDC                                          ; update hdw control byte
                                                                                                                              ; this part MUST be run from RAM because we are going
                                                                                                                              ; to lose control when switching the ROM slot!
EC97 8EECA9           xslot4  ldx     #specia2                                                ; point to beginning of code to execute from RAM
EC9A CE01DA                                   ldu     #$1da                                                   ; point at destination
EC9D EC81             xsL01           ldd     ,x++                                                    ; get a word
EC9F EDC1                                     std     ,u++                                                    ; put at destination
ECA1 8CECCD                                   cmpx    #strROM+3                                       ; got to the end?
ECA4 25F7                                     blo     xsL01                                                   ; no, loopback
ECA6 7E01DA                                   jmp     $1da                                                    ; jump to RAM copied code
ECA9 1A50             specia2 orcc    #dimask                                         ; disable interrupts
ECAB 0D10                                     tst     <noexec                                         ; should switch to MAP0?                                                                --- noexec = 0
ECAD 2703                                     beq     specia3                                         ; no, skip next                                                                                 --- apply jump
ECAF 7FFFDE                                   clr     $ffde                                                   ; switch to MAP0 (ROM mode)                                                     --- skipped
ECB2 D6F8             specia3 ldb     <numUni                                         ; get calculated code                                                                   --- B = $cc
ECB4 F703FF                                   stb     cpyMPIcfg                                       ; update copy
ECB7 F7FF7F                                   stb     MPIcfg                                          ; switch to that slot                                                                   --- MPIcfg = $cc
ECBA 0D10                                     tst     <noexec                                         ; called with param N?
ECBC 2601                                     bne     eOKSlot                                         ; no, start slot
ECBE 39                                       rts                                                                     ; return
ECBF CC444B           eOKSlot ldd     #$444b                                          ; signature for O.S.
ECC2 10B3C000                                 cmpd    romini                                          ; is an O.S. at $C000?
ECC6 2602                                     bne     strROM                                          ; no, start RomPack
ECC8 0F71                                     clr     <$71                                                    ; force coldstart
ECCA 7EB3B4           strROM  jmp     resetRt                                         ; reset machine
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; to access floppies or SDC-card
                      ; uses byte floSDC ($114) to determine what it must access
                      ; byte structure: 
                      ;       bit 7-6 - slot number where is the CoCo-SDC  (0-3)
                      ;       bit 5-4 - slot number where are the floppies (0-3)
                      ;       bit 3           - 1 if SDC present else 0
                      ;       bit 2           - 1 if Floppy controller present else 0
                      ;       bit 1           - for Unit #2: if 0 use floppy, if 1 use SDC
                      ;       bit 0           - for Unit #1: if 0 use floppy, if 1 use SDC
                      ; -------------------------------------------------------------------------------------------------------------------------------
ECCD 3401             flOrSd  pshs    cc                                                              ; save register
ECCF B60114                                   lda     floSDC                                          ; get hdw control byte
ECD2 840C                                     anda    #%00001100                                      ; test bits3-2 (SDC and Floppies present)
ECD4 810C                                     cmpa    #%00001100                                      ; are both present?
ECD6 263B                                     bne     eflOr                                                   ; no, exit
ECD8 96EB                                     lda     <$eb                                                    ; get unit number
ECDA 8102                                     cmpa    #2                                                              ; is greater than 2?  --- If 3-4 and SDC present, should change to FDC slot!
ECDC 221D                                     bhi     flo2flo                                         ; yes, switch to floppies
ECDE B60114                                   lda     floSDC                                          ; get hdw control byte
ECE1 94EB                                     anda    <$eb                                                    ; test corresponding bit 0-1 (affected drive)
ECE3 2716                                     beq     flo2flo                                         ; if zero, switch to floppies
                                                                                                                      ; has to switch to slot with SDC (bits 7-6 of floSDC)
ECE5 B60114           flo2SDC lda     floSDC                                          ; get hdw control byte
ECE8 84C0                                     anda    #%11000000                                      ; use bits 7-6 to get slot number
ECEA 44                                       lsra                                                                    ; send them
ECEB 44                                       lsra                                                                    ; to bits 5-4 (2 low bits of high nibble)
ECEC 3402                                     pshs    a                                                               ; save high nibble
ECEE 44                                       lsra                                                                    ; move it
ECEF 44                                       lsra                                                                    ; 4 times to the right
ECF0 44                                       lsra                                                                    ; to have it
ECF1 44                                       lsra                                                                    ; as low nibble
ECF2 AAE0                                     ora     ,s+                                                     ; add high nibble and clean stack
ECF4 B103FF                                   cmpa    cpyMPIcfg                                       ; already in that slot?
ECF7 271A                                     beq     eflOr                                                   ; yes, do nothing
ECF9 2012                                     bra     flOr01                                          ; go update value
                                                                                                                      ; has to switch to slot with floppies (bits 5-4- of floSDC)
ECFB B60114           flo2flo lda     floSDC                                          ; get hdw control byte
ECFE 8430                                     anda    #%00110000                                      ; use bits 5-4 (2 low bits of high nibble)
ED00 3402                                     pshs    a                                                               ; save high nibble
ED02 44                                       lsra                                                                    ; move it
ED03 44                                       lsra                                                                    ; 4 times to the right
ED04 44                                       lsra                                                                    ; to have it
ED05 44                                       lsra                                                                    ; as low nibble
ED06 AAE0                                     ora     ,s+                                                     ; add high nibble and clean stack
ED08 B103FF                                   cmpa    cpyMPIcfg                                       ; already in that slot?
ED0B 2706                                     beq     eflOr                                                   ; yes, do nothing
ED0D B703FF           flOr01  sta     cpyMPIcfg                                       ; update copy
ED10 B7FF7F                                   sta     MPIcfg                                          ; change active MPI slot
ED13 3581             eflOr           puls    cc,pc                                                   ; restore register and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; accept a value to be used as index disc in a HD in unit4 (for DW4)
                      ; -------------------------------------------------------------------------------------------------------------------------------
ED15 BDE785           xHDidx  jsr     getunit                                         ; read a number between 1-90
ED18 C101                                     cmpb    #1                                                              ; value under minimum accepted?
ED1A 10250858                                 lblo    badParam                                                ; yes, show message
ED1E C15A                                     cmpb    #90                                                     ; exceeds the max index number?
ED20 2207                                     bhi     idxBad                                          ; yes, show message
ED22 F70115                                   stb     idxHD                                                   ; save disc index number
ED25 BDE6AA                                   jsr     mrkmod                                          ; mark as modified
ED28 39               exHD            rts                                                                     ; return
ED29 8EE482           idxBad  ldx     #idxHigh-1                                      ; poit to message
ED2C 7E90E5                                   jmp     outstr                                          ; show it
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to deal with SDC-card DRIVE commands (1,2)
                      ; -------------------------------------------------------------------------------------------------------------------------------
ED2F 9DA5             xsdrive jsr     <redLChr                                                ; peek at next char after SDRIVE
ED31 102704BC                                 lbeq    sdcLST                                          ; is the SDRIVE alone
                                                                                                                      ; validate syntax and drive number
ED35 BDE785                                   jsr     getunit                                         ; read a number between 1-2
ED38 1027FCF0                                 lbeq    badnum                                          ; 0 not accepted
ED3C C102                                     cmpb    #2                                                              ; is it greater than 4?
ED3E 1022FCEA                                 lbhi    badnum                                          ; no, ok
                                                                                                                      ; update table of linked DW4 slots back to the number of the drive!     
ED42 8E00FB                                   ldx     #drvtab-1                                       ; point to linked slots -1, because we will use 1-2 as index (instead 0-1)
ED45 E785                                     stb     b,x                                                     ; link unit to DW4 slot with its same number
ED47 5A                                       decb                                                                    ; internally will work with 0-1
ED48 D7F8                                     stb     <numUni                                         ; save received number
ED4A 0FFA                                     clr     <valPar                                         ; value param is 0
ED4C C6E0                                     ldb     #$e0                                                    ; more used value
ED4E D7FB                                     stb     <cmdNum                                         ; store it
ED50 BD89AA                                   jsr     ckComma                                         ; ckcomma. if not comma found syntax error
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; decode token
ED53 81C2                                     cmpa    #$c2                                                    ; is this the token for off?
ED55 1027034F                                 lbeq    flopON                                          ; yes, go process it
ED59 8188                                     cmpa    #$88                                                    ; is this the token for on?
ED5B 10270340                                 lbeq    flopOF                                          ; yes, go process it
ED5F 81B3                                     cmpa    #$b3                                                    ; is this the token for get?
ED61 10270370                                 lbeq    sdcGET                                          ; yes, go process it
ED65 818C                                     cmpa    #$8c                                                    ; is this the token for dim?
ED67 1027035C                                 lbeq    sdcDIM                                          ; yes, go process it
ED6B 81F6                                     cmpa    #$f6                                                    ; is this the token for unload?
ED6D 260B                                     bne     nxtParam                                                ; no, go to params section
ED6F 9D9F                                     jsr     <getNChr                                                ; yes, it is the 'unload' command version. must skip the token to avoid a sn error when done
ED71 CC0100           reuseUL ldd     #$0100                                          ; get 1 byte with value equal null
ED74 FD01D1                                   std     nambuf                                          ; put in nambuf area
ED77 8D60             dTok01  bsr     putCmd                                          ; skip parameters section
ED79 39                                       rts                                                                     ; return
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      
                                                                                                                      ; search for more parameters
ED7A BDB7AA           nxtParam        jsr   getfnam                                           ; read string and length into $1d1 = nambuf
ED7D F601D1                   ldb     nambuf                                          ; is string length 0?
ED80 1027FA05                 lbeq    snError                                         ; yes, show error
ED84 C1FD                     cmpb    #253                                                    ; is string longer than maximum accepted? (253 + m: + final null)
ED86 1024FDA9                                 lbcc    TooLong                                         ; show error message
ED8A 9DA5                                     jsr     <redLChr                                                ; get last read char
ED8C 812C                                     cmpa    #$2c                                                    ; is it a comma?
ED8E 26E7                                     bne     dTok01                                          ; no, end of command. this is 'mount' command version
ED90 9D9F                                     jsr     <getNChr                                                ; get next token
ED92 1027F9F3                                 lbeq    snError                                         ; if no token after comma, show error
ED96 5F                                       clrb                                                                    ; bit 7 value 0 means dsk format
ED97 8197                                     cmpa    #$97                                                    ; is it the token for new?
ED99 2708                                     beq     crtDisc                                         ; yes, create a dsk file
ED9B CA80                                     orb     #$80                                                    ; bit 7 value 1 means sdf format
ED9D 8198                                     cmpa    #$98                                                    ; is it the token for def?
ED9F 1026F9E6                                 lbne    snError                                         ; no, show error message
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; create disc
EDA3 D710             crtDisc stb     <noexec                                         ; save format flag (bit7)
EDA5 17050A                                   lbsr    addExt                                          ; add extension to the file name
EDA8 9D9F                                     jsr     <getNChr                                                ; get next char
EDAA 812C                                     cmpa    #$2c                                                    ; is it a comma?
EDAC 2707                                     beq     crt01                                                   ; yes, test size parameter
EDAE 8601                                     lda     #1                                                              ; by default type=1
EDB0 8E00B4                                   ldx     #180                                                    ; and will be 180k (720 sectors)
EDB3 201A                                     bra     crtstep                                         ; exit cheks
EDB5 9D9F             crt01           jsr     <getNChr                                                ; advance one char. mandatory for next routine
EDB7 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into x
EDBA 8601                                     lda     #1                                                              ; 1 will mean 180k dragon-like disc (40 tracks 1 side)
EDBC 8C00B4                                   cmpx    #180                                                    ; equals read value 180?
EDBF 270E                                     beq     crtstep                                         ; yes, exit checks
EDC1 4C                                       inca                                                                    ; 2 will mean 360k dragon-like disc (40 tracks 2 sides)
EDC2 8C0168                                   cmpx    #360                                                    ; equals read value 360?
EDC5 2708                                     beq     crtstep                                         ; yes, exit checks
EDC7 4C                                       inca                                                                    ; 3 will mean 720k dragon-like disc (80 tracks 2 sides)
EDC8 8C02D0                                   cmpx    #720                                                    ; equals read value 720?
EDCB 1026FD60                                 lbne    BadFormat                                       ; not, bad format number, show error
EDCF 9B10             crtstep adda    <noexec                                         ; add disc type to format flag
EDD1 9710                                     sta     <noexec                                         ; save calculated value ($01-02-03 or $81-82-83)
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; entries to send command to the sdc
                                                                                                                      ; entry for create new disc comands
EDD3 CC4E3A                                   ldd     #"N:"                                                   ; command to be sent to create a file
EDD6 8D06                                     bsr     putCmd2                                         ; send command
EDD8 39               noMsgEr rts                                                                     ; return
                                                                                                                      ; entry for mount - unmount like commands
EDD9 0F10             putCmd          clr     <noexec                                         ; no params needed (no disk to be created)
EDDB CC4D3A                                   ldd     #"M:"                                                   ; command to be sent to mount or unmount a drive
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; detect if sdc is already active
EDDE 0F77             putCmd2 clr     hdwSdc                                          ; no need to go back to old active slot
EDE0 17FE28                                   lbsr    tstSDC                                          ; is there an active sdc?
EDE3 2733                                     beq     xsd01                                                   ; yes, go on
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; if present but not active change to that slot, save old one                   
                                                                                                                      ; if sdc present, active it and mark somewhere that we must go back to the active one!
EDE5 3406                                     pshs    d                                                               ; save registers
EDE7 B60114                                   lda     floSDC                                          ; get hdw control byte
EDEA 8508                                     bita    #%00001000                                      ; is a sdc in the system?
EDEC 260E                                     bne     vfySD01                                         ; yes, jump section
EDEE 3264                                     leas    4,s                                                     ; get rid of d and 1 return address
EDF0 AEE4                                     ldx     ,s                                                              ; see if return address is $0900 (from sdir?)
EDF2 8C0900                                   cmpx    #$0900                                          ; comes from sdir?
EDF5 2602                                     bne     vfySD00                                         ; no, skip next
EDF7 3262                                     leas    2,s                                                     ; clean stack                                                                   
EDF9 16FD3F           vfySD00 lbra    NotSDCPresent                           ; no, show message
                                                                                                                      ; calculate sdc slot
EDFC B60114           vfySD01 lda     floSDC                                          ; get hdw control byte
EDFF 84C0                                     anda    #%11000000                                      ; use bits 7-6 (slot where sdc is)
EE01 44                                       lsra                                                                    ; move them to
EE02 44                                       lsra                                                                    ; bits 5-4 (lower bits of high nibble)
EE03 3402                                     pshs    a                                                               ; save high nibble
EE05 44                                       lsra                                                                    ; low nibble   
EE06 44                                       lsra                                                                    ; gets high nibble
EE07 44                                       lsra                                                                    ; that will end  
EE08 44                                       lsra                                                                    ; as zero
EE09 AAE0                                     ora     ,s+                                                     ; add high nibble (now they are the same value)
                                                                                                                      ; save active slot in hdwsdc
EE0B F603FF                                   ldb     cpyMPIcfg                                       ; get active slot
EE0E D777                                     stb     hdwSdc                                          ; save it for later use                                         
EE10 B703FF                                   sta     cpyMPIcfg                                       ; update copy
EE13 B7FF7F                                   sta     MPIcfg                                          ; activate sdc
EE16 3506                                     puls    d                                                               ; restore registers
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; pass string to data buffer
EE18 8E01D2           xsd01           ldx   #nambuf+1                                 ; point to 1st char of the input string
EE1B CE0800                                   ldu     #$0800                                          ; point to 1st dos buffer
EE1E EDC1                                     std     ,u++                                                    ; put at the beginning of the command buffer
EE20 F601D1                                   ldb     nambuf                                          ; get string length
EE23 A680             str2buf lda     ,x+                                                     ; get a char from input string
EE25 A7C0                                     sta     ,u+                                                     ; copy in the buffer
EE27 5A                                       decb                                                                    ; decrement counter
EE28 26F9                                     bne     str2buf                                         ; not yet done, loopback
EE2A 6FC4                                     clr     ,u                                                              ; put a final zero
EE2C 0D10                                     tst     <noexec                                         ; was sdf format?
EE2E 2B06                                     bmi     addParms                                                ; yes, put params: cylinders and sides into b:x
                                                                                                                              ; the other varians send these registers with zero value                        
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; params to be passed (b:x)
EE30 D6FA                                     ldb     <valPar                                         ; get b parameter value
EE32 9E8A                                     ldx     <$8a                                                    ; 16 bits zero                                  
EE34 2015                                     bra     sendIt                                          ; send the command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; special parameters for command 'create disc' (b:x)
EE36 9610             addParms        lda     <noexec                                         ; get disc type
EE38 8403                                     anda    #$03                                                    ; use lowest nibble
EE3A C628                                     ldb     #$28                                                    ; minimum value 40 cylinders
EE3C 8103                                     cmpa    #3                                                              ; was type 3 (2880 sectors)?
EE3E 2601                                     bne     addP01                                          ; no, skip next
EE40 58                                       aslb                                                                    ; double cylinders number
EE41 8E0100           addP01  ldx     #$0100                                          ; one side by default
EE44 8101                                     cmpa    #1                                                              ; was type 0 or 1 (630 - 720 sectors)?
EE46 2303                                     bls     sendIt                                          ; yes, skip next
EE48 8E0200                                   ldx     #$0200                                          ; set double sided
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; send command to the sdc
                                                                                                                              ; b:x have zeros or tracks:sides (at x-high byte)
EE4B 96FB             sendIt  lda     <cmdNum                                         ; code for extended command with data block
EE4D 9BF8                                     adda    <numUni                                         ; add drive number
EE4F CE0800                                   ldu     #$0800                                          ; point to beginning of data block
EE52 BDF82D                                   jsr     CommSDC                                         ; send command to sdc-card with (a,b:x,u)
EE55 2438                                     bcc     send01                                          ; if ok, skip section
                                                                                                                      ; if error $10 and sdir command, show message (not error)
EE57 C510                                     bitb    #$10                                                    ; is bit 4 set?
EE59 2714                                     beq     nxtCEr                                          ; no, goto next control
EE5B 3406                                     pshs    d                                                               ; save registers
EE5D 96FA                                     lda     <valPar                                         ; get parameter used
EE5F 8143                                     cmpa    #'C'                                                    ; was it a 'C' (sdir)?
EE61 2608                                     bne     send00                                          ; no, exit
EE63 8D19                                     bsr     currentDirIsRoot                        ; show message
EE65 3506                                     puls    d                                                               ; restore registers
EE67 1A01                                     orcc    #%00000001                                      ; set carry to mark error
EE69 2027                                     bra     send02                                          ; exit
EE6B 3506             send00  puls    d                                                               ; clean stack
EE6D 2020                                     bra     send01                                          ; exit
                                                                                                                      ; if error $08 and get-dim command, show message (not error)
EE6F C508             nxtCEr  bitb    #$08                                                    ; is bit 3 set?
EE71 271C                                     beq     send01                                          ; no, skip section
EE73 84F0                                     anda    #$f0                                                    ; use high nibble
EE75 81C0                                     cmpa    #$c0                                                    ; was command $cn (get-dim)?
EE77 2616                                     bne     send01                                          ; no, go on
EE79 1A01                                     orcc    #%00000001                                      ; set carry to mark error
EE7B 160220                                   lbra    exsdrv1                                         ; exit
EE7E                  currentDirIsRoot                                                                ; current dir = root!
EE7E 96F9                                     lda     <numDir                                         ; get number of directories requested in a series
EE80 8101                                     cmpa    #1                                                              ; is first one?
EE82 260A                                     bne     curNoMsg                                                ; no, do not show message
EE84 3450                                     pshs    x,u                                                     ; save registers
EE86 8EE492                                   ldx     #noCurDir-1                                     ; point to message
EE89 BD90E5                                   jsr     outstr                                          ; show it
EE8C 3550                                     puls    x,u                                                     ; restore registers
EE8E 39               curNoMsg        rts                                                                     ; return
EE8F 17096B           send01  lbsr    vfyStatus                                       ; verify operation result
EE92 0D10             send02  tst     <noexec                                         ; test format type
EE94 10270206                                 lbeq    exsdrv1                                         ; if coco-like 160k, all done, exit. should never happen
EE98 102B0202                                 lbmi    exsdrv1                                         ; if sdf type, all done, exit   
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; additional swrite command for dragon-like disks
                                                                                                                      ; these three need a swrite,39(79),18(36),"",""
                                                                                                                      ; x must have the lsn number: 719,1439,2879
EE9C 8E02CF                                   ldx     #719                                                    ; to have 720 sectors
EE9F 9610                                     lda     <noexec                                         ; get disc type
EEA1 8403                                     anda    #3                                                              ; use lowest 2 bits
EEA3 8101                                     cmpa    #1                                                              ; is it a 180k (720 sectors) disc? 
EEA5 270A                                     beq     sendWrt                                         ; yes, send write order
EEA7 8E059F                                   ldx     #1439                                                   ; to force 1440 sectors
EEAA 8102                                     cmpa    #2                                                              ; is it a 360k (1440 sectors) disc?
EEAC 2703                                     beq     sendWrt                                         ; yes, send write order
EEAE 8E0B3F                                   ldx     #2879                                                   ; to force 2880 sectors
                                                                                                      ; *** ADDED CODE TO SUPPORT VDK FORMAT CREATING FILES   
                                                                                                                      ; here we must test the file extension to be ".VDK"
EEB1 0F76             sendWrt clr     <dsktyp                                         ; Now equals 0 = DSK
EEB3 CE01D1                                   ldu     #nambuf                                         ; point to filename buffer
EEB6 E6C4                                     ldb     ,u                                                              ; get filename length
EEB8 C003                                     subb    #3                                                              ; to point to the possible dot (.) if .VDK was entered
EEBA 33C5                                     leau    b,u                                                     ; point to it
EEBC CC2E56                                   ldd     #".V"                                                   ; get dot and letter V
EEBF 10A3C1                                   cmpd    ,u++                                                    ; have we received it?
EEC2 260C                                     bne     sWrt01                                          ; no, skip section
EEC4 CC444B                                   ldd     #"DK"                                                   ; get string DK
EEC7 10A3C4                                   cmpd    ,u                                                              ; have we received it?
EECA 2604                                     bne     sWrt01                                          ; no, skip section
                                                                                                                      ; now we know the user wants to create a virtual VDK file
EECC 3001                                     leax    1,x                                                     ; so that the disk has an extra sector (for the header)                                                                 
EECE 0C76                                     inc     <dsktyp                                         ; now is 1 = VDK
                                                                                                      ; *** END_ADDED CODE TO SUPPORT VDK FORMAT CREATING FILES       
EED0 CE0800           sWrt01  ldu     #$0800                                          ; point to beginning of buffer
EED3 4F                                       clra                                                                    ; create a  
EED4 5F                                       clrb                                                                    ; 16 bits zero
EED5 EDC1             cleanBuf        std     ,u++                                                    ; clean a word
EED7 11830900                                 cmpu    #$0900                                          ; reached buffers end?
EEDB 25F8                                     blo     cleanBuf                                                ; no, loopback
EEDD CE0800                                   ldu     #$0800                                          ; point to buffers beginning
EEE0 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EEE2 9BF8                                     adda    <numUni                                         ; add drive number
EEE4 BDF82D                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EEE7 170913                                   lbsr    vfyStatus                                       ; verify operation result
                                                                                                      ; *** ADDED CODE TO FORMAT ON THE FLY DSK and VDK FILES
                                                                                                                      ; as the buffer is clean, we just need to fill bytes 0-19
                                                                                                                              ; for a VDK file, we will write a suitable header to sector #0
                                                                                                                              ; it should contain:
                                                                                                                              ;  position             length contents                                  value
EEEA CC646B                                   ldd     #"dk"                                                   ;       offset 0     2     signature               ('dk')
EEED EDC1                                     std     ,u++
EEEF CC0001                                   ldd     #$0001                                          ;       offset 2     2     Header length           ($00, $01) = $100
EEF2 EDC1                                     std     ,u++
EEF4 CC1010                                   ldd     #$1010                                          ;       offset 4     1     VDK version - actual    ($10)
EEF7 EDC1                                     std     ,u++                                                    ;       offset 5     1     VDK version - compat    ($10)
EEF9 CC8800                                   ldd     #$8800                                          ;       offset 6     1     Source id               ($88)
EEFC EDC1                                     std     ,u++                                                    ;       offset 7     1     Source version          ($00)
EEFE 108E2801                                 ldy     #$2801                                          ; 40 tracks 01 side (180k)
EF02 9610                                     lda     <noexec                                         ; get disc type
EF04 8403                                     anda    #3                                                              ; use lowest 2 bits
EF06 8101                                     cmpa    #1                                                              ; is it a 180k disc? 
EF08 270A                                     beq     noMore2                                         ; yes, send write order
EF0A 3121                                     leay    1,y                                                     ; to force double sided ($2802)
EF0C 8102                                     cmpa    #2                                                              ; is it a 360k disc?
EF0E 2704                                     beq     noMore2                                         ; yes, send write order
EF10 108E5002                                 ldy     #$5002                                          ; it is a 720k disk
EF14 1F20             noMore2 tfr     y,d                                                     ; pass geodata to regD
EF16 97F2                                     sta     <$f2                                                    ; number of tracks to DOS system variable
EF18 5A                                       decb                                                                    ; because 0 means 1 side
EF19 D7F4                                     stb     <$f4                                                    ; number of sides to DOS system variable
                                                                                                                              ;       offset 8     1     Number of tracks        ($28)          40 or 80 --> ($28 or $50)
EF1B 10AFC1                                   sty     ,u++                                                    ;       offset 9     1     Number of sides         ($01)          1 or 2
EF1E CC0040                                   ldd     #$0040                                          ;       offset 10    1     Flags                   ($00)
EF21 EDC1                                     std     ,u++                                                    ;       offset 11    1     Comp & Name length      ($40)          bits 0-2 = compression [0=off, >0=TBD]
                                                                                                                              ;                                                                           bits 3-7 = filename length [min 0, max 31]
EF23 8E01D1                                   ldx     #nambuf                                         ;       offset 12    0-31  Disk name               (...)          (OPTIONAL) filename in ASCII. Doesn't need a zero terminator
EF26 E680                                     ldb     ,x+                                                     ; get filename length
EF28 C004                                     subb    #4                                                              ; subtract 4 to have the actual name without dot and extension
EF2A A680             cpy2buf lda     ,x+                                                     ; get a char from name
EF2C A7C0                                     sta     ,u+                                                     ; put into buffer
EF2E 5A                                       decb                                                                    ; decrement counter
EF2F 26F9                                     bne     cpy2buf                                         ; if not done, loopback, regB ends with value Zero
EF31 CE0800                                   ldu     #$0800                                          ; point to buffers beginning
EF34 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EF36 9BF8                                     adda    <numUni                                         ; add drive number
EF38 8E0000                                   ldx     #$0000                                          ; to point to sector 0 (header)
EF3B BDF82D                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EF3E 1708BC                                   lbsr    vfyStatus                                       ; verify operation result
                                                                                                                      ; Once we have the header, we must add 20 tracks of $e5 bytes
EF41 8E0800                                   ldx     #$0800                                          ; to use this buffer
EF44 9FEE                                     stx     <$ee                                                    ; update system pointer
EF46 BDE13A                                   jsr     filbuf                                          ; will fill it with bytes value $E5
EF49 CC1412                                   ldd     #$1412                                          ; get number of tracks to write (20) and numsectors x track
EF4C 0DF4                                     tst     <$f4                                                    ; is single sided?
EF4E 2701                                     beq     noDouble                                                ; yes, do not double
EF50 58                                       aslb                                                                    ; double number of sectors x track
EF51 3D               noDouble        mul                                                                     ; calculate total number of sector to write
EF52 1F02                                     tfr     d,y                                                     ; pass value to regY
EF54 8E0001                                   ldx     #1                                                              ; 1st sector (LSN) to be written for a VDK file
EF57 0D76                                     tst     <dsktyp                                         ; are we creating a VDK?
EF59 2602                                     bne     nSector                                         ; yes, skip next
EF5B 301F                                     leax    -1,x                                                    ; 1st LSN for a DSK file (and so rewrite the header!)
EF5D 3430             nSector pshs    x,y                                                     ; save variables
EF5F CE0800                                   ldu     #$0800                                          ; point to buffers beginning
EF62 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EF64 9BF8                                     adda    <numUni                                         ; add drive number
EF66 5F                                       clrb                                                                    ; higher byte to zero
EF67 BDF82D                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EF6A 170890                                   lbsr    vfyStatus                                       ; verify operation result
EF6D 3530                                     puls    x,y                                                     ; restore variables
EF6F 3001                                     leax    1,x                                                     ; point to next LSN
EF71 313F                                     leay    -1,y                                                    ; decrement counter
EF73 26E8                                     bne     nSector                                         ; if not done, loopback 
EF75 3410                                     pshs    x                                                               ; put next LSN on stack
                                                                                                                      ; now we must add 1st FAT sector
EF77 BDE17D                                   jsr     ffat1                                                   ; buffer: $800. fills 1st FAT sector upon geodata
EF7A CE0800                                   ldu     #$0800                                          ; point to buffers beginning
EF7D 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EF7F 9BF8                                     adda    <numUni                                         ; add drive number
EF81 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
EF82 AEE4                                     ldx     ,s                                                              ; get LSN from stack
EF84 BDF82D                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EF87 170873                                   lbsr    vfyStatus                                       ; verify operation result
                                                                                                                      ; let's try the same for track 16 (backup DIR)
                                                                                                                      ; we have to calculate the first sector for that track
EF8A 8610                                     lda     #16                                                     ; number of track to write on
EF8C C612                                     ldb     #18                                                     ; number of sectors x track if single sided disk
EF8E 0DF4                                     tst     <$f4                                                    ; is double sided?
EF90 2701                                     beq     1f                                                              ; no, skip next
EF92 58                                       aslb                                                                    ; double sectors x track
EF93 3D               1                       mul                                                                     ; to get sectors before sector 1 track 16
EF94 0D76                                     tst     <dsktyp                                         ; is it a VDK?
EF96 2703                                     beq     2f                                                              ; no, skip next
EF98 C30001                                   addd    #1                                                              ; add a sector (header)
EF9B DDD9             2                       std     <fST16                                          ; save that value for later use
                                                                                                                      ; now write 1st sector Track 16
EF9D CE0800                                   ldu     #$0800                                          ; point to buffers beginning
EFA0 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EFA2 9BF8                                     adda    <numUni                                         ; add drive number
EFA4 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
EFA5 9ED9                                     ldx     <fST16                                          ; get LSN from variable
EFA7 BDF82D                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EFAA 170850                                   lbsr    vfyStatus                                       ; verify operation result
                                                                                                                      ; now we must add 2nd FAT sector
EFAD BDE1D2                                   jsr     ffat2                                                   ; buffer: $900. fills 2nd FAT sector upon geodata
EFB0 CE0900                                   ldu     #$0900                                          ; point to buffers beginning
EFB3 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EFB5 9BF8                                     adda    <numUni                                         ; add drive number
EFB7 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
EFB8 AEE4                                     ldx     ,s                                                              ; get previous LSN from stack
EFBA 3001                                     leax    1,x                                                     ; increment number
EFBC AFE4                                     stx     ,s                                                              ; update it
EFBE BDF82D                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EFC1 170839                                   lbsr    vfyStatus                                       ; verify operation result
                                                                                                                      ; and do the same for Track 16
EFC4 CE0900                                   ldu     #$0900                                          ; point to buffers beginning
EFC7 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EFC9 9BF8                                     adda    <numUni                                         ; add drive number
EFCB 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
EFCC 9ED9                                     ldx     <fST16                                          ; get previous LSN from variable
EFCE 3001                                     leax    1,x                                                     ; increment number
EFD0 9FD9                                     stx     <fST16                                          ; update it
EFD2 BDF82D                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EFD5 170825                                   lbsr    vfyStatus                                       ; verify operation result
                                                                                                                      ; now we go for the 16 directory sectors with entries ...
EFD8 BDE15E                                   jsr     fil16s                                          ; buffer: $a00. fills a sector to be used as diretory sector (3-18)
EFDB C610                                     ldb     #16                                                     ; number of sectors to write
EFDD 3510                                     puls    x                                                               ; get previous LSN from stack
EFDF 3001                                     leax    1,x                                                     ; increment LSN number
EFE1 3414             nDSect  pshs    b,x                                                     ; save variables
EFE3 CE0A00                                   ldu     #$0a00                                          ; point to buffers beginning
EFE6 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EFE8 9BF8                                     adda    <numUni                                         ; add drive number
EFEA 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
EFEB BDF82D                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EFEE 17080C                                   lbsr    vfyStatus                                       ; verify operation result
EFF1 3514                                     puls    b,x                                                     ; restore variables
EFF3 3001                                     leax    1,x                                                     ; increment LSN number
EFF5 5A                                       decb                                                                    ; decrement sector counter
EFF6 26E9                                     bne     nDSect                                          ; not done, loop
EFF8 3410                                     pshs    x                                                               ; save next LSN (rest of the disk)
                                                                                                                      ; and do the same for Track16 too
EFFA C610                                     ldb     #16                                                     ; number of sectors to write
EFFC 9ED9                                     ldx     <fST16                                          ; get previous LSN from variable
EFFE 3001                                     leax    1,x                                                     ; increment LSN number
F000 3414             n16Sect pshs    b,x                                                     ; save variables
F002 CE0A00                                   ldu     #$0a00                                          ; point to buffers beginning
F005 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
F007 9BF8                                     adda    <numUni                                         ; add drive number
F009 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
F00A BDF82D                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
F00D 1707ED                                   lbsr    vfyStatus                                       ; verify operation result
F010 3514                                     puls    b,x                                                     ; restore variables
F012 3001                                     leax    1,x                                                     ; increment LSN number
F014 5A                                       decb                                                                    ; decrement sector counter
F015 26E9                                     bne     n16Sect                                         ; not done, loop
                                                                                                                      ; finally we will write the rest of the sectors with $e5
                                                                                                                      ; X points to next LSN. end od disk might be: 720, 1440, 2880 (due to the header)
F017 8E0800                                   ldx     #$0800                                          ; to use this buffer again
F01A 9FEE                                     stx     <$ee                                                    ; update system pointer
F01C BDE13A                                   jsr     filbuf                                          ; will fill it with bytes value $E5
F01F 3510                                     puls    x                                                               ; get LSN for rest of the disk from stack
F021 108E02D1                                 ldy     #721                                                    ; value to detect end of disk for 180k disk
F025 9610                                     lda     <noexec                                         ; get disc type
F027 8403                                     anda    #3                                                              ; use lowest 2 bits
F029 8101                                     cmpa    #1                                                              ; is it a 180k (720 sectors) disk? 
F02B 270C                                     beq     1f                                                              ; yes, send write order
F02D 108E05A1                                 ldy     #1441                                                   ; to detect end of 360 disk
F031 8102                                     cmpa    #2                                                              ; is it a 360k (1440 sectors) disk?
F033 2704                                     beq     1f                                                              ; yes, send write order
F035 108E0B41                                 ldy     #2881                                                   ; to detect end of 720k disk
F039 0D76             1                       tst     <dsktyp                                         ; are we creating a VDK file?
F03B 2602                                     bne     nRDisk                                          ; yes, skip next
F03D 313F                                     leay    -1,y                                                    ; subtract 1 (no header for DSK)
F03F 3430             nRDisk  pshs    x,y                                                     ; save registers (LSN, endOfFile)
F041 CE0800                                   ldu     #$0800                                          ; point to buffers beginning
F044 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
F046 9BF8                                     adda    <numUni                                         ; add drive number
F048 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
F049 BDF82D                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
F04C 1707AE                                   lbsr    vfyStatus                                       ; verify operation result
F04F 3510                                     puls    x                                                               ; restore LSN number
F051 3001                                     leax    1,x                                                     ; increment LSN number
F053 ACE4                                     cmpx    ,s                                                              ; is X greater than Y (in the stack)
F055 3520                                     puls    y                                                               ; to balance stack
F057 26E6                                     bne     nRDisk                                          ; not done, loop
                                                                                                                      ; call SDRIVE n,UNLOAD
                                                                                                                      ; first we must save the filename from nambuf or it will be lost
                                                                                                                      ; we need from nambuf to nambuf + 12 (8 plus dot plus VDK)
F059 8E0A00                                   ldx     #$a00                                                   ; point to last DOS buffer
F05C CE01D1                                   ldu     #nambuf                                         ; point to filename buffer
F05F C60D                                     ldb     #13                                                     ; number of bytes to copy
F061 A6C0             1                       lda     ,u+                                                     ; get a byte from filename buffer
F063 A780                                     sta     ,x+                                                     ; put into DOS buffer
F065 5A                                       decb                                                                    ; decrement counter
F066 26F9                                     bne     1b                                                              ; not done, loop
F068 0FFA                                     clr     <valPar                                         ; value param is 0
F06A C6E0                                     ldb     #$e0                                                    ; more used value
F06C D7FB                                     stb     <cmdNum                                         ; store it
F06E BDED71                                   jsr     reuseUL                                         ; call final part of SDRIVEx,UNLOAD
F071 8E0A00                                   ldx     #$a00                                                   ; point to last DOS buffer
F074 CE01D1                                   ldu     #nambuf                                         ; point to filename buffer
F077 C60D                                     ldb     #13                                                     ; number of bytes to copy
F079 A680             1                       lda     ,x+                                                     ; get a byte from DOS buffer
F07B A7C0                                     sta     ,u+                                                     ; put into filename buffer
F07D 5A                                       decb                                                                    ; decrement counter
F07E 26F9                                     bne     1b                                                              ; not done, loop
F080 0FFA                                     clr     <valPar                                         ; value param is 0
F082 C6E0                                     ldb     #$e0                                                    ; more used value
F084 D7FB                                     stb     <cmdNum                                         ; store it
F086 BDED77                                   jsr     dTok01                                  ; call SDRIVE n,"received FILENAME.VDK"
F089 9677                                     lda     hdwSdc                                          ; is here the old slot?
F08B 2706                                     beq     1f                                                              ; no, exit
F08D B703FF                                   sta     cpyMPIcfg                                       ; update copy
F090 B7FF7F                                   sta     MPIcfg                                          ; active it
F093 39               1                       rts                                                                     ; return
                                                                              ; *** END_ADDED CODE TO SUPPORT VDK AND DSK FORMAT WHILE CREATING FILES 
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; restore old slot if needed
F094 9677             exsdrv  lda     hdwSdc                                          ; is here the old slot?
F096 2706                                     beq     exsdrv1                                         ; no, exit
F098 B703FF                                   sta     cpyMPIcfg                                       ; update copy
F09B B7FF7F                                   sta     MPIcfg                                          ; active it
F09E 39               exsdrv1 rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; special command floppy off
F09F 8D0F             flopOF  bsr     flopCom                                         ; see if it could be done
F0A1 FA0114                                   orb     floSDC                                          ; add to hdw control byte (a bit to 1 disables floppy and enables sdc)
F0A4 F70114           eflop           stb     floSDC                                          ; update hdw control byte
F0A7 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; special command floppy on
F0A8 8D06             flopON  bsr     flopCom                                         ; see if it could be done
F0AA 53                                       comb                                                                    ; invert all bits: %00000001 - %00000010 convert to %11111110 - %11111101
F0AB F40114                                   andb    floSDC                                          ; a bit 0 enables floppy and disables sdc
F0AE 20F4                                     bra   eflop                                                     ; update and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; common part for floppy on-off
F0B0 9D9F             flopCom jsr     <getNChr                                                ; skip token to avoid sn error when returning
F0B2 F60114                                   ldb     floSDC                                          ; get hdw control byte
F0B5 C40C                                     andb    #%00001100                                      ; see if switching is possible
F0B7 C10C                                     cmpb    #%00001100                                      ; are both floppies and sdc present?
F0B9 2604                                     bne     notAllow                                                ; no, show error message
F0BB D6F8                                     ldb     <numUni                                         ; get drive number (0-1)
F0BD 5C                                       incb                                                                    ; convert to 1-2
F0BE 39                                       rts                                                                     ; return
F0BF 3262             notAllow leas   2,s                                                     ; clean stack (is inside one subroutine)
F0C1 8EE4A7                                   ldx     #canNot-1                                       ; point to message
F0C4 7E90E5                                   jmp     outstr                                          ; show it and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; special command dim
F0C7 8651             sdcDIM  lda     #'Q'                                                    ; param to send into b
F0C9 8D14                                     bsr     sdcDAT                                          ; process it
F0CB 2527                                     bcs     noDiscEr                                                ; if got "not disc" error, explain it
F0CD 170134                                   lbsr    shwDIM                                          ; show received data
F0D0 8DC2             rstSlot bsr     exsdrv                                          ; restore slot if needed
F0D2 1CFE                                     andcc   #%11111110                                      ; clear carry flag
F0D4 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; special command get
F0D5 8649             sdcGET  lda     #'I'                                                    ; param to send into b
F0D7 8D06                                     bsr     sdcDAT                                          ; process it
F0D9 2519                                     bcs     noDiscEr                                                ; if got "not disc" error, explain it
F0DB 8D24                                     bsr     shwGET                                          ; show received data
F0DD 20F1                                     bra     rstSlot                                         ; restore slot if needed
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; common part for get-dim
F0DF 97FA             sdcDAT  sta     <valPar                                         ; save it
F0E1 9D9F                                     jsr     <getNChr                                                ; skip read token
F0E3 86C0                                     lda     #$c0                                                    ; command to send
F0E5 97FB                                     sta     <cmdNum                                         ; save it
F0E7 CC0100                                   ldd     #$0100                                          ; get 1 byte with value equal null
F0EA FD01D1                                   std     nambuf                                          ; put in nambuf area (no name)
F0ED 0F10                                     clr     <noexec                                         ; no additional command needed
F0EF DC8A                                     ldd     <$8a                                                    ; get 16 bits zero
F0F1 7EEDDE                                   jmp     putCmd2                                         ; send command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; message no disc in drive
F0F4 96F8             noDiscEr        lda     <numUni                                         ; gets 0-1
F0F6 8B31                                     adda    #$31                                                    ; converts to '1'-'2'
F0F8 BDB54A                                   jsr     outchr                                          ; show drive number
F0FB 8EE4B5                                   ldx     #sdcNoDsc-1                                     ; point to message
F0FE 7E90E5                                   jmp     outstr                                          ; show it
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show received 'get' info
F101 96F8             shwGET  lda     <numUni                                         ; get drive number
F103 8B31                                     adda    #$31                                                    ; converts to '1'-'2'
F105 BDB54A                                   jsr     outchr                                          ; show drive number
F108 863A                                     lda     #':'                                                    ; get char ':'
F10A BDB54A                                   jsr     outchr                                          ; show it
                                                                                                                      ; show drive status
F10D 866F                                     lda     #'o'                                                    ; get fixed 1st letter
F10F BDB54A                                   jsr     outchr                                          ; show it
F112 866E                                     lda     #'n'                                                    ; get on as default
F114 D6F8                                     ldb     <numUni                                         ; get drive unit
F116 5C                                       incb                                                                    ; convert  0-1 into 1-2
F117 F40114                                   andb    floSDC                                          ; test corresponding bit of hdw control byte
F11A 2607                                     bne     sdcS00                                          ; if not zero, skip next
F11C 8666                                     lda     #'f'                                                    ; get value for off
F11E BDB54A                                   jsr     outchr                                          ; put first 'f'
F121 200D                                     bra     sdcS01                                          ; go put 2nd one instead of space
F123 BDB54A           sdcS00  jsr     outchr                                          ; show result
F126 8620                                     lda     #32                                                     ; get space as inverted block to poke it
F128 9E88                                     ldx     <$88                                                    ; get cursor address
F12A A780                                     sta     ,x+                                                     ; put inverse space there
F12C 9F88                                     stx     <$88                                                    ; update cusor address
F12E 2003                                     bra     sdcS02                                          ; skip next
F130 BDB54A           sdcS01  jsr     outchr                                          ; show it
F133 8D6D             sdcS02  bsr     shwFdat                                         ; show filename and type
F135 33C811                                   leau    17,u                                                    ; jump to length bytes
F138 8D06                                     bsr     shwFL                                                   ; show file length
F13A 860D                                     lda     #$0d                                                    ; get enter value
F13C BDB54A                                   jsr     outchr                                          ; print it
F13F 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show file length - structure of the fac
                                                                                                                      ;       $50 highest byte        --- always $00
                                                                                                                      ;       $51 high byte           --- high byte of u
                                                                                                                      ;       $52 mid  byte           --- low  byte of u
                                                                                                                      ;       $53 lower byte          --- reg. a ($00 = multiple of 256)
F140 A642             shwFL           lda 2,u                                                         ; get highest byte in A
F142 E641                                     ldb 1,u                                                         ; get high byte in B
F144 3406                                     pshs d                                                          ; hold on
F146 A6C4                                     lda ,u                                                          ; now get mid and low bytes
F148 E65F                                     ldb -1,u
F14A 3540                                     puls u
                      ; Revised shwNum to take U and D
F14C 11830010         shwNum  cmpu #$0010                                                     ; Check if high word shows >1M
F150 251A                                     blo less1M                                                      ; if not display size in bytes
F152 1F30                                     tfr u,d                         ; Otherwise take high word
F154 C4F0                                     andb #$F0                                                       ; Clear low 4 bits
F156 47                                       asra                                                                    ; Divide by 16 asr / ror
F157 56                                       rorb
F158 47                                       asra
F159 56                                       rorb
F15A 47                                       asra
F15B 56                                       rorb
F15C 47                                       asra
F15D 56                                       rorb
F15E 3406                                     pshs d                                                          ; Put B and then A onto stack
F160 5F                                       clrb                                                                    ; zero B
F161 3404                                     pshs b                                                          ; stack zero top byte as well
F163 3540                                     puls u                                                          ; get to U
F165 3502                                     puls a                                                          ; and bottom byte in A
F167 5C                                       incb                                                                    ; flag for Megabytes
F168 3404                                     pshs b                                                          ; remember flag 
F16A 200D                                     bra coreNum
F16C 3402             less1M  pshs a                                                          ; stash mid byte
F16E 3440                                     pshs u                                                          ; and top two
F170 3261                                     leas 1,s                                                                ; fudge frame drop high byte 
F172 3540                                     puls u                                                          ; get u
F174 1F98                                     tfr b,a                                                         ; put low byte in a
F176 5F                                       clrb                                                                    ; flag for bytes
F177 3404                                     pshs b                                                          ; remember
F179 BDDD7D           coreNum         jsr     $dd7d                                                   ; integer to fac and normalize it
F17C BD9587                                   jsr     $9587                                                   ; fac to ascii (x points to string ended with $00
                                                                                                                              ; calculate length and add spaces to have total length = 7
F17F 3101                                     leay    1,x                                                     ; point to first digit
F181 C608                                     ldb     #8                                                              ; desired length + final null
F183 E0E4                                     subb ,s                                                         ; leave a space if we need M indicator
F185 5A               shwN01  decb                                                                    ; decrement counter
F186 A6A0                                     lda     ,y+                                                     ; get a digit
F188 26FB                                     bne     shwN01                                          ; if not 0, loopback
F18A 5D                                       tstb                                                                    ; needs extra spaces?
F18B 2708                                     beq     shwN02                                          ; no, skip section
F18D 8620                                     lda     #32                                                     ; get space
F18F BDB54A           shwN03  jsr     outchr                                          ; print it
F192 5A                                       decb                                                                    ; decrement counter
F193 26FA                                     bne     shwN03                                          ; if not zero, loopback
F195 BD90E5           shwN02  jsr     outstr                                          ; print lengths' string
F198 E6E0                                     ldb     ,s+                                                     ; Are we printing Megabytes?
F19A 2705                                     beq     skipM                                                   ; No, bytes 
F19C 864D                                     lda     #77                                                     ; M character
F19E BDB54A                                   jsr     outchr                                          ; print it
F1A1 39               skipM           rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show filename and extension                   
F1A2 CE0800           shwFdat ldu     #$800                                                   ; point to beginning of data
F1A5 C608             shwFd01 ldb     #8                                                              ; 8 chars for name
F1A7 A6C0             sdc01           lda     ,u+                                                     ; get a char
F1A9 BDB54A                                   jsr     outchr                                          ; show it
F1AC 5A                                       decb                                                                    ; decrement counter
F1AD 26F8                                     bne     sdc01                                                   ; not all, loopback
F1AF 862E                                     lda     #'.'                                                    ; get a dot
F1B1 BDB54A                                   jsr     outchr                                          ; show it
F1B4 C603                                     ldb     #3                                                              ; 3 chars for extension
F1B6 A6C0             sdc02           lda     ,u+                                                     ; get a char
F1B8 BDB54A                                   jsr     outchr                                          ; show it
F1BB 5A                                       decb                                                                    ; decrement counter
F1BC 26F8                                     bne     sdc02                                                   ; not all, loopback
                                                                                                                      ; show file type and extra info
F1BE E6C0                                     ldb     ,u+                                                     ; get byte 11 (type)
F1C0 8620                                     lda     #32                                                     ; get space
F1C2 C102                                     cmpb    #$02                                                    ; is byte hidden?
F1C4 2602                                     bne     sdc05                                                   ; no, skip next 
F1C6 8668                                     lda     #'h'                                                    ; get h char
F1C8 BDB54A           sdc05           jsr     outchr                                          ; show it
F1CB 8620                                     lda     #32                                                     ; get space
F1CD C101                                     cmpb    #$01                                                    ; is it locked?
F1CF 2602                                     bne     sdc06                                                   ; no, skip next 
F1D1 866C                                     lda     #'l'                                                    ; get l char
F1D3 BDB54A           sdc06           jsr     outchr                                          ; show it
F1D6 C110                                     cmpb    #$10                                                    ; is it a directory?
F1D8 270C                                     beq     sdc04                                                   ; yes, get that text
F1DA C104                                     cmpb    #$04                                                    ; is it sdf type?
F1DC 2704                                     beq     sdc03                                                   ; yes, get that text
F1DE 8EE4DE                                   ldx     #datNUL-1                                       ; else get spaces
F1E1 10                                       fcb     #$10                                                    ; to skip next
F1E2 8EE4D4           sdc03           ldx     #datSDF-1                                       ; point to message
F1E5 10                                       fcb     #$10                                                    ; to skip next
F1E6 8EE4D9           sdc04           ldx     #datDIR-1                                       ; point to message
F1E9 3440                                     pshs    u                                                               ; save pointer
F1EB BD90E5                                   jsr     outstr                                          ; put the three chars
F1EE 3540                                     puls    u                                                               ; restore pointer
F1F0 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; command sdrive alone
F1F1 0FF8             sdcLST  clr     <numUni                                         ; set drive 1
F1F3 17FEDF                                   lbsr    sdcGET                                          ; get and show info for that drive
                      ;                       bcs     esdcLST                                         ; if carry set, exit (no sdc present)
F1F6 210B                                     brn     esdcLST                                         ; if carry set, exit (no sdc present)
F1F8 9EA6                                     ldx     <$a6                                                    ; get input pointer
F1FA 301E                                     leax    -2,x                                                    ; move it back (will be moved forward later)
F1FC 9FA6                                     stx     <$a6                                                    ; update it
F1FE 0CF8                                     inc     <numUni                                         ; det drive 2                   
F200 17FED2                                   lbsr    sdcGET                                          ; get and show info for that drive
F203 39               esdcLST rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show received 'dim' info
F204 96F8             shwDIM  lda     <numUni                                         ; get drive number
F206 8B31                                     adda    #$31                                                    ; converts to '1'-'2'
F208 BDB54A                                   jsr     outchr                                          ; show drive number
F20B 8EE4C3                                   ldx     #totSect-1                                      ; point to message
F20E BD90E5                                   jsr     outstr                                          ; show it
F211 4F                                       clra                                    ; now get - Mike Miller 2021-05
F212 F6FF41                                   ldb $ff41                               ; four - Mike Miller 2021-05
F215 1F03                                     tfr d,u                                 ; bytes - Mike Miller 2021-05
F217 FCFF42                                   ldd $ff42                               ; in regs UD - Mike Miller 2021-05
F21A 17FF2F                                   lbsr    shwNum                                          ; process and show it
F21D 7E90A5                                   jmp     sendCR                                          ; send cr
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; command smkdir
F220 8D09             xsmkdir bsr     others                                          ; read filename, get params
F222 CC4B3A                                   ldd     #"K:"                                                   ; command to send
F225 BDEDDE           xsmk01  jsr     putCmd2                                         ; send command
F228 16FEA5                                   lbra    rstSlot                                         ; restore slot if needed
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; read filename and set parameters                      
F22B BDB7AA           others  jsr   getfnam                                           ; read string and length into $1d1 = nambuf
F22E F601D1                   ldb     nambuf                                          ; is string length 0?
F231 1027F554                 lbeq    snError                                         ; yes, show error
F235 C1FD                     cmpb    #253                                                    ; is string longer than maximum accepted? (253 + m: + final null)
F237 2505                                     bcs     other01                                         ; no, skip section
F239 3262                                     leas    2,s                                                     ; clean stack (we are inside a subroutine)
F23B 16F8F5                                   lbra    TooLong                                         ; show error message
F23E 5F               other01 clrb                                                                    ; set to zero
F23F D7FA                                     stb     <valPar                                         ; parameter for b
F241 D710                                     stb     <noexec                                         ; no more parmas
F243 D7F8                                     stb     <numUni                                         ; drive 0
F245 86E0                                     lda     #$e0                                                    ; command to send
F247 97FB                                     sta     <cmdNum                                         ; save it
F249 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; command skill
F24A 8DDF             xskill  bsr     others                                          ; read filename, get params
F24C CC583A                                   ldd     #"X:"                                                   ; command to send
F24F 20D4                                     bra     xsmk01                                          ; go send command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; command sren
F251 BDB7AA           xsren           jsr     getfnam                                         ; get old name
F254 F601D1                   ldb     nambuf                                          ; is string length 0?
F257 1027F52E                 lbeq    snError                                         ; yes, show error
F25B C17D                     cmpb    #125                                                    ; is string longer than maximum accepted? (125 for each one)
F25D 1024F8D2                 lbcc    TooLong                                         ; show error message
                                                                                                                      ; send it to $800 ended with $00
F261 8E01D2                                   ldx   #nambuf+1                                 ; point to 1st char of the input string
F264 CE0800                                   ldu     #$0800                                          ; point to 1st dos buffer
F267 F601D1                                   ldb     nambuf                                          ; get string length
F26A A680             xsren01 lda     ,x+                                                     ; get a char from input string
F26C A7C0                                     sta     ,u+                                                     ; copy in the buffer
F26E 5A                                       decb                                                                    ; decrement counter
F26F 26F9                                     bne     xsren01                                         ; not yet done, loopback
F271 6FC0                                     clr     ,u+                                                     ; put a final zero
F273 DF76                                     stu     <bufPtr                                         ;save pointer
F275 BDB7AA                                   jsr     getfnam                                         ; get new name
F278 F601D1                   ldb     nambuf                                          ; is string length 0?
F27B 1027F50A                 lbeq    snError                                         ; yes, show error
F27F C17D                     cmpb    #125                                                    ; is string longer than maximum accepted? (125 for each one)
F281 1024F8AE                 lbcc    TooLong                                         ; show error message
                                                                                                                      ; add after old name
F285 8E01D2                                   ldx   #nambuf+1                                 ; point to 1st char of the input string
F288 DE76                                     ldu     <bufPtr                                         ; get old pointer
F28A F601D1                                   ldb     nambuf                                          ; get newname string length
F28D A680             xsren02 lda     ,x+                                                     ; get a char from input string
F28F A7C0                                     sta     ,u+                                                     ; copy in the buffer
F291 5A                                       decb                                                                    ; decrement counter
F292 26F9                                     bne     xsren02                                         ; not yet done, loopback
F294 DF76                                     stu     <bufPtr                                         ; save last byte received
                                                                                                                      ; send it back to nambuf+1 - put length in nambuf 
F296 8E01D2                                   ldx     #nambuf+1                                       ; point to 1st char in input buffer                                                                             
F299 CE0800                                   ldu     #$800                                                   ; point to 1st byte of dos buffer
F29C 5F                                       clrb                                                                    ; counter to zero
F29D A6C0             xsren03 lda     ,u+                                                     ; get a byte
F29F A780                                     sta     ,x+                                                     ; put on the input buffer
F2A1 5C                                       incb                                                                    ; increment counter
F2A2 119376                                   cmpu    <bufPtr                                         ; got to the end?
F2A5 25F6                                     blo     xsren03                                         ; no, loopback
F2A7 F701D1                                   stb     nambuf                                          ; save total string length 
F2AA 8D92                                     bsr     other01                                         ; set parameters
F2AC CC523A                                   ldd     #"R:"                                                   ; command to send
F2AF 16FF73                                   lbra    xsmk01                                          ; go send command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; routine to add extension to the file name if not present
                      ; param: noexec=$00 to add .DSK  --- noexec=$80 to add .SDF
                      ; -------------------------------------------------------------------------------------------------------------------------------
F2B2 3416             addExt  pshs    d,x                                                     ; save pointers
F2B4 8E01D1                                   ldx     #nambuf                                         ; poit to name buffer
F2B7 E680                                     ldb   ,x+                                                       ; length of name
                                                                                                                      ; Check for existing extension
F2B9 A680             isadot          lda   ,x+                                                       ; get a char from name
F2BB 812E                     cmpa  #'.'                                                      ; is it a dot?
F2BD 2727                     beq   eAddExt                                           ; yes, exit
F2BF 5A                       decb                                                                    ; decrement counter
F2C0 26F7                     bne   isadot                                            ; not end of string, get next char name
                                                                                                                      ; so, we must add an extension
F2C2 0D10                     tst     <noexec                                         ; is for a SDF file?
F2C4 2B0C                     bmi     addSDF                                          ; yes, jump section
F2C6 CC2E44           addDSK          ldd   #$2e44                                            ; get chars ".D"
F2C9 ED81                     std   ,x++                                                      ; add to end of name
F2CB CC534B                   ldd   #$534b                                            ; get chars "SK"
F2CE ED81                     std   ,x++                                                      ; add to end of name
F2D0 200A                                     bra     add01                                                   ; skip next section
F2D2 CC2E53           addSDF          ldd   #$2e53                                            ; get chars ".S"
F2D5 ED81                     std   ,x++                                                      ; add to end of name
F2D7 CC4446                   ldd   #$4446                                            ; get chars "DF"
F2DA ED81                     std   ,x++                                                      ; add to end of name
F2DC 6F84             add01           clr     ,x                                                              ; put a null at next byte
F2DE F601D1                                   ldb   nambuf                                            ; get old name length
F2E1 CB04                                     addb  #4                                                                ; add 4 (because of dot and extension added)
F2E3 F701D1                   stb   nambuf                                            ; save new length in byte before string
F2E6 3596             eAddExt puls  d,x,pc                                            ; restore pointers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Section to deal with SDC-card SCHD commands
                      ; -------------------------------------------------------------------------------------------------------------------------------
F2E8 9DA5             xschd           jsr     <redLChr                                                ; peek at next char after SCHD
F2EA 1027F49B                                 lbeq    snError                                         ; if null, syntax error
F2EE 8122                                     cmpa    #$22                                                    ; is this the double quote?  = new directory
F2F0 10270123                                 lbeq    setCD01                                         ; do the same as SDIR = (by now!)
F2F4 81C6                                     cmpa    #$c6                                                    ; is it the token for /?
F2F6 271C                                     beq     chgRoot                                         ; process it
F2F8 812E                                     cmpa    #'.'                                                    ; is it a dot '.'?
F2FA 1026F48B                                 lbne    snError                                         ; no, show syntax error
F2FE 9D9F                                     jsr     <getNChr                                                ; get next char
F300 812E                                     cmpa    #'.'                                                    ; is it another dot '.'?
F302 1026F483                                 lbne    snError                                         ; no, show syntax error
                                                                                                                      ; this is to set parent dir as actual
F306 9D9F             chgParD jsr     <getNChr                                                ; skip token
F308 8602             chwPD01 lda     #$02                                                    ; only one char in nambuf
F30A C62E                                     ldb     #'.'                                                    ; char to design root directory (twice)
F30C FD01D1                                   std     nambuf                                          ; put signs
F30F F701D3                                   stb     nambuf+2                                                ; into input buffer
F312 2009                                     bra     chgR01                                          ; process it
                                                                                                                      ; this is to set root as actual dir
F314 9D9F             chgRoot jsr     <getNChr                                                ; skip token
F316 8601                                     lda     #$01                                                    ; only one char in nambuf
F318 C62F                                     ldb     #'/'                                                    ; char to design root directory
F31A FD01D1                                   std     nambuf                                          ; put data in input buffer area
F31D 17FF1E           chgR01  lbsr    other01                                         ; set parameters
F320 1600F7                                   lbra    setCD02                                         ; go to process the requested directory
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Section to deal with SDC-card SDIR commands
                      ; -------------------------------------------------------------------------------------------------------------------------------
F323 9DA5             xsdir           jsr     <redLChr                                                ; peek at next char after sdir
F325 102700E6                                 lbeq    shwCAct                                         ; is the sdir alone = show current dir contents
                                                                                                                      ; decode token - sign
F329 81B3                                     cmpa    #$b3                                                    ; is the token for get?
F32B 102700AF                                 lbeq    shwCDir                                         ; yes, show current dir name
F32F 8187                                     cmpa    #$87                                                    ; is it the token for print (question mark)?
F331 102700EB                                 lbeq    shwFull                                         ; yes, show the full path name of actual dir (maybe substitute sdir get!)
F335 81C4                                     cmpa    #$c4                                                    ; is this the token for ('-')? = show contents of root dir
F337 102700C5                                 lbeq    shwRoot                                         ; yes, go process it
F33B 81CB                                     cmpa    #$cb                                                    ; is this the token for ('=')? = set current dir
F33D 102700D4                                 lbeq    setCDir                                         ; yes, go process it
F341 8122                                     cmpa    #$22                                                    ; is this the sign ('"')?  = show contents of the requested dir
F343 1026F442                                 lbne    snError                                         ; no, show syntax error
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; show contents of requested dir
                                                                                                                      ; send a initiate directory listing command
F347 17FEE1           shwRDir lbsr    others                                          ; read filename, get params
F34A CC4C3A           shwEDir ldd     #"L:"                                                   ; command to send
F34D BDEDDE                                   jsr     putCmd2                                         ; send command
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; ask for directory pages to the sdc
F350 17FEEB           shwRD00 lbsr    other01                                         ; set some parameters
F353 C63E                                     ldb     #'>'                                                    ; special parameter
F355 D7FA                                     stb     <valPar                                         ; save it
F357 86C0                                     lda     #$c0                                                    ; command to send
F359 97FB                                     sta     <cmdNum                                         ; save it
F35B CC0100                                   ldd     #$0100                                          ; mark 1 byte with value equal null
F35E FD01D1                                   std     nambuf                                          ; put in nambuf area (no name)
F361 BDEDDE                                   jsr     putCmd2                                         ; send command
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
F364 8E0800                                   ldx     #$0800                                          ; point to buffer beginning
F367 5F                                       clrb                                                                    ; counter to zero
F368 A684             shwRD01 lda     ,x                                                              ; get first char (1st name character)
F36A 2709                                     beq     shwRD02                                         ; if zero, no more items
F36C 5C                                       incb                                                                    ; increment received items counter
F36D 308810                                   leax    16,x                                                    ; point to next item
F370 8C0900                                   cmpx    #$0900                                          ; got to end of buffer?
F373 25F3                                     blo     shwRD01                                         ; no, loopback
F375 5D               shwRD02 tstb                                                                    ; have we read any item?
F376 2762                                     beq     shwRD09                                         ; no, print ok and exit
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
F378 D7FA                                     stb     <itsRead                                                ; save number of items we received
F37A CE0800                                   ldu     #$0800                                          ; point to beginning of received data
F37D DFF8                                     stu     <cpyPtr                                         ; save it
F37F 0FFB                                     clr     <itsDone                                                ; for each item (clear counter)
F381 0CFB             shwRD03 inc     <itsDone                                                ; add 1 to counter
F383 17FE1F                                   lbsr    shwFd01                                         ; show item name and type
F386 30C4                                     leax    ,u                                                              ; point to msb highest byte of item length (not used)
F388 EE84                                     ldu     ,x                                                              ; get 2 next bytes (Mike Miller)
F38A EC02                                     ldd     2,x                                                     ; get lowest byte (Mike Miller)
F38C 17FDBD                                   lbsr    shwNum                                          ; show item Length (U:A)
F38F 9EF8                                     ldx     <cpyPtr                                         ; get beginning of this record
F391 308810                                   leax    16,x                                                    ; point to next one
F394 9FF8                                     stx     <cpyPtr                                         ; update pointer
F396 D6FA                                     ldb     <itsRead                                                ; get number of items read
F398 C110                                     cmpb    #16                                                     ; was 16?                                                               
F39A 262C                                     bne     shwRD07                                         ; NO, so partial page. Send CR and go for next one
F39C 96FB                                     lda     <itsDone                                                ; YES, it was a full page. Get item number just printed
F39E 810F                                     cmpa    #15                                                     ; was penultimate row?
F3A0 2608                                     bne     shwRD04                                         ; no, see if it was the last one
F3A2 8EE4E3                                   ldx     #msgCont-1                                      ; yes point to message CONT
F3A5 BD90E5                                   jsr     outstr                                          ; show message                  
F3A8 201E                                     bra     shwRD07                                         ; and send CR and go for next item      
F3AA 8110             shwRD04 cmpa    #16                                                     ; is the last one?
F3AC 261A                                     bne     shwRD07                                         ; no, send CR and go for next item
F3AE 8EE4EA                                   ldx     #msgExit-1                                      ; yes, point to message EXIT
F3B1 BD90E5                                   jsr     outstr                                          ; show message                  
F3B4 BD8006           shwRD05 jsr     $8006                                                   ; wait for user keypress
F3B7 27FB                                     beq     shwRD05                                         ; none, loopback
F3B9 8143                                     cmpa    #$43                                                    ; is 'C' for Continue?
F3BB 2605                                     bne     shwRD06                                         ; no, verify if is 'E'
F3BD BD90A5                                   jsr     sendCR                                          ; send a CR (will scroll 1 line up)
F3C0 208E                                     bra   shwRD00                                           ; BREAK, ask for a new page to the SDC
F3C2 8145             shwRD06 cmpa    #$45                                                    ; is 'E' for eXIT?
F3C4 26EE                                     bne     shwRD05                                         ; no, loopback and wait for a correct key
F3C6 200D                                     bra     shwRD08                                         ; yes, send CR, show OK and exit
F3C8 BD90A5           shwRD07 jsr     sendCR                                          ; send CR
F3CB 96FB                                     lda     <itsDone                                                ; get number of items shown
F3CD 91FA                                     cmpa    <itsRead                                                ; work done?
F3CF 2709                                     beq     shwRD09                                         ; yes, send OK and exit
F3D1 DEF8                                     ldu     <cpyPtr                                         ; no, get saved buffer pointer
F3D3 20AC                                     bra     shwRD03                                         ; loopback for next item
F3D5 860D             shwRD08 lda     #$0d                                                    ; get enter value
F3D7 BDB54A                                   jsr     outchr                                          ; print it
F3DA 17FCB7           shwRD09 lbsr    exsdrv                                          ; restore slot if needed
F3DD 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show name of current dir
F3DE 9D9F             shwCDir jsr     <getNChr                                                ; skip token
F3E0 8601                                     lda     #1                                                              ; put value 1
F3E2 97F9                                     sta     <numDir                                         ; as first level requested
F3E4 17FE57                                   lbsr    other01                                         ; put some parameters
F3E7 86C0                                     lda     #$c0                                                    ; command to be sent
F3E9 97FB                                     sta     <cmdNum                                         ; save it
F3EB C643                                     ldb     #'C'                                                    ; param for b
F3ED D7FA                                     stb     <valPar                                         ; save it
F3EF CC0100                                   ldd     #$0100                                          ; get 1 byte with value equal null
F3F2 FD01D1                                   std     nambuf                                          ; put in nambuf area (no name)
F3F5 BDEDDE                                   jsr     putCmd2                                         ; send command
F3F8 2503                                     bcs     eshwCDir                                                ; if error, don't show garbage
F3FA 17FDA5                                   lbsr    shwFdat                                         ; show dirname and type
F3FD 16FC94           eshwCDir        lbra    exsdrv                                          ; restore slot if needed
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show contents of root dir
F400 9D9F             shwRoot jsr     <getNChr                                                ; skip token
F402 8601                                     lda     #$01                                                    ; only one char in nambuf
F404 C62F                                     ldb     #'/'                                                    ; char to design root directory
F406 FD01D1           shwRt01 std     nambuf                                          ; put data in input buffer area
F409 17FE32                                   lbsr    other01                                         ; set parameters
F40C 16FF3B                                   lbra    shwEDir                                         ; go to process the requested directory
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show contents of current dir
F40F 8601             shwCAct lda     #$01                                                    ; only one char in nambuf
F411 C62A                                     ldb     #'*'                                                    ; char to design current directory
F413 20F1                                     bra     shwRt01                                         ; complete data and process command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; set current dir to requested name
F415 9D9F             setCDir jsr     <getNChr                                                ; get next entered char
F417 17FE11           setCD01 lbsr    others                                          ; read filename, get params
F41A CC443A           setCD02 ldd     #"D:"                                                   ; command to send
F41D 16FE05                                   lbra    xsmk01                                          ; go send command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show actual dir full path
F420 9D9F             shwFull jsr     <getNChr                                                ; skip token
F422 327E                                     leas    -2,s                                                    ; create a 3 bytes hole for variables
F424 0FF9                                     clr     numDir                                          ; set items received to 0
F426 8E0900                                   ldx     #$0900                                          ; get 2nd dos buffer address
F429 AFE4                                     stx     destPtr,s                                       ; to receive results
F42B 17FE10           shwF01  lbsr    other01                                         ; put some parameters
F42E 86C0                                     lda     #$c0                                                    ; command to be sent
F430 97FB                                     sta     <cmdNum                                         ; save it
F432 C643                                     ldb     #'C'                                                    ; param for b
F434 D7FA                                     stb     <valPar                                         ; save it
F436 CC0100                                   ldd     #$0100                                          ; get 1 byte with value equal null
F439 FD01D1                                   std     nambuf                                          ; put in nambuf area (no name)
F43C 0CF9                                     inc     numDir                                          ; increment received items counter
F43E BDEDDE                                   jsr     putCmd2                                         ; send command to get actual directory
                                                                                                                      ; processing single answer
F441 253D                                     bcs     shwF80                                          ; if error (got to root) skip section  
                                                                                                                      ; save received data to $900 buffer
F443 8E0800                                   ldx     #$800                                                   ; point to beginning of received data
F446 EEE4                                     ldu     destPtr,s                                       ; point ot destination record
F448 C608                                     ldb     #8                                                              ; max name length 
F44A A680             shwF02  lda     ,x+                                                     ; get a received char
F44C 8120                                     cmpa    #$20                                                    ; is it space
F44E 2705                                     beq     shwF03                                          ; yes, stop copying name
F450 A7C0                                     sta     ,u+                                                     ; pass char to record
F452 5A                                       decb                                                                    ; decrement counter
F453 26F5                                     bne     shwF02                                          ; if not zero, loopback
F455 E680             shwF03  ldb     ,x+                                                     ; get 1st termination char
F457 C120                                     cmpb    #$20                                                    ; is it a space?
F459 2714                                     beq     shwF04                                          ; yes, goto next dir element
F45B 862E                                     lda     #'.'                                                    ; get dot char
F45D EDC1                                     std     ,u++                                                    ; add dot and 1st ext char
F45F A680                                     lda     ,x+                                                     ; get 2nd extension char
F461 8120                                     cmpa    #$20                                                    ; is it a space?
F463 270A                                     beq     shwF04                                          ; yes, goto next dir element
F465 A7C0                                     sta     ,u+                                                     ; add 2nd extension char
F467 A680                                     lda     ,x+                                                     ; get 3rd extension char
F469 8120                                     cmpa    #$20                                                    ; is it a space?
F46B 2702                                     beq     shwF04                                          ; yes, skip next
F46D A7C0                                     sta     ,u+                                                     ; add 3rd extension char
F46F CC2F00           shwF04  ldd     #$2f00"                                         ; get a slash and zero terminator
F472 EDC4                                     std     ,u                                                              ; add to destination buffer
F474 EEE4                                     ldu     destPtr,s                                       ; get beginning just used
F476 33C810                                   leau    16,u                                                    ; add 16 to buffer pointer
F479 EFE4                                     stu     destPtr,s                                       ; update it for next path directory
F47B 17FE8A                                   lbsr    chwPD01                                         ; ask SDC to go to parent dir (SCHD"..")
F47E 20AB                                     bra     shwF01                                          ; go back to ask for new actual directory
                                                                                                                      ; got to the root, NO MORE data to request. 
F480 96F9             shwF80  lda     <numDir                                         ; get number of received items
F482 8101                                     cmpa    #1                                                              ; only one item received?
F484 273E                                     beq     eshwFull                                                ; yes, it was ROOT, so exit
                                                                                                                      ; process received data to show full path
F486 CE01D2                                   ldu     #nambuf+1                                       ; destination for full path name (input buffer)
F489 862F                                     lda     #$2f                                                    ; get a slash to denote root
F48B A7C0                                     sta     ,u+                                                     ; put into buffer as 1st char
                                                                                                                      ; add all the received dirs in reverse order
F48D AEE4                                     ldx     destPtr,s                                       ; get last record address (not used ... it was root)
F48F 3010             shwF81  leax    -16,x                                                   ; point to previous used entry
F491 8C0900                                   cmpx    #$0900                                          ; gone back past the beginning?
F494 250E                                     bcs     shwF90                                          ; yes, end of putting items together
F496 3410                                     pshs    x                                                               ; save register
F498 A680             shwF82  lda     ,x+                                                     ; get a char from origin
F49A 2704                                     beq     shwF83                                          ; if null, end of string
F49C A7C0                                     sta     ,u+                                                     ; else put at destination
F49E 20F8                                     bra     shwF82                                          ; go get next char
F4A0 3510             shwF83  puls    x                                                               ; restore pointer
F4A2 20EB                                     bra     shwF81                                          ; back to get next directory
F4A4 6FC4             shwF90  clr     ,u                                                              ; mark end of string
F4A6 1F30                                     tfr     u,d                                                     ; send poiter to D
F4A8 8301D2                                   subd    #nambuf+1                                       ; to calculate length of string
F4AB F701D1                                   stb     nambuf                                          ; save it
F4AE 8E01D1                                   ldx     #nambuf                                         ; point to whole path name
F4B1 BD90E5                                   jsr     outstr                                          ; show the full mounted directory path
F4B4 860D                                     lda     #$0d                                                    ; code for Enter
F4B6 BDB54A                                   jsr     outchr                                          ; print it
                                                                                                                      ; issue a SCHD"" with the whole path to restore situation!!
F4B9 3262                                     leas    2,s                                                     ; clean stack
F4BB 17FD80                                   lbsr    other01                                         ; set some parameters
F4BE CC443A                                   ldd     #"D:"                                                   ; command to send       
F4C1 16FD61                                   lbra    xsmk01                                          ; go back to the actual directory we had before
F4C4 3262             eshwFull        leas    2,s                                                     ; clean stack
F4C6 16FBCB                                   lbra    exsdrv                                          ; exit
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; process for command WRITE MEM @bank, start, destination, length
                      ; this code is made based on the FLASHER.BIN program by Darren Atkinson
                      ; -------------------------------------------------------------------------------------------------------------------------------
F4C9 9D9F             xwrite  jsr     <getNChr                                                ; get next char
F4CB 819B                                     cmpa    #$9b                                                    ; is the token for MEM?
F4CD 1026F2B8                                 lbne    snError                                         ; no, show error message
F4D1 9D9F                                     jsr     <getNChr                                                ; get next byte
F4D3 8140                                     cmpa    #64                                                     ; is it sign '@'?
F4D5 1026F2B0                                 lbne    snError                                         ; no, show error message
F4D9 9D9F                                     jsr     <getNChr                                                ; get number into A
F4DB 8130                                     cmpa    #$30                                                    ; is greater or equal 0?
F4DD 2504                                     bcs     xwrt01                                          ; no, show error
F4DF 8137                                     cmpa    #$37                                                    ; is less or equal 7?
F4E1 2305                                     bls     xwrt02                                          ; yes, goto next parameters
F4E3 C611             xwrt01  ldb     #$11                                                    ; SD error
F4E5 7E8344                                   jmp     syserr                                          ; bas_system_error
F4E8 8407             xwrt02  anda    #$07                                                    ; use only valid bits
F4EA 97EB                                     sta     <DCDRV                                          ; save requested bank number
F4EC 9D9F                                     jsr     <getNChr                                                ; advance one char
F4EE 260F                                     bne     morParms                                                ; if more chars, read them
                                                                                                                      ; default parameters for writting a ROMPACK
F4F0 8E3000                                   ldx     #$3000                                          ; get origin of data
F4F3 9F76                                     stx     <dSource                                                ; save start into variable
F4F5 8EC000                                   ldx     #$c000                                          ; get destination in bank
F4F8 9FFA                                     stx     <dDest                                          ; save destination into variable
F4FA 8E3F00                                   ldx     #$3f00                                          ; get max. length (16k-256bytes)
F4FD 203F                                     bra     savLen                                          ; skip section
F4FF BD89AA           morParms        jsr     ckComma                                         ; CkComma
F502 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into X
F505 8C7FFF                                   cmpx    #basini-1                                       ; is it on the upper 32k?
F508 226C                                     bhi     badParam                                                ; yes, bad format number, show error
F50A 9F76                                     stx     <dSource                                                ; save start into variable
F50C 9DA5                                     jsr     <redLChr                                                ; advance one char
F50E BD89AA                                   jsr     ckComma                                         ; CkComma
F511 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into X
F514 8CC000                                   cmpx    #romini                                         ; is it out of SDC-ROM area?
F517 255D                                     blo     badParam                                                ; yes, bad format number, show error
F519 8CF000                                   cmpx    #$f000                                          ; is it higher than the beginning of 4th sector?
F51C 2258                                     bhi     badParam                                                ; yes, bad format number, show error
F51E 9FFA                                     stx     <dDest                                          ; save destination into variable
F520 9DA5                                     jsr     <redLChr                                                ; advance one char
F522 BD89AA                                   jsr     ckComma                                         ; CkComma
F525 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into X
F528 1F10                                     tfr     x,d                                                     ; pass value to D
F52A D3FA                                     addd    <dDest                                          ; add destination value
F52C 2548                                     bcs     badParam                                                ; yes, sum exceeds flash capacity
F52E 1083FF00                                 cmpd    #$ff00                                          ; uses result the reserved 256 bytes?
F532 2242                                     bhi     badParam                                                ; yes, bad format number, show error
F534 1F10                                     tfr     x,d                                                     ; get length again
F536 D376                                     addd    <dSource                                                ; add source beginning
F538 10837FFF                                 cmpd    #basini-1                                       ; exceeds RAM area?
F53C 2238                                     bhi     badParam                                                ; yes, bad format number, show error
F53E 9F50             savLen  stx     <FPA0                                                   ; save byte count
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; search slot where SDC is
F540 17F6C8                                   lbsr    tstSDC                                          ; is SDC already active?
F543 271A                                     beq     xwrt03                                          ; yes, save slot number (if no MPI this will be $00)
F545 B60114                                   lda     floSDC                                          ; no, get hdw control byte
F548 8508                                     bita    #%00001000                                      ; is a SDC in the system?
F54A 1027F5ED                                 lbeq    NotSDCPresent                           ; no, show message
                                                                                                                      ; yes, calculate occupied slot
F54E B60114                                   lda     floSDC                                          ; get hdw control byte
F551 84C0                                     anda    #%11000000                                      ; use bits 7-6 (slot where SDC is)
F553 44                                       lsra                                                                    ; move them to
F554 44                                       lsra                                                                    ; bits 5-4 (lower bits of high nibble)
F555 3402                                     pshs    a                                                               ; save high nibble
F557 44                                       lsra                                                                    ; low nibble   
F558 44                                       lsra                                                                    ; gets high nibble
F559 44                                       lsra                                                                    ; that will end  
F55A 44                                       lsra                                                                    ; as zero
F55B AAE0                                     ora     ,s+                                                     ; add high nibble (now they are the same value)
F55D 2003                                     bra     xwrt04                                          ; save slot number
F55F B603FF           xwrt03  lda     cpyMPIcfg                                       ; get active slot number
F562 97F9             xwrt04  sta     <sdcSlot                                                ; save slot where SDC is
                                                                                                                      ; copy the flasher routine to $1da. Should not exceed $2d2
F564 8EF585           cpyFlsh ldx     #xflash                                         ; point to beginning of program to be copied
F567 CE01DA                                   ldu     #$1da                                                   ; point to destination
F56A EC81             cpyFl01 ldd     ,x++                                                    ; get a word
F56C EDC1                                     std     ,u++                                                    ; put at destination
F56E 8CF693                                   cmpx    #erasEnd+2                                      ; got to end of program?
F571 25F7                                     blo     cpyFl01                                         ; no, loopback
F573 7E01DA                                   jmp     $1da                                                    ; execute copied program in low RAM
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
F576 8EE4F1           badParam        ldx     #wrongPar-1                                     ; point to message
F579 BD90E5                                   jsr     outstr                                          ; show it
F57C 9DA5                                     jsr     <redLChr                                                ; read last char
F57E 2704                                     beq     ebadPrm                                         ; if null, exit
F580 9D9F             bP001           jsr     <getNChr                                                ; skip an unused byte
F582 26FC                                     bne     bP001                                                   ; if not null, loopback
F584 39               ebadPrm rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; This code manages the process of flashing a bank
                      ; -------------------------------------------------------------------------------------------------------------------------------
F585 1A50             xflash  orcc  #$50                    ; mask interrupts
F587 96F9                      lda    <sdcSlot                                                ; get the slot where SDC is
                                                                                                                      ; this is to avoid starting the just flashed bank!
F589 F603FF                    ldb    cpyMPIcfg                                       ; get current active slot
F58C D7F9                                     stb     <sdcSlot                                                ; save it to go back to it at the end
F58E B703FF                                   sta     cpyMPIcfg                                       ; update copy
F591 B7FF7F                                   sta     MPIcfg                                          ; switch to the SDC slot
F594 B7FFD8                              sta   R1CLR                   ; normal speed for CoCo 3 (0,89MHz) - $ffd8 (resets $ffd7)
F597 B7FFDE                    sta   RAMROM                  ; activate RAM/ROM map mode = MAP0 - resets $ffdf
F59A D6EB                      ldb   <DCDRV                  ; get target bank number (parameter at $eb)
F59C 8D1B                      bsr   FlashKill               ; erase target bank
F59E 308C60                    leax  burner,pcr                   ; point X at burner subroutine
F5A1 9FEE                      stx   <DCBPT                  ; store subroutine address: $ee
F5A3 9E76                                     ldx     <dSource                                                ; point X at source data
F5A5 DEFA                                     ldu     <dDest                  ; point U at flash destination
F5A7 8D45                      bsr   callX                   ; write data to the flash
F5A9 D6F9                      ldb    <sdcSlot                                                ; get original active slot
F5AB F703FF                    stb    cpyMPIcfg                                       ; update copy
F5AE F7FF7F                    stb    MPIcfg                                          ; set it again
F5B1 0F71                      clr   <$71                    ; force a cold boot
F5B3 1A50                      orcc  #$50                    ; mask interrupts
F5B5 6E9FFFFE                  jmp   [$fffe]                 ; execute the system reset routine
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ;  Erase flash bank specified in ACCB
                      ; -------------------------------------------------------------------------------------------------------------------------------
F5B9                  FlashKill 
F5B9 D786                                     stb   <TargBank               ; store bank number: $86
F5BB 9650                                     lda     <FPA0                                                   ; get byte count                                                                                                                                                        ; 2B - 20
F5BD 84F0                                     anda    #$f0                                                    ; use only high nibble                                                                                                                                  ; 20 - 20
F5BF 3402                                     pshs    a                                                               ; push value (number of sectors of 4K)                                                                                          ; 20 - 20
F5C1 DC50                                     ldd     <FPA0                                                   ; get full byte count                                                                                                                                   ; 2B00 - 2000
F5C3 840F                                     anda    #$0f                                                    ; mask high nibble of high byte                                                                                                         ; 0B00 - 0000
F5C5 10830000                                 cmpd    #$0000                                          ; is masked D equal 0?                                                                                                                                  ; NO   - YES
F5C9 2706                                     beq     flK01                                                   ; yes, don't correct values                                                                                                                     ; corr - jump
F5CB 8610                                     lda     #$10                                                    ; add one sector (x16)
F5CD ABE4                                     adda    ,s                                                              ; to pushed value                                                                                                                                                       ; 30
F5CF A7E4                                     sta     ,s                                                              ; update it in the stack                                                                                                                                ; 30
F5D1 3502             flK01           puls    a                                                               ; get number of sectors to kill (x16 'cause in high nibble)                                     ; 30 - 20
F5D3 8140                                     cmpa    #$40                                                    ; number of sectors greater than 4?
F5D5 2302                                     bls     flK02                                                   ; no, go on
F5D7 8640                                     lda     #$40                                                    ; yes, limit to 4
F5D9 1F89             flK02           tfr     a,b                                                     ; copy to B                                                                                                                                                                     ; 30 - 20
F5DB 54                                       lsrb                                                                    ; move
F5DC 54                                       lsrb                                                                    ; 4 times to
F5DD 54                                       lsrb                                                                    ; the right to
F5DE 54                                       lsrb                                                                    ; divide by 16 to get the actual number of sectors      to kill                                 ; 03 - 02
F5DF 96FA                                     lda     <dDest                                          ; get destination ini high byte                                                                                                         ; D3 - C0       ($D300 - $C000)
F5E1 84F0                                     anda    #$f0                                                    ; use high nibble                                                                                                                                                       ; D0 - C0
                                                                                                                      ; now D should contain: 
                                                                                                                      ;     A = High byte of address of 1st sector to kill ($C0-$D0-$E0-$F0)
                                                                                                                      ;     B = number of sectors to be killed
                                                                                                                      ; save parameter for later use
F5E3 9752                      sta   <FPA0+2                 ; store MSB of default sector address: $52
F5E5 D703                      stb   <ErasCtr                ; store sector count: $03
F5E7 0F53                      clr   <FPA0+3                 ; clear LSB of sector address: $53
F5E9 308C65                    leax  eraser,pcr              ; point X at erasure routine
F5EC 9FEE                      stx   <DCBPT                                           ; save it: $ee
F5EE 9686             callX    lda   <TargBank                        ; get current flash bank selection: $86
F5F0 8407                      anda  #$07                    ; mask out undefined bits
F5F2 3403                      pshs  a,cc                    ; save current bank and IRQ mask
F5F4 AD9F00EE                  jsr   [DCBPT]                 ; call utility routine: $ee -> eraser (routine)
F5F8 B6FF22                    lda   $ff22                   ; read PIA data reg to clear any CART interrupt
F5FB 3503                      puls  cc,a                    ; restore old IRQ mask and pop saved bank number
F5FD 7FFF4A                    clr   FLSHREG                 ; clear the Flash byte register: $ff4a
F600 39                        rts                           ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Write Data to Flash
                      ; Entry:
                      ;   X = source data address
                      ;   U = destination flash address
                      ;   High word of FPA0 = byte count ($50)
                      ; -------------------------------------------------------------------------------------------------------------------------------
F601 DC50             burner   ldd   <FPA0                   ; D = byte count: $50
F603 31CB                      leay  d,u                     ; Y = destination end address
F605 109F52                    sty   <FPA0+2                 ; save end address in FPA0: $52
F608 3184                      leay  ,x                      ; point Y at the source data
F60A 30C4                      leax  ,u                      ; point X at the destination
F60C 338C1F                    leau  burnPrfx,PCR            ; point U at the prefix data for Byte Program
F60F 9686                      lda   <TargBank               ; get target bank number: $86
F611 B7FF4B                    sta   BANKREG                 ; activate target bank: ff4b
F614 8A80                      ora   #$80                    ; setup bank number combined with PGM Enable
F616 E6A0             burn010  ldb   ,y+                     ; get next data byte from source
F618 E184                      cmpb  ,x                      ; does flash already contain this value?
F61A 2604                      bne   burn020                 ; branch if needs to change
F61C 3001                      leax  1,x                     ; increment flash address
F61E 2008                      bra   burn030                 ; skip ahead to end of loop
F620 3456             burn020  pshs  u,x,b,a                 ; save registers
F622 8D17                      bsr   flshPrefx               ; send the unlock sequence
F624 3556                      puls  a,b,x,u                 ; restore target bank and destination address
F626 8D20                      bsr   flshWrCyc               ; write the byte to the Flash destination
F628 9C52             burn030  cmpx  <FPA0+2                 ; have we reached the final address: $52
F62A 25EA                      blo   burn010                 ; loop if more
F62C 2016                      bra   flshDone                ; restore original bank selection and return
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; - - -  Prefix Data for Byte-Program  - - -
F62E 81AA             burnPrfx fdb   $81aa                   ; Bank = 1, Data = $AA...
F630 D555                      fdb   $d555                   ; ...Address = $D555 ($5555)
F632 8055                      fdb   $8055                   ; Bank 0, Data = $55...
F634 EAAA                      fdb   $eaaa                   ; ...Address = $EAAA ($2AAA)
F636 81A0                      fdb   $81a0                   ; Bank 1, Data = $A0...
F638 D555                      fdb   $d555                   ; ...Address = $D555 ($5555)
F63A 00                        fcb   $0                                 ; end of sequence
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Send a Programming Prefix Sequence to the Flash.
                      ; Enter with U pointing to Prefix data.
                      ; -------------------------------------------------------------------------------------------------------------------------------
F63B                  flshPrefx
F63B 3716                                     pulu  a,b,x                   ; get next bank, data byte and address
F63D 4D                        tsta                          ; if reached end-of-sequence..
F63E 2710                      beq   flshRts                 ; ..then return
F640 8D06                      bsr   flshWrCyc               ; write byte to flash
F642 20F7                      bra   flshPrefx               ; loop for next byte of sequence
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; Restores old flash bank and returns upon completion of Flash operation
F644 A663             flshDone lda   3,s                     ; get orignal bank number from stack
F646 847F                      anda  #$7f                    ; make sure the PGM Enable bit is cleared
                                                                                                                      ;  *** Fall Thru ***
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                      ; Perform a Write Cycle to the Flash.
                      ; Enter with Address in X, Bank+PGM Enable in ACCA and the data byte in ACCB.
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
F648                  flshWrCyc
F648 B7FF4B                                   sta   BANKREG                 ; select Flash bank / PGM Enable: $ff4b
F64B F7FF4A                    stb   FLSHREG                 ; store data byte in Flash register: $ff4a
F64E E580                      bitb  ,x+                     ; perform Flash Write by reading target address
F650 39               flshRts  rts                           ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Erase Flash Sector
                      ; -------------------------------------------------------------------------------------------------------------------------------
F651 338C27           eraser   leau  erasPrfx,PCR            ; point U to the prefix data for Sector Erase
F654 8DE5                      bsr   flshPrefx               ; write the prefix bytes
F656 CC8030                    ldd   #$8030                  ; ACCA = PGM Enable;  ACCB = final prefix byte
F659 9A86                      ora   <TargBank               ; combine target bank number with PGM Enable: $86
F65B 9E52                      ldx   <FPA0+2                 ; X = sector address: $52 ($C0xx)
F65D 8DE9                      bsr   flshWrCyc               ; write final prefix byte at sector address
F65F 8407                      anda  #$07                    ; turn off the..
F661 B7FF4B                    sta   BANKREG                 ; ..PGM Enable bit: $ff4b
F664 4F                        clra                          ; clear ACCD for use..
F665 5F                        clrb                          ; ..as timeout counter
F666 6D1F             eras025  tst   -1,x                    ; poll the sector address: $C0xx-1
F668 2B05                      bmi   eras030                 ; branch if bit 7 is set (erasure complete)
F66A 830001                    subd  #1                      ; decrement timeout counter
F66D 26F7                      bne   eras025                 ; loop if not yet timed out
F66F 30890FFF         eras030  leax  $0fff,x                 ; increment X to point at the next sector
F673 9F52                      stx   <FPA0+2                 ; save sector address in FPA0: $52 ($D0xx)
F675 0A03                      dec   <ErasCtr                ; decrement erase sector counter: $03
F677 26D8                      bne   eraser                  ; loop if erasing another sector
F679 20C9                      bra   flshDone                ; restore original bank selection and return
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; - - -  Programming Prefix for Sector Erase  - - -
F67B 81AA             erasPrfx fdb   $81aa                   ; Bank = 1, Data = $AA...
F67D D555                      fdb   $d555                   ; ...Address = $D555 ($5555)
F67F 8055                      fdb   $8055                   ; Bank 0, Data = $55...
F681 EAAA                      fdb   $eaaa                   ; ...Address = $EAAA ($2AAA)
F683 8180                      fdb   $8180                   ; Bank 1, Data = $80...
F685 D555                      fdb   $d555                   ; ...Address = $D555 ($5555)
F687 81AA                      fdb   $81aa                   ; Bank = 1, Data = $AA...
F689 D555                      fdb   $d555                   ; ...Address = $D555 ($5555)
F68B 8055                      fdb   $8055                   ; Bank 0, Data = $55...
F68D EAAA                      fdb   $eaaa                   ; ...Address = $EAAA ($2AAA)
F68F 0000                      fdb   $0000                   ; end of sequence
F691 0000             erasEnd  fdb   $0000                                                    ; ...a record is 4 bytes long ...
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; process for command SCOPY MEM @number   ,&HC000,&H4000,&H3F00
                      ; or alternate        SCOPY MEM SLOTnumber,&HC000,&H4000,&H3F00
                      ; -------------------------------------------------------------------------------------------------------------------------------
F693 9D9F             xscopy  jsr     <getNChr                                                ; get next char
F695 819B                                     cmpa    #$9b                                                    ; is the token for MEM?
F697 1026F0EE                                 lbne    snError                                         ; no, show error message
F69B 9D9F                                     jsr     <getNChr                                                ; get next byte
F69D 97F9                                     sta     <cpyWhat                                                ; save received command
F69F 8140                                     cmpa    #64                                                     ; is it sign '@' for BANK?
F6A1 2717                                     beq     xsbnk01                                         ; yes, go get bank number
F6A3 81EF                                     cmpa    #$ef                                                    ; is the token for SLOT?
F6A5 1026F0E0                                 lbne    snError                                         ; no, show error
                                                                                                                      ; processing slot command
F6A9 9D9F                                     jsr     <getNChr                                                ; get number into A
F6AB 8131                                     cmpa    #$31                                                    ; is greater or equal 1?
F6AD 2507                                     bcs     xscerr1                                         ; no, show error
F6AF 8134                                     cmpa    #$34                                                    ; is less or equal 4?
F6B1 2203                                     bhi   xscerr1                                           ; no, show error 
F6B3 4A                                       deca                                                                    ; internally MUST work with 0-1-2-3
F6B4 2013                                     bra     xsParam                                         ; yes, goto next parameters
F6B6 C60D             xscerr1 ldb     #$0d                                                    ; MU error
F6B8 200C                                     bra     xscerr0                                         ; goto bas_system_error
                                                                                                                      ; processing bank command
F6BA 9D9F             xsbnk01 jsr     <getNChr                                                ; get number into A
F6BC 8130                                     cmpa    #$30                                                    ; is greater or equal 0?
F6BE 2504                                     bcs     xscerr2                                         ; no, show error
F6C0 8137                                     cmpa    #$37                                                    ; is less or equal 7?
F6C2 2305                                     bls     xsParam                                         ; yes, goto next parameters
F6C4 C611             xscerr2         ldb     #$11                                                    ; SD error
F6C6 7E8344           xscerr0 jmp     syserr                                          ; bas_system_error
                                                                                                                      ; look for more parameters
F6C9 8030             xsParam suba    #$30                                                    ; convert ASCII to integer (0-3 or 0-7)
F6CB 97F8                                     sta     <oriNum                                                 ; save requested bank/slot number
F6CD 9D9F                                     jsr     <getNChr                                                ; advance one char
F6CF 260F                                     bne     otherPar                                                ; if more chars, read them
                                                                                                                      ; default parameters for writting a ROMPACK
F6D1 8EC000                                   ldx     #$c000                                          ; get origin of data
F6D4 9F76                                     stx     <dSource                                                ; save start into variable
F6D6 8E3000                                   ldx     #$3000                                          ; get destination in bank
F6D9 9FFA                                     stx     <dDest                                          ; save destination into variable
F6DB 8E3F00                                   ldx     #$3f00                                          ; get max. length (16k-256bytes)
F6DE 2028                                     bra     storeLen                                                ; skip section                  
F6E0 BD89AA           otherPar        jsr     ckComma                                         ; CkComma
F6E3 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into X
F6E6 8CC000                                   cmpx    #romini                                         ; is it on the upper 32k?
F6E9 1025FE89                                 lblo    badParam                                                ; no, bad format number, show error
F6ED 9F76                                     stx     <dSource                                                ; save start into variable
F6EF 9DA5                                     jsr     <redLChr                                                ; advance one char
F6F1 BD89AA                                   jsr     ckComma                                         ; CkComma
F6F4 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into X
F6F7 8C4000                                   cmpx    #$4000                                          ; is it leaving space for a 16k ROM?
F6FA 1022FE78                                 lbhi    badParam                                                ; yes, bad format number, show error
F6FE 9FFA                                     stx     <dDest                                          ; save destination into variable
F700 9DA5                                     jsr     <redLChr                                                ; advance one char
F702 BD89AA                                   jsr     ckComma                                         ; CkComma
F705 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into X
F708 1F10             storeLen        tfr     x,d                                                     ; pass value to D
F70A D3FA                                     addd    <dDest                                          ; add destination value to calculate end value
F70C 10837FFF                                 cmpd    #basini-1                                       ; does result exceed the RAM area?
F710 1022FE62                                 lbhi    badParam                                                ; yes, bad format number, show error
F714 DD50                                     std     <FPA0                                                   ; save last byte to be written
F716 1F10                                     tfr     x,d                                                     ; get byte count again
F718 D376                                     addd    <dSource                                                ; add first one to copy
F71A 1025FE58                                 lbcs    badParam                                                ; if carry it goes past $FFFF, show message
                                                                                                                      ; stack control
F71E DC50                                     ldd     <FPA0                                                   ; get last byte to write
F720 C30032                                   addd    #50                                                     ; 50 security bytes (stack depth)
F723 109321                                   cmpd    <$21                                                    ; is last calculated address lower than stack pointer?
F726 250D                                     blo     stkOK                                                   ; yes, so it's sure to continue
F728 DCFA                                     ldd     <dDest                                          ; get first destination byte in RAM
F72A 109323                                   cmpd    <$23                                                    ; is higher than strings beginning area?
F72D 2206                                     bhi     stkOK                                                   ; yes, so it's sure to continue
F72F 8EE50A                                   ldx     #stackPrb-1                                     ; point to message
F732 7E90E5                                   jmp     outstr                                          ; show it
                                                                                                                      ; HDW verification
F735 96F9             stkOK           lda     cpyWhat                                         ; get kind of origin to copy
F737 81EF                                     cmpa    #$ef                                                    ; is SLOT requested?
F739 2609                                     bne     seeBank                                         ; no, go to bank control
F73B 17F4A9                                   lbsr    tstMPI                                          ; yes, is there an active MPI?
F73E 270D                                     beq     xsProces                                                ; yes go on     
F740 17F3F4                                   lbsr    NotMPIPresent                           ; no, show message
F743 39                                       rts                                                                     ; return
F744 B60114           seeBank lda     floSDC                                          ; get hdw control byte
F747 8508                                     bita    #%00001000                                      ; is there an SDC?
F749 1027F3EE                                 lbeq    NotSDCPresent                           ; no, show error
                                                                                                                      ; section to copy the code to be executed into $1da
F74D 8EF760           xsProces        ldx     #xsMovCod                                       ; point to origin of code
F750 CE01DA                                   ldu     #$1da                                                   ; point to destination
F753 EC81             xsMov01 ldd     ,x++                                                    ; get a word
F755 EDC1                                     std     ,u++                                                    ; put at destination
F757 8CF7FD                                   cmpx    #xsLoEnd+1                                      ; got to the end?
F75A 25F7                                     blo     xsMov01                                         ; no, loopback
F75C BD01DA                                   jsr     $1da                                                    ; call code at $1da
F75F 39                                       rts                                                                     ; return
                                                                                                                      ; code to be executed
F760 1A50             xsMovCod        orcc    #dimask                                         ; disable interrupts
F762 4F                                       clra                                                                    ; $00 is code for NO old value
F763 9752                                     sta     oldSlot                                         ; for old slot
F765 4A                                       deca                                                                    ; $ff is code for NO old value
F766 9753                                     sta     oldBank                                         ; for old bank
F768 96F9                                     lda     <cpyWhat                                                ; get kind of element to copy
F76A 8140                                     cmpa    #64                                                     ; was command a copy BANK?
F76C 271D                                     beq     xsCopBnk                                                ; yes, go there
                                                                                                                      ; change to the requested slot if not already there and save old slot
F76E B603FF                                   lda     cpyMPIcfg                                       ; get active slot number
F771 9752                                     sta     <oldSlot                                                ; save it
F773 8403                                     anda    #3                                                              ; to have just the number
F775 91F8                                     cmpa    <oriNum                                         ; is the requested one?
F777 2742                                     beq     startCpy                                                ; yes, go start the copy
F779 D6F8                                     ldb     <oriNum                                         ; get requested slot number
F77B 3404                                     pshs    b                                                               ; save it
F77D 58                                       lslb                                                                    ; move to
F77E 58                                       lslb                                                                    ; the high
F77F 58                                       lslb                                                                    ; nibble
F780 58                                       lslb                                                                    ; so 
F781 EAE0                                     orb     ,s+                                                     ; now both are equal
F783 F703FF                                   stb     cpyMPIcfg                                       ; update copy
F786 F7FF7F                                   stb     MPIcfg                                          ; change of slot
F789 2030                                     bra     startCpy                                                ; done, go start the copy
F78B B60114           xsCopBnk        lda     floSDC                                          ; get hdw control byte
F78E 84C0                                     anda    #%11000000                                      ; use bits 7-6 (slot where SDC is)
F790 44                                       lsra                                                                    ; move them to
F791 44                                       lsra                                                                    ; bits 5-4 (lower bits of high nibble)
F792 3402                                     pshs    a                                                               ; save high nibble
F794 44                                       lsra                                                                    ; low nibble   
F795 44                                       lsra                                                                    ; gets high nibble
F796 44                                       lsra                                                                    ; that will end  
F797 44                                       lsra                                                                    ; as zero
F798 AAE0                                     ora     ,s+                                                     ; add high nibble (now they are the same value)
F79A B103FF                                   cmpa    cpyMPIcfg                                       ; is this slot active right now?
F79D 270B                                     beq     cmpBank                                         ; yes, go see if bank differs
F79F F603FF                                   ldb     cpyMPIcfg                                       ; get actual slot
F7A2 B703FF                                   sta     cpyMPIcfg                                       ; update copy
F7A5 B7FF7F                                   sta     MPIcfg                                          ; change of slot
F7A8 D752                                     stb     <oldSlot                                                ; save old slot
F7AA 96F8             cmpBank lda     <oriNum                                         ; compare requested bank with actually selected one 
F7AC B1FF4B                                   cmpa    $ff4b                                                   ; is active now?
F7AF 2708                                     beq   savBank                                           ; yes, save bank
F7B1 F6FF4B                                   ldb     $ff4b                                                   ; no, get active one
F7B4 B7FF4B                                   sta     $ff4b                                                   ; change to requested
F7B7 1F98                                     tfr     b,a                                                     ; pass B to A
F7B9 9753             savBank sta     <oldBank                                                ; save old bank number
F7BB 5F               startCpy        clrb                                                                    ; 0 = not in MAP1
F7BC B6C000                                   lda     romini                                          ; get value in $C000
F7BF 43                                       coma                                                                    ; reverse bits
F7C0 B7C000                                   sta     romini                                          ; update ram cell
F7C3 B1C000                                   cmpa    romini                                          ; retains the new value?
F7C6 2608                                     bne     noMap1                                          ; no, we are in MAP0
F7C8 43                                       coma                                                                    ; reverse again
F7C9 B7C000                                   sta     romini                                          ; restore value
F7CC 5C                                       incb                                                                    ; 1 = we are in MAP1
F7CD B7FFDE                                   sta     $ffde                                                   ; switch to MAP0 to copy the requested ROM
F7D0 D7F8             noMap1  stb     <oriNum                                         ; re-use variable to save that value
F7D2 9E76                                     ldx     <dSource                                                ; point to source ROM
F7D4 DEFA                                     ldu     <dDest                                          ; point to destination RAM
F7D6 EC81             xsLoop01        ldd     ,x++                                                    ; get a word
F7D8 EDC1                                     std     ,u++                                                    ; put at destination
F7DA 119350                                   cmpu    <FPA0                                                   ; got to the end?
F7DD 23F7                                     bls     xsLoop01                                                ; no, loopback
                                                                                                                      ; restore old bank-slot numbers and Map Type
F7DF 9652                                     lda     <oldSlot                                                ; get old slot
F7E1 2706                                     beq     getBank                                         ; if $00, do nothing
F7E3 B703FF                                   sta     cpyMPIcfg                                       ; update copy
F7E6 B7FF7F                                   sta     MPIcfg                                          ; change to old slot number
F7E9 9653             getBank lda     <oldBank                                                ; get old bank number
F7EB 2B03                                     bmi     exscopy                                         ; if $ff, do nothing
F7ED B7FF4B                                   sta     $ff4b                                                   ; switch to old bank number
F7F0 0DF8             exscopy tst     <oriNum                                         ; were we initially in MAP1?
F7F2 2703                                     beq     noMapChg                                                ; no, skip next
F7F4 B7FFDF                                   sta     $ffdf                                                   ; back to MAP1
F7F7 1CAF             noMapChg        andcc   #eimask                                         ; enable interrupts
F7F9 7FFF48                                   clr     $ff48                                                   ; to unsure no led stays lit on FDC
F7FC 39               xsLoEnd rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; routine to verify the status returned by the SDC to a command
                      ;         Bit 7 ($80) set on any failure.
                      ;         Bit 5 ($20) set if target file is already in use.
                      ;         Bit 4 ($10) set if target file not found.
                      ;         Bit 3 ($08) set on miscellaneous hardware errors.
                      ;         Bit 2 ($04) set if path name is invalid.                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
F7FD                  vfyStatus
F7FD 242D                                     bcc     evfy                                                    ; if no error return
F7FF 5D                        tstb                                                                   ; update flags upon result status 
F800 2724                      beq    timeOutError                            ; if zero, timeout
F802 C520                      bitb   #$20                                                    ; detected file in use?
F804 2610                      bne    targetInUseError                        ; yes, message
F806 C510                      bitb   #$10                                                    ; was file not found?
F808 2610                      bne    targetNotFoundError             ; no, message
F80A C508                                bitb         #$08                                                    ; was a hdw error?
F80C 2610                      bne    miscHardwareError                       ; yes, message
F80E C504                      bitb   #$04                                                    ; was invalid pathname?
F810 2610                      bne    pathNameInvalidError            ; yes, message
F812                  unknownError                                                                    ; this is for unknown errors. Should not get here!
F812 8EE570                                   ldx     #unknown-1                                      ; point to message
F815 10                        fcb    #$10                                                    ; skip next ldx 
F816                  targetInUseError                                                                ; 
F816 8EE524                    ldx    #targetInUse-1                          ; point to message
F819 10                        fcb    #$10                                                    ; skip next ldx 
F81A                  targetNotFoundError                                                     ; 
F81A 8EE57F                    ldx    #targetNotFound-1                       ; point to message 
F81D 10                        fcb    #$10                                                    ; skip next ldx 
F81E                  miscHardwareError                                                               ; 
F81E 8EE55A                                   ldx     #miscHardware-1                 ; point to message 
F821 10                        fcb    #$10                                                    ; skip next ldx 
F822                  pathNameInvalidError                                                    ; 
F822 8EE548                                   ldx     #pathNameInvalid-1              ; point to message 
F825 10                        fcb    #$10                                                    ; skip next ldx 
F826                  timeOutError                                                                    ; 
F826 8EE51B                                   ldx     #timeout-1                                      ; point to message 
F829 7E90E5           Exit            jmp   outstr                                            ; show message
F82C 39               evfy            rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; CoCo SDC Low-level interface routine
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; CommSDC by Darren Atkinson
                      ;
                      ;    This is the core routine used for all
                      ;    transactions with the SDC controller.
                      ;
                      ; Entry:
                      ;    A = Command code
                      ;    B = LSN hi byte   or  First parameter byte
                      ;    X = LSN lo word   or  2nd and third parameter bytes
                      ;    U = Address of 256 byte I/O buffer ($ffff = none)
                      ;
                      ; Exit:
                      ;    Carry set on error.
                      ;    B = controller status code.
                      ;    A, X, Y and U are preserved.
                      ;--------------------------------------------------------------------------
F82D 3473             CommSDC  pshs  u,y,x,a,cc                               ; preserve resgisters
F82F 64E4                      lsr   ,s                                       ; shift carry flag out of saved cc
                                                                                                                      ; put controller in command mode
F831 108EFF42                  ldy   #DATREGA                                 ; setup y for hardware addressing (ff42 - ff4a for coco)
F835 860B                      lda   #CMDMODE                                 ; the magic number
F837 A726                      sta   +6,y                                     ; was -10,y for coco - send to control latch (ff48 - ff40 for coco)
                                                                                                                      ; put input parameters into the hardware registers.
                                                                                                                      ; it does no harm to put random data in the
                                                                                                                      ; registers for commands which dont use them.
F839 E73F                      stb   -1,y                                     ; high byte to param reg 1 (ff41 - ff49 for coco)
F83B AFA4                      stx   ,y                                       ; low word to param regs 2 and 3 (ff42-ff43 - ff4a-ff4b for coco)
                                                                                                                      ; wait for not busy.
F83D 8D61                      bsr   waitForIt                           ; run polling loop
F83F 2555                      bcs   cmdExit                             ; exit if error or timeout
                                                                                                                      ; send command to controller
F841 A661                      lda   1,s                                 ; get preserved command code from stack
F843 A73E                      sta   -2,y                                ; send to command register (ff40 - ff48 for coco)
                                                                                                                      ; determine if a data block needs to be sent.
                                                                                                                      ; any command which requires a data block will
                                                                                                                      ; have bit 5 set in the command code.
F845 8520                      bita  #$20                                     ; test the "send block" command bit
F847 272B                      beq   rxBlock                                  ; branch if no block to send
                                                                                                                              ; wait for ready to send
F849 8D55                      bsr   waitForIt                           ; run polling loop
F84B 2549                      bcs   cmdExit                             ; exit if error or timeout
F84D 30C4                      leax  ,u                                  ; move data address to x
                                                                                                                              ; send 256 bytes of data
F84F CC2008                    ldd   #32*256+8                                ; 32 chunks of 8 bytes
F852 EE84             txChunk  ldu   ,x                                       ; send one chunk...
F854 EFA4                      stu   ,y                                                       ; ff42-ff43 - ff4a-ff4b for coco
F856 EE02                      ldu   2,x
F858 EFA4                      stu   ,y
F85A EE04                      ldu   4,x
F85C EFA4                      stu   ,y
F85E EE06                      ldu   6,x
F860 EFA4                      stu   ,y
F862 3A                        abx                                            ; point x at next chunk
F863 4A                        deca                                           ; decrement chunk counter
F864 26EC                      bne   txChunk                                  ; loop until all 256 bytes sent
                                                                                                                      ; wait for command completion
F866 8605                      lda   #5                                       ; timeout retries
F868                  waitCmplt
F868 8D36                                     bsr   waitForIt                                 ; run polling loop
F86A C501                      bitb  #BUSY                                    ; test busy bit
F86C 2728                      beq   cmdExit                                  ; exit if completed
F86E 4A                        deca                                           ; decrement retry counter
F86F 26F7                      bne   waitCmplt                                ; repeat until 0
F871 43                        coma                                           ; set carry for timeout error
F872 2022                      bra   cmdExit                                  ; exit
                                                                                                                      ; for commands which return a 256 byte response block the
                                                                                                                      ; controller will set the ready bit in the status register
                                                                                                                      ; when it has the data ready for transfer.   for commands
                                                                                                                      ; which do not return a response block the busy bit will
                                                                                                                      ; be cleared to indicate that the command has completed.
F874 8D26             rxBlock  bsr   longWait                                 ; run long status polling loop
F876 231E                      bls   cmdExit                                  ; exit if error, timeout or completed
F878 3041                      leax  1,u                                      ; test the provided buffer address
F87A 271A                      beq   cmdExit                                  ; exit if "no buffer" ($ffff)
F87C 30C4                      leax  ,u                                       ; move data address to x
                                                                                                                      ; read 256 bytes of data
F87E CC2008                    ldd   #32*256+8                                ; 32 chunks of 8 bytes
F881 EEA4             rxChunk  ldu   ,y                                       ; read one chunk... (ff42-ff43 - ff4a-ff4b for coco)
F883 EF84                      stu   ,x
F885 EEA4                      ldu   ,y
F887 EF02                      stu   2,x
F889 EEA4                      ldu   ,y
F88B EF04                      stu   4,x
F88D EEA4                      ldu   ,y
F88F EF06                      stu   6,x
F891 3A                        abx                                            ; update x for next chunk
F892 4A                        deca                                           ; decrement chunk counter
F893 26EC                      bne   rxChunk                                  ; loop until all 256 bytes transferred
F895 5F                        clrb                                           ; status code for success, clear carry
                                                                                                                      ; exit
F896 69E4             cmdExit  rol   ,s                                       ; rotate carry into saved cc on stack
F898 6F26                      clr   +6,y                                     ; was -10,y for coco - end command mode (ff48 - ff40 for coco)
F89A 35F3                      puls  cc,a,x,y,u,pc                            ; restore irq masks, update carry and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Wait for controller status to indicate either "Not Busy" or "Ready".
                      ; Will time out if neither condition satisfied within a suitable period.
                      ;
                      ; Exit:
                      ;    CC.C set on error or time out.
                      ;    CC.Z set on "Not Busy" status (if carry cleared).
                      ;    B = status
                      ;    X is clobbered.  A, Y and U are preserved.
                      ; -------------------------------------------------------------------------------------------------------------------------------
F89C 8D02             longWait bsr   waitForIt                                ; enter here for doubled timeout
F89E 241B                      bcc   waitRet                                  ; return if cleared in 1st pass
F8A0                  waitForIt
F8A0 8E0000                                   ldx   #0                                        ; setup timeout counter
F8A3 53               waitLp   comb                                           ; set carry for assumed FAIL
F8A4 E63E                      ldb   -2,y                                     ; read status (FF40 - FF48 for CoCo)
F8A6 2B13                      bmi   waitRet                                  ; return if FAILED
F8A8 54                        lsrb                                           ; BUSY --> Carry
F8A9 240E                      bcc   waitDone                                 ; branch if not busy
F8AB C501                      bitb  #READY/2                                 ; test READY (shifted)
F8AD 260B                      bne   waitRdy                                  ; branch if ready for transfer
F8AF 8D0A                      bsr   waitRet                                  ; consume some time
F8B1 C681                      ldb   #$81                                     ; status = timeout
F8B3 3082                      leax  ,-x                                      ; decrement timeout counter
F8B5 2704                      beq   waitRet                                  ; return if timed out
F8B7 20EA                      bra   waitLp                                   ; try again
F8B9 5F               waitDone clrb                                           ; Not Busy: status = 0, set Z
F8BA 59               waitRdy  rolb                                           ; On Ready: clear C and Z
F8BB 39               waitRet  rts                                            ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; DWLOAD implementation for patched Dragon 32 ROM (upper 8KB) 2014 Tormod Volden
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; Entry point from command line (DWLOAD or EXEC)
                                                                                                                      ; for later to see that we came from DWLOAD command
F8BC 0F11             dwload   clr   <bootflag                                        ; clear our autoboot flag
F8BE 8EFA05                    ldx   #dwtext-1                                        ; 
F8C1 BD90E5                    jsr   outstr                                           ; print string
F8C4 1A50             Start           orcc  #IntMasks                                 ; disable FIRQ, IRQ
F8C6 8EFF20                    ldx   #PIA1Base                        ; PIA1
F8C9 C602                      ldb   #$02
F8CB E784                      stb   ,x                               ; make RS-232 output marking
                                                                                                                      ; Spin for a while so that the RS-232 bit stays hi for a time
F8CD 8EA000           Reset           ldx   #$a000
F8D0 301F             Spin     leax  -1,x
F8D2 26FC                      bne    Spin
                                                                                                                      ; Request named object from DW server
F8D4 9611                      lda   <bootflag                                        ; coming from autoboot?
F8D6 263E                      bne   autoreq                                          ; then use default name
F8D8 9DA5                      jsr   <redLChr                                         ; peek at next character
F8DA 804E                      suba  #'N'                                                     ; DLOADN ?
F8DC 9710                      sta   <noexec                                          ; 0 = noexec
F8DE 2602                      bne   getn
F8E0 9D9F                      jsr   <getNChr                                         ; read next char (the N)
F8E2 BDB7AA           getn     jsr   getfnam                                          ; read file name and length into $1d1 = namebuf
F8E5 8E01D0                    ldx   #namebuf-1                                       ; packet buffer start
F8E8 6F84                      clr   ,x                                                               ; zero MSB for Y
F8EA 10AE81                    ldy   ,x++                                                     ; length of file name (16 bit)
F8ED 2729                      beq   noname                                           ; no file name given?
F8EF E61F                      ldb   -1,x                                                     ; length of name (8 bit)
F8F1 6F85                      clr   b,x                                                      ; zero terminate name string (for error)
F8F3 6C83                      inc   ,--x                                                     ; 1 = DriveWire OP_NAMEOBJ_MOUNT
F8F5 3122                      leay  2,y                                                      ; length of DW packet, name length + 2
F8F7 BDFBA8           reqobj  jsr   DWWrite
F8FA 8E0012                    ldx   #dnum                                                    ; Our drive number variable
F8FD 6F84                      clr   ,x
F8FF 3121                      leay  1,y                                                      ; read one byte back (Y is 0 after DWWrite)
F901 BDFB21                    jsr   DWRead                                           ; get drive number
F904 2401                      bcc    reqOK                                                   ; if open has not failed go on
F906 39                                       rts                                                                     ; else return
F907 6D84             reqOK    tst   ,x
F909 2616                      bne   ReadDECB                                         ; successful mount
F90B 0D11                      tst   <bootflag
F90D 10260137                  lbne  stealth                                          ; silent failure, BASIC OK prompt
F911 C619                      ldb   #$19                                                     ; MO ERROR
F913 7E8344                    jmp   syserr                                           ; system error
F916 9710             autoreq  sta   <noexec                          ; a is non null, autoexec
F918 8EFA36           noname   ldx   #autoname
F91B 108E000E                  ldy   #12+2                                                    ; length of DW packet
F91F 20D6                      bra   reqobj
                                                                                                                      ; named object has been mounted, proceed to read in file
F921 8E0000           ReadDECB        ldx   #0000
F924 BF01CF                    stx   sector
F927 CE02D9                    ldu   #endbuf                                          ; start with empty buffer
F92A 8CF933                                   cmpx    #nextseg
F92D 2104                                     brn     nextseg
F92F 10FF01CD                                 sts     sstack
                                                                                                                      ; read DECB header
F933 108E0005         nextseg  ldy   #5
F937 8E01D1                    ldx   #decbhdr                                         ; copy DECB header here
F93A BDFA58                    jsr   copybuf                                          ; moves x ahead
F93D A61B                      lda   -5,x                                             ; DECB segment header starts with zero
F93F 2753                      beq   ml                                               ; normal data segment
F941 8155                      cmpa  #$55                                             ; Dragon DOS file?
F943 261A                      bne   noddd
F945 3124                      leay  4,y                                              ; remaining header bytes (y is 0 here)
F947 BDFA58                    jsr   copybuf
F94A 6A18                      dec   -8,x                                             ; Dragon DOS BASIC = 1
F94C 2604                      bne   ddbin
F94E 301F                      leax  -1,x                                             ; length at x-5
F950 2022                      bra   ldbas
F952 10AE1B           ddbin    ldy   -5,x                                             ; length
F955 AE19                      ldx   -7,x                                             ; load address
F957 BDFA58                    jsr   copybuf                                          ; read whole file
F95A 8E01D9                    ldx   #decbhdr+8                                       ; exec address ptr + 2
F95D 204B                      bra   oldsp
F95F 4C               noddd    inca
F960 102600E1                  lbne  ErrDWL                                           ; must be $FF otherwise
F964 3121                      leay  1,y                                              ; Y is 0 after copybuf
F966 10BC01CF                  cmpy  sector                                           ; only first sector can be BASIC header
F96A 263A                      bne   endseg                                           ; otherwise end flag
F96C 118301DE                  cmpu  #startbuf+5                                      ; must be first segment also
F970 2634                      bne   endseg
                                                                                                                      ; loading DECB BASIC file
                                                                                                                      ; bytes 4 and 5 are actually part of the program
F972 335E                      leau  -2,u                                             ; u was 5 bytes into read buffer here
                                                                                                                      ; at this point x is past 5-byte header, u is 3 bytes into first 256-bytes block
                                                                                                                      ; for Dragon DOS x is 8 bytes into header, u is 9 bytes into first 256-bytes block
F974 10AE1C           ldbas    ldy   -4,x                                             ; read whole BASIC program
F977 9E19                      ldx   <$19
F979 BDFA58                    jsr   copybuf
F97C BDF99E                    jsr   prbang
                                                                                                                      ; set up BASIC pointers and finish
F97F 9F1B                      stx   <$1b                                             ; end of BASIC program
F981 9F1D                      stx   <$1d
F983 9F1F                      stx   <$1f
F985 0D10                      tst   <noexec
F987 1027BDA2                                 lbeq  $b72d                                             ; print OK, run basvect1, basvect2, readline
F98B BD841F                    jsr   basvect1                                         ; BasVect1 reset BASIC stack etc
F98E BD83ED                    jsr   basvect2                                         ; BasVect2 initialize BASIC
F991 7E849F                    jmp   runbasic                                         ; run_basic
F994 10AE1C           ml       ldy   -4,x                                             ; DECB segment length
F997 AE1E                      ldx   -2,x                                             ; DECB segment loading address
F999 BDFA58                    jsr   copybuf
F99C 2095                      bra   nextseg
F99E BD9A89           prbang   jsr   backspc                                          ; print backspace to devnum
F9A1 8621                      lda   #'!'                                             ; print bang
F9A3 7EB54A                    jmp   outchr                                           ; print to devnum
F9A6 EE1C             endseg  ldu   -4,x                                              ; new stack pointer specified?
F9A8 2603                      bne   setsp
F9AA FE01CD           oldsp    ldu   sstack                                           ; otherwise restore original SP
F9AD 1F34             setsp    tfr   u,s
F9AF 8DED                      bsr   prbang
F9B1 1CAF                      andcc #~IntMasks                                       ; enable interrupts
F9B3 AE1E                      ldx   -2,x                                             ; exec address
F9B5 1F10                      tfr   x,d
F9B7 4C                        inca
F9B8 2708                      beq   retbas                                           ; return to basic if exec address $FFxx
F9BA 9F9D                      stx   <$9d                                             ; save BASIC EXEC address
F9BC 0D10                      tst   <noexec
F9BE 2702                      beq   retbas
F9C0 AD84                      jsr   ,x                                               ; and run loaded program
F9C2 39               retbas   rts
                                      
                                      ; vector table for chainloaders, etc
                                      ; let's give it a fixed location so other progs can access it
F9FE                                  ORG $f9fe
F9FE FB21             dwrvec   fdb   DWRead
FA00 FBA8             dwwvec   fdb   DWWrite
FA02 FAD3             dwdvec   fdb   DoRead
FA04 0000                      fdb   0
FA06 44574C4F4144     dwtext   fcc   /DWLOAD/
FA0C 0D00                      fcb   $0d,0
FA0E EEE1             fromboot ldu   ,s++                                                     ; check return address (and drop it)
FA10 1183B469                  cmpu  #$b469                                           ; ROM code location (not a copy)
FA14 263F                      bne   gocmdl                                           ; return if run from a copied code segment
FA16 8CB44F                    cmpx  #wrmStrt                                         ; coldstart sets this, warmstart doesn't
FA19 263A                      bne   gocmdl                                           ; return if warmstart
                                                                                                                      ; check for SHIFT key
FA1B B6FF02           chkshift lda   $ff02                                                    ; save PIA
FA1E C67F                      ldb   #$7f
FA20 F7FF02                    stb   $ff02
FA23 F6FF00                    ldb   $ff00
FA26 B7FF02                    sta   $ff02                                                    ; restore PIA
FA29 53                        comb
FA2A C440                      andb  #$40
FA2C 2625                                     bne   ste01                                                     ; exit but enabling interrupts
FA2E 5C                        incb                                                                   ; B was 0 before
FA2F D711                      stb   <bootflag                                        ; our autoboot flag = 1
FA31 BDF8C4                    jsr   Start
FA34 201D                                     bra     ste01                                                   ; exit but enabling interrupts
FA36 01               autoname fcb   $01                                                      ; OP_NAMEOBJ_MOUNT
FA37 0C                        fcb   12                                                               ; length of name string
FA38 4155544F4C4F4144          fcn   /AUTOLOAD.DWL/
     2E44574C00
FA45 16BE03           ErrDWL   lbra  ioerror                                          ; BASIC IO ERROR
                      
FA48 CCFAC4           stealth  ldd    #retFDwl                                                ; get return address from DWLOAD
FA4B 10A362                                   cmpd    2,s                                                     ; is this on stack as 2nd retAdrs?
FA4E 2603                                     bne     ste01                                                   ; no, skip next one
FA50 3262                                     leas    2,s                                                     ; get rid of return address (from checkshift)
FA52 39                                       rts                                                                     ; return
                      
FA53 1CAF             ste01           andcc #~IntMasks                                        ; enable interrupts
FA55 7E8371           gocmdl   jmp   okprmpt                                          ; BASIC OK prompt
                                                                                                                      ; copy y chars from read buffer to x, updates u
FA58                  copybuf
FA58 118302D9         copyl    cmpu  #endbuf
FA5C 261D                      bne   copym
                                                                                                                      ; fill up buffer via DW - resets buffer pointer u
FA5E 3430                      pshs  x,y
FA60 BE01CF                    ldx   sector
FA63 108E01D9                  ldy   #startbuf
FA67 1F23                      tfr   y,u
FA69 8D68                      bsr   DoRead
FA6B 25D8                      bcs   ErrDWL
FA6D 26D6                      bne   ErrDWL
FA6F 3001                      leax  1,x
FA71 BF01CF                    stx   sector
FA74 862E                      lda   #'.'                                                     ; print dot
FA76 BDB54A                    jsr   outchr
FA79 3530                      puls  x,y
FA7B A6C0             copym    lda   ,u+
FA7D A780                      sta   ,x+
FA7F 313F                      leay  -1,y
FA81 26D5                      bne   copyl
FA83 39                        rts
                      
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; EXPERimenTs area
                      ; to help Boot any 'bootable' disk in drive 1 if SPACE IS pressed
                      ; or start AUTOLOAD.DWL if SHIFT is NOT pressed
                      ; -------------------------------------------------------------------------------------------------------------------------------
FA84 C601             expert  ldb     #1                                                              ; set drive number
FA86 D7EB                                     stb     <$eb                                                    ; in system variable
FA88 F7060A                                   stb     >$60a                                                   ; and in DOS area
FA8B B6FF02                                   lda   $ff02                                                     ; save PIA value
FA8E C67F                      ldb   #$7f                                                     ; value to test for Space & Shift
FA90 F7FF02                    stb   $ff02                                                    ; put it in the PIA
FA93 F6FF00                    ldb   $ff00                                                    ; read PIA output
FA96 B7FF02                    sta   $ff02                                                    ; restore old value in PIA
FA99 53                        comb                                                                   ; invert read bits
FA9A C420                      andb  #$20                                                     ; is bit5 set?
FA9C 2605                                     bne   doBoot                                            ; yes, SPACE is pressed, BOOT
FA9E BDC16A           noBoot  jsr   $c16a                                                     ; attempt to read a disk sector
FAA1 200B                                     bra     doDWAuto                                                ; simulate it has failed
FAA3 10CE7F36         doBoot  lds     #$7f36                                          ; set new stackpointer
FAA7 8D20                      bsr    rebReset                                                ; rebuild Reset
FAA9 1CAF                                     andcc   #$af                                                    ; enable interrupts
FAAB 7EC13D                                   jmp     $c13d                                                   ; call BOOT drive 1
FAAE 7FFF48           doDWAuto clr    $ff48                                                   ; ensure motors off
FAB1 1CAF                                     andcc #$af                                                      ; enable interrupts 
FAB3 8EB4B2                    ldx   #$b4b2                                           ; get Basic Intro message 
FAB6 BD90E5                    jsr   outstr                                           ; show it
FAB9 8EC34C                    ldx   #$c34c                                           ; get DOS intro message
FABC BD90E5                    jsr   outstr                                           ; show it
FABF 8D08                                     bsr     rebReset                                                ; rebuild Reset
FAC1 17FF57                                   lbsr    chkshift                                                ; check for shift to call AUTOLOAD.DWL
FAC4                  retFDwl 
FAC4 1CAF                                     andcc   #$af                                                    ; enable interrupts
FAC6 7E8371                                   jmp     okprmpt                                         ; goto Basic Iterpreter
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
FAC9 8EC6B4           rebReset        ldx   #$c6b4                                            ; get new reset routine
FACC 9F72                                     stx     <$72                                                    ; put in variables area
FACE 8655                                     lda     #$55                                                    ; flag value for warmreset
FAD0 9771                                     sta     <$71                                                    ; update variable
FAD2 39                                       rts                                                                     ; return
                      
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                              ; below code is taken from toolshed/dwdos
FAD3 9612             DoRead  lda   <dnum                                                     ; our drive number
FAD5 5F                        clrb                                                                   ; LSN bits 23-16
FAD6 3436                      pshs  d,x,y
FAD8 86D2                      lda   #OP_READEX
FADA 3402             ReRead   pshs  a
FADC 30E4                      leax  ,s
FADE 108E0005                                 ldy   #$0005
FAE2 1700C3                                   lbsr  DWWrite
FAE5 3502                                     puls  a
FAE7 AE64                                     ldx   4,s                                                       ; get read buffer pointer
FAE9 108E0100                                 ldy   #256                                                      ; read 256 bytes
FAED CC0085                                   ldd   #133*1                                            ; 1 second timeout
FAF0 8D2F                                     bsr   DWRead
FAF2 252B                      bcs   ReadEx
FAF4 2629                      bne   ReadEx
                                                                                                                      ; Send 2 byte checksum
FAF6 3420                                     pshs  y
FAF8 30E4                                     leax  ,s
FAFA 108E0002                                 ldy   #2
FAFE 1700A7                                   lbsr  DWWrite
FB01 108E0001                                 ldy   #1
FB05 CC0085                                   ldd   #133*1
FB08 8D17                                     bsr   DWRead
FB0A 3262                                     leas  2,s
FB0C 2511                                     bcs   ReadEx
FB0E 260F                     bne   ReadEx
FB10 A6E4                                     lda   ,s
FB12 270B                                     beq   ReadEx
FB14 81F3                                     cmpa  #E_CRC
FB16 2606                                     bne   ReadErr
FB18 86F2                                     lda   #OP_REREADEX
FB1A 6FE4                                     clr   ,s
FB1C 20BC                                     bra   ReRead  
FB1E 53               ReadErr  comb
FB1F 35B6             ReadEx  puls  d,x,y,pc
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; DWRead
                      ;    Receive a response from the DriveWire server.
                      ;    Times out if serial port goes idle for more than 1.4 (0.7) seconds.
                      ;    Serial data format:  1-8-N-1
                      ;    4/12/2009 by Darren Atkinson
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ;    Added a timeout control to the Becker part to avoid infinite loops
                      ;    11-Mars-2016 by Pere Serrat
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Entry:
                      ;    X  = starting address where data is to be stored
                      ;    Y  = number of bytes expected
                      ; Exit:
                      ;    CC = carry set on framing error, Z set if all bytes received
                      ;    X  = starting address of data received
                      ;    Y  = checksum
                      ;    U is preserved.  All accumulators are clobbered
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                              IF becker > 0
                      DWRead   clra                                   ; clear Carry (no framing error)
                               deca                                   ; clear Z flag, A = timeout msb ($ff)
                               tfr    cc,b
                               pshs  u,x,dp,b,a                       ; preserve registers, push flags and timeout msb
                               leau  ,x                                                               ; U points to received data buffer
                               ldx   #$0000                                           ; checksum to zero
                               leas   -2,s                                                    ; create a word hole for a 16 bits counter
                      loop0    ldd    #$F000                                          ; reset counter to a fixed value
                                              std     ,s                                                              ; to count 16 times 256
                      loop1    dec    1,s                                                     ; decrement low byte counter
                                              bne     loop2                                                   ; if not zero, skip next byte control
                                              inc     ,s                                                              ; increment high byte
                                              beq     notReady                                                ; if zero, exit via notReady
                      loop2           ldb   $ff49                                                     ; pol if DW is ready
                               bitb  #$02                                                     ; is ready?
                               beq   loop1                                                    ; no, loop
                               ldb   $ff4a                                                    ; get data byte
                               stb   ,u+                                                      ; put at destination buffer
                               abx                                                                    ; accumulate in checksum word
                               leay  ,-y                                                      ; decrement byte counter
                                              bne     loop0                                                   ; not all received, loopback
                                              leas    2,s                                                     ; discard word counter off the stack
                               tfr   x,y                                                      ; pass checksum to Y
                               ldb   #0
                               lda   #3
                               leas  1,s                              ; remove timeout msb from stack
                      outLoop  inca                                   ; A = status to be returned in C and Z (bit2-Z; bit0-C), now A=4 (Z=1 C=0)
                               ora   ,s                               ; place status information into the..
                               sta   ,s                               ; ..C and Z bits of the preserved CC
                               leay  ,x                               ; get checksum into Y
                               puls  cc,dp,x,u,pc                     ; restore registers and return
                      
                      notReady leas   3,s                                                     ; to remove word counter and timeout
                                              clra                                                                    ; to get a #$01 in next opcode (to set Carry flag)
                                              bra     outLoop                                         ; update flags and exit
                      
                                              ELSE
FB21 4F               DWRead   clra                                   ; clear Carry (no framing error)
FB22 4A                        deca                                   ; clear Z flag, A = timeout msb ($ff)
FB23 1FA9                      tfr   cc,b
FB25 345E                      pshs  u,x,dp,b,a                       ; preserve registers, push timeout msb
                                      IF      NOINTMASK
FB27 1A50                     orcc      #IntMasks           ; mask interrupts
                                      ENDIF
FB29 1F8B                      tfr   a,dp                             ; set direct page to $FFxx
FB2B                           setdp $ff
FB2B 3384                      leau  ,x                               ; U = storage ptr
FB2D 8E0000                    ldx   #0                               ; initialize checksum
FB30 8601                      lda   #$01                             ; A = serial in mask
FB32 2032                      bra   rx0030                           ; go wait for start bit
                                                                                                                      ; Read a byte
FB34 3341             rxByte   leau  1,u                              ; bump storage ptr
FB36 31A2                      leay  ,-y                              ; decrement request count
FB38 9622                      lda   <BBIN                            ; read bit 0
FB3A 44                        lsra                                   ; move bit 0 into Carry
FB3B CCFF20                    ldd   #$ff20                           ; A = timeout msb, B = shift counter
FB3E A7E4                      sta   ,s                               ; reset timeout msb for next byte
FB40 56                        rorb                                   ; rotate bit 0 into byte accumulator
FB41 9622             rx0010   lda   <BBIN                            ; read bit (d1, d3, d5)
FB43 44                        lsra
FB44 56                        rorb
FB45 A561                      bita  1,s                              ; 5 cycle delay
FB47 2508                      bcs   rx0020                           ; exit loop after reading bit 5
FB49 9622                      lda   <BBIN                            ; read bit (d2, d4)
FB4B 44                        lsra
FB4C 56                        rorb
FB4D 33C4                      leau  ,u
FB4F 20F0                      bra   rx0010
FB51 9622             rx0020   lda   <BBIN                            ; read bit 6
FB53 44                        lsra
FB54 56                        rorb
FB55 31A4                      leay  ,y                               ; test request count
FB57 2737                      beq   rx0050                           ; branch if final byte of request
FB59 9622                      lda   <BBIN                            ; read bit 7
FB5B 44                        lsra
FB5C 56                        rorb                                   ; byte is now complete
FB5D E75F                      stb   -1,u                             ; store received byte to memory
FB5F 3A                        abx                                    ; update checksum
FB60 9622                      lda   <BBIN                            ; read stop bit
FB62 8401                      anda  #$01                             ; mask out other bits
FB64 2737                      beq   rxExit                           ; exit if framing error
                                                                                                                      ; Wait for a start bit or timeout
FB66 9522             rx0030   bita  <BBIN                            ; check for start bit
FB68 27CA                      beq   rxByte                           ; branch if start bit detected
FB6A 9522                      bita  <BBIN                            ; again
FB6C 27C6                      beq   rxByte
FB6E C6FF                      ldb   #$ff                             ; init timeout lsb
FB70 9522             rx0040   bita  <BBIN
FB72 27C0                      beq   rxByte
FB74 C001                      subb  #1                               ; decrement timeout lsb
FB76 9522                      bita  <BBIN
FB78 27BA                      beq   rxByte
FB7A 24F4                      bcc   rx0040                           ; loop until timeout lsb rolls under
FB7C 9522                      bita  <BBIN
FB7E 27B4                      beq   rxByte
FB80 EBE4                      addb  ,s                               ; B = timeout msb - 1
FB82 9522                      bita  <BBIN
FB84 27AE                      beq   rxByte
FB86 E7E4                      stb   ,s                               ; store decremented timeout msb
FB88 9522                      bita  <BBIN
FB8A 27A8                      beq   rxByte
FB8C 25D8                      bcs   rx0030                           ; loop if timeout hasn't expired
FB8E 200D                      bra   rxExit                           ; exit due to timeout
FB90 9622             rx0050   lda   <BBIN                            ; read bit 7 of final byte
FB92 44                        lsra
FB93 56                        rorb                                   ; byte is now complete
FB94 E75F                      stb   -1,u                             ; store received byte to memory
FB96 3A                        abx                                    ; calculate final checksum
FB97 9622                      lda   <BBIN                            ; read stop bit
FB99 8401                      anda  #$01                             ; mask out other bits
FB9B 8A02                      ora   #$02                             ; return SUCCESS if no framing error
                                                                                                                      ; Clean up, set status and return
FB9D 3261             rxExit   leas  1,s                              ; remove timeout msb from stack
FB9F 4C                        inca                                   ; A = status to be returned in C and Z
FBA0 AAE4                      ora   ,s                               ; place status information into the..
FBA2 A7E4                      sta   ,s                               ; ..C and Z bits of the preserved CC
FBA4 3184                      leay  ,x                               ; return checksum in Y
FBA6 35D9                      puls  cc,dp,x,u,pc                     ; restore registers and return
FBA8                           setdp $00
                                              ENDIF
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; DWWrite
                      ;    Send a packet to the DriveWire server.
                      ;    Serial data format:  1-8-N-1
                      ;    4/12/2009 by Darren Atkinson
                      ; Entry:
                      ;    X  = starting address of data to send
                      ;    Y  = number of bytes to send
                      ; Exit:
                      ;    X  = address of last byte sent + 1
                      ;    Y  = 0
                      ;    All others preserved
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                              IF becker > 0
                      DWWrite  pshs  d,cc                             ; preserve registers
                      txByte  lda   ,x+
                               sta   $ff4a
                               leay  -1,y                     ; decrement byte counter
                               bne   txByte                   ; loop if more to send
                               puls  cc,d,pc                  ; restore registers and return
                      
                                              ELSE                                                       
FBA8 340F             DWWrite  pshs  dp,d,cc                  ; preserve registers
                                      IF      NOINTMASK
FBAA 1A50                     orcc      #IntMasks           ; mask interrupts
                                      ENDIF
FBAC CC04FF                    ldd   #$04ff                   ; A = loop counter, B = $ff
FBAF 1F9B                      tfr   b,dp                     ; set direct page to $FFxx
FBB1                           setdp $ff                                      
FBB1 D623                      ldb   <$ff23                   ; read PIA 1-B control register
FBB3 C4F7                      andb  #$f7                     ; clear sound enable bit
FBB5 D723                      stb   <$ff23                   ; disable sound output
FBB7 8C                        fcb   $8c                      ; skip next instruction
FBB8 D720             txByte   stb   <BBOUT                   ; send stop bit
FBBA E680                      ldb   ,x+                      ; get a byte to transmit
FBBC 12                        nop                                                    
FBBD 58                        lslb                           ; left rotate the byte two positions..
FBBE 59                        rolb                           ; ..placing a zero (start bit) in bit 1
FBBF D720             tx0020   stb   <BBOUT                   ; send bit (start bit, d1, d3, d5)
FBC1 56                        rorb                           ; move next bit into position
FBC2 1E88                      exg   a,a                                      
FBC4 12                        nop                                                    
FBC5 D720                      stb   <BBOUT                   ; send bit (d0, d2, d4, d6)
FBC7 56                        rorb                           ; move next bit into position
FBC8 33C4                      leau  ,u                                               
FBCA 4A                        deca                           ; decrement loop counter
FBCB 26F2                      bne   tx0020                   ; loop until 7th data bit has been sent
FBCD D720                      stb   <BBOUT                   ; send bit 7
FBCF CC0402                    ldd   #$0402                   ; A = loop counter, B = MARK value
FBD2 31A2                      leay  ,-y                      ; decrement byte counter
FBD4 26E2                      bne   txByte                   ; loop if more to send
FBD6 D720                      stb   <BBOUT                   ; leave bit banger output at MARK
FBD8 358F                      puls  cc,d,dp,pc               ; restore registers and return
FBDA                           setdp $00
                                              ENDIF
                      
                      ; ===============================================================================================================================
                                                                                                                      ; THIS PART WILL ONLY BE NEEDED IF WE MODIFY THE PATCHES-CODE
                                                                                                                      ; IN THIS CASE THE DOSPLUS HAS TO BE RE-PATCHED TO UPDATE LINKS/HOOKS
                                                                                                                      ; No problem as long as we just work from the init routine downwards
                                                                                                                      ; simply EXEC $reptch from $6xxx having DPlus at $4000 and resave the DOS
                                                                                                                      ; for easy of use just need to do: jmp $c005
                      ; ===============================================================================================================================
                                                                                                                      ; 1st patch. To redirect ReadAbsoluteSector and WriteAbsoluteSector to DW4 new process
FBDA 338DC528         reptch  leau    $c106,pcr                                       ; the DOS address code to be redirected here
FBDE CC7E12                                   ldd     #$7e12                                          ; opcodes for jmp and NOP
FBE1 8EE008                                   ldx     #entry                                          ; new entry point for DOS sector READ-WRITE commands
FBE4 A7C0                                     sta     ,u+                                                     ; put jmp
FBE6 AFC1                                     stx     ,u++                                                    ; put the new dispatch routine
FBE8 E7C4                                     stb     ,u                                                              ; put NOP
                                                                                                                      ; 2nd patch - for DSKINIT while writting to NOT directory sectors
FBEA 338DC737                                 leau    $c325,pcr                                       ; point to intercept
FBEE 8EE0CA                                   ldx     #inidsk                                         ; new added code
FBF1 A7C0                                     sta     ,u+                                                     ; put jmp
FBF3 AFC4                                     stx     ,u                                                              ; put the new code address
                                                                                                                      ; 3rd patch to fill the three buffers for DSKINIT ($800-$900-$a00) writting to directory sectors
FBF5 338DCDFA                                 leau    $c9f3,pcr                                       ; point to intercept
FBF9 8EE145                                   ldx     #fildir                                         ; new added code
FBFC A7C0                                     sta     ,u+                                                     ; put jmp
FBFE AFC4                                     stx     ,u                                                              ; put the new code address
                                                                                                                      ; 4th patch to correct track number when verifying tracks in DSKINIT to VDK files
FC00 338DD5A0                                 leau    $d1a4,pcr                                       ; point to intercept
FC04 8EE1EE                                   ldx     #modtrk                                         ; new added code
FC07 A7C0                                     sta     ,u+                                                     ; put jmp
FC09 AFC4                                     stx     ,u                                                              ; put the new code address
                                                                                                                      ; 5th patch to update system table at $6a7-8-9-a for BACKUP
FC0B 338DCC27                                 leau    $c836,pcr                                       ; point to intercept
FC0F 8EE276                                   ldx     #patbck                                         ; new added code
FC12 A7C0                                     sta     ,u+                                                     ; put jmp
FC14 AFC4                                     stx     ,u                                                              ; put the new code address
                                                                                                                      ; 6th patch to prevent a rutine to test hdw for DW4 drives
FC16 338DC556                                 leau    $c170,pcr                                       ; point to intercept
FC1A 8EE29F                                   ldx     #noHdw                                          ; new added code
FC1D A7C0                                     sta     ,u+                                                     ; put jmp
FC1F AFC1                                     stx     ,u++                                                    ; put the new code address
FC21 E7C4                                     stb     ,u                                                              ; put NOP
                                                                                                                      ; 7th patch for DOS reset routine
FC23 338DCAA2                                 leau    $c6c9,pcr                                       ; point to intercept
FC27 8EE2C1                                   ldx     #dosReset                                       ; new added code
FC2A A7C0                                     sta     ,u+                                                     ; put jmp
FC2C AFC1                                     stx     ,u++                                                    ; put the new code address
                                                                                                                      ; 8th patch to make BOOT command RSDOS capable (Mike Miller)
FC2E 338DC517                                 leau    $c149,pcr                                       ; point to patch location
FC32 8EE852                                   ldx     #rsbtchk                                        ; address of new code in DPE
FC35 A7C0                                     sta     ,u+                                                     ; patch jmp
FC37 AFC1                                     stx     ,u++                                                    ; patch address
                      
FC39 39                                       rts                                                                     ; return to caller
                      ; ===============================================================================================================================
                      
                                              IF drgrom > 0
                                                      if (*%256 > 0)
                                                                      rzb      256-(*%256)    ; make it ROM compatible (length multiple of 256 bytes)
                                                      endif
                                              ENDIF
                      ; -------------------------------------------------------------------------------------------------------------------------------
FC3A                  absEnd  end
