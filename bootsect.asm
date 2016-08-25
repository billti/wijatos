; *************************************************************
; The boot sector
; *************************************************************

; The BIOS will load the boot sector at 0x7c00 and transfer control to that address.
; This bootsector will relocate itself to 0x0600 and set stack top to 0x1000, and
; transfer control to its new location. It will then continue to load the first 120
; sectors (60kb) from disk to the memory region 0x1000 to 0xFFFF. It will then enter
; protected mode and transfer control to the load address of 0x1000 with a FAR jump.

SECTION .bootsect vstart=0x0600  ; Will be moved to 0x0600 from BIOS default of 0x7c00 as first action
BITS 16

    jmp near start  ; Use "near" jump to force a 3 byte instruction (next structure should be a offset 0x03)

; The BIOS parameter block
%include "biosparams.asm"

; The Global Descriptor Table for going into protected mode
DW 0  ; 2 bytes padding to ensure GDT is aligned on 8 bytes
%include "gdt.asm"

; Disk geometry is specified as C/H/S (cylinder/head/sector) with the first two being 0 based, and the last one
; based (i.e. the first sector, the boot sector, is 0/0/1). CHS can be mapped to a Logical Block Address (LBA) with:
; LBA = (C * <heads> + H) * <sectors> + (S - 1). i.e. 10/1/3 = (10 * 2 + 1) * 18 + (3 - 1) = 380
;
; Note: LBA33 (where the OS.BIN file starts) = C/H/S -> 0/1/16
;
; In FAT calculations, LBA for the sector for a cluster 'n' = n - 2 + 33, or n + 31


greeting DB "WIJAT OS by Bill Ticehurst.", 0x0D, 0x0A, 0
diskerr  DB "Failed to read from the drive", 0x0D, 0x0A, 0

; Helper calls

;********************************************
; Print a 0 terminated string
;
; DS:SI should hold the address of the string
;
  printsz:
    cld           ; Ensure we increment after each lodsb
  .loop:
    lodsb         ; Move byte into AL in increment SI
	or al, al     ; Exit if 0 found
	jz .done
    mov ah, 0x0e  ; Write teletype char
	int 0x10      ; Screen BIOS calls
	jmp .loop
  .done:
    ret

;********************************************
; Read a range of sectors from disk to memory
;
; CX, DX, BX, and AL should all be set as expected for int 13h, function 02h
counter DW 0

  readsectors:
    mov WORD [counter], 3   ; How many retries
  .retry:
	pusha              ; Save state for retries
	mov ah, 02h
	int 13h
	jnc .done
	dec WORD [counter]
	jz .error
	popa
	jmp .retry
  .error:
    mov si, diskerr
    call printsz
    hlt    
  .done:
    popa
	ret

;********************************************
; Convert LBA (0 based) to CHS (0/0/1 based)
;
; Desired LBA should be in AX. CHS will be returned in CX and DX as expected by 'read sector' int 13h
; namely, CH = cylinder, DH = head, CL = sector, DL = drive
  lbatochs:
    ; For 3.5" floppy there are 18 sectors and 2 heads. LBA 0 = CHS 0/0/1 (only the sector is 1 based)
	;
	; Cylinder is LBA / 36, e.g. 0 - 35 = 0, 36 - 71 = 1, etc..
	; Head is LBA % 36 / 18 , e.g. 0 - 17 = 0, 18 - 35 = 1, 36 - 53 = 0, 54 - 72 = 1, etc..
	; Sector is LBA % 18 + 1, e.g. 0 = 1, 17 = 18, 18 = 1, 35 = 17, etc..
	;
	; Note that for a floppy geometry, all results fit in a byte (max cylinder is 80, head 1, and sector 18).

	push bx                ; We need to use BX, so save/restore
	push bp                ; Use BP to set a frame for locals
	mov bp, sp

    push ax                ; save LBA @ [bp - 2]
	sub sp, 4              ; Use bp-4 = CX, bp-6 = DX
	mov bl, 36
	div bl                 ; Divide AX by 36, AL = quotient, AH = remainder
	mov byte [bp - 3], al  ; Store the cylinder number (will become CH)

	shr ax, 8              ; Make AX be AH (which is currently LBA % 36)
	mov bl, 18
	div bl                 ; AL = LBA % 36 / 18 = Head, AH = LBA % 36 % 18 = Sector - 1
	mov byte [bp - 5], al  ; Store the head (will become DH)
	mov byte [bp - 4], ah  ; Store the sector - 1 (will become CL)
	inc byte [bp - 4]
	mov byte [bp - 6], 0   ; Drive number
	
	mov cx, [bp - 4]
	mov dx, [bp - 6]
	mov sp, bp
	pop bp
	pop bx
	ret
	

; entry point
  start:
    xor bx, bx
	mov ds, bx
	mov es, bx
    mov sp, 0x1000

    ; Relocate the boot sector to 0x600 and jump there
	cld
	mov si, 0x7c00
	mov di, 0x0600
	mov cx, 0x100   ; Move 0x100 words (0x200 bytes)
	rep movsw
	
	; Jump to the new location
	mov ax, greet
	jmp ax

  greet:
	mov si, greeting
	call printsz  

  ; Try to load OS.BIN to 0x1000
  loados:
    mov cx, 3
  .reset:
    mov ah, 0x00  ; Reset disks - see http://www.ctyme.com/intr/rb-0605.htm
	mov dl, 0x00  ; Drive 0 - floppy drive A:
	int 13h       ; Disk services - see https://en.wikipedia.org/wiki/INT_13H
	jnc .driveok  ; disk reset OK
	dec cx
	jnz .reset
	mov si, diskerr
	call printsz
	hlt

  .driveok:
    ; Load OS.BIN, which is the 60kb of data (120 sectors) starting at LBA 33
    mov bx, 1000h ; Destination address
	mov ax, 0x21  ; LBA 33 is the first data sector
	mov cx, 120   ; Sectors to read

  .loadsector:
	push cx          ; Save the counter
	push ax          ; Save the LBA
	call lbatochs    ; Get the CHS for the LBA
    mov al, 01h      ; Read 1 sector at a time
	call readsectors ; Will only return if successful
	add bx, 512      ; Increment load address by a sector size
	pop ax           ; Restore and increment the LBA
	inc ax
	pop cx           ; Restore and decrement the counter
	dec cx
	jnz .loadsector  ; Repeat for any remaining sectors
	
  ; OS.BIN loaded at 0x1000. Swith to protected mode and jump to it.
    cli
	lgdt [gdt_descriptor]
	mov eax, cr0
	or eax, 0x01
	mov cr0, eax
	jmp CODE_SEG:OS_START

TIMES 0x200 - ($-$$) - 2 DB 0xCC  ; Padding sector with INT 3
DW 0xAA55                         ; Bytes 510/511 of the boot sector must contain the MBR signature
