; *************************************************************
; Loader.sys contents
; *************************************************************

; Should be at img file offset 0x4200 (first sector of data region)

SECTION .loader vstart=0x1000 ; Expect to be loaded at memory address 0x1000
jmp loader
testStr DB 'Code in the next sector'       ; Should be located in sector 2 (starts at 1).
loader:
  mov ax, testStr
  hlt
; *** TODO: Rest of loader code here ***

TIMES (120 * 512 - ($-$$)) DB 0xCC      ; Fill up 16KB for this file (will error if code runs over)
; File size should now be 0xF000


; *************************************************************
; Floppy image padding
; *************************************************************

; Fill up space for a 1.44MB floppy img
TIMES (1440 * 1024 - 0xF000 - 0x4200) DB 0
; Total image size should be 1,474,560 (0x168000) bytes
