; EDFSDET.ASM (Nasm code)

; detect if EtherDFS is loaded
; and (if yes) print EtherDFS drive letters

; Frank Haeseler 5/2024

; compile with: nasm -f bin -o EDFSDET.COM EDFSDET.ASM

; Memo: tsrshareddata structure is defined in GLOBALS.H

 use16
 org 0x100               ; a COM program

; process command line arguments (only "-q" at the moment)
mov  si, 81h          ; get command line args

args: 
  lodsb
  cmp  al, ' '
  jz   args
  cmp  al, '-'
  jz   args
  cmp  al, '/'
  jz   args
  cmp  al, 13          ; CR at end of line?
  jb   start
  cmp  al, 51h         ; is it "Q" ?
  je   quiet
  cmp  al, 71h         ; is it "q" ?
  je   quiet
  jmp  args

quiet:
  mov  byte [qvar],1   ; Quiet: User wants no output at all
  jmp  skip_title

start:
    mov  dx,title        ; print title message
    mov  ah,09
    int  21h

skip_title:

    call findfreemultiplex
    cmp  byte [pflag],0
    je   not_present

    call tsr_data
    cmp  byte [pflag],0
    je   not_present

    cmp  byte [qvar],1     ; is qvar == 1? (User wants no output)
    je   Exit_0

    mov  dx,yes_msg
    mov  ah,9
    int  21h
Exit_0:
    mov  ax,0x4c00
    int  21h               ; exit with errorlevel 0 (EtherDFS found)

not_present:
    cmp  byte [qvar],1     ; is qvar == 1? (User wants no output)
    je   Exit_1

    mov  dx,no_msg
    mov  ah,9
    int  21h
Exit_1:
    mov  ax,0x4c01
    int  21h               ; exit with errorlevel 1


tsr_data:                  ; get the ptr to TSR's data
    push ax
    push bx
    push cx
    pushf

    mov  ah,byte [freeid]
    mov  al,1
    mov  cx,4d86h
    mov  word [myseg],0ffffh
    int  2Fh            ; AX should be 0, and BX:CX contains the address
    test ax,ax
    jnz  fail           ; Communication with the TSR failed

    mov  [myseg],bx     ; a far pointer to EtherDFS's internal data will be
                        ;  returned in BX:CX.
    cmp  word [myseg],0ffffh
    je   fail

; Now we have the address of the tsrshareddata structure in BX:CX, so
; all we need is to offset CX that it points at 'ldrv' instead of the top of
; the structure, then add to CX the drive number we want to test (C=2, D=3).
; Finally load the byte at BX:CX into AL, and test al, 0xff.
; If not equal, then it is an EtherDFS drive.
; A value == 0xff means 'not etherdfs'.

    add  cx,9              ; tsrshareddata structure: 'ldrv' starts at 9
    add  cx,2              ; start at drive C: (0-based: A=0, B=1, C=2, etc)
    mov  byte [Drive], 3   ; BUT: Variable 'Drive' is 1-based (A=1, B=2, etc)
                           ; (for printletter subroutine)
loop_it:
    push bx                ; save BX
    mov  es,bx             ; 8086 has no mov instruction that takes
                           ; a 32bit pointer (so we trash another segment)
    mov  bx, cx
    cmp  byte [es:bx],0xff ; if not equal, then it is an EtherDFS drive
    je   not_etherdfs      ; while value == 0xff means 'not etherdfs'

    cmp  byte [qvar],1     ; is qvar == 1? (User wants no output)
    je   not_etherdfs
    call printletter       ; printletter uses Drive = 1-based drive

    push dx
    mov  dx,drive_msg
    mov  ah,9
    int  21h
    pop  dx

not_etherdfs:
    pop  bx                ; restore BX
    inc  byte [Drive]
    add  cx,1
    cmp  byte [Drive],27   ; stop at 27 (Z=26)
    je   loop_end
    jmp  loop_it

fail:
    mov  byte [pflag],0    ; reset presentflag
loop_end:
    popf
    pop  cx
    pop  bx
    pop  ax
ret

findfreemultiplex:
;  scans the 2Fh interrupt for some available 'multiplex id' in the range
;  C0..FF. also checks for EtherDFS presence at the same time. returns:
;   - the available id if found
;   - the id of the already-present etherdfs instance
;   - 0 if no available id found
;  presentflag set to 0 if no etherdfs found loaded, non-zero otherwise.

    mov  byte [id],0C0h  ;  start scanning at C0h
checkid:
    xor  al,al     ;  subfunction is 'installation check' (00h)
    mov  ah,byte [id]
    int  2Fh
    ;  is it free? (AL == 0)
    test al,al
    jnz  notfree    ;  not free - is it me perhaps?
;   mov  freeid, ah ;  it's free - remember it, I may use it myself soon
    jmp  checknextid
notfree:
    ;  is it me? (AL=FF + BX=4D86 CX=7E1 [MV 2017])
    cmp  al,0ffh
    jne  checknextid
    cmp  bx,4d86h
    jne  checknextid
    cmp  cx,7e1h
    jne  checknextid
    ;  if here, then it's me...
    mov  ah,byte [id]
    mov  byte [freeid],ah
    mov  byte [pflag],1      ; set presentflag
    jmp  gameover
checknextid:
    ;  if not me, then check next id
    inc  byte [id]
    jnz  checkid ;  if id is zero, then all range has been covered (C0..FF)
gameover:
    ret

printletter:              ; print the drive letter
    push  dx
    mov   dl,byte [Drive] ; 1-based drive
    add   dl,'A'-1        ; convert drive to "A" based letter
    mov   ah,02           ; write DL ASCII char to screen
    int   21h  
    pop   dx
    ret

; Data
qvar       db  0              ; Quiet (batch mode) variable
id         db  0
freeid     db  0
pflag      db  0
Drive      db  0
myseg      dw  0

title      db "EDFSDET.COM: EtherDFS detection tool - by Frank Haeseler 5/2024.",0x0D,0x0A,0x0D,0x0A
           db "EtherDFS is a DOS network drive, running over raw ethernet, (C) Mateusz Viste.",0x0D,0x0A
           db "Type 'edfsdet -q' for quiet (batch) mode (only errorlevel).",0x0D,0x0A,0x0D,0x0A,"$"
no_msg     db "EtherDFS is not loaded (EL 1).",0x0D,0x0A,"$"
yes_msg    db 0x0D,0x0A,"EtherDFS is loaded (EL 0).",0x0D,0x0A,"$"

drive_msg  db " - Remote (network) drive (EtherDFS)",0x0D,0x0A,"$"
