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
E015 170CB7                                   lbsr    flOrSd                                          ; control access to floppy or SDC
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
E2AB 170A21                                   lbsr    flOrSd                                          ; will take care of destination hdw                     
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
E5F4 1705F2                                   lbsr    tstMPI                                          ; is there an MPI?
E5F7 2604                                     bne     initsk01                                                ; no, go to individual checks
E5F9 17054A                                   lbsr    tstHARD                                         ; yes, verify connected hardware
E5FC 39                                       rts                                                                     ; return
                                                                                                                      ; else verify individual elements (only one active)
E5FD 17060D           initsk01        lbsr    tstSDC                                          ; is SDC active?
E600 2709                                     beq     fndSDC                                          ; yes, skip next test
E602 17061F                                   lbsr    tstFLO                                          ; is FDC active instead?
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
E686 F8BE             nwtb01  fdb   dwload                                            ; routine for DWLOAD command
E688 E6B9                                     fdb   mount                                             ; routine for MOUNT command                
E68A E727                                     fdb     link                                                    ; routine for LINK command
E68C E7A4                                     fdb     llink                                                   ; routine for LLINK command
E68E E801                                     fdb     os9boot                                         ; routine to boot NitrOS-9
E690 E881                                     fdb     xlrom                                                   ; routine to load - run a ROM image
E692 EA27                                     fdb     xbank                                                   ; routine to switch SDC active bank
E694 EC41                                     fdb     xslot                                                   ; routine to change of MPI slot
E696 ED31                                     fdb     xsdrive                                         ; routine for SDC-card DRIVE functions
E698 F325                                     fdb     xsdir                                                   ; routine for SDC-card DIR functions
E69A ED17                                     fdb     xHDidx                                          ; routine to select index of HD
E69C F222                                     fdb     xsmkdir                                         ; routine for SMKDIR command
E69E F24C                                     fdb     xskill                                          ; routine for SDELETE command
E6A0 F253                                     fdb     xsren                                                   ; routine for SRENAME command
E6A2 E78B                                     fdb     snError                                         ; simply show syntax error
E6A4 F2EA                                     fdb     xschd                                                   ; routine for SCHD command
E6A6 F4CB                                     fdb     xwrite                                          ; routine for WRITE command
E6A8 F695                                     fdb     xscopy                                          ; routine for SCOPY command
E6AA E748                                     fdb linkwrk
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Dispatch routines for the new added commands
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Routine to mark as invalid the four I/O buffers
                      ; -------------------------------------------------------------------------------------------------------------------------------
E6AC 4F               mrkmod  clra                                                                    ; get a 0
E6AD 8E0636                                   ldx     #$636                                                   ; point to 1st I/O buffer flags data
E6B0 C615                                     ldb     #21                                                     ; offset to last I/O
E6B2 A785             mo01            sta     b,x                                                     ; mark as invalid
E6B4 C007                                     subb    #7                                                              ; offset to previous I/O
E6B6 2AFA                                     bpl     mo01                                                    ; if not negative, loopback
E6B8 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to ask DW4 to mount a VDK file and get the slot number back
                      ; -------------------------------------------------------------------------------------------------------------------------------
E6B9 1700BA           mount           lbsr    readunit                                                ; read unit number
E6BC D7F8                                     stb     <numUni                                         ; save it as number of Unit
E6BE BD89AA                                   jsr     ckComma                                         ; CkComma
E6C1 BDB7AA                                   jsr     getfnam                                         ; GetNam into $1d1 (nambuf)
E6C4 8E01D0                   ldx   #nambuf-1                                 ; byte before packet buffer start
E6C7 6F84                     clr   ,x                                                                ; zero MSB to make a 16 bit value for Y
E6C9 10AE81                   ldy   ,x++                                                      ; length of file name (16 bit)
E6CC 2756                     beq   failvdk                                           ; if len=0 no file entered
E6CE E61F                     ldb   -1,x                                                      ; length of name (8 bit)
                                                                                                                      ; Adding .VDK if not termination entered, costs 31 bytes       
E6D0 3414                                     pshs  b,x                                                       ; save pointer to beginning of name and name length
E6D2 A680             isdot   lda   ,x+                                                       ; get a char from name
E6D4 812E                     cmpa  #'.'                                                      ; is it a dot?
E6D6 2718                     beq   alrdot                                            ; yes, stop search, quit loop
E6D8 5A                       decb                                                                    ; decrement counter
E6D9 26F7                     bne   isdot                                                     ; not end of string, get next char name
E6DB CC2E56                   ldd   #$2e56                                            ; get chars ".V"
E6DE ED81                     std   ,x++                                                      ; add to end of name
E6E0 CC444B                   ldd   #$444b                                            ; get chars "DK"
E6E3 ED81                     std   ,x++                                                      ; add to end of name
E6E5 E6E4                                     ldb   ,s                                                                ; get old name length
E6E7 CB04                                     addb  #4                                                                ; add 4 (because of .VDK added)
E6E9 E7E4                                     stb   ,s                                                                ; update new length in stack
E6EB F701D1                   stb   nambuf                                            ; save new length in byte before string
E6EE 3124                     leay  4,y                                                       ; correction to name length - DW parameter
E6F0 3402             alrdot  pshs    a                                                               ; save register
E6F2 8602                                     lda     #2                                                              ; get value to mark output
E6F4 B7FF20                                   sta     BBOUT                                                   ; to DW4
E6F7 4F                                       clra                                                                    ; set counter
E6F8 4A               mount01 deca                                                                    ; decrement counter
E6F9 26FD                                     bne     mount01                                         ; not zero, loopback
E6FB 3502                                     puls    a                                                               ; restore register
E6FD 3514                                     puls  b,x                                               ; restore pointer and length
E6FF 6F85                                     clr   b,x                                                       ; zero terminate name string (for error)
E701 6C83                     inc   ,--x                                                      ; 1 = DriveWire OP_NAMEOBJ_MOUNT command
E703 3122                     leay  2,y                                                       ; length of DW packet = name length + 2
E705 1A50                     orcc    #dimask                                         ; disable interrupts to work with DW4
E707 BDFBA8                   jsr   DWWrite                                           ; send file request to server
E70A 8E0012                   ldx   #dnum                                                     ; our drive number variable
E70D 6F84                     clr   ,x                                                                ; clear it
E70F 3121                     leay  1,y                                                       ; read one byte back
E711 BDFB21                   jsr   DWRead                                            ; get drive number
E714 1CAF                                     andcc #eimask                                           ; enable interrupts again 
E716 6D84                     tst   ,x                                                                ; verify received value
E718 2605                     bne   vdkok                                                     ; successful mount                                       
E71A C619                     ldb   #$19                                                      ; code for MO ERROR
E71C 7E8344                                   jmp   syserr                                            ; show error message (syserr)
E71F D612             vdkok           ldb     <dnum                                                   ; pass slot to B
E721 8D25                                     bsr     linkwrk                                                 ; verify / store new value
E723 39                                       rts                                                                     ; return
E724 7EB84B           failvdk jmp   ioerror                                           ; I/O error message
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to link a Unit with a drive number or a DW4 slot number
                      ; -------------------------------------------------------------------------------------------------------------------------------
E727 8D4D             link            bsr     readunit                                                ; read unit number
E729 D7F8                                     stb     <numUni                                         ; save it as number of Unit
E72B 8D65                                     bsr     opt8bit                                         ; search another param 8 bit number
E72D 260E                                     bne     link01                                          ; if greater than 0, goto more tests
                                                                                                                      ; requested slot #0
E72F D6F8                                     ldb     <numUni                                         ; get unit number
E731 C101                                     cmpb    #1                                                              ; is it 1?
E733 2604                                     bne     notalw                                          ; no, error. Only unit 1 is allowed to be linked to slot #0
E735 0FFC                                     clr     <$fc                                                    ; put 0 value in first cell (unit 1, value 0)
E737 200E                                     bra     link03                                          ; exit
E739 C608             notalw  ldb     #$08                                                    ; code for FC error
E73B 2045                                     bra     basyserr                                                ; show error message
E73D C104             link01  cmpb    #4                                                              ; is new value greater than 4 (DW4)?
E73F 2204                                     bhi     link02                                          ; yes, skip test
E741 D1F8                                     cmpb    <numUni                                         ; equals new drive number the unit number? (mandatory!)
E743 262B                                     bne     numError                                                ; no, show unit error
E745 8D01             link02  bsr     linkwrk                                                 ; verify and store new value
E747 39               link03  rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Verifies that the new value (B) is not linked to another unit. If good, saves it
                      ; -------------------------------------------------------------------------------------------------------------------------------
E748 8E00FB           linkwrk         ldx     #$00fb                                          ; point one byte before drive/slot table
E74B 8604                                     lda     #4                                                              ; counter (number of units)
E74D E186             stv02           cmpb    a,x                                                     ; equals new value the contents of that slot?
E74F 2715                                     beq     stv04                                                   ; yes, see if it is the same unit
E751 4A                                       deca                                                                    ; decrement counter
E752 26F9                                     bne     stv02                                                   ; if not 0, loopback
E754 8E00FB           estval  ldx     #$00fb                                          ; point to one byte before data table
E757 96F8                                     lda     <numUni                                         ; get unit number
E759 8104                                     cmpa    #4                                                              ; is unit 4?
E75B 2603                                     bne     stv03                                                   ; no, skip next
E75D 7F0115                                   clr     idxHD                                                   ; set index to HD to 0
E760 E786             stv03           stb     a,x                                                     ; store slot into table
E762 17FF47                                   lbsr    mrkmod                                          ; modify data to flag drive changes to system   
E765 39                                       rts                                                                     ; everything alright, return
E766 91F8             stv04           cmpa    <numUni                                         ; is unit with this value the same as destination in LINK command?
E768 27EA                                     beq     estval                                          ; yes, acceptable, return
E76A 3262                                     leas    2,s                                                     ; get rid of return address
                                                                                                                              ; show error. We do not admit the same slot number in two units!
                      ;                       bra     already                                 ; *** Fall Thru *** not needed 
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
E76C 8EE3D3           already ldx     #alrput-1                                       ; point to error message
E76F 10                                       fcb     #$10                                                    ; to jump over next one
E770 8EE3BC           numError ldx    #drverr-1                                       ; point to error message
E773 7E90E5                                   jmp     outstr                                          ; show message and return to interpreter
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E776 0FF8             readunit        clr     <numUni                                         ; clear unit number
E778 8D0D                                     bsr     getunit                                         ; get a one digit number
E77A 2704                                     beq     errNum                                          ; if zero jump to device error
E77C C104                                     cmpb    #4                                                              ; is it greater than 4?
E77E 2305                                     bls     OKnext                                          ; no, goto OK
E780 C628             errNum  ldb     #$28                                                    ; device number error (bas_err_DN)
E782 7E8344           basyserr        jmp     syserr                                          ; bas_system_error
E785 0EA5             OKnext  jmp     <redLChr                                                ; bas_poll_char                 
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E787 9DA5             getunit jsr     <redLChr                                                ; get a char (bas_poll_char)
E789 2603                                     bne     r8b01                                                   ; if there is something, skip next
E78B 7E89B4           snError jmp     synerr                                          ; show error message (BAS-SN-Error)
E78E BDE79C           r8b01           jsr     get8bit                                         ; get a number (8bits)
E791 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E792 9DA5             opt8bit jsr     <redLChr                                                ; get a char (bas_poll_char)
E794 2705                                     beq     eo8b                                                    ; if 0, return
E796 BD89AA                                   jsr     ckComma                                         ; check if there is a comma separator (CkComa)
E799 8D01                                     bsr     get8bit                                         ; get a 8 bits number
E79B 39               eo8b            rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E79C 3460             get8bit pshs    y,u                                                     ; save working registers
E79E BD8E51                                   jsr     asc2Num                                         ; convert ASCII to number (1 byte)
E7A1 5D                                       tstb                                                                    ; update flags upon result
E7A2 35E0                                     puls    y,u,pc                                          ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to show the links of every unit
                      ; -------------------------------------------------------------------------------------------------------------------------------
E7A4 8EE3EE           llink           ldx     #headlnk-1                                      ; point to message header
E7A7 BD90E5                                   jsr     outstr                                          ; show it
E7AA 8E00FB                                   ldx     #$00fb                                          ; point one byte before first data byte
E7AD C601                                     ldb     #1                                                              ; unit counter
E7AF A685             llink01 lda     b,x                                                     ; get linked value
E7B1 8D06                                     bsr     showLine                                                ; show data
E7B3 5C                                       incb                                                                    ; increment counter
E7B4 C104                                     cmpb    #4                                                              ; done all units?
E7B6 23F7                                     bls     llink01                                         ; no, loopback
E7B8 39                                       rts                                                                     ; return to caller
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E7B9 3416             showLine        pshs    d,x                                                     ; save working registers
E7BB 8EE3FB                                   ldx     #spaces+1                                       ; point to print 2 spaces
E7BE BD90E5                                   jsr     outstr                                          ; print them
E7C1 E661                                     ldb     1,s                                                     ; get unit number
E7C3 4F                                       clra                                                                    ; clear high byte
E7C4 BD957A                                   jsr     outnum                                          ; print number
E7C7 E6E4                                     ldb     ,s                                                              ; get linked value
E7C9 4F                                       clra                                                                    ; clear high byte
E7CA C10A                                     cmpb    #10                                                     ; is value lower than 10?
E7CC 2506                                     blo     sL01                                                    ; yes, goto print
E7CE 4C                                       inca                                                                    ; one space less
E7CF C164                                     cmpb    #100                                                    ; is value lower than 100?
E7D1 2501                                     blo     sL01                                                    ; yes, goto print
E7D3 4C                                       inca                                                                    ; one space less
E7D4 8EE3F9           sL01            ldx     #spaces-1                                       ; point to print 4 spaces
E7D7 3086                                     leax    a,x                                                     ; skip the calculated ones upon the value
E7D9 BD90E5                                   jsr     outstr                                          ; print required spaces
E7DC E6E4                                     ldb     ,s                                                              ; get linked value
E7DE 4F                                       clra                                                                    ; clear high byte                                                       
E7DF BD957A                                   jsr     outnum                                          ; print number
E7E2 E661                                     ldb     1,s                                                     ; get unit number
E7E4 C104                                     cmpb    #4                                                              ; is it 4?
E7E6 2612                                     bne     sL02                                                    ; no, stop printing
E7E8 F60115                                   ldb     idxHD                                                   ; get index for HD
E7EB 270D                                     beq     sL02                                                    ; if zero, skip printing it
E7ED 8EE427                                   ldx     #xidxTxt-1                                      ; point to text
E7F0 BD90E5                                   jsr     outstr                                          ; show it
E7F3 F60115                                   ldb     idxHD                                                   ; get unit number
E7F6 4F                                       clra                                                                    ; zero to high byte
E7F7 BD957A                                   jsr     outnum                                          ; call ROM to print integer in D
E7FA 860D             sL02            lda     #$0d                                                    ; enter
E7FC BDBCAB                                   jsr     outRegA                                         ; print A 
E7FF 3596                                     puls    d,x,pc                                          ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to Boot a NitrOS-9 disc
                      ; -------------------------------------------------------------------------------------------------------------------------------
E801 5F               os9boot  clrb                                                                   ; default drive 0
E802 9DA5                      jsr   <redLChr                 ; peek at next char
E804 2703                      beq   defnum                                           ; not found, use default
E806 BD8E51                    jsr   asc2Num                                  ; Get 1 byte
E809 D712             defnum  stb   <dnum                                                     ; save drive number
E80B 8EE3FE                                   ldx   #ldtext-1                                 ; point to 'loading' message
E80E BD90E5                    jsr   outstr                                           ; show it
E811 1A50                                     orcc  #dimask                                           ; disable interrupts
E813 BDE86F                                   jsr     trick                                                   ; make sure DW4 connection is on
                                                                                                                              ; DriveWire bootstrap code. Get sectors 612-629 to $2600
E816 8E0264                         ldx   #612                                                        ; starting sector number to load
E819 108E2600                  ldy   #$2600                                           ; destination in memory
E81D BDFAD3           DOSLoop  jsr   DoRead                                           ; read sector (into Y)
E820 252F                      bcs   fail2                                                    ; start all over
E822 262D                      bne   fail2                                                    ; show error
E824 8C0264                    cmpx  #612                                                     ; our first sector?
E827 2608                      bne   not1st                                           ; branch if not
E829 ECA4                      ldd   ,y                                                               ; else get 1st two bytes at $2600
E82B 10834F53                  cmpd  #$4f53                                           ; OS?
E82F 261A                      bne   noos                                                     ; no, show error
E831 866A             not1st   lda   #'*'+$40                                         ; print star
E833 31A90100                  leay  256,y                                                    ; move for next sector
E837 3001                      leax  1,x                                                      ; increment number of sector to be read
E839 A789023B                  sta   571,x                                                    ; print progress (1024+32*5-612-1)
E83D 8C0276                    cmpx  #630                                                     ; are we at last sector?
E840 2DDB                      blt   DOSLoop                                          ; branch if not
E842 8661                      lda   #'!'+$40                                         ; print bang
E844 A789027B                  sta   635,x                                                    ; over last '*' (636-1)
E848 7E2602                    jmp   $2602                                                    ; jump into Boot code
E84B 8EE411           noos     ldx   #noostxt-1                                       ; point to message
E84E BD90E5                    jsr   outstr                                           ; print string at x+1
E851 7EB84B           fail2    jmp   ioerror                                          ; IO_error equ $b84b
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Patch to DosPlus Boot to allow RSDOS disks to boot too (Mike Miller 2021-05)
                      ; -------------------------------------------------------------------------------------------------------------------------------
E854 8C4F53           rsbtchk  cmpx   #$4F53                                          ; Check for signature
E857 2713                                     beq     rsbt01                                                  ; Boot DragonDOS style disk
E859 CC2201                                   ldd     #$2201                                                  ; Look instead RSDOS location track 34 first sector
E85C BDC0F9                                   jsr     gtbtsig                                    ; Read boot sig (enter after track and sector set)
E85F 2401                                     bcc     rsbt00                                          ; it's OK, skip next
                      ;                       jmp     $C166                                                   ; Failed to read then exit
E861 39                                       rts                                                             ; Failed to read then exit
E862 9E4F             rsbt00  ldx     $4F                                                     ; Get first 2 bytes 
E864 8C4F53                                   cmpx    #$4F53                                          ; Check for signature 
E867 2703                                     beq     rsbt01                                          ; it is Bootable!
E869 7EC164                                   jmp     $C164                                              ; Not bootable RSDOS way either, exit with ?BT error 
E86C 7EC14E           rsbt01  jmp     $C14E                                                   ; Otherwise load the track
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Routine that marks on the DW4 line for a while, to avoid fails at 1st access
                      ; -------------------------------------------------------------------------------------------------------------------------------
E86F 3414             trick    pshs   b,x                                                     ; save working registers
E871 8EFF20                                   ldx   #PIA1Base                         ; address of PIA1
E874 C602                      ldb   #$02                                                     ; put value #2 (bit1 to high level)
E876 E784                      stb   ,x                               ; make RS-232 output marking
                                                                                                                              ; Spin for a while so that the RS-232 bit stays hi for a time
E878 8EA000           waw             ldx   #$a000                                            ; wait counter
E87B 301F             waw1     leax  -1,x                                                     ; decrement counter
E87D 26FC                      bne   waw1                                                     ; if not 0, loopback
E87F 3594                      puls   b,x,pc                                          ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to load - run a ROM image
                      ; -------------------------------------------------------------------------------------------------------------------------------
E881 1A50             xlrom           orcc  #dimask                   ; disable firq, irq
E883 8DEA                                     bsr     trick                                                   ; make sure dw4 connection is on
E885 9DA5             lromrty         jsr   <redLChr                                          ; peek at next character (after "rom")
E887 804E                     suba  #'N'                                                      ; to detect if it was an 'n' - if so don't exec it after loading
E889 9710                     sta   <noexec                                           ; save difference. 0 = noexec
E88B 2602                     bne   savvec                                            ; if not 'n' jump next instruccion
E88D 9D9F                     jsr   <getNChr                                          ; jump over that char (the 'n')
E88F 8EE364           savvec  ldx   #ldtextr-1                                        ; byte before message
E892 8D76                                     bsr   prtstr                                            ; print string
E894 BDB7AA                           jsr   getfnam                                           ; read rom file name and length into $1d1 = nambuf
E897 7D01D1                   tst     nambuf                                          ; is filename length equal 0?
E89A 261D                     bne     rom01                                                   ; no, process it
E89C F6060A                   ldb     $60a                                                    ; get default drive number
E89F 8E00FB                   ldx     #$00fb                                          ; point to table of links x unit
E8A2 A685                     lda     b,x                                                     ; search slot number in table
E8A4 2604                     bne     ver01                                                   ; if not 0, do more tests
E8A6 C101                     cmpb    #1                                                              ; is slot 0 linked to unit 1? - to avoid tricks with poke unit's slot numbers
E8A8 2704                     beq     ver02                                                   ; yes, accept it and go on. the only legal one!
E8AA 8105             ver01           cmpa    #5                                                              ; is it a dw4 slot?
E8AC 2504                     blo     errdw4                                          ; no, show error
E8AE 9712             ver02           sta     <dnum                                                   ; save slot number at variable
E8B0 2064                     bra     rdecb                                                   ; go process rom at default drive
E8B2 8EE38D           errdw4  ldx     #notdw4-1                                       ; point to message error
E8B5 BD90E5                                   jsr   outstr                                            ; show message
E8B8 39                                       rts                                                                     ; return
E8B9 8E01D0           rom01           ldx   #nambuf-1                                 ; byte before packet buffer start
E8BC 6F84                     clr   ,x                                                                ; zero msb to make a 16bit value for y
E8BE 10AE81                   ldy   ,x++                                                      ; length of file name (16 bit)
E8C1 2742                     beq   failedr                                           ; if len=0 no file entered
E8C3 E61F                     ldb   -1,x                                                      ; length of name (8 bit)
                                                                                                                              ; adding .rom if not termination entered      
