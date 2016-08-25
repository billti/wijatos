;==============================================================================
;
; This code creates an image for a bootable floppy disk for a custom OS.
;
;
; USAGE
; Build with: "nasm -f bin floppy.asm -o floppy.img"
; Debug with: bochsdbg.exe
; Set a breakpoint at the boot sector start address with: "lb 0x7c00"
; Or at the OS.BIN start address with: lb 0x1000
; Examine memory at OS.BIN load address with "x /24xb 0x1000"
;
;
; A .img file is just a sequential series of bytes as would be in the disk sectors.
; There are 2880 sectors on a 1.44MB 3.5" floppy: 2880 * 512 = 1,474,560 (0x168000) bytes.
;
; A bootable 3.5" floppy is uses the FAT12 file system, and is layed out here as follows:
;
;  LBA            Byte range         Usage
;   0           0x0000 -   0x01FF   Boot sector
;   1 -    9    0x0200 -   0x13FF   Primary FAT
;  10 -   18    0x1400 -   0x25FF   Backup FAT
;  19 -   32    0x2600 -   0x41FF   Root directory table
;  33 -  152    0x4200 -  0x131FF   Data region (60kb file OS.BIN)
; 153 - 2879  0x131200 - 0x168000   Data region (free)
;==============================================================================


; The section containing the real-mode boot sector the BIOS loads (1 sector)
%include "bootsect.asm"

; The FAT12 data structures (32 sectors)
%include "fats.asm"

; The protected mode OS (120 sectors)
%include "os.asm"

; Floppy image padding

; For a 1.44MB floppy, fill with 0s for 2880 sectors, less the above 153 sectors.
TIMES (2880 - 153) * 512 DB 0
; Total image size should be 1,474,560 (0x168000) bytes
