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
