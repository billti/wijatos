;==============================================================================
;
; This code creates an image for a bootable floppy disk for a custom OS.
;
;
; USAGE
; Build with: "nasm -f bin bootsect.asm -o bootsect.img"
; Debug with: bochsdbg.exe
; Set a breakpoint at the boot sector start address with: "lb 0x7c00"
; Examine memory at disk segment load address with "x /24xb 0x1000"
;
;
; A .img file is just a sequential series of bytes as would be in the disk sectors.
; There are 2880 sectors on a 1.44MB 3.5" floppy: 2880 * 512 = 1,474,560 (0x168000) bytes.
;
; A bootable 3.5" floppy is uses the FAT12 file system, and is layed out here as follows:
;
;  Sectors         Byte range         Usage
;   0           0x0000 -   0x01FF   Boot sector
;   1 -    9    0x0200 -   0x13FF   Primary FAT
;  10 -   18    0x1400 -   0x25FF   Backup FAT
;  19 -   32    0x2600 -   0x41FF   Root directory table
;  33 -  152    0x4200 -  0x131FF   Data region (60kb file OS.BIN)
; 153 - 2879  0x131200 - 0x168000   Data region (free)
;==============================================================================


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

; BIOS parameter block. All FAT volumes must have a BPB in the boot sector. Model a 3.5" 1.44MB floppy (uses FAT12).
bsOEM                   DB "WIJAT OS"       ; 8 byte OEM name.
bpbBytesPerSector:  	DW 512              ; Only use 512 for max compat.
bpbSectorsPerCluster: 	DB 1
bpbReservedSectors: 	DW 1                ; Only use 1 (the boot sector) for max compat.
bpbNumberOfFATs: 	    DB 2                ; Only use 2 for max compat.
bpbRootEntries: 	    DW 224              ; For FAT12, the # of 32-bytes dir entries in the root dir.
bpbTotalSectors: 	    DW 2880             ; 2880 * 512 = 1.44MB
bpbMedia: 	            DB 0xF0             ; F0 for removable media (e.g. floppy disk).
bpbSectorsPerFAT: 	    DW 9
bpbSectorsPerTrack: 	DW 18               ; 18 sectors numbered 1 - 18 for a 3.5" floppy.
bpbHeadsPerCylinder: 	DW 2                ; 2 heads on a dual-sided high denstiy floppy (3.5" 1.44MB)
bpbHiddenSectors: 	    DD 0                ; Should be 0 on non-partitioned media
bpbTotalSectorsBig:     DD 0                ; A 32-bit version of TotalSectors if needed.
bsDriveNumber: 	        DB 0
bsReserved:	            DB 0
bsExtBootSignature: 	DB 0x29             ; Extended boot signature. Indicates the next 3 fields are present.
bsSerialNumber:	        DD 0x19720327       ; Any unique ID (usually a timestamp)
bsVolumeLabel: 	        DB "BOOT FLOPPY"    ; An 11 byte label padded with spaces
bsFileSystem: 	        DB "FAT12   "       ; 8 bytes padded with spaces

; Disk geometry is specified as C/H/S (cylinder/head/sector) with the first two being 0 based, and the last one
; based (i.e. the first sector, the boot sector, is 0/0/1). CHS can be mapped to a Logical Block Address (LBA) with:
; LBA = (C * <heads> + H) * <sectors> + (S - 1). i.e. 10/1/3 = (10 * 2 + 1) * 18 + (3 - 1) = 380

; Disk sector layout
; - LBA   0      = Boot sector. 
; - LBAs  1 -  9 = First FAT.  (Offset 0x0200)
; - LBAs 10 - 18 = Backup FAT. (Offset 0x1400)
; - LBAs 19 - 32 = Root directory. (224 entries * 32 bytes) / 512 bytes per sector = 14 sectors. (Offset 0x2600)
; - LBAs 33+     = Data region. (First data sector is the sector for "cluster #2" in the FAT).   (Offset 0x4200)
; Note: LBA33 = C/H/S -> 0/1/16

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
	jnc 0x1000    ; If carry flag not set, jump to loader.sys
    hlt           ; Else hlt (TODO: Print error)

TIMES 0x200 - 2 - ($ - $$) DB 0xCC  ; Padding sector with INT 3
DW 0xAA55                           ; Bytes 510/511 of the boot sector must contain the MBR signature


SECTION .fatdata
; *************************************************************
; The FAT12 file allocation tables
; *************************************************************

; The first FAT should be at offset 0x200

DB 0xF0, 0xFF, 0xFF   ; Start with FAT ID and end-of-chain markers

; Linked list of clusters. Note that as each entry is 12-bits, and they are little endian, the
; layout can look a little wierd. e.g. If the first two entries were 0x123 and 0xabc, then the 
; first 2 bytes would be: 0x23, 0xc1, 0xab.
; If the first file is 16kb (32 clusters) running serially from cluster 2, then first entries would be clusters 3 - 33.
DB 0x03, 0x40, 0x00, 0x05, 0x60, 0x00, 0x07, 0x80, 0x00, 0x09, 0xA0, 0x00
DB 0x0B, 0xC0, 0x00, 0x0D, 0xE0, 0x00, 0x0F, 0x00, 0x01, 0x11, 0x20, 0x01
DB 0x13, 0x40, 0x01, 0x15, 0x60, 0x01, 0x17, 0x80, 0x01, 0x19, 0xA0, 0x01
DB 0x1B, 0xC0, 0x01, 0x1D, 0xE0, 0x01, 0x1F, 0x00, 0x02, 0x21, 0xF0, 0xFF

; First FAT should total 9 sectors
TIMES 9 * 512 - ($ - $$) DB 0
   
; The identical backup FAT should be at offset 0x1400
DB 0xF0, 0xFF, 0xFF
DB 0x03, 0x40, 0x00, 0x05, 0x60, 0x00, 0x07, 0x80, 0x00, 0x09, 0xA0, 0x00
DB 0x0B, 0xC0, 0x00, 0x0D, 0xE0, 0x00, 0x0F, 0x00, 0x01, 0x11, 0x20, 0x01
DB 0x13, 0x40, 0x01, 0x15, 0x60, 0x01, 0x17, 0x80, 0x01, 0x19, 0xA0, 0x01
DB 0x1B, 0xC0, 0x01, 0x1D, 0xE0, 0x01, 0x1F, 0x00, 0x02, 0x21, 0xF0, 0xFF

; Both FATs should total 18 sectors
TIMES 18 * 512 - ($ - $$) DB 0


; *************************************************************
; The FAT12 root directory
; *************************************************************

; Should start at offset 0x2600 (i.e. after 19 sectors)
; Only put one entry for loader.sys in the root directory
DB "LOADER  " ; 8 char filename
DB "SYS"      ; 3 char extension
DB 5          ; attribute flags. 0x01 = read only. 0x04 = system file
DB 0          ; Reserved
TIMES 7 DB 0  ; Creation and last accessed  times 
DW 0          ; First cluster high word (0 for FAT12/16)
DW 0          ; Time of last write
DW 0          ; Date of last write
DW 2          ; This entry's first cluster number
DD 0x1000     ; Size in bytes (mark file as 4kb in size (8 sectors/clusters)).

; FAT12 directory is 224 * 32 bytes = 0x1C00 = 14 sectors. 
; Plus 18 sectors for the two FATs = 32 sectors, = 0x4000 bytes total for this section
TIMES 0x4000 - ($ - $$) DB 0


; *************************************************************
; Loader.sys contents
; *************************************************************

; Should be at offset 0x4200 (first sector of data region)
SECTION .loader vstart=0x1000 ; Expect to be loaded at memory address 0x1000
jmp loader
testStr DB 'Code in the next sector'       ; Should be located in sector 2 (starts at 1).
loader:
  mov ax, testStr
  hlt
; *** TODO: Rest of loader code here ***

TIMES (32 * 512 - ($-$$) - 4) DB 0xCC      ; Fill up 16KB for this file (will error if code runs over)
DB 0, 'EOF'                                ; Marker for end of loader.sys 
; Should now be at offset 0x8200


; *************************************************************
; Floppy image padding
; *************************************************************
SECTION .padding
; Fill up space for a 1.44MB floppy img
TIMES (1440 * 1024 - 0x8200) DB 0
; Total image size should be 1,474,560 (0x168000) bytes
