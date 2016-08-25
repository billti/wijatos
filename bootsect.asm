; *************************************************************
; The boot sector
; *************************************************************

; The BIOS will load the boot sector at 0x7c00 and transfer control to that address.
; *** TODO ***
; This bootsector will relocate itself to 0x0600 and set stack top to 0x1000, and
; transfer control to its new location. It will then continue to load the first 120
; sectors (60kb) from disk to the memory region 0x1000 to 0xFFFF. It will then enter
; protected mode and transfer control to the load address of 0x1000 with a FAR jump.


SECTION .bootsect vstart=0x7c00  ; 0x7c00 is the default memory address for loaded boot sector

BITS 16

    jmp near start  ; Use "near" jump to force a 3 byte instruction (next structure should be a offset 0x03)

%include "biosparams.asm"

; Disk geometry is specified as C/H/S (cylinder/head/sector) with the first two being 0 based, and the last one
; based (i.e. the first sector, the boot sector, is 0/0/1). CHS can be mapped to a Logical Block Address (LBA) with:
; LBA = (C * <heads> + H) * <sectors> + (S - 1). i.e. 10/1/3 = (10 * 2 + 1) * 18 + (3 - 1) = 380

; Note: LBA33 (where the OS.BIN file starts) = C/H/S -> 0/1/16

; In FAT calculations, LBA for the sector for a cluster 'n' = n - 2 + 33, or n + 31


message DB "Ticehurst OS. (c) 2016", 0x0D, 0x0A, 0
msglen EQU $-message

; entry point
  start:
    xor bx, bx
	mov ds, bx
	mov es, bx

  greet:
    mov cx, msglen ; Check if destroyed
	mov si, message
	cld           ; Increment after each operation
  nextchar:
	lodsb         ; Move byte from DS:SI into AL
    mov ah, 0x0e  ; Write teletype char
	int 10h
	loop nextchar

  readsector:
    mov ah, 0x00  ; Reset disks - see http://www.ctyme.com/intr/rb-0605.htm
	mov dl, 0x00  ; Drive 0 - floppy drive A:
	int 13h       ; Disk services - see https://en.wikipedia.org/wiki/INT_13H

    mov bx, 1000h ; Destination address
    mov ah, 02h   ; Read disk - see http://www.ctyme.com/intr/rb-0607.htm
    mov al, 20h   ; Read 32 sectors
    mov ch, 00h   ; Low 8 bits of cylinder number
    mov dh, 01h   ; Head number
    mov cl, 10h   ; Bits 0 - 5 = sector number (1 - 63)
    mov dl, 00h   ; Drive number
    int 13h
	jnc 0x1000    ; If carry flag not set, jump to OS.BIN
    hlt           ; Else hlt (TODO: Print error)

TIMES 0x200 - ($-$$) - 2 DB 0xCC  ; Padding sector with INT 3
DW 0xAA55                         ; Bytes 510/511 of the boot sector must contain the MBR signature
