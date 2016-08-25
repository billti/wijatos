SECTION .fats
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
DB "OS      " ; 8 char filename
DB "BIN"      ; 3 char extension
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