E8C5 3414                                     pshs  b,x                                                       ; save pointer to beginning of name and name length
E8C7 A680             isdotr          lda   ,x+                                                       ; get a char from name
E8C9 812E                     cmpa  #'.'                                                      ; is it a dot?
E8CB 2718                     beq   alrdotr                                           ; yes, stop search, quit loop
E8CD 5A                       decb                                                                    ; decrement counter
E8CE 26F7                     bne   isdotr                                            ; not end of string, get next char name
E8D0 CC2E52                   ldd   #$2e52                                            ; get chars ".r"
E8D3 ED81                     std   ,X++                                                      ; add to end of name
E8D5 CC4F4D                   ldd   #$4f4d                                            ; get chars "om"
E8D8 ED81                     std   ,x++                                                      ; add to end of name
E8DA E6E4                                     ldb   ,s                                                                ; get old name length
E8DC CB04                                     addb  #4                                                                ; add 4 (because of .rom added)
E8DE E7E4                                     stb   ,s                                                                ; update new length in stack
E8E0 F701D1                   stb   nambuf                                            ; save new length in byte before string
E8E3 3124                     leay  4,y                       ; correction to name length - dw parameter
E8E5 3514             alrdotr         puls  b,x                                               ; restore pointer and length
E8E7 6F85                     clr   b,x                                                       ; zero terminate name string (for error)
E8E9 6C83                     inc   ,--x                                                      ; 1 = drivewire op_nameobj_mount command
E8EB 3122                     leay  2,y                                                       ; length of dw packet = name length + 2
E8ED BDFBA8                   jsr   DWWrite                                           ; send file request to server
E8F0 8E0012                   ldx   #dnum                                                     ; our drive number variable
E8F3 6F84                     clr   ,x                                                                ; clear it
E8F5 3121                     leay  1,y                                                       ; read one byte back
E8F7 BDFB21                   jsr   DWRead                                            ; get drive number
E8FA 6D84                     tst   ,x                                                                ; verify received value
E8FC 2618                     bne   rdecb                                                     ; successful mount. if z has not been set = error (coundn't mount). jump to readin
E8FE C619             moError         ldb   #$19                                                      ; errror code for mo error
E900 1CAF                     andcc #eimask                                   ; enable interrupts
E902 7E8344                   jmp   syserr                                            ; show error message
E905 1CAF             failedr         andcc #eimask                                   ; enable interrupts
E907 7EB84B                                   jmp   ioerror                                           ; i/o errror message
E90A D689             prtstr  ldb     <curlow                                                 ; get low byte of cursor position
E90C C41F                     andb  #$1f                                                      ; is column zero?
E90E 2602                     bne   shwmsg                                    ; no, print whith leading enter
E910 3001                                     leax  1,x                                       ; jump leading enter 
E912 BD90E5           shwmsg  jsr   outstr                                       ; print string
E915 39                                       rts                                                                     ; return
E916 8E0000           rdecb   ldx   #0                                                                ; begin at sector zero
E919 108E3000                 ldy   #ramini                                           ; destination address
E91D 9F76                     stx   <endadr                                           ; set last load address to zero 
E91F 0FE6                     clr   <bigfil                                           ; flag for long file to false
E921 1700AB           romlop  lbsr  doreadr                                   ; read sector (into y) 
E924 25DF                     bcs   failedr                                           ; detect frame error
E926 26DD                     bne   failedr                                           ; detect incomplete read
E928 2D15                     blt   nomore                    ; detect end of file. finish
E92A 862A                     lda   #'*'                                                      ; get 'star' ascii code
E92C BDB54A                                   jsr   outchr                                            ; show on screen, we have read a sector
E92F 31A90100                 leay  256,y                                                     ; point to next sector address
E933 108C6FFF                 cmpy  #rmaxld                                           ; got to the ram limit?
E937 2404                     bhs   bigend                                            ; no, keep on copying
E939 3001                     leax  1,x                                                       ; increment sector number
E93B 20E4                     bra   romlop                                            ; go read next sector
E93D 0CE6             bigend  inc   <bigfil                                           ; big file flag to true
E93F 109F76           nomore  sty   <endadr                                           ; save as last loaded address
E942 8608                     lda   #$08                                                      ; get backspace ascii code
E944 BDB54A                                   jsr      outchr                                         ; print on screen (go back one char)
E947 8621                     lda   #'!'                                                      ; get 'bang' ascii code
E949 BDB54A                                   jsr   outchr                                            ; put it on screen
E94C 0DE6                                     tst   <bigfil                                           ; is this a too long file?
E94E 2705                                     beq   final                                                     ; no, jump message
E950 8EE380                                   ldx   #bigrom-1                                 ; message for rom greater than 16k-256bytes
E953 8DB5                                     bsr   prtstr                                            ; print message
E955 0D10             final   tst   <noexec                                           ; has to be run?
E957 2610                     bne   runit                                                     ; yes, do it
E959 8EE372                   ldx   #endtxt-1                                 ; point to end text
E95C 8DAC                                     bsr   prtstr                                            ; print message
E95E DC76                                     ldd   <endadr                                           ; get last loaded ram address
E960 833000                                   subd  #ramini                                           ; subtract init ram address
E963 BD957A                                   jsr   outnum                                            ; print length 
E966 1CAF                             andcc #eimask                                           ; enable interrupts
E968 39                       rts                                                                     ; return to the caller
E969 FCC000           runit   ldd   >romini                                           ; get two bytes from rom area
E96C 8E9669                                   ldx   #$9669                                            ; create a pattern 1001 0110 0110 1001
E96F BFC000                                   stx   >romini                                           ; store into two dos-rom bytes
E972 BCC000                                   cmpx  >romini                                           ; have been modified?
E975 2603                                     bne   basicup                                           ; no, must switch to map1 and copy basic to upper ram
E977 FDC000                                   std   >romini                                           ; put back two saved bytes
E97A 8EE98C           basicup  ldx    #basic                                          ; point to beginning of code to be moved
E97D CE2A00                                   ldu     #$2a00                                          ; destination in low ram
E980 EC81             basup01 ldd     ,x++                                                    ; get a word
E982 EDC1                                     std     ,u++                                                    ; put at destination
E984 8CE9CF                                   cmpx    #doreadr                                                ; got to the end?
E987 23F7                                     bls     basup01                                         ; no, loopback
E989 7E2A00                                   jmp     $2a00                                                   ; transfer control to copied code in ram
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
E98C 8E8000           basic   ldx   #basini                                           ; get basic initial address
E98F B7FFDE           bas1    sta   $ffde                                                     ; go map0 (rom)
E992 EC84                     ldd   ,x                                                                ; get 2 bytes
E994 B7FFDF                   sta   $ffdf                                                     ; go map1 (ram)
E997 ED81                     std   ,x++                                                      ; store 2 bytes, incr. pointer
E999 8CC000                   cmpx  #romini                                           ; reached end of basic?
E99C 25F1                     blo   bas1                                                      ; no, keep on copying basic
E99E 8E3000           map1            ldx     #ramini                                         ; get rom origin address at ram area
E9A1 CEC000                   ldu   #romini                                           ; get rom destination address
E9A4 B7FFDF                   sta   $ffdf                                                     ; go map1 (ram) and stay there
E9A7 EC81             move    ldd   ,x++                                                      ; get two bytes, inc pointer
E9A9 EDC1                     std   ,u++                                                      ; store two bytes, inc pointer
E9AB 9C76                     cmpx  <endadr                                           ; reached last loaded address?
E9AD 2405                                     bhs   nohook                                            ; yes, quit loop
E9AF 8C6EFF                                   cmpx  #rammax                                           ; reached max rom possible (16k-256bytes)?
E9B2 25F3                                     blo      move                                                   ; no, keep on copying rom
E9B4 8639             nohook  lda   #$39                                                      ; opcode for rts
E9B6 8E015E                                   ldx   #hokini                                           ; get initial address of system hooks
E9B9 A780             hooks   sta   ,x+                                                       ; overwrite them
E9BB 8C01A8                   cmpx  #hokend                                           ; got hooks end?
E9BE 25F9                     blo   hooks                                                     ; no, keep on overwriting them
E9C0 CC444B                                   ldd     #$444b                                          ; sign for dos roms
E9C3 8EC000                                   ldx     #romini                                         ; beginning of the rom
E9C6 10A384                                   cmpd    ,x                                                              ; is a dos what we have loaded?
E9C9 2602                                     bne     bas2                                                    ; no, execute it
E9CB 3002                                     leax    2,x                                                     ; skip over dos signature
E9CD 6E84             bas2            jmp   ,x                                                                ; start loaded rom
                      
                      ; -------------------------------------------------------------------------------------------
E9CF 9612             doreadr         lda   <dnum                                                     ; our drive number
E9D1 5F                       clrb                                                                    ; lsn bits 23-16
E9D2 3436                     pshs  a,b,x,y                                           ; save registers / data
E9D4 86D2                     lda   #$d2                                                      ; dw op_readex (read one sector)
E9D6 3402             rereadr         pshs  a                                                         ; save command to stack
E9D8 30E4                     leax  ,s                                                                ; point x to top of stack
E9DA 108E0005                 ldy   #5                                                                ; 5 bytes
E9DE BDFBA8                   jsr   DWWrite                                           ; send 5 bytes to dw      - readex, dnum, $0, sector
E9E1 3502                     puls  a                                                         ; discard command
E9E3 AE64                     ldx   4,s                                                       ; get read buffer pointer (old y)
E9E5 108E0100                 ldy   #256                                                      ; read 256 bytes
E9E9 CC0085                   ldd   #133                                                      ; 1 second timeout
E9EC BDFB21                   jsr   DWRead                                            ; receive 256 bytes
E9EF 2534                     bcs   readex2                                           ; detect framing error
E9F1 2632                     bne   readex2                                           ; detect not all bytes received
E9F3 3420                     pshs  y                                                         ; save checksum
E9F5 30E4                     leax  ,s                                                                ; point x to top of stack
E9F7 108E0002                 ldy   #2                                                                ; 2 bytes
E9FB BDFBA8                   jsr   DWWrite                                           ; send checksum
E9FE 3121                     leay  1,y                                                       ; after a dwrite 'y' returns zeroed, so this way it becomes equal to one
EA00 CC0085                   ldd   #133                                                      ; 1 second timeout
EA03 BDFB21                   jsr   DWRead                                            ; read dw answer
EA06 3262                     leas  2,s                                                       ; discard checksum
EA08 251B                     bcs   readex2                                           ; detect framing error
EA0A 2619                     bne   readex2                                           ; detect not all bytes received
EA0C A6E4                     lda   ,s                                                                ; get server answer
EA0E 2715                     beq   readex2                                           ; zero=ok, return
EA10 81F3                     cmpa  #$f3                                                      ; error code is #e_crc?
EA12 2606                     bne   reader                                            ; not this one, go verify eof condition
EA14 86F2                     lda   #$f2                                                      ; command reread. #op_rereadex
EA16 6FE4                     clr   ,s                                                                ; clear received answer
EA18 20BC                     bra   rereadr                                           ; read again
EA1A 81F4             reader  cmpa  #$f4                                      ; error code is 'read past end' (eof)?
EA1C 2606                                     bne   noteof                                            ; no, mark read error
EA1E 1CFC                     andcc #$fc                    ; unsets the 'c' and 'v' flags
EA20 1A0C                     orcc  #$0c                                                      ; sets 'n' and 'z' flags. both prepare the flags to be positive at 'blt' test
EA22 2001                     bra   readex2                                           ; jump over next instruction, not a read error
EA24 53               noteof  comb                                                                    ; sets the carry flag (error)
EA25 35B6             readex2         puls  a,b,x,y,pc                                        ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to start a SDC-bank
                      ; -------------------------------------------------------------------------------------------------------------------------------
EA27 BDE787           xbank           jsr     getunit                                         ; read a number between 0-7
EA2A C107                                     cmpb    #7                                                              ; is it greater than 7?
EA2C 2305                                     bls     OKbank                                          ; no, OK
EA2E C611             badnum  ldb     #$11                                                    ; SD error
EA30 7E8344                                   jmp     syserr                                          ; bas_system_error
EA33 1A50             OKbank  orcc    #dimask                                         ; disable interrupts
EA35 D7F8                                     stb     <numUni                                         ; save received number in first sentence (B)
EA37 0FF9                                     clr     swMap1                                          ; by default don't change map type
EA39 9DA5                                     jsr     <redLChr                                                ; see next char after BANK
EA3B 274B                                     beq     seeSlot                                         ; no extra chars, skip extra param search
EA3D 812C                                     cmpa    #','                                                    ; is it a comma?
EA3F 1026FD48                                 lbne    snError                                         ; no, show error
EA43 9D9F                                     jsr     <getNChr                                                ; get next char
EA45 8152                                     cmpa    #'R'                                                    ; is it R (for RAM mode = MAP1)?
EA47 1026FD40                                 lbne    snError                                         ; no, show error
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; copy and execute from RAM the 64k tester
EA4B 8EEA65                                   ldx     #tst64k                                         ; point to beginning of data to be copied
EA4E CE01DA                                   ldu     #$1da                                                   ; point to destination
EA51 EC81             xb001           ldd     ,x++                                                    ; get a wrod
EA53 EDC1                                     std     ,u++                                                    ; put at destination
EA55 8CEA86                                   cmpx    #emod1B+2                                       ; got to the end?
EA58 25F7                                     blo     xb001                                                   ; no, loopback
EA5A BD01DA                                   jsr     $1da                                                    ; jsr that copied code from RAM
EA5D 2627                                     bne     xb002                                                   ; if not zero, we have 64K
EA5F 8EE591                              ldx  #not64K-1                                       ; else show message NO 64K COMPUTER                     
EA62 7E90E5                                   jmp     outstr                                          ; show message
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; validate if there are 64k - This must be executed from RAM
EA65 8D0B             tst64k  bsr     mod1Byt                                         ; can modify rom area?
EA67 2608                                     bne     etst64k                                         ; yes, return result
EA69 B7FFDF                                   sta     $ffdf                                                   ; no, try switching to map1                     
EA6C 8D04                                     bsr     mod1Byt                                         ; can modify area?
EA6E F7FFDE                                   stb     $ffde                                                   ; back to map0 where it was
EA71 39               etst64k rts                                                                     ; return result
EA72 5F               mod1Byt clrb                                                                    ; default 32K
EA73 B6C000                                   lda     $c000                                                   ; get first DOS ROM char 
EA76 43                                       coma                                                                    ; invert bits
EA77 B7C000                                   sta     $c000                                                   ; update value
EA7A B1C000                                   cmpa    $c000                                                   ; has been updated?
EA7D 2605                                     bne     emod1B                                          ; no, return
EA7F 43                                       coma                                                                    ; invert bits again
EA80 B7C000                                   sta     $c000                                                   ; restore value
EA83 5C                                       incb                                                                    ; found 64k
EA84 5D               emod1B  tstb                                                                    ; update flags
EA85 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
EA86 0CF9             xb002           inc     swMap1                                          ; mark flag to change to map1
                                                                                                                      ; see if we have a SDC
EA88 B60114           seeSlot lda     floSDC                                          ; get hdw control byte
EA8B 8508                                     bita    #%00001000                                      ; is there an SDC?
EA8D 102700AC                                 lbeq    NotSDCPresent                           ; no, show error
EA91 84C0                                     anda    #%11000000                                      ; use bits 7-6 (slot where it is)
EA93 44                                       lsra                                                                    ; move them to
EA94 44                                       lsra                                                                    ; bits 5-4 (lower bits of high nibble)
EA95 3402                                     pshs    a                                                               ; save high nibble
EA97 44                                       lsra                                                                    ; low nibble   
EA98 44                                       lsra                                                                    ; gets high nibble
EA99 44                                       lsra                                                                    ; that will end  
EA9A 44                                       lsra                                                                    ; as zero
EA9B AAE0                                     ora     ,s+                                                     ; add high nibble (now they are the same value)
EA9D 0DF9                                     tst     swMap1                                          ; should it be run in MAP1?
EA9F 2616                                     bne     swMbank                                         ; yes, go to next section
EAA1 3402             swbank  pshs    a                                                               ; save SDC slot number
EAA3 8EEACD                                   ldx     #special                                                ; point to the beginning of code to execute from RAM
EAA6 CE01DA                                   ldu     #$1da                                                   ; point at destination
EAA9 EC81             swB01           ldd     ,x++                                                    ; get a word
EAAB EDC1                                     std     ,u++                                                    ; copy at destination
EAAD 8CEAF4                                   cmpx    #exbank+3                                       ; got to the end?
EAB0 25F7                                     blo     swB01                                                   ; no, loopback
EAB2 3502                                     puls    a                                                               ; restore slot number
EAB4 7E01DA                                   jmp     $1da                                                    ; jumto to RAM copied code
EAB7 3402             swMbank pshs    a                                                               ; save SDC slot number
EAB9 8EEAF4                                   ldx     #allRAM                                         ; point to the beginning of code to execute from RAM
EABC CE01DA                                   ldu     #$1da                                                   ; point at destination
EABF EC81             swMB01  ldd     ,x++                                                    ; get a word
EAC1 EDC1                                     std     ,u++                                                    ; copy at destination
EAC3 8CEB31                                   cmpx    #m1L03+3                                                ; got to the end?
EAC6 25F7                                     blo     swMB01                                          ; no, loopback
EAC8 3502                                     puls    a                                                               ; restore slot number
EACA 7E01DA                                   jmp     $1da                                                    ; jumto to RAM copied code
                                                                                                                      ; this TWO parts MUST be run from RAM because we are going
                                                                                                                      ; to lose control when switching the ROM slot and/or the bank!
                                                                                                                      ; code to start the bank in ROM mode (MAP0)
                                                                                                                      ; SDC slot# comes onto stack 
EACD 1A50             special orcc    #dimask                                         ; disable interrupts
EACF 7FFFDE                                   clr     $ffde                                                   ; switch to MAP0 (ROM-RAM mode)
EAD2 B703FF                                   sta     cpyMPIcfg                                       ; update copy
EAD5 B7FF7F                                   sta     MPIcfg                                          ; switch to the slot where the SDC is
EAD8 D6F8                                     ldb     <numUni                                         ; get requested bank number
EADA F7FF4B                                   stb     $ff4b                                                   ; point to it
EADD 8E444B                                   ldx     #$444b                                          ; get mark for DOS system
EAE0 BCC000                                   cmpx    romini                                          ; is there a DOS ROM?
EAE3 270A                                     beq     spec01                                          ; yes, issue cold start
EAE5 8E7F37                                   ldx     #$7f37                                          ; get std value for stack
EAE8 3284                                     leas    ,x                                                              ; assign it
EAEA C4AF                                     andb    #eimask                                         ; enable interrupts
EAEC 7EC000                                   jmp     romini                                          ; no, execute ROMPACK
EAEF 0F71             spec01  clr     <$71                                                    ; force a cold boot
EAF1 7EB3B4           exbank  jmp     resetRt                                         ; execute the system reset routine
                                                                                                                      ; code to start the bank but having copied everything into MAP1
                                                                                                                      ; SDC slot# comes onto stack 
EAF4 1A50             allRAM  orcc  #dimask                           ; disable interrupts
EAF6 B703FF                                   sta     cpyMPIcfg                                       ; update copy
EAF9 B7FF7F                                   sta     MPIcfg                                          ; switch to the slot where the SDC is
EAFC D6F8                                     ldb     <numUni                                         ; get requested bank number
EAFE F7FF4B                                   stb     $ff4b                                                   ; point to it
                                                                                                                      ; copy ROM to RAM
EB01 8E8000                                   ldx   #basini                           ; point to beginning of Basic
EB04 B7FFDE           m1L01           sta   $ffde                             ; switch to ROM map
EB07 EC84                                     ldd   ,x                                ; get a word
EB09 B7FFDF                                   sta   $ffdf                             ; switch to RAM map
EB0C ED81                                     std   ,x++                              ; copy at RAM destination
EB0E 8CFEFF                                   cmpx  #$feff                            ; end of ROM?
EB11 25F1                                     bcs   m1L01                                     ; no, loopback
EB13 8639                                     lda   #$39                              ; get RTS opcode
EB15 8E015E                                   ldx   #$015e                            ; point to beginning of User vectors (hooks)
EB18 A780             m1L02           sta   ,x+                               ; put an RTS in each one
EB1A 8C01A8                                   cmpx  #$01a8                            ; end of user vectors?
EB1D 25F9                                     bcs   m1L02                                             ; no, loopback
EB1F BDBA77                                   jsr     $ba77                                                   ; clear screen
EB22 CC444B                                   ldd     #$444b                                          ; get mark for O.S.
EB25 10B3C000                                 cmpd    romini                                          ; is there an O.S. in RAM now?
EB29 2703                                     beq     m1L03                                                   ; yes, start it
EB2B 7EC000                                   jmp     romini                                          ; else start ROM from the beginning
EB2E 7EC002           m1L03           jmp   romini+2                          ; start ROM (copied into RAM)
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                              ; MESSAGES. They all will return with carry set.
EB31                  BadFormat
EB31 8EE46A                                   ldx     #BadFmtType-1                           ; point to message
EB34 10                                       fcb     #$10                                                    ; skip next ldx
EB35 8EE42A           TooLong ldx     #Str2Long-1                                     ; point to message
EB38 10                                       fcb     #$10                                                    ; skip next ldx
EB39                  NotMPIPresent
EB39 8EE43B                                   ldx     #NotAnMPI-1                                     ; point to message
EB3C 10                                       fcb     #$10                                                    ; skip next ldx
EB3D                  NotSDCPresent
EB3D 8EE44B                                   ldx     #NotAnSDC-1                                     ; point to message
EB40 BD90E5                                   jsr     outstr                                          ; show it
EB43 1A01                                     orcc    #%00000001                                      ; set carry flag
EB45 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; This routine will copy the hardware tests routines at $1da and jump there 
                      ; to avoid hanging the system while switching of MPI slot
                      ; -------------------------------------------------------------------------------------------------------------------------------
EB46 8EEB59           tstHARD ldx     #tstHDW                                         ; point to beginning of program to be copied
EB49 CE01DA                                   ldu     #$1da                                                   ; point to destination
EB4C EC81             tstL01  ldd     ,x++                                                    ; get a word
EB4E EDC1                                     std     ,u++                                                    ; put at destination
EB50 8CEC41                                   cmpx    #xslot                                          ; got to end of program?
EB53 25F7                                     blo     tstL01                                          ; no, loopback
EB55 BD01DA                                   jsr     $1da                                                    ; execute copied program in low RAM
EB58 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; test for the presence of MPI, floppies, SDC and update $114 accordingly
                      ; -------------------------------------------------------------------------------------------------------------------------------
EB59 5F               tstHDW  clrb                                                                    ; get zero value
EB5A F70114                                   stb     floSDC                                          ; control byte default value (no hdw found)
EB5D 170089                                   lbsr    tstMPI                                          ; is there an MPI present?
EB60 10260084                                 lbne    etstHDW                                         ; no, exit
EB64 D776                                     stb     hdwFlo                                          ; no Floppies found
EB66 D777                                     stb     hdwSdc                                          ; no SDC found
                                                                                                                      ; search for SDC and/or floppies
EB68 B603FF                                   lda     cpyMPIcfg                                       ; get active MPI slot
EB6B C604                                     ldb     #4                                                              ; ready to check four slots
                                                                                                                      ; first look for SDC
EB6D 0D77             tst01           tst     hdwSdc                                          ; have we found it before?
EB6F 2611                                     bne     tst02                                                   ; yes, go to floppy test
EB71 170099                                   lbsr    tstSDC                                          ; is there an SDC in this MPI slot?             
EB74 260C                                     bne     tst02                                                   ; no, go to floppy test
EB76 9777                                     sta     hdwSdc                                          ; save slot where SDC has been found
EB78 B60114                                   lda     floSDC                                          ; get hdw control byte
EB7B 8A08                                     ora     #%00001000                                      ; add flag for SDC present
EB7D B70114                                   sta     floSDC                                          ; update it
EB80 2013                                     bra     tst03                                                   ; go process another slot
                                                                                                                      ; if not SDC, then for floppy
EB82 0D76             tst02           tst     hdwFlo                                          ; have we found it before?
EB84 260F                                     bne     tst03                                                   ; go process another slot
EB86 17009B                                   lbsr    tstFLO                                          ; is there a floppy controller in this MPI slot?
EB89 260A                                     bne     tst03                                                   ; no, process another slot
EB8B 9776                                     sta     hdwFlo                                          ; save slot where floppy has been found
EB8D B60114                                   lda     floSDC                                          ; get hdw control byte
EB90 8A04                                     ora     #%00000100                                      ; add flag for Floppies present
EB92 B70114                                   sta     floSDC                                          ; update it
                                                                                                                      ; look at another slot
EB95 B603FF           tst03           lda     cpyMPIcfg                                       ; get analized slot                                                                                                                                             ---     A = $33/$22/$11/$00
EB98 8011                                     suba    #$11                                                    ; calculate previous slot                                                                                                                               ---   A = $22/$11/$00/$EF
EB9A 2A02                                     bpl     tst04                                           ; if not negative, skip next
EB9C 8633                                     lda     #$33                                                    ; get upper value                                                                                                                                                       ---   A = $33
EB9E 3402             tst04           pshs    a                                                               ; save new calculated slot number                                                                                                       ---   pushed $22/$11/$00/$33
EBA0 B603FF                                   lda     cpyMPIcfg                                       ; get last tested slot value                                                                                                                    ---        A = $33/$22/$11/$00
EBA3 84CC                                     anda    #$cc                                                    ; clean bits 0-1 in both nibbles                                                                                                                ---        A = $00/$00/$00/$00
EBA5 AAE0                                     ora     ,s+                                                     ; add new calculated slot number ($00-$11-$22-$33)                                                              ---        A = $22/$11/$00/$33
EBA7 B703FF                                   sta     cpyMPIcfg                                       ; update copy
EBAA B7FF7F                                   sta     MPIcfg                                          ; change of I/O slot (not keeping the same ROM slot)                                                    ---  MPIcfg = $22/$11/$00/$33
EBAD 5A                                       decb                                                                    ; decrement slot counter                                                                                                                                ---      B =   3/  2/  1/  0
EBAE 26BD                                     bne     tst01                                                   ; if not zero, loopback
                                                                                                                      ; if zero: end of tests. MPIcfg must be restored to original value
EBB0 B60114           tst05           lda     floSDC                                          ; get hdw control byte
EBB3 8508                                     bita    #%00001000                                      ; is bit3 ON (SDC present)?
EBB5 271C                                     beq     tst07                                                   ; no, look for floppies 
EBB7 9677                                     lda     hdwSdc                                          ; get SDC slot                                                                                                                                                          --- A = $00
EBB9 B103FF                                   cmpa    cpyMPIcfg                                       ; equals copy of MPIcfg? 
EBBC 2608                                     bne     tst06                                                   ; no, don't modify floSDC
EBBE F60114                                   ldb     floSDC                                          ; get hdw control byte                                                                                  
EBC1 CA03                                     orb     #%00000011                                      ; set floSDC.bits1-0 to #%11 (SDC ON)
EBC3 F70114                                   stb     floSDC                                          ; update control byte
EBC6 8403             tst06           anda    #%00000011                                      ; use just slot number                                                                                                                                  --- A = $00
EBC8 5F                                       clrb                                                                    ; result = 0                                                                                                                                                            --- B = 0
EBC9 44                                       lsra                                                                    ; send bit 0 to carry                                                                                                                                   --- A = 0, C = 0
EBCA 56                                       rorb                                                                    ; receive bit0 from carry in bit7                                                                                                       --- B = 0
EBCB 44                                       lsra                                                                    ; send bit 1 (now 0) to carry                                                                                                                   --- A = 0, C = 0
EBCC 56                                       rorb                                                                    ; receive bit1 (now 0) from carry in bit7 and bit6 goes to bit7                 --- B = 0
EBCD FA0114                                   orb     floSDC                                          ; update bits 7-6 of $114 with slot used by SDC                                                                 --- floSDC.bits5-4 = %00
EBD0 F70114                                   stb     floSDC                                          ; save new value
EBD3 B60114           tst07           lda     floSDC                                          ; get hdw control byte
EBD6 8504                                     bita    #%00000100                                      ; is bit2 ON (floppies present)?
EBD8 270E                                     beq     etstHDW                                         ; no, exit
EBDA 9676                                     lda     hdwFlo                                          ; get floppies slot                                                                                                                                             --- A = $33
EBDC 8403                                     anda    #%00000011                                      ; get just slot number                                                                                                                                  --- A = $03
EBDE 48                                       lsla                                                                    ; move bits 0-1                                                                                                                                                 --- A = $06
EBDF 48                                       lsla                                                                    ; to bits 5-4                                                                                                                                                           --- A = $0C
EBE0 48                                       lsla                                                                    ;                                                                                                                                                                                               --- A = $18
EBE1 48                                       lsla                                                                    ;                                                                                                                                                                                               --- A = $30
EBE2 BA0114                                   ora     floSDC                                          ; update bits 5-4 of $114 with slot used by Floppies                                                    --- floSDC.bits7-6 = %11
EBE5 B70114                                   sta     floSDC                                          ; save new value
EBE8 39               etstHDW rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Tests for the presence of an MPI
                      ; returns zero flag Z=1 if present else Z=0
                      ; by Darren Atkinson (2015)
                      ; modified to support mega-mini-MPI by Pere Serrat (2021)
                      ; -------------------------------------------------------------------------------------------------------------------------------
EBE9 3402             tstMPI  pshs    a                                                               ; save register
EBEB B603FF                                   lda     cpyMPIcfg                               ; get MPI settings
EBEE 8803                                     eora  #$03                                              ; toggle two low used bits in /SCS nibble
EBF0 B703FF                                   sta     cpyMPIcfg                                       ; update copy
EBF3 B7FF7F                                   sta   MPIcfg                                            ; update MPI settings
EBF6 B1FF7F                                   cmpa  MPIcfg                                            ; did it accept the change? MANDATORY. Do not CHANGE it!
EBF9 2704                                     beq   yesMPI                                            ; branch if yes (MPI present), will return with Z=1
EBFB 8601                                     lda     #1                                                              ; will return with Z=0
EBFD 200C                                     bra     noMPI                                                   ; exit
EBFF B603FF           yesMPI  lda     cpyMPIcfg                                       ; get old value
EC02 8803                                     eora    #$03                                                    ; recover modified bits in /SCS
EC04 B703FF                                   sta     cpyMPIcfg                                       ; update copy
EC07 B7FF7F                                   sta     MPIcfg                                          ; back to its old value
EC0A 4F                                       clra                                                                    ; make Z=1
EC0B 3582             noMPI           puls    a,pc                                                    ; restore register and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Tests for the presence of a CoCo SDC on active slot
                      ; returns zero flag Z=1 if present else to zero
                      ; by Darren Atkinson (2015)
                      ; -------------------------------------------------------------------------------------------------------------------------------
EC0D 3412             tstSDC  pshs    a,x                                                     ; save registers
EC0F 8EFF4A                           ldx   #$ff4a                                            ; point X at Flash registers (FF42 for CoCo)
EC12 861A                             lda   #$1a                                              ; test pattern
EC14 A784                             sta   ,x                                                ; store in data register
EC16 A601                             lda   1,x                                               ; get value from control register
EC18 6F84                             clr   ,x                                                ; clear data register
EC1A A801                             eora  1,x                                               ; get changed bits from control register
EC1C 8118                             cmpa  #$18                                              ; did the expected bits change?
EC1E 2702                             beq   yesSDC                                            ; branch if SDC present, will return with Z=1
EC20 8601                                     lda     #1                                                              ; will return with Z=0
EC22 3592             yesSDC  puls    a,x,pc                                          ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Test for presence of FDC in active MPI slot.
                      ; Returns with Z=1 if FDC has been found
                      ; by Darren Atkinson (2015)
                      ; -------------------------------------------------------------------------------------------------------------------------------
EC24 3416             tstFLO   pshs  d,x                              ; save registers
EC26 8EFF40                    ldx   #$ff40                           ; address for Dragon DOS controller
EC29 86D0                      lda   #$d0                             ; FORCE INTERRUPT command
EC2B A784                      sta   ,x                               ; send to FDC command register
EC2D 8D0D                      bsr   fdcDelay                         ; delay time
EC2F A684                      lda   ,x                               ; read FDC status to clear INTRQ
EC31 EC02                      ldd   2,x                              ; get FDC sector and data registers
EC33 43                        coma                                   ; invert sector bits only
EC34 ED02                      std   2,x                              ; put both registers back
EC36 8D04                      bsr   fdcDelay                         ; delay time
EC38 A302                      subd  2,x                              ; set Z if read matches write
EC3A 3596                      puls  d,x,pc                           ; restore registers and return
EC3C 3437             fdcDelay pshs  y,x,d,cc                         ; push registers
EC3E 3D                        mul                                    ; consume 11 CPU cycles
EC3F 35B7                      puls  cc,d,x,y,pc                      ; restore registers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to change of MPI-slot and start it 
                      ; it could happen that the new slot has no FDC nor SDC
                      ; but if it had any of them, then floSDC must be adjusted accordingly
                      ; -------------------------------------------------------------------------------------------------------------------------------
EC41 9DA5             xslot           jsr   <redLChr                                          ; peek at next character after "SLOT"
EC43 804E                     suba  #'N'                                                      ; to detect if it was an 'N' - if so do not switch to MAP0
EC45 9710                     sta   <noexec                                           ; save difference. 0 = do not switch
EC47 2602                     bne   xslot1                                            ; if not 'N' skip next
EC49 9D9F                     jsr   <getNChr                                          ; jump over char 'N'
EC4B BDE787           xslot1  jsr     getunit                                         ; read a number between 1-4
EC4E 2704                                     beq     nogood                                          ; if 0 error
EC50 C104                                     cmpb    #4                                                              ; is it greater than 4?
EC52 2305                                     bls     OKslot                                          ; no, OK
EC54 C60D             nogood  ldb     #$0d                                                    ; MU error
EC56 7E8344                                   jmp     syserr                                          ; bas_system_error
EC59 8D8E             OKslot  bsr     tstMPI                                          ; is there an MPI present?
EC5B 2704                                     beq     OKslot01                                                ; yes, skip section
EC5D 17FED9                                   lbsr    NotMPIPresent                           ; no, show message
EC60 39                                       rts                                                                     ; return
EC61 5A               OKslot01        decb                                                                    ; slots range 0-3. We use reg B read at function getunit
EC62 D7F8                                     stb     <numUni                                         ; save low nibble --- $00 - $03 if command was SLOTN1 - SLOTN4
EC64 58                                       lslb                                                                    ; move it                       --- $00 - $06
EC65 58                                       lslb                                                                    ; to the                        --- $00 - $0c
EC66 58                                       lslb                                                                    ; high                          --- $00 - $18
EC67 58                                       lslb                                                                    ; nibble                                --- $00 - $30
EC68 DAF8                                     orb     <numUni                                         ; add low nibble ($nn)          --- $00 - $33
EC6A D7F8                                     stb     <numUni                                         ; save calculated code          --- $00 - $33
                                                                                                                      ; now must compare the new slot with the one for FDC and SDC and modify floSDC accordingly
                                                                                                                      ; by definition, switching the slot MUST enable the drives of that slot, so $114 must vary
EC6C C430                                     andb    #%00110000                                      ; get just low bits of high nibble = new slot number    --- $00 - $30
EC6E 3404                                     pshs    b                                                               ; save value                                                                                                            --- $00 - $30
EC70 B60114                                   lda     floSDC                                          ; get hdw control byte                                                                                  --- $3C - $3C if we are in the FDC
EC73 8430                                     anda    #%00110000                                      ; get the slot where the Floppies are                                           --- $30 - $30
EC75 A1E0                                     cmpa    ,s+                                                     ; is new slot where the floppies are?                                           --- NO  - YES
EC77 2607                                     bne     xslot2                                          ; no, compare SDC                                                                                                       --- jmp - mod
EC79 B60114                                   lda     floSDC                                          ; get control value
EC7C 84FC                                     anda    #%11111100                                      ; set both floppies ON
EC7E 2016                                     bra     xslot3                                          ; skip section - no need to verify SDC
EC80 96F8             xslot2  lda     <numUni                                         ; get new slot number                                                                                   --- $00 - $33
EC82 8430                                     anda    #%00110000                                      ; get just low bits of high nibble = new slot number    --- $00 - $30
EC84 48                                       asla                                                                    ; move 2 bits to 
EC85 48                                       asla                                                                    ; the left                                                                                                                      --- $00 - $00
EC86 3402                                     pshs    a                                                               ; save value                                                                                                            --- $00 - $00
EC88 B60114                                   lda     floSDC                                          ; get control bte
EC8B 84C0                                     anda    #%11000000                                      ; get the slot where SD is                                                                              --- $00 - $00
EC8D A1E0                                     cmpa    ,s+                                                     ; is the select one?                                                                                            --- YES - NO
EC8F 2608                                     bne     xslot4                                          ; no, skip two next                                                                                             --- mod - jump
EC91 B60114                                   lda     floSDC                                          ; get control value
EC94 8A03                                     ora     #%00000011                                      ; set both floppies OFF
EC96 B70114           xslot3  sta     floSDC                                          ; update hdw control byte
                                                                                                                              ; this part MUST be run from RAM because we are going
                                                                                                                              ; to lose control when switching the ROM slot!
EC99 8EECAB           xslot4  ldx     #specia2                                                ; point to beginning of code to execute from RAM
EC9C CE01DA                                   ldu     #$1da                                                   ; point at destination
EC9F EC81             xsL01           ldd     ,x++                                                    ; get a word
ECA1 EDC1                                     std     ,u++                                                    ; put at destination
ECA3 8CECCF                                   cmpx    #strROM+3                                       ; got to the end?
ECA6 25F7                                     blo     xsL01                                                   ; no, loopback
ECA8 7E01DA                                   jmp     $1da                                                    ; jump to RAM copied code
ECAB 1A50             specia2 orcc    #dimask                                         ; disable interrupts
ECAD 0D10                                     tst     <noexec                                         ; should switch to MAP0?                                                                --- noexec = 0
ECAF 2703                                     beq     specia3                                         ; no, skip next                                                                                 --- apply jump
ECB1 7FFFDE                                   clr     $ffde                                                   ; switch to MAP0 (ROM mode)                                                     --- skipped
ECB4 D6F8             specia3 ldb     <numUni                                         ; get calculated code                                                                   --- B = $cc
ECB6 F703FF                                   stb     cpyMPIcfg                                       ; update copy
ECB9 F7FF7F                                   stb     MPIcfg                                          ; switch to that slot                                                                   --- MPIcfg = $cc
ECBC 0D10                                     tst     <noexec                                         ; called with param N?
ECBE 2601                                     bne     eOKSlot                                         ; no, start slot
ECC0 39                                       rts                                                                     ; return
ECC1 CC444B           eOKSlot ldd     #$444b                                          ; signature for O.S.
ECC4 10B3C000                                 cmpd    romini                                          ; is an O.S. at $C000?
ECC8 2602                                     bne     strROM                                          ; no, start RomPack
ECCA 0F71                                     clr     <$71                                                    ; force coldstart
ECCC 7EB3B4           strROM  jmp     resetRt                                         ; reset machine
                      
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
ECCF 3401             flOrSd  pshs    cc                                                              ; save register
ECD1 B60114                                   lda     floSDC                                          ; get hdw control byte
ECD4 840C                                     anda    #%00001100                                      ; test bits3-2 (SDC and Floppies present)
ECD6 810C                                     cmpa    #%00001100                                      ; are both present?
ECD8 263B                                     bne     eflOr                                                   ; no, exit
ECDA 96EB                                     lda     <$eb                                                    ; get unit number
ECDC 8102                                     cmpa    #2                                                              ; is greater than 2?  --- If 3-4 and SDC present, should change to FDC slot!
ECDE 221D                                     bhi     flo2flo                                         ; yes, switch to floppies
ECE0 B60114                                   lda     floSDC                                          ; get hdw control byte
ECE3 94EB                                     anda    <$eb                                                    ; test corresponding bit 0-1 (affected drive)
ECE5 2716                                     beq     flo2flo                                         ; if zero, switch to floppies
                                                                                                                      ; has to switch to slot with SDC (bits 7-6 of floSDC)
ECE7 B60114           flo2SDC lda     floSDC                                          ; get hdw control byte
ECEA 84C0                                     anda    #%11000000                                      ; use bits 7-6 to get slot number
ECEC 44                                       lsra                                                                    ; send them
ECED 44                                       lsra                                                                    ; to bits 5-4 (2 low bits of high nibble)
ECEE 3402                                     pshs    a                                                               ; save high nibble
ECF0 44                                       lsra                                                                    ; move it
ECF1 44                                       lsra                                                                    ; 4 times to the right
ECF2 44                                       lsra                                                                    ; to have it
ECF3 44                                       lsra                                                                    ; as low nibble
ECF4 AAE0                                     ora     ,s+                                                     ; add high nibble and clean stack
ECF6 B103FF                                   cmpa    cpyMPIcfg                                       ; already in that slot?
ECF9 271A                                     beq     eflOr                                                   ; yes, do nothing
ECFB 2012                                     bra     flOr01                                          ; go update value
                                                                                                                      ; has to switch to slot with floppies (bits 5-4- of floSDC)
ECFD B60114           flo2flo lda     floSDC                                          ; get hdw control byte
ED00 8430                                     anda    #%00110000                                      ; use bits 5-4 (2 low bits of high nibble)
ED02 3402                                     pshs    a                                                               ; save high nibble
ED04 44                                       lsra                                                                    ; move it
ED05 44                                       lsra                                                                    ; 4 times to the right
ED06 44                                       lsra                                                                    ; to have it
ED07 44                                       lsra                                                                    ; as low nibble
ED08 AAE0                                     ora     ,s+                                                     ; add high nibble and clean stack
ED0A B103FF                                   cmpa    cpyMPIcfg                                       ; already in that slot?
ED0D 2706                                     beq     eflOr                                                   ; yes, do nothing
ED0F B703FF           flOr01  sta     cpyMPIcfg                                       ; update copy
ED12 B7FF7F                                   sta     MPIcfg                                          ; change active MPI slot
ED15 3581             eflOr           puls    cc,pc                                                   ; restore register and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; accept a value to be used as index disc in a HD in unit4 (for DW4)
                      ; -------------------------------------------------------------------------------------------------------------------------------
ED17 BDE787           xHDidx  jsr     getunit                                         ; read a number between 1-90
ED1A C101                                     cmpb    #1                                                              ; value under minimum accepted?
ED1C 10250858                                 lblo    badParam                                                ; yes, show message
ED20 C15A                                     cmpb    #90                                                     ; exceeds the max index number?
ED22 2207                                     bhi     idxBad                                          ; yes, show message
ED24 F70115                                   stb     idxHD                                                   ; save disc index number
ED27 BDE6AC                                   jsr     mrkmod                                          ; mark as modified
ED2A 39               exHD            rts                                                                     ; return
ED2B 8EE482           idxBad  ldx     #idxHigh-1                                      ; poit to message
ED2E 7E90E5                                   jmp     outstr                                          ; show it
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Command to deal with SDC-card DRIVE commands (1,2)
                      ; -------------------------------------------------------------------------------------------------------------------------------
ED31 9DA5             xsdrive jsr     <redLChr                                                ; peek at next char after SDRIVE
ED33 102704BC                                 lbeq    sdcLST                                          ; is the SDRIVE alone
                                                                                                                      ; validate syntax and drive number
ED37 BDE787                                   jsr     getunit                                         ; read a number between 1-2
ED3A 1027FCF0                                 lbeq    badnum                                          ; 0 not accepted
ED3E C102                                     cmpb    #2                                                              ; is it greater than 4?
ED40 1022FCEA                                 lbhi    badnum                                          ; no, ok
                                                                                                                      ; update table of linked DW4 slots back to the number of the drive!     
ED44 8E00FB                                   ldx     #drvtab-1                                       ; point to linked slots -1, because we will use 1-2 as index (instead 0-1)
ED47 E785                                     stb     b,x                                                     ; link unit to DW4 slot with its same number
ED49 5A                                       decb                                                                    ; internally will work with 0-1
ED4A D7F8                                     stb     <numUni                                         ; save received number
ED4C 0FFA                                     clr     <valPar                                         ; value param is 0
ED4E C6E0                                     ldb     #$e0                                                    ; more used value
ED50 D7FB                                     stb     <cmdNum                                         ; store it
ED52 BD89AA                                   jsr     ckComma                                         ; ckcomma. if not comma found syntax error
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; decode token
ED55 81C2                                     cmpa    #$c2                                                    ; is this the token for off?
ED57 1027034F                                 lbeq    flopON                                          ; yes, go process it
ED5B 8188                                     cmpa    #$88                                                    ; is this the token for on?
ED5D 10270340                                 lbeq    flopOF                                          ; yes, go process it
ED61 81B3                                     cmpa    #$b3                                                    ; is this the token for get?
ED63 10270370                                 lbeq    sdcGET                                          ; yes, go process it
ED67 818C                                     cmpa    #$8c                                                    ; is this the token for dim?
ED69 1027035C                                 lbeq    sdcDIM                                          ; yes, go process it
ED6D 81F6                                     cmpa    #$f6                                                    ; is this the token for unload?
ED6F 260B                                     bne     nxtParam                                                ; no, go to params section
ED71 9D9F                                     jsr     <getNChr                                                ; yes, it is the 'unload' command version. must skip the token to avoid a sn error when done
ED73 CC0100           reuseUL ldd     #$0100                                          ; get 1 byte with value equal null
ED76 FD01D1                                   std     nambuf                                          ; put in nambuf area
ED79 8D60             dTok01  bsr     putCmd                                          ; skip parameters section
ED7B 39                                       rts                                                                     ; return
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      
                                                                                                                      ; search for more parameters
ED7C BDB7AA           nxtParam        jsr   getfnam                                           ; read string and length into $1d1 = nambuf
ED7F F601D1                   ldb     nambuf                                          ; is string length 0?
ED82 1027FA05                 lbeq    snError                                         ; yes, show error
ED86 C1FD                     cmpb    #253                                                    ; is string longer than maximum accepted? (253 + m: + final null)
ED88 1024FDA9                                 lbcc    TooLong                                         ; show error message
ED8C 9DA5                                     jsr     <redLChr                                                ; get last read char
ED8E 812C                                     cmpa    #$2c                                                    ; is it a comma?
ED90 26E7                                     bne     dTok01                                          ; no, end of command. this is 'mount' command version
ED92 9D9F                                     jsr     <getNChr                                                ; get next token
ED94 1027F9F3                                 lbeq    snError                                         ; if no token after comma, show error
ED98 5F                                       clrb                                                                    ; bit 7 value 0 means dsk format
ED99 8197                                     cmpa    #$97                                                    ; is it the token for new?
ED9B 2708                                     beq     crtDisc                                         ; yes, create a dsk file
ED9D CA80                                     orb     #$80                                                    ; bit 7 value 1 means sdf format
ED9F 8198                                     cmpa    #$98                                                    ; is it the token for def?
EDA1 1026F9E6                                 lbne    snError                                         ; no, show error message
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; create disc
EDA5 D710             crtDisc stb     <noexec                                         ; save format flag (bit7)
EDA7 17050A                                   lbsr    addExt                                          ; add extension to the file name
EDAA 9D9F                                     jsr     <getNChr                                                ; get next char
EDAC 812C                                     cmpa    #$2c                                                    ; is it a comma?
EDAE 2707                                     beq     crt01                                                   ; yes, test size parameter
EDB0 8601                                     lda     #1                                                              ; by default type=1
EDB2 8E00B4                                   ldx     #180                                                    ; and will be 180k (720 sectors)
EDB5 201A                                     bra     crtstep                                         ; exit cheks
EDB7 9D9F             crt01           jsr     <getNChr                                                ; advance one char. mandatory for next routine
EDB9 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into x
EDBC 8601                                     lda     #1                                                              ; 1 will mean 180k dragon-like disc (40 tracks 1 side)
EDBE 8C00B4                                   cmpx    #180                                                    ; equals read value 180?
EDC1 270E                                     beq     crtstep                                         ; yes, exit checks
EDC3 4C                                       inca                                                                    ; 2 will mean 360k dragon-like disc (40 tracks 2 sides)
EDC4 8C0168                                   cmpx    #360                                                    ; equals read value 360?
EDC7 2708                                     beq     crtstep                                         ; yes, exit checks
EDC9 4C                                       inca                                                                    ; 3 will mean 720k dragon-like disc (80 tracks 2 sides)
EDCA 8C02D0                                   cmpx    #720                                                    ; equals read value 720?
EDCD 1026FD60                                 lbne    BadFormat                                       ; not, bad format number, show error
EDD1 9B10             crtstep adda    <noexec                                         ; add disc type to format flag
EDD3 9710                                     sta     <noexec                                         ; save calculated value ($01-02-03 or $81-82-83)
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; entries to send command to the sdc
                                                                                                                      ; entry for create new disc comands
EDD5 CC4E3A                                   ldd     #"N:"                                                   ; command to be sent to create a file
EDD8 8D06                                     bsr     putCmd2                                         ; send command
EDDA 39               noMsgEr rts                                                                     ; return
                                                                                                                      ; entry for mount - unmount like commands
EDDB 0F10             putCmd          clr     <noexec                                         ; no params needed (no disk to be created)
EDDD CC4D3A                                   ldd     #"M:"                                                   ; command to be sent to mount or unmount a drive
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; detect if sdc is already active
EDE0 0F77             putCmd2 clr     hdwSdc                                          ; no need to go back to old active slot
EDE2 17FE28                                   lbsr    tstSDC                                          ; is there an active sdc?
EDE5 2733                                     beq     xsd01                                                   ; yes, go on
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; if present but not active change to that slot, save old one                   
                                                                                                                      ; if sdc present, active it and mark somewhere that we must go back to the active one!
EDE7 3406                                     pshs    d                                                               ; save registers
EDE9 B60114                                   lda     floSDC                                          ; get hdw control byte
EDEC 8508                                     bita    #%00001000                                      ; is a sdc in the system?
EDEE 260E                                     bne     vfySD01                                         ; yes, jump section
EDF0 3264                                     leas    4,s                                                     ; get rid of d and 1 return address
EDF2 AEE4                                     ldx     ,s                                                              ; see if return address is $0900 (from sdir?)
EDF4 8C0900                                   cmpx    #$0900                                          ; comes from sdir?
EDF7 2602                                     bne     vfySD00                                         ; no, skip next
EDF9 3262                                     leas    2,s                                                     ; clean stack                                                                   
EDFB 16FD3F           vfySD00 lbra    NotSDCPresent                           ; no, show message
                                                                                                                      ; calculate sdc slot
EDFE B60114           vfySD01 lda     floSDC                                          ; get hdw control byte
EE01 84C0                                     anda    #%11000000                                      ; use bits 7-6 (slot where sdc is)
EE03 44                                       lsra                                                                    ; move them to
EE04 44                                       lsra                                                                    ; bits 5-4 (lower bits of high nibble)
EE05 3402                                     pshs    a                                                               ; save high nibble
EE07 44                                       lsra                                                                    ; low nibble   
EE08 44                                       lsra                                                                    ; gets high nibble
EE09 44                                       lsra                                                                    ; that will end  
EE0A 44                                       lsra                                                                    ; as zero
EE0B AAE0                                     ora     ,s+                                                     ; add high nibble (now they are the same value)
                                                                                                                      ; save active slot in hdwsdc
EE0D F603FF                                   ldb     cpyMPIcfg                                       ; get active slot
EE10 D777                                     stb     hdwSdc                                          ; save it for later use                                         
EE12 B703FF                                   sta     cpyMPIcfg                                       ; update copy
EE15 B7FF7F                                   sta     MPIcfg                                          ; activate sdc
EE18 3506                                     puls    d                                                               ; restore registers
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; pass string to data buffer
EE1A 8E01D2           xsd01           ldx   #nambuf+1                                 ; point to 1st char of the input string
EE1D CE0800                                   ldu     #$0800                                          ; point to 1st dos buffer
EE20 EDC1                                     std     ,u++                                                    ; put at the beginning of the command buffer
EE22 F601D1                                   ldb     nambuf                                          ; get string length
EE25 A680             str2buf lda     ,x+                                                     ; get a char from input string
EE27 A7C0                                     sta     ,u+                                                     ; copy in the buffer
EE29 5A                                       decb                                                                    ; decrement counter
EE2A 26F9                                     bne     str2buf                                         ; not yet done, loopback
EE2C 6FC4                                     clr     ,u                                                              ; put a final zero
EE2E 0D10                                     tst     <noexec                                         ; was sdf format?
EE30 2B06                                     bmi     addParms                                                ; yes, put params: cylinders and sides into b:x
                                                                                                                              ; the other varians send these registers with zero value                        
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; params to be passed (b:x)
EE32 D6FA                                     ldb     <valPar                                         ; get b parameter value
EE34 9E8A                                     ldx     <$8a                                                    ; 16 bits zero                                  
EE36 2015                                     bra     sendIt                                          ; send the command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; special parameters for command 'create disc' (b:x)
EE38 9610             addParms        lda     <noexec                                         ; get disc type
EE3A 8403                                     anda    #$03                                                    ; use lowest nibble
EE3C C628                                     ldb     #$28                                                    ; minimum value 40 cylinders
EE3E 8103                                     cmpa    #3                                                              ; was type 3 (2880 sectors)?
EE40 2601                                     bne     addP01                                          ; no, skip next
EE42 58                                       aslb                                                                    ; double cylinders number
EE43 8E0100           addP01  ldx     #$0100                                          ; one side by default
EE46 8101                                     cmpa    #1                                                              ; was type 0 or 1 (630 - 720 sectors)?
EE48 2303                                     bls     sendIt                                          ; yes, skip next
EE4A 8E0200                                   ldx     #$0200                                          ; set double sided
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; send command to the sdc
                                                                                                                              ; b:x have zeros or tracks:sides (at x-high byte)
EE4D 96FB             sendIt  lda     <cmdNum                                         ; code for extended command with data block
EE4F 9BF8                                     adda    <numUni                                         ; add drive number
EE51 CE0800                                   ldu     #$0800                                          ; point to beginning of data block
EE54 BDF82F                                   jsr     CommSDC                                         ; send command to sdc-card with (a,b:x,u)
EE57 2438                                     bcc     send01                                          ; if ok, skip section
                                                                                                                      ; if error $10 and sdir command, show message (not error)
EE59 C510                                     bitb    #$10                                                    ; is bit 4 set?
EE5B 2714                                     beq     nxtCEr                                          ; no, goto next control
EE5D 3406                                     pshs    d                                                               ; save registers
EE5F 96FA                                     lda     <valPar                                         ; get parameter used
EE61 8143                                     cmpa    #'C'                                                    ; was it a 'C' (sdir)?
EE63 2608                                     bne     send00                                          ; no, exit
EE65 8D19                                     bsr     currentDirIsRoot                        ; show message
EE67 3506                                     puls    d                                                               ; restore registers
EE69 1A01                                     orcc    #%00000001                                      ; set carry to mark error
EE6B 2027                                     bra     send02                                          ; exit
EE6D 3506             send00  puls    d                                                               ; clean stack
EE6F 2020                                     bra     send01                                          ; exit
                                                                                                                      ; if error $08 and get-dim command, show message (not error)
EE71 C508             nxtCEr  bitb    #$08                                                    ; is bit 3 set?
EE73 271C                                     beq     send01                                          ; no, skip section
EE75 84F0                                     anda    #$f0                                                    ; use high nibble
EE77 81C0                                     cmpa    #$c0                                                    ; was command $cn (get-dim)?
EE79 2616                                     bne     send01                                          ; no, go on
EE7B 1A01                                     orcc    #%00000001                                      ; set carry to mark error
EE7D 160220                                   lbra    exsdrv1                                         ; exit
EE80                  currentDirIsRoot                                                                ; current dir = root!
EE80 96F9                                     lda     <numDir                                         ; get number of directories requested in a series
EE82 8101                                     cmpa    #1                                                              ; is first one?
EE84 260A                                     bne     curNoMsg                                                ; no, do not show message
EE86 3450                                     pshs    x,u                                                     ; save registers
EE88 8EE492                                   ldx     #noCurDir-1                                     ; point to message
EE8B BD90E5                                   jsr     outstr                                          ; show it
EE8E 3550                                     puls    x,u                                                     ; restore registers
EE90 39               curNoMsg        rts                                                                     ; return
EE91 17096B           send01  lbsr    vfyStatus                                       ; verify operation result
EE94 0D10             send02  tst     <noexec                                         ; test format type
EE96 10270206                                 lbeq    exsdrv1                                         ; if coco-like 160k, all done, exit. should never happen
EE9A 102B0202                                 lbmi    exsdrv1                                         ; if sdf type, all done, exit   
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; additional swrite command for dragon-like disks
                                                                                                                      ; these three need a swrite,39(79),18(36),"",""
                                                                                                                      ; x must have the lsn number: 719,1439,2879
EE9E 8E02CF                                   ldx     #719                                                    ; to have 720 sectors
EEA1 9610                                     lda     <noexec                                         ; get disc type
EEA3 8403                                     anda    #3                                                              ; use lowest 2 bits
EEA5 8101                                     cmpa    #1                                                              ; is it a 180k (720 sectors) disc? 
EEA7 270A                                     beq     sendWrt                                         ; yes, send write order
EEA9 8E059F                                   ldx     #1439                                                   ; to force 1440 sectors
EEAC 8102                                     cmpa    #2                                                              ; is it a 360k (1440 sectors) disc?
EEAE 2703                                     beq     sendWrt                                         ; yes, send write order
EEB0 8E0B3F                                   ldx     #2879                                                   ; to force 2880 sectors
                                                                                                      ; *** ADDED CODE TO SUPPORT VDK FORMAT CREATING FILES   
                                                                                                                      ; here we must test the file extension to be ".VDK"
EEB3 0F76             sendWrt clr     <dsktyp                                         ; Now equals 0 = DSK
EEB5 CE01D1                                   ldu     #nambuf                                         ; point to filename buffer
EEB8 E6C4                                     ldb     ,u                                                              ; get filename length
EEBA C003                                     subb    #3                                                              ; to point to the possible dot (.) if .VDK was entered
EEBC 33C5                                     leau    b,u                                                     ; point to it
EEBE CC2E56                                   ldd     #".V"                                                   ; get dot and letter V
EEC1 10A3C1                                   cmpd    ,u++                                                    ; have we received it?
EEC4 260C                                     bne     sWrt01                                          ; no, skip section
EEC6 CC444B                                   ldd     #"DK"                                                   ; get string DK
EEC9 10A3C4                                   cmpd    ,u                                                              ; have we received it?
EECC 2604                                     bne     sWrt01                                          ; no, skip section
                                                                                                                      ; now we know the user wants to create a virtual VDK file
EECE 3001                                     leax    1,x                                                     ; so that the disk has an extra sector (for the header)                                                                 
EED0 0C76                                     inc     <dsktyp                                         ; now is 1 = VDK
                                                                                                      ; *** END_ADDED CODE TO SUPPORT VDK FORMAT CREATING FILES       
EED2 CE0800           sWrt01  ldu     #$0800                                          ; point to beginning of buffer
EED5 4F                                       clra                                                                    ; create a  
EED6 5F                                       clrb                                                                    ; 16 bits zero
EED7 EDC1             cleanBuf        std     ,u++                                                    ; clean a word
EED9 11830900                                 cmpu    #$0900                                          ; reached buffers end?
EEDD 25F8                                     blo     cleanBuf                                                ; no, loopback
EEDF CE0800                                   ldu     #$0800                                          ; point to buffers beginning
EEE2 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EEE4 9BF8                                     adda    <numUni                                         ; add drive number
EEE6 BDF82F                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EEE9 170913                                   lbsr    vfyStatus                                       ; verify operation result
                                                                                                      ; *** ADDED CODE TO FORMAT ON THE FLY DSK and VDK FILES
                                                                                                                      ; as the buffer is clean, we just need to fill bytes 0-19
                                                                                                                              ; for a VDK file, we will write a suitable header to sector #0
                                                                                                                              ; it should contain:
                                                                                                                              ;  position             length contents                                  value
EEEC CC646B                                   ldd     #"dk"                                                   ;       offset 0     2     signature               ('dk')
EEEF EDC1                                     std     ,u++
EEF1 CC0001                                   ldd     #$0001                                          ;       offset 2     2     Header length           ($00, $01) = $100
EEF4 EDC1                                     std     ,u++
EEF6 CC1010                                   ldd     #$1010                                          ;       offset 4     1     VDK version - actual    ($10)
EEF9 EDC1                                     std     ,u++                                                    ;       offset 5     1     VDK version - compat    ($10)
EEFB CC8800                                   ldd     #$8800                                          ;       offset 6     1     Source id               ($88)
EEFE EDC1                                     std     ,u++                                                    ;       offset 7     1     Source version          ($00)
EF00 108E2801                                 ldy     #$2801                                          ; 40 tracks 01 side (180k)
EF04 9610                                     lda     <noexec                                         ; get disc type
EF06 8403                                     anda    #3                                                              ; use lowest 2 bits
EF08 8101                                     cmpa    #1                                                              ; is it a 180k disc? 
EF0A 270A                                     beq     noMore2                                         ; yes, send write order
EF0C 3121                                     leay    1,y                                                     ; to force double sided ($2802)
EF0E 8102                                     cmpa    #2                                                              ; is it a 360k disc?
EF10 2704                                     beq     noMore2                                         ; yes, send write order
EF12 108E5002                                 ldy     #$5002                                          ; it is a 720k disk
EF16 1F20             noMore2 tfr     y,d                                                     ; pass geodata to regD
EF18 97F2                                     sta     <$f2                                                    ; number of tracks to DOS system variable
EF1A 5A                                       decb                                                                    ; because 0 means 1 side
EF1B D7F4                                     stb     <$f4                                                    ; number of sides to DOS system variable
                                                                                                                              ;       offset 8     1     Number of tracks        ($28)          40 or 80 --> ($28 or $50)
EF1D 10AFC1                                   sty     ,u++                                                    ;       offset 9     1     Number of sides         ($01)          1 or 2
EF20 CC0040                                   ldd     #$0040                                          ;       offset 10    1     Flags                   ($00)
EF23 EDC1                                     std     ,u++                                                    ;       offset 11    1     Comp & Name length      ($40)          bits 0-2 = compression [0=off, >0=TBD]
                                                                                                                              ;                                                                           bits 3-7 = filename length [min 0, max 31]
EF25 8E01D1                                   ldx     #nambuf                                         ;       offset 12    0-31  Disk name               (...)          (OPTIONAL) filename in ASCII. Doesn't need a zero terminator
EF28 E680                                     ldb     ,x+                                                     ; get filename length
EF2A C004                                     subb    #4                                                              ; subtract 4 to have the actual name without dot and extension
EF2C A680             cpy2buf lda     ,x+                                                     ; get a char from name
EF2E A7C0                                     sta     ,u+                                                     ; put into buffer
EF30 5A                                       decb                                                                    ; decrement counter
EF31 26F9                                     bne     cpy2buf                                         ; if not done, loopback, regB ends with value Zero
EF33 CE0800                                   ldu     #$0800                                          ; point to buffers beginning
EF36 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EF38 9BF8                                     adda    <numUni                                         ; add drive number
EF3A 8E0000                                   ldx     #$0000                                          ; to point to sector 0 (header)
EF3D BDF82F                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EF40 1708BC                                   lbsr    vfyStatus                                       ; verify operation result
                                                                                                                      ; Once we have the header, we must add 20 tracks of $e5 bytes
EF43 8E0800                                   ldx     #$0800                                          ; to use this buffer
EF46 9FEE                                     stx     <$ee                                                    ; update system pointer
EF48 BDE13A                                   jsr     filbuf                                          ; will fill it with bytes value $E5
EF4B CC1412                                   ldd     #$1412                                          ; get number of tracks to write (20) and numsectors x track
EF4E 0DF4                                     tst     <$f4                                                    ; is single sided?
EF50 2701                                     beq     noDouble                                                ; yes, do not double
EF52 58                                       aslb                                                                    ; double number of sectors x track
EF53 3D               noDouble        mul                                                                     ; calculate total number of sector to write
EF54 1F02                                     tfr     d,y                                                     ; pass value to regY
EF56 8E0001                                   ldx     #1                                                              ; 1st sector (LSN) to be written for a VDK file
EF59 0D76                                     tst     <dsktyp                                         ; are we creating a VDK?
EF5B 2602                                     bne     nSector                                         ; yes, skip next
EF5D 301F                                     leax    -1,x                                                    ; 1st LSN for a DSK file (and so rewrite the header!)
EF5F 3430             nSector pshs    x,y                                                     ; save variables
EF61 CE0800                                   ldu     #$0800                                          ; point to buffers beginning
EF64 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EF66 9BF8                                     adda    <numUni                                         ; add drive number
EF68 5F                                       clrb                                                                    ; higher byte to zero
EF69 BDF82F                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EF6C 170890                                   lbsr    vfyStatus                                       ; verify operation result
EF6F 3530                                     puls    x,y                                                     ; restore variables
EF71 3001                                     leax    1,x                                                     ; point to next LSN
EF73 313F                                     leay    -1,y                                                    ; decrement counter
EF75 26E8                                     bne     nSector                                         ; if not done, loopback 
EF77 3410                                     pshs    x                                                               ; put next LSN on stack
                                                                                                                      ; now we must add 1st FAT sector
EF79 BDE17D                                   jsr     ffat1                                                   ; buffer: $800. fills 1st FAT sector upon geodata
EF7C CE0800                                   ldu     #$0800                                          ; point to buffers beginning
EF7F 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EF81 9BF8                                     adda    <numUni                                         ; add drive number
EF83 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
EF84 AEE4                                     ldx     ,s                                                              ; get LSN from stack
EF86 BDF82F                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EF89 170873                                   lbsr    vfyStatus                                       ; verify operation result
                                                                                                                      ; let's try the same for track 16 (backup DIR)
                                                                                                                      ; we have to calculate the first sector for that track
EF8C 8610                                     lda     #16                                                     ; number of track to write on
EF8E C612                                     ldb     #18                                                     ; number of sectors x track if single sided disk
EF90 0DF4                                     tst     <$f4                                                    ; is double sided?
EF92 2701                                     beq     1f                                                              ; no, skip next
EF94 58                                       aslb                                                                    ; double sectors x track
EF95 3D               1                       mul                                                                     ; to get sectors before sector 1 track 16
EF96 0D76                                     tst     <dsktyp                                         ; is it a VDK?
EF98 2703                                     beq     2f                                                              ; no, skip next
EF9A C30001                                   addd    #1                                                              ; add a sector (header)
EF9D DDD9             2                       std     <fST16                                          ; save that value for later use
                                                                                                                      ; now write 1st sector Track 16
EF9F CE0800                                   ldu     #$0800                                          ; point to buffers beginning
EFA2 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EFA4 9BF8                                     adda    <numUni                                         ; add drive number
EFA6 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
EFA7 9ED9                                     ldx     <fST16                                          ; get LSN from variable
EFA9 BDF82F                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EFAC 170850                                   lbsr    vfyStatus                                       ; verify operation result
                                                                                                                      ; now we must add 2nd FAT sector
EFAF BDE1D2                                   jsr     ffat2                                                   ; buffer: $900. fills 2nd FAT sector upon geodata
EFB2 CE0900                                   ldu     #$0900                                          ; point to buffers beginning
EFB5 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EFB7 9BF8                                     adda    <numUni                                         ; add drive number
EFB9 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
EFBA AEE4                                     ldx     ,s                                                              ; get previous LSN from stack
EFBC 3001                                     leax    1,x                                                     ; increment number
EFBE AFE4                                     stx     ,s                                                              ; update it
EFC0 BDF82F                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EFC3 170839                                   lbsr    vfyStatus                                       ; verify operation result
                                                                                                                      ; and do the same for Track 16
EFC6 CE0900                                   ldu     #$0900                                          ; point to buffers beginning
EFC9 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EFCB 9BF8                                     adda    <numUni                                         ; add drive number
EFCD 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
EFCE 9ED9                                     ldx     <fST16                                          ; get previous LSN from variable
EFD0 3001                                     leax    1,x                                                     ; increment number
EFD2 9FD9                                     stx     <fST16                                          ; update it
EFD4 BDF82F                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EFD7 170825                                   lbsr    vfyStatus                                       ; verify operation result
                                                                                                                      ; now we go for the 16 directory sectors with entries ...
EFDA BDE15E                                   jsr     fil16s                                          ; buffer: $a00. fills a sector to be used as diretory sector (3-18)
EFDD C610                                     ldb     #16                                                     ; number of sectors to write
EFDF 3510                                     puls    x                                                               ; get previous LSN from stack
EFE1 3001                                     leax    1,x                                                     ; increment LSN number
EFE3 3414             nDSect  pshs    b,x                                                     ; save variables
EFE5 CE0A00                                   ldu     #$0a00                                          ; point to buffers beginning
EFE8 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
EFEA 9BF8                                     adda    <numUni                                         ; add drive number
EFEC 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
EFED BDF82F                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
EFF0 17080C                                   lbsr    vfyStatus                                       ; verify operation result
EFF3 3514                                     puls    b,x                                                     ; restore variables
EFF5 3001                                     leax    1,x                                                     ; increment LSN number
EFF7 5A                                       decb                                                                    ; decrement sector counter
EFF8 26E9                                     bne     nDSect                                          ; not done, loop
EFFA 3410                                     pshs    x                                                               ; save next LSN (rest of the disk)
                                                                                                                      ; and do the same for Track16 too
EFFC C610                                     ldb     #16                                                     ; number of sectors to write
EFFE 9ED9                                     ldx     <fST16                                          ; get previous LSN from variable
F000 3001                                     leax    1,x                                                     ; increment LSN number
F002 3414             n16Sect pshs    b,x                                                     ; save variables
F004 CE0A00                                   ldu     #$0a00                                          ; point to buffers beginning
F007 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
F009 9BF8                                     adda    <numUni                                         ; add drive number
F00B 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
F00C BDF82F                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
F00F 1707ED                                   lbsr    vfyStatus                                       ; verify operation result
F012 3514                                     puls    b,x                                                     ; restore variables
F014 3001                                     leax    1,x                                                     ; increment LSN number
F016 5A                                       decb                                                                    ; decrement sector counter
F017 26E9                                     bne     n16Sect                                         ; not done, loop
                                                                                                                      ; finally we will write the rest of the sectors with $e5
                                                                                                                      ; X points to next LSN. end od disk might be: 720, 1440, 2880 (due to the header)
F019 8E0800                                   ldx     #$0800                                          ; to use this buffer again
F01C 9FEE                                     stx     <$ee                                                    ; update system pointer
F01E BDE13A                                   jsr     filbuf                                          ; will fill it with bytes value $E5
F021 3510                                     puls    x                                                               ; get LSN for rest of the disk from stack
F023 108E02D1                                 ldy     #721                                                    ; value to detect end of disk for 180k disk
F027 9610                                     lda     <noexec                                         ; get disc type
F029 8403                                     anda    #3                                                              ; use lowest 2 bits
F02B 8101                                     cmpa    #1                                                              ; is it a 180k (720 sectors) disk? 
F02D 270C                                     beq     1f                                                              ; yes, send write order
F02F 108E05A1                                 ldy     #1441                                                   ; to detect end of 360 disk
F033 8102                                     cmpa    #2                                                              ; is it a 360k (1440 sectors) disk?
F035 2704                                     beq     1f                                                              ; yes, send write order
F037 108E0B41                                 ldy     #2881                                                   ; to detect end of 720k disk
F03B 0D76             1                       tst     <dsktyp                                         ; are we creating a VDK file?
F03D 2602                                     bne     nRDisk                                          ; yes, skip next
F03F 313F                                     leay    -1,y                                                    ; subtract 1 (no header for DSK)
F041 3430             nRDisk  pshs    x,y                                                     ; save registers (LSN, endOfFile)
F043 CE0800                                   ldu     #$0800                                          ; point to buffers beginning
F046 86A0                                     lda     #$a0                                                    ; command to be sent: SDWRITE
F048 9BF8                                     adda    <numUni                                         ; add drive number
F04A 5F                                       clrb                                                                    ; higher byte to zero. X is the good number
F04B BDF82F                                   jsr     CommSDC                                         ; send command to SDC-card      (LSN = B:X)
F04E 1707AE                                   lbsr    vfyStatus                                       ; verify operation result
F051 3510                                     puls    x                                                               ; restore LSN number
F053 3001                                     leax    1,x                                                     ; increment LSN number
F055 ACE4                                     cmpx    ,s                                                              ; is X greater than Y (in the stack)
F057 3520                                     puls    y                                                               ; to balance stack
F059 26E6                                     bne     nRDisk                                          ; not done, loop
                                                                                                                      ; call SDRIVE n,UNLOAD
                                                                                                                      ; first we must save the filename from nambuf or it will be lost
                                                                                                                      ; we need from nambuf to nambuf + 12 (8 plus dot plus VDK)
F05B 8E0A00                                   ldx     #$a00                                                   ; point to last DOS buffer
F05E CE01D1                                   ldu     #nambuf                                         ; point to filename buffer
F061 C60D                                     ldb     #13                                                     ; number of bytes to copy
F063 A6C0             1                       lda     ,u+                                                     ; get a byte from filename buffer
F065 A780                                     sta     ,x+                                                     ; put into DOS buffer
F067 5A                                       decb                                                                    ; decrement counter
F068 26F9                                     bne     1b                                                              ; not done, loop
F06A 0FFA                                     clr     <valPar                                         ; value param is 0
F06C C6E0                                     ldb     #$e0                                                    ; more used value
F06E D7FB                                     stb     <cmdNum                                         ; store it
F070 BDED73                                   jsr     reuseUL                                         ; call final part of SDRIVEx,UNLOAD
F073 8E0A00                                   ldx     #$a00                                                   ; point to last DOS buffer
F076 CE01D1                                   ldu     #nambuf                                         ; point to filename buffer
F079 C60D                                     ldb     #13                                                     ; number of bytes to copy
F07B A680             1                       lda     ,x+                                                     ; get a byte from DOS buffer
F07D A7C0                                     sta     ,u+                                                     ; put into filename buffer
F07F 5A                                       decb                                                                    ; decrement counter
F080 26F9                                     bne     1b                                                              ; not done, loop
F082 0FFA                                     clr     <valPar                                         ; value param is 0
F084 C6E0                                     ldb     #$e0                                                    ; more used value
F086 D7FB                                     stb     <cmdNum                                         ; store it
F088 BDED79                                   jsr     dTok01                                  ; call SDRIVE n,"received FILENAME.VDK"
F08B 9677                                     lda     hdwSdc                                          ; is here the old slot?
F08D 2706                                     beq     1f                                                              ; no, exit
F08F B703FF                                   sta     cpyMPIcfg                                       ; update copy
F092 B7FF7F                                   sta     MPIcfg                                          ; active it
F095 39               1                       rts                                                                     ; return
                                                                              ; *** END_ADDED CODE TO SUPPORT VDK AND DSK FORMAT WHILE CREATING FILES 
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; restore old slot if needed
F096 9677             exsdrv  lda     hdwSdc                                          ; is here the old slot?
F098 2706                                     beq     exsdrv1                                         ; no, exit
F09A B703FF                                   sta     cpyMPIcfg                                       ; update copy
F09D B7FF7F                                   sta     MPIcfg                                          ; active it
F0A0 39               exsdrv1 rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; special command floppy off
F0A1 8D0F             flopOF  bsr     flopCom                                         ; see if it could be done
F0A3 FA0114                                   orb     floSDC                                          ; add to hdw control byte (a bit to 1 disables floppy and enables sdc)
F0A6 F70114           eflop           stb     floSDC                                          ; update hdw control byte
F0A9 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; special command floppy on
F0AA 8D06             flopON  bsr     flopCom                                         ; see if it could be done
F0AC 53                                       comb                                                                    ; invert all bits: %00000001 - %00000010 convert to %11111110 - %11111101
F0AD F40114                                   andb    floSDC                                          ; a bit 0 enables floppy and disables sdc
F0B0 20F4                                     bra   eflop                                                     ; update and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; common part for floppy on-off
F0B2 9D9F             flopCom jsr     <getNChr                                                ; skip token to avoid sn error when returning
F0B4 F60114                                   ldb     floSDC                                          ; get hdw control byte
F0B7 C40C                                     andb    #%00001100                                      ; see if switching is possible
F0B9 C10C                                     cmpb    #%00001100                                      ; are both floppies and sdc present?
F0BB 2604                                     bne     notAllow                                                ; no, show error message
F0BD D6F8                                     ldb     <numUni                                         ; get drive number (0-1)
F0BF 5C                                       incb                                                                    ; convert to 1-2
F0C0 39                                       rts                                                                     ; return
F0C1 3262             notAllow leas   2,s                                                     ; clean stack (is inside one subroutine)
F0C3 8EE4A7                                   ldx     #canNot-1                                       ; point to message
F0C6 7E90E5                                   jmp     outstr                                          ; show it and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; special command dim
F0C9 8651             sdcDIM  lda     #'Q'                                                    ; param to send into b
F0CB 8D14                                     bsr     sdcDAT                                          ; process it
F0CD 2527                                     bcs     noDiscEr                                                ; if got "not disc" error, explain it
F0CF 170134                                   lbsr    shwDIM                                          ; show received data
F0D2 8DC2             rstSlot bsr     exsdrv                                          ; restore slot if needed
F0D4 1CFE                                     andcc   #%11111110                                      ; clear carry flag
F0D6 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; special command get
F0D7 8649             sdcGET  lda     #'I'                                                    ; param to send into b
F0D9 8D06                                     bsr     sdcDAT                                          ; process it
F0DB 2519                                     bcs     noDiscEr                                                ; if got "not disc" error, explain it
F0DD 8D24                                     bsr     shwGET                                          ; show received data
F0DF 20F1                                     bra     rstSlot                                         ; restore slot if needed
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; common part for get-dim
F0E1 97FA             sdcDAT  sta     <valPar                                         ; save it
F0E3 9D9F                                     jsr     <getNChr                                                ; skip read token
F0E5 86C0                                     lda     #$c0                                                    ; command to send
F0E7 97FB                                     sta     <cmdNum                                         ; save it
F0E9 CC0100                                   ldd     #$0100                                          ; get 1 byte with value equal null
F0EC FD01D1                                   std     nambuf                                          ; put in nambuf area (no name)
F0EF 0F10                                     clr     <noexec                                         ; no additional command needed
F0F1 DC8A                                     ldd     <$8a                                                    ; get 16 bits zero
F0F3 7EEDE0                                   jmp     putCmd2                                         ; send command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; message no disc in drive
F0F6 96F8             noDiscEr        lda     <numUni                                         ; gets 0-1
F0F8 8B31                                     adda    #$31                                                    ; converts to '1'-'2'
F0FA BDB54A                                   jsr     outchr                                          ; show drive number
F0FD 8EE4B5                                   ldx     #sdcNoDsc-1                                     ; point to message
F100 7E90E5                                   jmp     outstr                                          ; show it
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show received 'get' info
F103 96F8             shwGET  lda     <numUni                                         ; get drive number
F105 8B31                                     adda    #$31                                                    ; converts to '1'-'2'
F107 BDB54A                                   jsr     outchr                                          ; show drive number
F10A 863A                                     lda     #':'                                                    ; get char ':'
F10C BDB54A                                   jsr     outchr                                          ; show it
                                                                                                                      ; show drive status
F10F 866F                                     lda     #'o'                                                    ; get fixed 1st letter
F111 BDB54A                                   jsr     outchr                                          ; show it
F114 866E                                     lda     #'n'                                                    ; get on as default
F116 D6F8                                     ldb     <numUni                                         ; get drive unit
F118 5C                                       incb                                                                    ; convert  0-1 into 1-2
F119 F40114                                   andb    floSDC                                          ; test corresponding bit of hdw control byte
F11C 2607                                     bne     sdcS00                                          ; if not zero, skip next
F11E 8666                                     lda     #'f'                                                    ; get value for off
F120 BDB54A                                   jsr     outchr                                          ; put first 'f'
F123 200D                                     bra     sdcS01                                          ; go put 2nd one instead of space
F125 BDB54A           sdcS00  jsr     outchr                                          ; show result
F128 8620                                     lda     #32                                                     ; get space as inverted block to poke it
F12A 9E88                                     ldx     <$88                                                    ; get cursor address
F12C A780                                     sta     ,x+                                                     ; put inverse space there
F12E 9F88                                     stx     <$88                                                    ; update cusor address
F130 2003                                     bra     sdcS02                                          ; skip next
F132 BDB54A           sdcS01  jsr     outchr                                          ; show it
F135 8D6D             sdcS02  bsr     shwFdat                                         ; show filename and type
F137 33C811                                   leau    17,u                                                    ; jump to length bytes
F13A 8D06                                     bsr     shwFL                                                   ; show file length
F13C 860D                                     lda     #$0d                                                    ; get enter value
F13E BDB54A                                   jsr     outchr                                          ; print it
F141 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show file length - structure of the fac
                                                                                                                      ;       $50 highest byte        --- always $00
                                                                                                                      ;       $51 high byte           --- high byte of u
                                                                                                                      ;       $52 mid  byte           --- low  byte of u
                                                                                                                      ;       $53 lower byte          --- reg. a ($00 = multiple of 256)
F142 A642             shwFL           lda 2,u                                                         ; get highest byte in A
F144 E641                                     ldb 1,u                                                         ; get high byte in B
F146 3406                                     pshs d                                                          ; hold on
F148 A6C4                                     lda ,u                                                          ; now get mid and low bytes
F14A E65F                                     ldb -1,u
F14C 3540                                     puls u
                      ; Revised shwNum to take U and D
F14E 11830010         shwNum  cmpu #$0010                                                     ; Check if high word shows >1M
F152 251A                                     blo less1M                                                      ; if not display size in bytes
F154 1F30                                     tfr u,d                         ; Otherwise take high word
F156 C4F0                                     andb #$F0                                                       ; Clear low 4 bits
F158 47                                       asra                                                                    ; Divide by 16 asr / ror
F159 56                                       rorb
F15A 47                                       asra
F15B 56                                       rorb
F15C 47                                       asra
F15D 56                                       rorb
F15E 47                                       asra
F15F 56                                       rorb
F160 3406                                     pshs d                                                          ; Put B and then A onto stack
F162 5F                                       clrb                                                                    ; zero B
F163 3404                                     pshs b                                                          ; stack zero top byte as well
F165 3540                                     puls u                                                          ; get to U
F167 3502                                     puls a                                                          ; and bottom byte in A
F169 5C                                       incb                                                                    ; flag for Megabytes
F16A 3404                                     pshs b                                                          ; remember flag 
F16C 200D                                     bra coreNum
F16E 3402             less1M  pshs a                                                          ; stash mid byte
F170 3440                                     pshs u                                                          ; and top two
F172 3261                                     leas 1,s                                                                ; fudge frame drop high byte 
F174 3540                                     puls u                                                          ; get u
F176 1F98                                     tfr b,a                                                         ; put low byte in a
F178 5F                                       clrb                                                                    ; flag for bytes
F179 3404                                     pshs b                                                          ; remember
F17B BDDD7D           coreNum         jsr     $dd7d                                                   ; integer to fac and normalize it
F17E BD9587                                   jsr     $9587                                                   ; fac to ascii (x points to string ended with $00
                                                                                                                              ; calculate length and add spaces to have total length = 7
F181 3101                                     leay    1,x                                                     ; point to first digit
F183 C608                                     ldb     #8                                                              ; desired length + final null
F185 E0E4                                     subb ,s                                                         ; leave a space if we need M indicator
F187 5A               shwN01  decb                                                                    ; decrement counter
F188 A6A0                                     lda     ,y+                                                     ; get a digit
F18A 26FB                                     bne     shwN01                                          ; if not 0, loopback
F18C 5D                                       tstb                                                                    ; needs extra spaces?
F18D 2708                                     beq     shwN02                                          ; no, skip section
F18F 8620                                     lda     #32                                                     ; get space
F191 BDB54A           shwN03  jsr     outchr                                          ; print it
F194 5A                                       decb                                                                    ; decrement counter
F195 26FA                                     bne     shwN03                                          ; if not zero, loopback
F197 BD90E5           shwN02  jsr     outstr                                          ; print lengths' string
F19A E6E0                                     ldb     ,s+                                                     ; Are we printing Megabytes?
F19C 2705                                     beq     skipM                                                   ; No, bytes 
F19E 864D                                     lda     #77                                                     ; M character
F1A0 BDB54A                                   jsr     outchr                                          ; print it
F1A3 39               skipM           rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show filename and extension                   
F1A4 CE0800           shwFdat ldu     #$800                                                   ; point to beginning of data
F1A7 C608             shwFd01 ldb     #8                                                              ; 8 chars for name
F1A9 A6C0             sdc01           lda     ,u+                                                     ; get a char
F1AB BDB54A                                   jsr     outchr                                          ; show it
F1AE 5A                                       decb                                                                    ; decrement counter
F1AF 26F8                                     bne     sdc01                                                   ; not all, loopback
F1B1 862E                                     lda     #'.'                                                    ; get a dot
F1B3 BDB54A                                   jsr     outchr                                          ; show it
F1B6 C603                                     ldb     #3                                                              ; 3 chars for extension
F1B8 A6C0             sdc02           lda     ,u+                                                     ; get a char
F1BA BDB54A                                   jsr     outchr                                          ; show it
F1BD 5A                                       decb                                                                    ; decrement counter
F1BE 26F8                                     bne     sdc02                                                   ; not all, loopback
                                                                                                                      ; show file type and extra info
F1C0 E6C0                                     ldb     ,u+                                                     ; get byte 11 (type)
F1C2 8620                                     lda     #32                                                     ; get space
F1C4 C102                                     cmpb    #$02                                                    ; is byte hidden?
F1C6 2602                                     bne     sdc05                                                   ; no, skip next 
F1C8 8668                                     lda     #'h'                                                    ; get h char
F1CA BDB54A           sdc05           jsr     outchr                                          ; show it
F1CD 8620                                     lda     #32                                                     ; get space
F1CF C101                                     cmpb    #$01                                                    ; is it locked?
F1D1 2602                                     bne     sdc06                                                   ; no, skip next 
F1D3 866C                                     lda     #'l'                                                    ; get l char
F1D5 BDB54A           sdc06           jsr     outchr                                          ; show it
F1D8 C110                                     cmpb    #$10                                                    ; is it a directory?
F1DA 270C                                     beq     sdc04                                                   ; yes, get that text
F1DC C104                                     cmpb    #$04                                                    ; is it sdf type?
F1DE 2704                                     beq     sdc03                                                   ; yes, get that text
F1E0 8EE4DE                                   ldx     #datNUL-1                                       ; else get spaces
F1E3 10                                       fcb     #$10                                                    ; to skip next
F1E4 8EE4D4           sdc03           ldx     #datSDF-1                                       ; point to message
F1E7 10                                       fcb     #$10                                                    ; to skip next
F1E8 8EE4D9           sdc04           ldx     #datDIR-1                                       ; point to message
F1EB 3440                                     pshs    u                                                               ; save pointer
F1ED BD90E5                                   jsr     outstr                                          ; put the three chars
F1F0 3540                                     puls    u                                                               ; restore pointer
F1F2 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; command sdrive alone
F1F3 0FF8             sdcLST  clr     <numUni                                         ; set drive 1
F1F5 17FEDF                                   lbsr    sdcGET                                          ; get and show info for that drive
                      ;                       bcs     esdcLST                                         ; if carry set, exit (no sdc present)
F1F8 210B                                     brn     esdcLST                                         ; if carry set, exit (no sdc present)
F1FA 9EA6                                     ldx     <$a6                                                    ; get input pointer
F1FC 301E                                     leax    -2,x                                                    ; move it back (will be moved forward later)
F1FE 9FA6                                     stx     <$a6                                                    ; update it
F200 0CF8                                     inc     <numUni                                         ; det drive 2                   
F202 17FED2                                   lbsr    sdcGET                                          ; get and show info for that drive
F205 39               esdcLST rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show received 'dim' info
F206 96F8             shwDIM  lda     <numUni                                         ; get drive number
F208 8B31                                     adda    #$31                                                    ; converts to '1'-'2'
F20A BDB54A                                   jsr     outchr                                          ; show drive number
F20D 8EE4C3                                   ldx     #totSect-1                                      ; point to message
F210 BD90E5                                   jsr     outstr                                          ; show it
F213 4F                                       clra                                    ; now get - Mike Miller 2021-05
F214 F6FF41                                   ldb $ff41                               ; four - Mike Miller 2021-05
F217 1F03                                     tfr d,u                                 ; bytes - Mike Miller 2021-05
F219 FCFF42                                   ldd $ff42                               ; in regs UD - Mike Miller 2021-05
F21C 17FF2F                                   lbsr    shwNum                                          ; process and show it
F21F 7E90A5                                   jmp     sendCR                                          ; send cr
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; command smkdir
F222 8D09             xsmkdir bsr     others                                          ; read filename, get params
F224 CC4B3A                                   ldd     #"K:"                                                   ; command to send
F227 BDEDE0           xsmk01  jsr     putCmd2                                         ; send command
F22A 16FEA5                                   lbra    rstSlot                                         ; restore slot if needed
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; read filename and set parameters                      
F22D BDB7AA           others  jsr   getfnam                                           ; read string and length into $1d1 = nambuf
F230 F601D1                   ldb     nambuf                                          ; is string length 0?
F233 1027F554                 lbeq    snError                                         ; yes, show error
F237 C1FD                     cmpb    #253                                                    ; is string longer than maximum accepted? (253 + m: + final null)
F239 2505                                     bcs     other01                                         ; no, skip section
F23B 3262                                     leas    2,s                                                     ; clean stack (we are inside a subroutine)
F23D 16F8F5                                   lbra    TooLong                                         ; show error message
F240 5F               other01 clrb                                                                    ; set to zero
F241 D7FA                                     stb     <valPar                                         ; parameter for b
F243 D710                                     stb     <noexec                                         ; no more parmas
F245 D7F8                                     stb     <numUni                                         ; drive 0
F247 86E0                                     lda     #$e0                                                    ; command to send
F249 97FB                                     sta     <cmdNum                                         ; save it
F24B 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; command skill
F24C 8DDF             xskill  bsr     others                                          ; read filename, get params
F24E CC583A                                   ldd     #"X:"                                                   ; command to send
F251 20D4                                     bra     xsmk01                                          ; go send command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; command sren
F253 BDB7AA           xsren           jsr     getfnam                                         ; get old name
F256 F601D1                   ldb     nambuf                                          ; is string length 0?
F259 1027F52E                 lbeq    snError                                         ; yes, show error
F25D C17D                     cmpb    #125                                                    ; is string longer than maximum accepted? (125 for each one)
F25F 1024F8D2                 lbcc    TooLong                                         ; show error message
                                                                                                                      ; send it to $800 ended with $00
F263 8E01D2                                   ldx   #nambuf+1                                 ; point to 1st char of the input string
F266 CE0800                                   ldu     #$0800                                          ; point to 1st dos buffer
F269 F601D1                                   ldb     nambuf                                          ; get string length
F26C A680             xsren01 lda     ,x+                                                     ; get a char from input string
F26E A7C0                                     sta     ,u+                                                     ; copy in the buffer
F270 5A                                       decb                                                                    ; decrement counter
F271 26F9                                     bne     xsren01                                         ; not yet done, loopback
F273 6FC0                                     clr     ,u+                                                     ; put a final zero
F275 DF76                                     stu     <bufPtr                                         ;save pointer
F277 BDB7AA                                   jsr     getfnam                                         ; get new name
F27A F601D1                   ldb     nambuf                                          ; is string length 0?
F27D 1027F50A                 lbeq    snError                                         ; yes, show error
F281 C17D                     cmpb    #125                                                    ; is string longer than maximum accepted? (125 for each one)
F283 1024F8AE                 lbcc    TooLong                                         ; show error message
                                                                                                                      ; add after old name
F287 8E01D2                                   ldx   #nambuf+1                                 ; point to 1st char of the input string
F28A DE76                                     ldu     <bufPtr                                         ; get old pointer
F28C F601D1                                   ldb     nambuf                                          ; get newname string length
F28F A680             xsren02 lda     ,x+                                                     ; get a char from input string
F291 A7C0                                     sta     ,u+                                                     ; copy in the buffer
F293 5A                                       decb                                                                    ; decrement counter
F294 26F9                                     bne     xsren02                                         ; not yet done, loopback
F296 DF76                                     stu     <bufPtr                                         ; save last byte received
                                                                                                                      ; send it back to nambuf+1 - put length in nambuf 
F298 8E01D2                                   ldx     #nambuf+1                                       ; point to 1st char in input buffer                                                                             
F29B CE0800                                   ldu     #$800                                                   ; point to 1st byte of dos buffer
F29E 5F                                       clrb                                                                    ; counter to zero
F29F A6C0             xsren03 lda     ,u+                                                     ; get a byte
F2A1 A780                                     sta     ,x+                                                     ; put on the input buffer
F2A3 5C                                       incb                                                                    ; increment counter
F2A4 119376                                   cmpu    <bufPtr                                         ; got to the end?
F2A7 25F6                                     blo     xsren03                                         ; no, loopback
F2A9 F701D1                                   stb     nambuf                                          ; save total string length 
F2AC 8D92                                     bsr     other01                                         ; set parameters
F2AE CC523A                                   ldd     #"R:"                                                   ; command to send
F2B1 16FF73                                   lbra    xsmk01                                          ; go send command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; routine to add extension to the file name if not present
                      ; param: noexec=$00 to add .DSK  --- noexec=$80 to add .SDF
                      ; -------------------------------------------------------------------------------------------------------------------------------
F2B4 3416             addExt  pshs    d,x                                                     ; save pointers
F2B6 8E01D1                                   ldx     #nambuf                                         ; poit to name buffer
F2B9 E680                                     ldb   ,x+                                                       ; length of name
                                                                                                                      ; Check for existing extension
F2BB A680             isadot          lda   ,x+                                                       ; get a char from name
F2BD 812E                     cmpa  #'.'                                                      ; is it a dot?
F2BF 2727                     beq   eAddExt                                           ; yes, exit
F2C1 5A                       decb                                                                    ; decrement counter
F2C2 26F7                     bne   isadot                                            ; not end of string, get next char name
                                                                                                                      ; so, we must add an extension
F2C4 0D10                     tst     <noexec                                         ; is for a SDF file?
F2C6 2B0C                     bmi     addSDF                                          ; yes, jump section
F2C8 CC2E44           addDSK          ldd   #$2e44                                            ; get chars ".D"
F2CB ED81                     std   ,x++                                                      ; add to end of name
F2CD CC534B                   ldd   #$534b                                            ; get chars "SK"
F2D0 ED81                     std   ,x++                                                      ; add to end of name
F2D2 200A                                     bra     add01                                                   ; skip next section
F2D4 CC2E53           addSDF          ldd   #$2e53                                            ; get chars ".S"
F2D7 ED81                     std   ,x++                                                      ; add to end of name
F2D9 CC4446                   ldd   #$4446                                            ; get chars "DF"
F2DC ED81                     std   ,x++                                                      ; add to end of name
F2DE 6F84             add01           clr     ,x                                                              ; put a null at next byte
F2E0 F601D1                                   ldb   nambuf                                            ; get old name length
F2E3 CB04                                     addb  #4                                                                ; add 4 (because of dot and extension added)
F2E5 F701D1                   stb   nambuf                                            ; save new length in byte before string
F2E8 3596             eAddExt puls  d,x,pc                                            ; restore pointers and return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Section to deal with SDC-card SCHD commands
                      ; -------------------------------------------------------------------------------------------------------------------------------
F2EA 9DA5             xschd           jsr     <redLChr                                                ; peek at next char after SCHD
F2EC 1027F49B                                 lbeq    snError                                         ; if null, syntax error
F2F0 8122                                     cmpa    #$22                                                    ; is this the double quote?  = new directory
F2F2 10270123                                 lbeq    setCD01                                         ; do the same as SDIR = (by now!)
F2F6 81C6                                     cmpa    #$c6                                                    ; is it the token for /?
F2F8 271C                                     beq     chgRoot                                         ; process it
F2FA 812E                                     cmpa    #'.'                                                    ; is it a dot '.'?
F2FC 1026F48B                                 lbne    snError                                         ; no, show syntax error
F300 9D9F                                     jsr     <getNChr                                                ; get next char
F302 812E                                     cmpa    #'.'                                                    ; is it another dot '.'?
F304 1026F483                                 lbne    snError                                         ; no, show syntax error
                                                                                                                      ; this is to set parent dir as actual
F308 9D9F             chgParD jsr     <getNChr                                                ; skip token
F30A 8602             chwPD01 lda     #$02                                                    ; only one char in nambuf
F30C C62E                                     ldb     #'.'                                                    ; char to design root directory (twice)
F30E FD01D1                                   std     nambuf                                          ; put signs
F311 F701D3                                   stb     nambuf+2                                                ; into input buffer
F314 2009                                     bra     chgR01                                          ; process it
                                                                                                                      ; this is to set root as actual dir
F316 9D9F             chgRoot jsr     <getNChr                                                ; skip token
F318 8601                                     lda     #$01                                                    ; only one char in nambuf
F31A C62F                                     ldb     #'/'                                                    ; char to design root directory
F31C FD01D1                                   std     nambuf                                          ; put data in input buffer area
F31F 17FF1E           chgR01  lbsr    other01                                         ; set parameters
F322 1600F7                                   lbra    setCD02                                         ; go to process the requested directory
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Section to deal with SDC-card SDIR commands
                      ; -------------------------------------------------------------------------------------------------------------------------------
F325 9DA5             xsdir           jsr     <redLChr                                                ; peek at next char after sdir
F327 102700E6                                 lbeq    shwCAct                                         ; is the sdir alone = show current dir contents
                                                                                                                      ; decode token - sign
F32B 81B3                                     cmpa    #$b3                                                    ; is the token for get?
F32D 102700AF                                 lbeq    shwCDir                                         ; yes, show current dir name
F331 8187                                     cmpa    #$87                                                    ; is it the token for print (question mark)?
F333 102700EB                                 lbeq    shwFull                                         ; yes, show the full path name of actual dir (maybe substitute sdir get!)
F337 81C4                                     cmpa    #$c4                                                    ; is this the token for ('-')? = show contents of root dir
F339 102700C5                                 lbeq    shwRoot                                         ; yes, go process it
F33D 81CB                                     cmpa    #$cb                                                    ; is this the token for ('=')? = set current dir
F33F 102700D4                                 lbeq    setCDir                                         ; yes, go process it
F343 8122                                     cmpa    #$22                                                    ; is this the sign ('"')?  = show contents of the requested dir
F345 1026F442                                 lbne    snError                                         ; no, show syntax error
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; show contents of requested dir
                                                                                                                      ; send a initiate directory listing command
F349 17FEE1           shwRDir lbsr    others                                          ; read filename, get params
F34C CC4C3A           shwEDir ldd     #"L:"                                                   ; command to send
F34F BDEDE0                                   jsr     putCmd2                                         ; send command
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; ask for directory pages to the sdc
F352 17FEEB           shwRD00 lbsr    other01                                         ; set some parameters
F355 C63E                                     ldb     #'>'                                                    ; special parameter
F357 D7FA                                     stb     <valPar                                         ; save it
F359 86C0                                     lda     #$c0                                                    ; command to send
F35B 97FB                                     sta     <cmdNum                                         ; save it
F35D CC0100                                   ldd     #$0100                                          ; mark 1 byte with value equal null
F360 FD01D1                                   std     nambuf                                          ; put in nambuf area (no name)
F363 BDEDE0                                   jsr     putCmd2                                         ; send command
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
F366 8E0800                                   ldx     #$0800                                          ; point to buffer beginning
F369 5F                                       clrb                                                                    ; counter to zero
F36A A684             shwRD01 lda     ,x                                                              ; get first char (1st name character)
F36C 2709                                     beq     shwRD02                                         ; if zero, no more items
F36E 5C                                       incb                                                                    ; increment received items counter
F36F 308810                                   leax    16,x                                                    ; point to next item
F372 8C0900                                   cmpx    #$0900                                          ; got to end of buffer?
F375 25F3                                     blo     shwRD01                                         ; no, loopback
F377 5D               shwRD02 tstb                                                                    ; have we read any item?
F378 2762                                     beq     shwRD09                                         ; no, print ok and exit
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
F37A D7FA                                     stb     <itsRead                                                ; save number of items we received
F37C CE0800                                   ldu     #$0800                                          ; point to beginning of received data
F37F DFF8                                     stu     <cpyPtr                                         ; save it
F381 0FFB                                     clr     <itsDone                                                ; for each item (clear counter)
F383 0CFB             shwRD03 inc     <itsDone                                                ; add 1 to counter
F385 17FE1F                                   lbsr    shwFd01                                         ; show item name and type
F388 30C4                                     leax    ,u                                                              ; point to msb highest byte of item length (not used)
F38A EE84                                     ldu     ,x                                                              ; get 2 next bytes (Mike Miller)
F38C EC02                                     ldd     2,x                                                     ; get lowest byte (Mike Miller)
F38E 17FDBD                                   lbsr    shwNum                                          ; show item Length (U:A)
F391 9EF8                                     ldx     <cpyPtr                                         ; get beginning of this record
F393 308810                                   leax    16,x                                                    ; point to next one
F396 9FF8                                     stx     <cpyPtr                                         ; update pointer
F398 D6FA                                     ldb     <itsRead                                                ; get number of items read
F39A C110                                     cmpb    #16                                                     ; was 16?                                                               
F39C 262C                                     bne     shwRD07                                         ; NO, so partial page. Send CR and go for next one
F39E 96FB                                     lda     <itsDone                                                ; YES, it was a full page. Get item number just printed
F3A0 810F                                     cmpa    #15                                                     ; was penultimate row?
F3A2 2608                                     bne     shwRD04                                         ; no, see if it was the last one
F3A4 8EE4E3                                   ldx     #msgCont-1                                      ; yes point to message CONT
F3A7 BD90E5                                   jsr     outstr                                          ; show message                  
F3AA 201E                                     bra     shwRD07                                         ; and send CR and go for next item      
F3AC 8110             shwRD04 cmpa    #16                                                     ; is the last one?
F3AE 261A                                     bne     shwRD07                                         ; no, send CR and go for next item
F3B0 8EE4EA                                   ldx     #msgExit-1                                      ; yes, point to message EXIT
F3B3 BD90E5                                   jsr     outstr                                          ; show message                  
F3B6 BD8006           shwRD05 jsr     $8006                                                   ; wait for user keypress
F3B9 27FB                                     beq     shwRD05                                         ; none, loopback
F3BB 8143                                     cmpa    #$43                                                    ; is 'C' for Continue?
F3BD 2605                                     bne     shwRD06                                         ; no, verify if is 'E'
F3BF BD90A5                                   jsr     sendCR                                          ; send a CR (will scroll 1 line up)
F3C2 208E                                     bra   shwRD00                                           ; BREAK, ask for a new page to the SDC
F3C4 8145             shwRD06 cmpa    #$45                                                    ; is 'E' for eXIT?
F3C6 26EE                                     bne     shwRD05                                         ; no, loopback and wait for a correct key
F3C8 200D                                     bra     shwRD08                                         ; yes, send CR, show OK and exit
F3CA BD90A5           shwRD07 jsr     sendCR                                          ; send CR
F3CD 96FB                                     lda     <itsDone                                                ; get number of items shown
F3CF 91FA                                     cmpa    <itsRead                                                ; work done?
F3D1 2709                                     beq     shwRD09                                         ; yes, send OK and exit
F3D3 DEF8                                     ldu     <cpyPtr                                         ; no, get saved buffer pointer
F3D5 20AC                                     bra     shwRD03                                         ; loopback for next item
F3D7 860D             shwRD08 lda     #$0d                                                    ; get enter value
F3D9 BDB54A                                   jsr     outchr                                          ; print it
F3DC 17FCB7           shwRD09 lbsr    exsdrv                                          ; restore slot if needed
F3DF 39                                       rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show name of current dir
F3E0 9D9F             shwCDir jsr     <getNChr                                                ; skip token
F3E2 8601                                     lda     #1                                                              ; put value 1
F3E4 97F9                                     sta     <numDir                                         ; as first level requested
F3E6 17FE57                                   lbsr    other01                                         ; put some parameters
F3E9 86C0                                     lda     #$c0                                                    ; command to be sent
F3EB 97FB                                     sta     <cmdNum                                         ; save it
F3ED C643                                     ldb     #'C'                                                    ; param for b
F3EF D7FA                                     stb     <valPar                                         ; save it
F3F1 CC0100                                   ldd     #$0100                                          ; get 1 byte with value equal null
F3F4 FD01D1                                   std     nambuf                                          ; put in nambuf area (no name)
F3F7 BDEDE0                                   jsr     putCmd2                                         ; send command
F3FA 2503                                     bcs     eshwCDir                                                ; if error, don't show garbage
F3FC 17FDA5                                   lbsr    shwFdat                                         ; show dirname and type
F3FF 16FC94           eshwCDir        lbra    exsdrv                                          ; restore slot if needed
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show contents of root dir
F402 9D9F             shwRoot jsr     <getNChr                                                ; skip token
F404 8601                                     lda     #$01                                                    ; only one char in nambuf
F406 C62F                                     ldb     #'/'                                                    ; char to design root directory
F408 FD01D1           shwRt01 std     nambuf                                          ; put data in input buffer area
F40B 17FE32                                   lbsr    other01                                         ; set parameters
F40E 16FF3B                                   lbra    shwEDir                                         ; go to process the requested directory
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show contents of current dir
F411 8601             shwCAct lda     #$01                                                    ; only one char in nambuf
F413 C62A                                     ldb     #'*'                                                    ; char to design current directory
F415 20F1                                     bra     shwRt01                                         ; complete data and process command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; set current dir to requested name
F417 9D9F             setCDir jsr     <getNChr                                                ; get next entered char
F419 17FE11           setCD01 lbsr    others                                          ; read filename, get params
F41C CC443A           setCD02 ldd     #"D:"                                                   ; command to send
F41F 16FE05                                   lbra    xsmk01                                          ; go send command
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; show actual dir full path
F422 9D9F             shwFull jsr     <getNChr                                                ; skip token
F424 327E                                     leas    -2,s                                                    ; create a 3 bytes hole for variables
F426 0FF9                                     clr     numDir                                          ; set items received to 0
F428 8E0900                                   ldx     #$0900                                          ; get 2nd dos buffer address
F42B AFE4                                     stx     destPtr,s                                       ; to receive results
F42D 17FE10           shwF01  lbsr    other01                                         ; put some parameters
F430 86C0                                     lda     #$c0                                                    ; command to be sent
F432 97FB                                     sta     <cmdNum                                         ; save it
F434 C643                                     ldb     #'C'                                                    ; param for b
F436 D7FA                                     stb     <valPar                                         ; save it
F438 CC0100                                   ldd     #$0100                                          ; get 1 byte with value equal null
F43B FD01D1                                   std     nambuf                                          ; put in nambuf area (no name)
F43E 0CF9                                     inc     numDir                                          ; increment received items counter
F440 BDEDE0                                   jsr     putCmd2                                         ; send command to get actual directory
                                                                                                                      ; processing single answer
F443 253D                                     bcs     shwF80                                          ; if error (got to root) skip section  
                                                                                                                      ; save received data to $900 buffer
F445 8E0800                                   ldx     #$800                                                   ; point to beginning of received data
F448 EEE4                                     ldu     destPtr,s                                       ; point ot destination record
F44A C608                                     ldb     #8                                                              ; max name length 
F44C A680             shwF02  lda     ,x+                                                     ; get a received char
F44E 8120                                     cmpa    #$20                                                    ; is it space
F450 2705                                     beq     shwF03                                          ; yes, stop copying name
F452 A7C0                                     sta     ,u+                                                     ; pass char to record
F454 5A                                       decb                                                                    ; decrement counter
F455 26F5                                     bne     shwF02                                          ; if not zero, loopback
F457 E680             shwF03  ldb     ,x+                                                     ; get 1st termination char
F459 C120                                     cmpb    #$20                                                    ; is it a space?
F45B 2714                                     beq     shwF04                                          ; yes, goto next dir element
F45D 862E                                     lda     #'.'                                                    ; get dot char
F45F EDC1                                     std     ,u++                                                    ; add dot and 1st ext char
F461 A680                                     lda     ,x+                                                     ; get 2nd extension char
F463 8120                                     cmpa    #$20                                                    ; is it a space?
F465 270A                                     beq     shwF04                                          ; yes, goto next dir element
F467 A7C0                                     sta     ,u+                                                     ; add 2nd extension char
F469 A680                                     lda     ,x+                                                     ; get 3rd extension char
F46B 8120                                     cmpa    #$20                                                    ; is it a space?
F46D 2702                                     beq     shwF04                                          ; yes, skip next
F46F A7C0                                     sta     ,u+                                                     ; add 3rd extension char
F471 CC2F00           shwF04  ldd     #$2f00"                                         ; get a slash and zero terminator
F474 EDC4                                     std     ,u                                                              ; add to destination buffer
F476 EEE4                                     ldu     destPtr,s                                       ; get beginning just used
F478 33C810                                   leau    16,u                                                    ; add 16 to buffer pointer
F47B EFE4                                     stu     destPtr,s                                       ; update it for next path directory
F47D 17FE8A                                   lbsr    chwPD01                                         ; ask SDC to go to parent dir (SCHD"..")
F480 20AB                                     bra     shwF01                                          ; go back to ask for new actual directory
                                                                                                                      ; got to the root, NO MORE data to request. 
F482 96F9             shwF80  lda     <numDir                                         ; get number of received items
F484 8101                                     cmpa    #1                                                              ; only one item received?
F486 273E                                     beq     eshwFull                                                ; yes, it was ROOT, so exit
                                                                                                                      ; process received data to show full path
F488 CE01D2                                   ldu     #nambuf+1                                       ; destination for full path name (input buffer)
F48B 862F                                     lda     #$2f                                                    ; get a slash to denote root
F48D A7C0                                     sta     ,u+                                                     ; put into buffer as 1st char
                                                                                                                      ; add all the received dirs in reverse order
F48F AEE4                                     ldx     destPtr,s                                       ; get last record address (not used ... it was root)
F491 3010             shwF81  leax    -16,x                                                   ; point to previous used entry
F493 8C0900                                   cmpx    #$0900                                          ; gone back past the beginning?
F496 250E                                     bcs     shwF90                                          ; yes, end of putting items together
F498 3410                                     pshs    x                                                               ; save register
F49A A680             shwF82  lda     ,x+                                                     ; get a char from origin
F49C 2704                                     beq     shwF83                                          ; if null, end of string
F49E A7C0                                     sta     ,u+                                                     ; else put at destination
F4A0 20F8                                     bra     shwF82                                          ; go get next char
F4A2 3510             shwF83  puls    x                                                               ; restore pointer
F4A4 20EB                                     bra     shwF81                                          ; back to get next directory
F4A6 6FC4             shwF90  clr     ,u                                                              ; mark end of string
F4A8 1F30                                     tfr     u,d                                                     ; send poiter to D
F4AA 8301D2                                   subd    #nambuf+1                                       ; to calculate length of string
F4AD F701D1                                   stb     nambuf                                          ; save it
F4B0 8E01D1                                   ldx     #nambuf                                         ; point to whole path name
F4B3 BD90E5                                   jsr     outstr                                          ; show the full mounted directory path
F4B6 860D                                     lda     #$0d                                                    ; code for Enter
F4B8 BDB54A                                   jsr     outchr                                          ; print it
                                                                                                                      ; issue a SCHD"" with the whole path to restore situation!!
F4BB 3262                                     leas    2,s                                                     ; clean stack
F4BD 17FD80                                   lbsr    other01                                         ; set some parameters
F4C0 CC443A                                   ldd     #"D:"                                                   ; command to send       
F4C3 16FD61                                   lbra    xsmk01                                          ; go back to the actual directory we had before
F4C6 3262             eshwFull        leas    2,s                                                     ; clean stack
F4C8 16FBCB                                   lbra    exsdrv                                          ; exit
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; process for command WRITE MEM @bank, start, destination, length
                      ; this code is made based on the FLASHER.BIN program by Darren Atkinson
                      ; -------------------------------------------------------------------------------------------------------------------------------
F4CB 9D9F             xwrite  jsr     <getNChr                                                ; get next char
F4CD 819B                                     cmpa    #$9b                                                    ; is the token for MEM?
F4CF 1026F2B8                                 lbne    snError                                         ; no, show error message
F4D3 9D9F                                     jsr     <getNChr                                                ; get next byte
F4D5 8140                                     cmpa    #64                                                     ; is it sign '@'?
F4D7 1026F2B0                                 lbne    snError                                         ; no, show error message
F4DB 9D9F                                     jsr     <getNChr                                                ; get number into A
F4DD 8130                                     cmpa    #$30                                                    ; is greater or equal 0?
F4DF 2504                                     bcs     xwrt01                                          ; no, show error
F4E1 8137                                     cmpa    #$37                                                    ; is less or equal 7?
F4E3 2305                                     bls     xwrt02                                          ; yes, goto next parameters
F4E5 C611             xwrt01  ldb     #$11                                                    ; SD error
F4E7 7E8344                                   jmp     syserr                                          ; bas_system_error
F4EA 8407             xwrt02  anda    #$07                                                    ; use only valid bits
F4EC 97EB                                     sta     <DCDRV                                          ; save requested bank number
F4EE 9D9F                                     jsr     <getNChr                                                ; advance one char
F4F0 260F                                     bne     morParms                                                ; if more chars, read them
                                                                                                                      ; default parameters for writting a ROMPACK
F4F2 8E3000                                   ldx     #$3000                                          ; get origin of data
F4F5 9F76                                     stx     <dSource                                                ; save start into variable
F4F7 8EC000                                   ldx     #$c000                                          ; get destination in bank
F4FA 9FFA                                     stx     <dDest                                          ; save destination into variable
F4FC 8E3F00                                   ldx     #$3f00                                          ; get max. length (16k-256bytes)
F4FF 203F                                     bra     savLen                                          ; skip section
F501 BD89AA           morParms        jsr     ckComma                                         ; CkComma
F504 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into X
F507 8C7FFF                                   cmpx    #basini-1                                       ; is it on the upper 32k?
F50A 226C                                     bhi     badParam                                                ; yes, bad format number, show error
F50C 9F76                                     stx     <dSource                                                ; save start into variable
F50E 9DA5                                     jsr     <redLChr                                                ; advance one char
F510 BD89AA                                   jsr     ckComma                                         ; CkComma
F513 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into X
F516 8CC000                                   cmpx    #romini                                         ; is it out of SDC-ROM area?
F519 255D                                     blo     badParam                                                ; yes, bad format number, show error
F51B 8CF000                                   cmpx    #$f000                                          ; is it higher than the beginning of 4th sector?
F51E 2258                                     bhi     badParam                                                ; yes, bad format number, show error
F520 9FFA                                     stx     <dDest                                          ; save destination into variable
F522 9DA5                                     jsr     <redLChr                                                ; advance one char
F524 BD89AA                                   jsr     ckComma                                         ; CkComma
F527 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into X
F52A 1F10                                     tfr     x,d                                                     ; pass value to D
F52C D3FA                                     addd    <dDest                                          ; add destination value
F52E 2548                                     bcs     badParam                                                ; yes, sum exceeds flash capacity
F530 1083FF00                                 cmpd    #$ff00                                          ; uses result the reserved 256 bytes?
F534 2242                                     bhi     badParam                                                ; yes, bad format number, show error
F536 1F10                                     tfr     x,d                                                     ; get length again
F538 D376                                     addd    <dSource                                                ; add source beginning
F53A 10837FFF                                 cmpd    #basini-1                                       ; exceeds RAM area?
F53E 2238                                     bhi     badParam                                                ; yes, bad format number, show error
F540 9F50             savLen  stx     <FPA0                                                   ; save byte count
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; search slot where SDC is
F542 17F6C8                                   lbsr    tstSDC                                          ; is SDC already active?
F545 271A                                     beq     xwrt03                                          ; yes, save slot number (if no MPI this will be $00)
F547 B60114                                   lda     floSDC                                          ; no, get hdw control byte
F54A 8508                                     bita    #%00001000                                      ; is a SDC in the system?
F54C 1027F5ED                                 lbeq    NotSDCPresent                           ; no, show message
                                                                                                                      ; yes, calculate occupied slot
F550 B60114                                   lda     floSDC                                          ; get hdw control byte
F553 84C0                                     anda    #%11000000                                      ; use bits 7-6 (slot where SDC is)
F555 44                                       lsra                                                                    ; move them to
F556 44                                       lsra                                                                    ; bits 5-4 (lower bits of high nibble)
F557 3402                                     pshs    a                                                               ; save high nibble
F559 44                                       lsra                                                                    ; low nibble   
F55A 44                                       lsra                                                                    ; gets high nibble
F55B 44                                       lsra                                                                    ; that will end  
F55C 44                                       lsra                                                                    ; as zero
F55D AAE0                                     ora     ,s+                                                     ; add high nibble (now they are the same value)
F55F 2003                                     bra     xwrt04                                          ; save slot number
F561 B603FF           xwrt03  lda     cpyMPIcfg                                       ; get active slot number
F564 97F9             xwrt04  sta     <sdcSlot                                                ; save slot where SDC is
                                                                                                                      ; copy the flasher routine to $1da. Should not exceed $2d2
F566 8EF587           cpyFlsh ldx     #xflash                                         ; point to beginning of program to be copied
F569 CE01DA                                   ldu     #$1da                                                   ; point to destination
F56C EC81             cpyFl01 ldd     ,x++                                                    ; get a word
F56E EDC1                                     std     ,u++                                                    ; put at destination
F570 8CF695                                   cmpx    #erasEnd+2                                      ; got to end of program?
F573 25F7                                     blo     cpyFl01                                         ; no, loopback
F575 7E01DA                                   jmp     $1da                                                    ; execute copied program in low RAM
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
F578 8EE4F1           badParam        ldx     #wrongPar-1                                     ; point to message
F57B BD90E5                                   jsr     outstr                                          ; show it
F57E 9DA5                                     jsr     <redLChr                                                ; read last char
F580 2704                                     beq     ebadPrm                                         ; if null, exit
F582 9D9F             bP001           jsr     <getNChr                                                ; skip an unused byte
F584 26FC                                     bne     bP001                                                   ; if not null, loopback
F586 39               ebadPrm rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; This code manages the process of flashing a bank
                      ; -------------------------------------------------------------------------------------------------------------------------------
F587 1A50             xflash  orcc  #$50                    ; mask interrupts
F589 96F9                      lda    <sdcSlot                                                ; get the slot where SDC is
                                                                                                                      ; this is to avoid starting the just flashed bank!
F58B F603FF                    ldb    cpyMPIcfg                                       ; get current active slot
F58E D7F9                                     stb     <sdcSlot                                                ; save it to go back to it at the end
F590 B703FF                                   sta     cpyMPIcfg                                       ; update copy
F593 B7FF7F                                   sta     MPIcfg                                          ; switch to the SDC slot
F596 B7FFD8                              sta   R1CLR                   ; normal speed for CoCo 3 (0,89MHz) - $ffd8 (resets $ffd7)
F599 B7FFDE                    sta   RAMROM                  ; activate RAM/ROM map mode = MAP0 - resets $ffdf
F59C D6EB                      ldb   <DCDRV                  ; get target bank number (parameter at $eb)
F59E 8D1B                      bsr   FlashKill               ; erase target bank
F5A0 308C60                    leax  burner,pcr                   ; point X at burner subroutine
F5A3 9FEE                      stx   <DCBPT                  ; store subroutine address: $ee
F5A5 9E76                                     ldx     <dSource                                                ; point X at source data
F5A7 DEFA                                     ldu     <dDest                  ; point U at flash destination
F5A9 8D45                      bsr   callX                   ; write data to the flash
F5AB D6F9                      ldb    <sdcSlot                                                ; get original active slot
F5AD F703FF                    stb    cpyMPIcfg                                       ; update copy
F5B0 F7FF7F                    stb    MPIcfg                                          ; set it again
F5B3 0F71                      clr   <$71                    ; force a cold boot
F5B5 1A50                      orcc  #$50                    ; mask interrupts
F5B7 6E9FFFFE                  jmp   [$fffe]                 ; execute the system reset routine
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ;  Erase flash bank specified in ACCB
                      ; -------------------------------------------------------------------------------------------------------------------------------
F5BB                  FlashKill 
F5BB D786                                     stb   <TargBank               ; store bank number: $86
F5BD 9650                                     lda     <FPA0                                                   ; get byte count                                                                                                                                                        ; 2B - 20
F5BF 84F0                                     anda    #$f0                                                    ; use only high nibble                                                                                                                                  ; 20 - 20
F5C1 3402                                     pshs    a                                                               ; push value (number of sectors of 4K)                                                                                          ; 20 - 20
F5C3 DC50                                     ldd     <FPA0                                                   ; get full byte count                                                                                                                                   ; 2B00 - 2000
F5C5 840F                                     anda    #$0f                                                    ; mask high nibble of high byte                                                                                                         ; 0B00 - 0000
F5C7 10830000                                 cmpd    #$0000                                          ; is masked D equal 0?                                                                                                                                  ; NO   - YES
F5CB 2706                                     beq     flK01                                                   ; yes, don't correct values                                                                                                                     ; corr - jump
F5CD 8610                                     lda     #$10                                                    ; add one sector (x16)
F5CF ABE4                                     adda    ,s                                                              ; to pushed value                                                                                                                                                       ; 30
F5D1 A7E4                                     sta     ,s                                                              ; update it in the stack                                                                                                                                ; 30
F5D3 3502             flK01           puls    a                                                               ; get number of sectors to kill (x16 'cause in high nibble)                                     ; 30 - 20
F5D5 8140                                     cmpa    #$40                                                    ; number of sectors greater than 4?
F5D7 2302                                     bls     flK02                                                   ; no, go on
F5D9 8640                                     lda     #$40                                                    ; yes, limit to 4
F5DB 1F89             flK02           tfr     a,b                                                     ; copy to B                                                                                                                                                                     ; 30 - 20
F5DD 54                                       lsrb                                                                    ; move
F5DE 54                                       lsrb                                                                    ; 4 times to
F5DF 54                                       lsrb                                                                    ; the right to
F5E0 54                                       lsrb                                                                    ; divide by 16 to get the actual number of sectors      to kill                                 ; 03 - 02
F5E1 96FA                                     lda     <dDest                                          ; get destination ini high byte                                                                                                         ; D3 - C0       ($D300 - $C000)
F5E3 84F0                                     anda    #$f0                                                    ; use high nibble                                                                                                                                                       ; D0 - C0
                                                                                                                      ; now D should contain: 
                                                                                                                      ;     A = High byte of address of 1st sector to kill ($C0-$D0-$E0-$F0)
                                                                                                                      ;     B = number of sectors to be killed
                                                                                                                      ; save parameter for later use
F5E5 9752                      sta   <FPA0+2                 ; store MSB of default sector address: $52
F5E7 D703                      stb   <ErasCtr                ; store sector count: $03
F5E9 0F53                      clr   <FPA0+3                 ; clear LSB of sector address: $53
F5EB 308C65                    leax  eraser,pcr              ; point X at erasure routine
F5EE 9FEE                      stx   <DCBPT                                           ; save it: $ee
F5F0 9686             callX    lda   <TargBank                        ; get current flash bank selection: $86
F5F2 8407                      anda  #$07                    ; mask out undefined bits
F5F4 3403                      pshs  a,cc                    ; save current bank and IRQ mask
F5F6 AD9F00EE                  jsr   [DCBPT]                 ; call utility routine: $ee -> eraser (routine)
F5FA B6FF22                    lda   $ff22                   ; read PIA data reg to clear any CART interrupt
F5FD 3503                      puls  cc,a                    ; restore old IRQ mask and pop saved bank number
F5FF 7FFF4A                    clr   FLSHREG                 ; clear the Flash byte register: $ff4a
F602 39                        rts                           ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Write Data to Flash
                      ; Entry:
                      ;   X = source data address
                      ;   U = destination flash address
                      ;   High word of FPA0 = byte count ($50)
                      ; -------------------------------------------------------------------------------------------------------------------------------
F603 DC50             burner   ldd   <FPA0                   ; D = byte count: $50
F605 31CB                      leay  d,u                     ; Y = destination end address
F607 109F52                    sty   <FPA0+2                 ; save end address in FPA0: $52
F60A 3184                      leay  ,x                      ; point Y at the source data
F60C 30C4                      leax  ,u                      ; point X at the destination
F60E 338C1F                    leau  burnPrfx,PCR            ; point U at the prefix data for Byte Program
F611 9686                      lda   <TargBank               ; get target bank number: $86
F613 B7FF4B                    sta   BANKREG                 ; activate target bank: ff4b
F616 8A80                      ora   #$80                    ; setup bank number combined with PGM Enable
F618 E6A0             burn010  ldb   ,y+                     ; get next data byte from source
F61A E184                      cmpb  ,x                      ; does flash already contain this value?
F61C 2604                      bne   burn020                 ; branch if needs to change
F61E 3001                      leax  1,x                     ; increment flash address
F620 2008                      bra   burn030                 ; skip ahead to end of loop
F622 3456             burn020  pshs  u,x,b,a                 ; save registers
F624 8D17                      bsr   flshPrefx               ; send the unlock sequence
F626 3556                      puls  a,b,x,u                 ; restore target bank and destination address
F628 8D20                      bsr   flshWrCyc               ; write the byte to the Flash destination
F62A 9C52             burn030  cmpx  <FPA0+2                 ; have we reached the final address: $52
F62C 25EA                      blo   burn010                 ; loop if more
F62E 2016                      bra   flshDone                ; restore original bank selection and return
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; - - -  Prefix Data for Byte-Program  - - -
F630 81AA             burnPrfx fdb   $81aa                   ; Bank = 1, Data = $AA...
F632 D555                      fdb   $d555                   ; ...Address = $D555 ($5555)
F634 8055                      fdb   $8055                   ; Bank 0, Data = $55...
F636 EAAA                      fdb   $eaaa                   ; ...Address = $EAAA ($2AAA)
F638 81A0                      fdb   $81a0                   ; Bank 1, Data = $A0...
F63A D555                      fdb   $d555                   ; ...Address = $D555 ($5555)
F63C 00                        fcb   $0                                 ; end of sequence
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Send a Programming Prefix Sequence to the Flash.
                      ; Enter with U pointing to Prefix data.
                      ; -------------------------------------------------------------------------------------------------------------------------------
F63D                  flshPrefx
F63D 3716                                     pulu  a,b,x                   ; get next bank, data byte and address
F63F 4D                        tsta                          ; if reached end-of-sequence..
F640 2710                      beq   flshRts                 ; ..then return
F642 8D06                      bsr   flshWrCyc               ; write byte to flash
F644 20F7                      bra   flshPrefx               ; loop for next byte of sequence
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; Restores old flash bank and returns upon completion of Flash operation
F646 A663             flshDone lda   3,s                     ; get orignal bank number from stack
F648 847F                      anda  #$7f                    ; make sure the PGM Enable bit is cleared
                                                                                                                      ;  *** Fall Thru ***
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                      ; Perform a Write Cycle to the Flash.
                      ; Enter with Address in X, Bank+PGM Enable in ACCA and the data byte in ACCB.
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
F64A                  flshWrCyc
F64A B7FF4B                                   sta   BANKREG                 ; select Flash bank / PGM Enable: $ff4b
F64D F7FF4A                    stb   FLSHREG                 ; store data byte in Flash register: $ff4a
F650 E580                      bitb  ,x+                     ; perform Flash Write by reading target address
F652 39               flshRts  rts                           ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; Erase Flash Sector
                      ; -------------------------------------------------------------------------------------------------------------------------------
F653 338C27           eraser   leau  erasPrfx,PCR            ; point U to the prefix data for Sector Erase
F656 8DE5                      bsr   flshPrefx               ; write the prefix bytes
F658 CC8030                    ldd   #$8030                  ; ACCA = PGM Enable;  ACCB = final prefix byte
F65B 9A86                      ora   <TargBank               ; combine target bank number with PGM Enable: $86
F65D 9E52                      ldx   <FPA0+2                 ; X = sector address: $52 ($C0xx)
F65F 8DE9                      bsr   flshWrCyc               ; write final prefix byte at sector address
F661 8407                      anda  #$07                    ; turn off the..
F663 B7FF4B                    sta   BANKREG                 ; ..PGM Enable bit: $ff4b
F666 4F                        clra                          ; clear ACCD for use..
F667 5F                        clrb                          ; ..as timeout counter
F668 6D1F             eras025  tst   -1,x                    ; poll the sector address: $C0xx-1
F66A 2B05                      bmi   eras030                 ; branch if bit 7 is set (erasure complete)
F66C 830001                    subd  #1                      ; decrement timeout counter
F66F 26F7                      bne   eras025                 ; loop if not yet timed out
F671 30890FFF         eras030  leax  $0fff,x                 ; increment X to point at the next sector
F675 9F52                      stx   <FPA0+2                 ; save sector address in FPA0: $52 ($D0xx)
F677 0A03                      dec   <ErasCtr                ; decrement erase sector counter: $03
F679 26D8                      bne   eraser                  ; loop if erasing another sector
F67B 20C9                      bra   flshDone                ; restore original bank selection and return
                      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                                                                                                      ; - - -  Programming Prefix for Sector Erase  - - -
F67D 81AA             erasPrfx fdb   $81aa                   ; Bank = 1, Data = $AA...
F67F D555                      fdb   $d555                   ; ...Address = $D555 ($5555)
F681 8055                      fdb   $8055                   ; Bank 0, Data = $55...
F683 EAAA                      fdb   $eaaa                   ; ...Address = $EAAA ($2AAA)
F685 8180                      fdb   $8180                   ; Bank 1, Data = $80...
F687 D555                      fdb   $d555                   ; ...Address = $D555 ($5555)
F689 81AA                      fdb   $81aa                   ; Bank = 1, Data = $AA...
F68B D555                      fdb   $d555                   ; ...Address = $D555 ($5555)
F68D 8055                      fdb   $8055                   ; Bank 0, Data = $55...
F68F EAAA                      fdb   $eaaa                   ; ...Address = $EAAA ($2AAA)
F691 0000                      fdb   $0000                   ; end of sequence
F693 0000             erasEnd  fdb   $0000                                                    ; ...a record is 4 bytes long ...
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; process for command SCOPY MEM @number   ,&HC000,&H4000,&H3F00
                      ; or alternate        SCOPY MEM SLOTnumber,&HC000,&H4000,&H3F00
                      ; -------------------------------------------------------------------------------------------------------------------------------
F695 9D9F             xscopy  jsr     <getNChr                                                ; get next char
F697 819B                                     cmpa    #$9b                                                    ; is the token for MEM?
F699 1026F0EE                                 lbne    snError                                         ; no, show error message
F69D 9D9F                                     jsr     <getNChr                                                ; get next byte
F69F 97F9                                     sta     <cpyWhat                                                ; save received command
F6A1 8140                                     cmpa    #64                                                     ; is it sign '@' for BANK?
F6A3 2717                                     beq     xsbnk01                                         ; yes, go get bank number
F6A5 81EF                                     cmpa    #$ef                                                    ; is the token for SLOT?
F6A7 1026F0E0                                 lbne    snError                                         ; no, show error
                                                                                                                      ; processing slot command
F6AB 9D9F                                     jsr     <getNChr                                                ; get number into A
F6AD 8131                                     cmpa    #$31                                                    ; is greater or equal 1?
F6AF 2507                                     bcs     xscerr1                                         ; no, show error
F6B1 8134                                     cmpa    #$34                                                    ; is less or equal 4?
F6B3 2203                                     bhi   xscerr1                                           ; no, show error 
F6B5 4A                                       deca                                                                    ; internally MUST work with 0-1-2-3
F6B6 2013                                     bra     xsParam                                         ; yes, goto next parameters
F6B8 C60D             xscerr1 ldb     #$0d                                                    ; MU error
F6BA 200C                                     bra     xscerr0                                         ; goto bas_system_error
                                                                                                                      ; processing bank command
F6BC 9D9F             xsbnk01 jsr     <getNChr                                                ; get number into A
F6BE 8130                                     cmpa    #$30                                                    ; is greater or equal 0?
F6C0 2504                                     bcs     xscerr2                                         ; no, show error
F6C2 8137                                     cmpa    #$37                                                    ; is less or equal 7?
F6C4 2305                                     bls     xsParam                                         ; yes, goto next parameters
F6C6 C611             xscerr2         ldb     #$11                                                    ; SD error
F6C8 7E8344           xscerr0 jmp     syserr                                          ; bas_system_error
                                                                                                                      ; look for more parameters
F6CB 8030             xsParam suba    #$30                                                    ; convert ASCII to integer (0-3 or 0-7)
F6CD 97F8                                     sta     <oriNum                                                 ; save requested bank/slot number
F6CF 9D9F                                     jsr     <getNChr                                                ; advance one char
F6D1 260F                                     bne     otherPar                                                ; if more chars, read them
                                                                                                                      ; default parameters for writting a ROMPACK
F6D3 8EC000                                   ldx     #$c000                                          ; get origin of data
F6D6 9F76                                     stx     <dSource                                                ; save start into variable
F6D8 8E3000                                   ldx     #$3000                                          ; get destination in bank
F6DB 9FFA                                     stx     <dDest                                          ; save destination into variable
F6DD 8E3F00                                   ldx     #$3f00                                          ; get max. length (16k-256bytes)
F6E0 2028                                     bra     storeLen                                                ; skip section                  
F6E2 BD89AA           otherPar        jsr     ckComma                                         ; CkComma
F6E5 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into X
F6E8 8CC000                                   cmpx    #romini                                         ; is it on the upper 32k?
F6EB 1025FE89                                 lblo    badParam                                                ; no, bad format number, show error
F6EF 9F76                                     stx     <dSource                                                ; save start into variable
F6F1 9DA5                                     jsr     <redLChr                                                ; advance one char
F6F3 BD89AA                                   jsr     ckComma                                         ; CkComma
F6F6 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into X
F6F9 8C4000                                   cmpx    #$4000                                          ; is it leaving space for a 16k ROM?
F6FC 1022FE78                                 lbhi    badParam                                                ; yes, bad format number, show error
F700 9FFA                                     stx     <dDest                                          ; save destination into variable
F702 9DA5                                     jsr     <redLChr                                                ; advance one char
F704 BD89AA                                   jsr     ckComma                                         ; CkComma
F707 BD8E83                                   jsr     get16bN                                         ; get a 16 bit number into X
F70A 1F10             storeLen        tfr     x,d                                                     ; pass value to D
F70C D3FA                                     addd    <dDest                                          ; add destination value to calculate end value
F70E 10837FFF                                 cmpd    #basini-1                                       ; does result exceed the RAM area?
F712 1022FE62                                 lbhi    badParam                                                ; yes, bad format number, show error
F716 DD50                                     std     <FPA0                                                   ; save last byte to be written
F718 1F10                                     tfr     x,d                                                     ; get byte count again
F71A D376                                     addd    <dSource                                                ; add first one to copy
F71C 1025FE58                                 lbcs    badParam                                                ; if carry it goes past $FFFF, show message
                                                                                                                      ; stack control
F720 DC50                                     ldd     <FPA0                                                   ; get last byte to write
F722 C30032                                   addd    #50                                                     ; 50 security bytes (stack depth)
F725 109321                                   cmpd    <$21                                                    ; is last calculated address lower than stack pointer?
F728 250D                                     blo     stkOK                                                   ; yes, so it's sure to continue
F72A DCFA                                     ldd     <dDest                                          ; get first destination byte in RAM
F72C 109323                                   cmpd    <$23                                                    ; is higher than strings beginning area?
F72F 2206                                     bhi     stkOK                                                   ; yes, so it's sure to continue
F731 8EE50A                                   ldx     #stackPrb-1                                     ; point to message
F734 7E90E5                                   jmp     outstr                                          ; show it
                                                                                                                      ; HDW verification
F737 96F9             stkOK           lda     cpyWhat                                         ; get kind of origin to copy
F739 81EF                                     cmpa    #$ef                                                    ; is SLOT requested?
F73B 2609                                     bne     seeBank                                         ; no, go to bank control
F73D 17F4A9                                   lbsr    tstMPI                                          ; yes, is there an active MPI?
F740 270D                                     beq     xsProces                                                ; yes go on     
F742 17F3F4                                   lbsr    NotMPIPresent                           ; no, show message
F745 39                                       rts                                                                     ; return
F746 B60114           seeBank lda     floSDC                                          ; get hdw control byte
F749 8508                                     bita    #%00001000                                      ; is there an SDC?
F74B 1027F3EE                                 lbeq    NotSDCPresent                           ; no, show error
                                                                                                                      ; section to copy the code to be executed into $1da
F74F 8EF762           xsProces        ldx     #xsMovCod                                       ; point to origin of code
F752 CE01DA                                   ldu     #$1da                                                   ; point to destination
F755 EC81             xsMov01 ldd     ,x++                                                    ; get a word
F757 EDC1                                     std     ,u++                                                    ; put at destination
F759 8CF7FF                                   cmpx    #xsLoEnd+1                                      ; got to the end?
F75C 25F7                                     blo     xsMov01                                         ; no, loopback
F75E BD01DA                                   jsr     $1da                                                    ; call code at $1da
F761 39                                       rts                                                                     ; return
                                                                                                                      ; code to be executed
F762 1A50             xsMovCod        orcc    #dimask                                         ; disable interrupts
F764 4F                                       clra                                                                    ; $00 is code for NO old value
F765 9752                                     sta     oldSlot                                         ; for old slot
F767 4A                                       deca                                                                    ; $ff is code for NO old value
F768 9753                                     sta     oldBank                                         ; for old bank
F76A 96F9                                     lda     <cpyWhat                                                ; get kind of element to copy
F76C 8140                                     cmpa    #64                                                     ; was command a copy BANK?
F76E 271D                                     beq     xsCopBnk                                                ; yes, go there
                                                                                                                      ; change to the requested slot if not already there and save old slot
F770 B603FF                                   lda     cpyMPIcfg                                       ; get active slot number
F773 9752                                     sta     <oldSlot                                                ; save it
F775 8403                                     anda    #3                                                              ; to have just the number
F777 91F8                                     cmpa    <oriNum                                         ; is the requested one?
F779 2742                                     beq     startCpy                                                ; yes, go start the copy
F77B D6F8                                     ldb     <oriNum                                         ; get requested slot number
F77D 3404                                     pshs    b                                                               ; save it
F77F 58                                       lslb                                                                    ; move to
F780 58                                       lslb                                                                    ; the high
F781 58                                       lslb                                                                    ; nibble
F782 58                                       lslb                                                                    ; so 
F783 EAE0                                     orb     ,s+                                                     ; now both are equal
F785 F703FF                                   stb     cpyMPIcfg                                       ; update copy
F788 F7FF7F                                   stb     MPIcfg                                          ; change of slot
F78B 2030                                     bra     startCpy                                                ; done, go start the copy
F78D B60114           xsCopBnk        lda     floSDC                                          ; get hdw control byte
F790 84C0                                     anda    #%11000000                                      ; use bits 7-6 (slot where SDC is)
F792 44                                       lsra                                                                    ; move them to
F793 44                                       lsra                                                                    ; bits 5-4 (lower bits of high nibble)
F794 3402                                     pshs    a                                                               ; save high nibble
F796 44                                       lsra                                                                    ; low nibble   
F797 44                                       lsra                                                                    ; gets high nibble
F798 44                                       lsra                                                                    ; that will end  
F799 44                                       lsra                                                                    ; as zero
F79A AAE0                                     ora     ,s+                                                     ; add high nibble (now they are the same value)
F79C B103FF                                   cmpa    cpyMPIcfg                                       ; is this slot active right now?
F79F 270B                                     beq     cmpBank                                         ; yes, go see if bank differs
F7A1 F603FF                                   ldb     cpyMPIcfg                                       ; get actual slot
F7A4 B703FF                                   sta     cpyMPIcfg                                       ; update copy
F7A7 B7FF7F                                   sta     MPIcfg                                          ; change of slot
F7AA D752                                     stb     <oldSlot                                                ; save old slot
F7AC 96F8             cmpBank lda     <oriNum                                         ; compare requested bank with actually selected one 
F7AE B1FF4B                                   cmpa    $ff4b                                                   ; is active now?
F7B1 2708                                     beq   savBank                                           ; yes, save bank
F7B3 F6FF4B                                   ldb     $ff4b                                                   ; no, get active one
F7B6 B7FF4B                                   sta     $ff4b                                                   ; change to requested
F7B9 1F98                                     tfr     b,a                                                     ; pass B to A
F7BB 9753             savBank sta     <oldBank                                                ; save old bank number
F7BD 5F               startCpy        clrb                                                                    ; 0 = not in MAP1
F7BE B6C000                                   lda     romini                                          ; get value in $C000
F7C1 43                                       coma                                                                    ; reverse bits
F7C2 B7C000                                   sta     romini                                          ; update ram cell
F7C5 B1C000                                   cmpa    romini                                          ; retains the new value?
F7C8 2608                                     bne     noMap1                                          ; no, we are in MAP0
F7CA 43                                       coma                                                                    ; reverse again
F7CB B7C000                                   sta     romini                                          ; restore value
F7CE 5C                                       incb                                                                    ; 1 = we are in MAP1
F7CF B7FFDE                                   sta     $ffde                                                   ; switch to MAP0 to copy the requested ROM
F7D2 D7F8             noMap1  stb     <oriNum                                         ; re-use variable to save that value
F7D4 9E76                                     ldx     <dSource                                                ; point to source ROM
F7D6 DEFA                                     ldu     <dDest                                          ; point to destination RAM
F7D8 EC81             xsLoop01        ldd     ,x++                                                    ; get a word
F7DA EDC1                                     std     ,u++                                                    ; put at destination
F7DC 119350                                   cmpu    <FPA0                                                   ; got to the end?
F7DF 23F7                                     bls     xsLoop01                                                ; no, loopback
                                                                                                                      ; restore old bank-slot numbers and Map Type
F7E1 9652                                     lda     <oldSlot                                                ; get old slot
F7E3 2706                                     beq     getBank                                         ; if $00, do nothing
F7E5 B703FF                                   sta     cpyMPIcfg                                       ; update copy
F7E8 B7FF7F                                   sta     MPIcfg                                          ; change to old slot number
F7EB 9653             getBank lda     <oldBank                                                ; get old bank number
F7ED 2B03                                     bmi     exscopy                                         ; if $ff, do nothing
F7EF B7FF4B                                   sta     $ff4b                                                   ; switch to old bank number
F7F2 0DF8             exscopy tst     <oriNum                                         ; were we initially in MAP1?
F7F4 2703                                     beq     noMapChg                                                ; no, skip next
F7F6 B7FFDF                                   sta     $ffdf                                                   ; back to MAP1
F7F9 1CAF             noMapChg        andcc   #eimask                                         ; enable interrupts
F7FB 7FFF48                                   clr     $ff48                                                   ; to unsure no led stays lit on FDC
F7FE 39               xsLoEnd rts                                                                     ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; routine to verify the status returned by the SDC to a command
                      ;         Bit 7 ($80) set on any failure.
                      ;         Bit 5 ($20) set if target file is already in use.
                      ;         Bit 4 ($10) set if target file not found.
                      ;         Bit 3 ($08) set on miscellaneous hardware errors.
                      ;         Bit 2 ($04) set if path name is invalid.                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
F7FF                  vfyStatus
F7FF 242D                                     bcc     evfy                                                    ; if no error return
F801 5D                        tstb                                                                   ; update flags upon result status 
F802 2724                      beq    timeOutError                            ; if zero, timeout
F804 C520                      bitb   #$20                                                    ; detected file in use?
F806 2610                      bne    targetInUseError                        ; yes, message
F808 C510                      bitb   #$10                                                    ; was file not found?
F80A 2610                      bne    targetNotFoundError             ; no, message
F80C C508                                bitb         #$08                                                    ; was a hdw error?
F80E 2610                      bne    miscHardwareError                       ; yes, message
F810 C504                      bitb   #$04                                                    ; was invalid pathname?
F812 2610                      bne    pathNameInvalidError            ; yes, message
F814                  unknownError                                                                    ; this is for unknown errors. Should not get here!
F814 8EE570                                   ldx     #unknown-1                                      ; point to message
F817 10                        fcb    #$10                                                    ; skip next ldx 
F818                  targetInUseError                                                                ; 
F818 8EE524                    ldx    #targetInUse-1                          ; point to message
F81B 10                        fcb    #$10                                                    ; skip next ldx 
F81C                  targetNotFoundError                                                     ; 
F81C 8EE57F                    ldx    #targetNotFound-1                       ; point to message 
F81F 10                        fcb    #$10                                                    ; skip next ldx 
F820                  miscHardwareError                                                               ; 
F820 8EE55A                                   ldx     #miscHardware-1                 ; point to message 
F823 10                        fcb    #$10                                                    ; skip next ldx 
F824                  pathNameInvalidError                                                    ; 
F824 8EE548                                   ldx     #pathNameInvalid-1              ; point to message 
F827 10                        fcb    #$10                                                    ; skip next ldx 
F828                  timeOutError                                                                    ; 
F828 8EE51B                                   ldx     #timeout-1                                      ; point to message 
F82B 7E90E5           Exit            jmp   outstr                                            ; show message
F82E 39               evfy            rts                                                                     ; return
                      
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
F82F 3473             CommSDC  pshs  u,y,x,a,cc                               ; preserve resgisters
F831 64E4                      lsr   ,s                                       ; shift carry flag out of saved cc
                                                                                                                      ; put controller in command mode
F833 108EFF42                  ldy   #DATREGA                                 ; setup y for hardware addressing (ff42 - ff4a for coco)
F837 860B                      lda   #CMDMODE                                 ; the magic number
F839 A726                      sta   +6,y                                     ; was -10,y for coco - send to control latch (ff48 - ff40 for coco)
                                                                                                                      ; put input parameters into the hardware registers.
                                                                                                                      ; it does no harm to put random data in the
                                                                                                                      ; registers for commands which dont use them.
F83B E73F                      stb   -1,y                                     ; high byte to param reg 1 (ff41 - ff49 for coco)
F83D AFA4                      stx   ,y                                       ; low word to param regs 2 and 3 (ff42-ff43 - ff4a-ff4b for coco)
                                                                                                                      ; wait for not busy.
F83F 8D61                      bsr   waitForIt                           ; run polling loop
F841 2555                      bcs   cmdExit                             ; exit if error or timeout
                                                                                                                      ; send command to controller
F843 A661                      lda   1,s                                 ; get preserved command code from stack
F845 A73E                      sta   -2,y                                ; send to command register (ff40 - ff48 for coco)
                                                                                                                      ; determine if a data block needs to be sent.
                                                                                                                      ; any command which requires a data block will
                                                                                                                      ; have bit 5 set in the command code.
F847 8520                      bita  #$20                                     ; test the "send block" command bit
F849 272B                      beq   rxBlock                                  ; branch if no block to send
                                                                                                                              ; wait for ready to send
F84B 8D55                      bsr   waitForIt                           ; run polling loop
F84D 2549                      bcs   cmdExit                             ; exit if error or timeout
F84F 30C4                      leax  ,u                                  ; move data address to x
                                                                                                                              ; send 256 bytes of data
F851 CC2008                    ldd   #32*256+8                                ; 32 chunks of 8 bytes
F854 EE84             txChunk  ldu   ,x                                       ; send one chunk...
F856 EFA4                      stu   ,y                                                       ; ff42-ff43 - ff4a-ff4b for coco
F858 EE02                      ldu   2,x
F85A EFA4                      stu   ,y
F85C EE04                      ldu   4,x
F85E EFA4                      stu   ,y
F860 EE06                      ldu   6,x
F862 EFA4                      stu   ,y
F864 3A                        abx                                            ; point x at next chunk
F865 4A                        deca                                           ; decrement chunk counter
F866 26EC                      bne   txChunk                                  ; loop until all 256 bytes sent
                                                                                                                      ; wait for command completion
F868 8605                      lda   #5                                       ; timeout retries
F86A                  waitCmplt
F86A 8D36                                     bsr   waitForIt                                 ; run polling loop
F86C C501                      bitb  #BUSY                                    ; test busy bit
F86E 2728                      beq   cmdExit                                  ; exit if completed
F870 4A                        deca                                           ; decrement retry counter
F871 26F7                      bne   waitCmplt                                ; repeat until 0
F873 43                        coma                                           ; set carry for timeout error
F874 2022                      bra   cmdExit                                  ; exit
                                                                                                                      ; for commands which return a 256 byte response block the
                                                                                                                      ; controller will set the ready bit in the status register
                                                                                                                      ; when it has the data ready for transfer.   for commands
                                                                                                                      ; which do not return a response block the busy bit will
                                                                                                                      ; be cleared to indicate that the command has completed.
F876 8D26             rxBlock  bsr   longWait                                 ; run long status polling loop
F878 231E                      bls   cmdExit                                  ; exit if error, timeout or completed
F87A 3041                      leax  1,u                                      ; test the provided buffer address
F87C 271A                      beq   cmdExit                                  ; exit if "no buffer" ($ffff)
F87E 30C4                      leax  ,u                                       ; move data address to x
                                                                                                                      ; read 256 bytes of data
F880 CC2008                    ldd   #32*256+8                                ; 32 chunks of 8 bytes
F883 EEA4             rxChunk  ldu   ,y                                       ; read one chunk... (ff42-ff43 - ff4a-ff4b for coco)
F885 EF84                      stu   ,x
F887 EEA4                      ldu   ,y
F889 EF02                      stu   2,x
F88B EEA4                      ldu   ,y
F88D EF04                      stu   4,x
F88F EEA4                      ldu   ,y
F891 EF06                      stu   6,x
F893 3A                        abx                                            ; update x for next chunk
F894 4A                        deca                                           ; decrement chunk counter
F895 26EC                      bne   rxChunk                                  ; loop until all 256 bytes transferred
F897 5F                        clrb                                           ; status code for success, clear carry
                                                                                                                      ; exit
F898 69E4             cmdExit  rol   ,s                                       ; rotate carry into saved cc on stack
F89A 6F26                      clr   +6,y                                     ; was -10,y for coco - end command mode (ff48 - ff40 for coco)
F89C 35F3                      puls  cc,a,x,y,u,pc                            ; restore irq masks, update carry and return
                      
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
F89E 8D02             longWait bsr   waitForIt                                ; enter here for doubled timeout
F8A0 241B                      bcc   waitRet                                  ; return if cleared in 1st pass
F8A2                  waitForIt
F8A2 8E0000                                   ldx   #0                                        ; setup timeout counter
F8A5 53               waitLp   comb                                           ; set carry for assumed FAIL
F8A6 E63E                      ldb   -2,y                                     ; read status (FF40 - FF48 for CoCo)
F8A8 2B13                      bmi   waitRet                                  ; return if FAILED
F8AA 54                        lsrb                                           ; BUSY --> Carry
F8AB 240E                      bcc   waitDone                                 ; branch if not busy
F8AD C501                      bitb  #READY/2                                 ; test READY (shifted)
F8AF 260B                      bne   waitRdy                                  ; branch if ready for transfer
F8B1 8D0A                      bsr   waitRet                                  ; consume some time
F8B3 C681                      ldb   #$81                                     ; status = timeout
F8B5 3082                      leax  ,-x                                      ; decrement timeout counter
F8B7 2704                      beq   waitRet                                  ; return if timed out
F8B9 20EA                      bra   waitLp                                   ; try again
F8BB 5F               waitDone clrb                                           ; Not Busy: status = 0, set Z
F8BC 59               waitRdy  rolb                                           ; On Ready: clear C and Z
F8BD 39               waitRet  rts                                            ; return
                      
                      ; -------------------------------------------------------------------------------------------------------------------------------
                      ; DWLOAD implementation for patched Dragon 32 ROM (upper 8KB) 2014 Tormod Volden
                      ; -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                      ; Entry point from command line (DWLOAD or EXEC)
                                                                                                                      ; for later to see that we came from DWLOAD command
F8BE 0F11             dwload   clr   <bootflag                                        ; clear our autoboot flag
F8C0 8EFA05                    ldx   #dwtext-1                                        ; 
F8C3 BD90E5                    jsr   outstr                                           ; print string
F8C6 1A50             Start           orcc  #IntMasks                                 ; disable FIRQ, IRQ
F8C8 8EFF20                    ldx   #PIA1Base                        ; PIA1
F8CB C602                      ldb   #$02
F8CD E784                      stb   ,x                               ; make RS-232 output marking
                                                                                                                      ; Spin for a while so that the RS-232 bit stays hi for a time
F8CF 8EA000           Reset           ldx   #$a000
F8D2 301F             Spin     leax  -1,x
F8D4 26FC                      bne    Spin
                                                                                                                      ; Request named object from DW server
F8D6 9611                      lda   <bootflag                                        ; coming from autoboot?
F8D8 263E                      bne   autoreq                                          ; then use default name
F8DA 9DA5                      jsr   <redLChr                                         ; peek at next character
F8DC 804E                      suba  #'N'                                                     ; DLOADN ?
F8DE 9710                      sta   <noexec                                          ; 0 = noexec
F8E0 2602                      bne   getn
F8E2 9D9F                      jsr   <getNChr                                         ; read next char (the N)
F8E4 BDB7AA           getn     jsr   getfnam                                          ; read file name and length into $1d1 = namebuf
F8E7 8E01D0                    ldx   #namebuf-1                                       ; packet buffer start
F8EA 6F84                      clr   ,x                                                               ; zero MSB for Y
F8EC 10AE81                    ldy   ,x++                                                     ; length of file name (16 bit)
F8EF 2729                      beq   noname                                           ; no file name given?
F8F1 E61F                      ldb   -1,x                                                     ; length of name (8 bit)
F8F3 6F85                      clr   b,x                                                      ; zero terminate name string (for error)
F8F5 6C83                      inc   ,--x                                                     ; 1 = DriveWire OP_NAMEOBJ_MOUNT
F8F7 3122                      leay  2,y                                                      ; length of DW packet, name length + 2
F8F9 BDFBA8           reqobj  jsr   DWWrite
F8FC 8E0012                    ldx   #dnum                                                    ; Our drive number variable
F8FF 6F84                      clr   ,x
F901 3121                      leay  1,y                                                      ; read one byte back (Y is 0 after DWWrite)
F903 BDFB21                    jsr   DWRead                                           ; get drive number
F906 2401                      bcc    reqOK                                                   ; if open has not failed go on
F908 39                                       rts                                                                     ; else return
F909 6D84             reqOK    tst   ,x
F90B 2616                      bne   ReadDECB                                         ; successful mount
F90D 0D11                      tst   <bootflag
F90F 10260135                  lbne  stealth                                          ; silent failure, BASIC OK prompt
F913 C619                      ldb   #$19                                                     ; MO ERROR
F915 7E8344                    jmp   syserr                                           ; system error
F918 9710             autoreq  sta   <noexec                          ; a is non null, autoexec
F91A 8EFA36           noname   ldx   #autoname
F91D 108E000E                  ldy   #12+2                                                    ; length of DW packet
F921 20D6                      bra   reqobj
                                                                                                                      ; named object has been mounted, proceed to read in file
F923 8E0000           ReadDECB        ldx   #0000
F926 BF01CF                    stx   sector
F929 CE02D9                    ldu   #endbuf                                          ; start with empty buffer
F92C 8CF935                                   cmpx    #nextseg
F92F 2104                                     brn     nextseg
F931 10FF01CD                                 sts     sstack
                                                                                                                      ; read DECB header
F935 108E0005         nextseg  ldy   #5
F939 8E01D1                    ldx   #decbhdr                                         ; copy DECB header here
F93C BDFA58                    jsr   copybuf                                          ; moves x ahead
F93F A61B                      lda   -5,x                                             ; DECB segment header starts with zero
F941 2753                      beq   ml                                               ; normal data segment
F943 8155                      cmpa  #$55                                             ; Dragon DOS file?
F945 261A                      bne   noddd
F947 3124                      leay  4,y                                              ; remaining header bytes (y is 0 here)
F949 BDFA58                    jsr   copybuf
F94C 6A18                      dec   -8,x                                             ; Dragon DOS BASIC = 1
F94E 2604                      bne   ddbin
F950 301F                      leax  -1,x                                             ; length at x-5
F952 2022                      bra   ldbas
F954 10AE1B           ddbin    ldy   -5,x                                             ; length
F957 AE19                      ldx   -7,x                                             ; load address
F959 BDFA58                    jsr   copybuf                                          ; read whole file
F95C 8E01D9                    ldx   #decbhdr+8                                       ; exec address ptr + 2
F95F 204B                      bra   oldsp
F961 4C               noddd    inca
F962 102600DF                  lbne  ErrDWL                                           ; must be $FF otherwise
F966 3121                      leay  1,y                                              ; Y is 0 after copybuf
F968 10BC01CF                  cmpy  sector                                           ; only first sector can be BASIC header
F96C 263A                      bne   endseg                                           ; otherwise end flag
F96E 118301DE                  cmpu  #startbuf+5                                      ; must be first segment also
F972 2634                      bne   endseg
                                                                                                                      ; loading DECB BASIC file
                                                                                                                      ; bytes 4 and 5 are actually part of the program
F974 335E                      leau  -2,u                                             ; u was 5 bytes into read buffer here
                                                                                                                      ; at this point x is past 5-byte header, u is 3 bytes into first 256-bytes block
                                                                                                                      ; for Dragon DOS x is 8 bytes into header, u is 9 bytes into first 256-bytes block
F976 10AE1C           ldbas    ldy   -4,x                                             ; read whole BASIC program
F979 9E19                      ldx   <$19
F97B BDFA58                    jsr   copybuf
F97E BDF9A0                    jsr   prbang
                                                                                                                      ; set up BASIC pointers and finish
F981 9F1B                      stx   <$1b                                             ; end of BASIC program
F983 9F1D                      stx   <$1d
F985 9F1F                      stx   <$1f
F987 0D10                      tst   <noexec
F989 1027BDA0                                 lbeq  $b72d                                             ; print OK, run basvect1, basvect2, readline
F98D BD841F                    jsr   basvect1                                         ; BasVect1 reset BASIC stack etc
F990 BD83ED                    jsr   basvect2                                         ; BasVect2 initialize BASIC
F993 7E849F                    jmp   runbasic                                         ; run_basic
F996 10AE1C           ml       ldy   -4,x                                             ; DECB segment length
F999 AE1E                      ldx   -2,x                                             ; DECB segment loading address
F99B BDFA58                    jsr   copybuf
F99E 2095                      bra   nextseg
F9A0 BD9A89           prbang   jsr   backspc                                          ; print backspace to devnum
F9A3 8621                      lda   #'!'                                             ; print bang
F9A5 7EB54A                    jmp   outchr                                           ; print to devnum
F9A8 EE1C             endseg  ldu   -4,x                                              ; new stack pointer specified?
F9AA 2603                      bne   setsp
F9AC FE01CD           oldsp    ldu   sstack                                           ; otherwise restore original SP
F9AF 1F34             setsp    tfr   u,s
F9B1 8DED                      bsr   prbang
F9B3 1CAF                      andcc #~IntMasks                                       ; enable interrupts
F9B5 AE1E                      ldx   -2,x                                             ; exec address
F9B7 1F10                      tfr   x,d
F9B9 4C                        inca
F9BA 2708                      beq   retbas                                           ; return to basic if exec address $FFxx
F9BC 9F9D                      stx   <$9d                                             ; save BASIC EXEC address
F9BE 0D10                      tst   <noexec
F9C0 2702                      beq   retbas
F9C2 AD84                      jsr   ,x                                               ; and run loaded program
F9C4 39               retbas   rts
                                      
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
FA31 BDF8C6                    jsr   Start
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
FC32 8EE854                                   ldx     #rsbtchk                                        ; address of new code in DPE
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
