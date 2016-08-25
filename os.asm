; *************************************************************
; OS.BIN contents
; *************************************************************

; The code should be at FAT12 .img file offset 0x4200 (first sector of data region)

SECTION .loader vstart=0x1000 ; Expect to be loaded at memory address 0x1000
BITS 32

VIDEO_MEMORY   equ 0xb8000
WHITE_ON_BLACK equ 0x0f

  OS_START:
    ; Change all the segment selectors for data access
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

	mov esi, runningStr
	call writeline
    
    ; *** TODO: Rest of OS.BIN here ***
	mov esi, stoppingStr
	call writeline
    hlt
    
  writeline: ; null terminated string should be in ESI
    push edi
    push esi
    ; The screen is an 80 x 25 area, with 2 bytes for each char.
	; First, move all lines up one (i.e. scroll one line)
	
	mov edi, VIDEO_MEMORY
	mov esi, VIDEO_MEMORY + 160
	mov ecx, 24 * 80
	rep movsw
	
	; Blank out the last line
	mov ah, WHITE_ON_BLACK
	mov al, 0x20  ; space char
	mov edi, VIDEO_MEMORY + (24 * 80 * 2) ; skip over 24 lines
	mov ecx, 80                           ; write 80 chars
	rep stosw
	
	; write the source string to the last line
	pop esi
	push esi
	mov edi, VIDEO_MEMORY + (24 * 80 * 2)
	mov ah, WHITE_ON_BLACK	
  .nextchar:
	mov al, [ESI]
	cmp al, 0
	je .done
	mov [edi], ax
	add edi, 2
	add esi, 1
	jmp .nextchar
  .done:
    pop esi
	pop edi
    ret

runningStr DB 'WIJAT OS now running in 32-bit protected mode.', 0
stoppingStr DB 'OS halting. Please continue development!', 0
    
TIMES (120 * 512 - ($-$$)) DB 0xCC      ; Fill up 60KB for this file (will error if code runs over)
; File size should now be 0xF000
