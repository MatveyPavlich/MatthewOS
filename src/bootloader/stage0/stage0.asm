;======================================================================================
; This is stage0 of the bootloader that contains code to load sectors from disk,
; finding files in the FAT12 file system and interpreting cluster chains for each file.
; It does not switches to real mode, which will be done by stage1. BIOS Parameter
; Block (BPB) is defined to describe the physical layout of the disk.
;======================================================================================

org 0x7C00                                    ; For assembler to organise the code where first address is 0x7C00
bits 16                                       ; For assembler to know that should be in 16 bits
jmp short main                                ; Jump to code in main (<127 bytes down in memo, so use SHORT)
nop                                           ; Do nothing for 1 CPU cycle
 
bdb_oem:                   db 'MSWIN4.1'      ; Tells what formatted the disk
bdb_bytes_per_sector:      dw 512             ; 
bdb_sectors_per_cluster:   db 1               ; FAT table has offsets to clusters, not sectors! This is why it is important
bdb_reserved_sectors:      dw 1               ; Number of sectors before FAT sector including boot sector => 1 => no additional sectors
bdb_fat_count:             db 2               ; Number of fat tables (one will be for a backup)
bdb_dir_entries_count:     dw 0xE0            ; Max number of enteries in a root directory
bdb_total_sectors:         dw 2880 
bdb_media_descriptor_type: db 0xF0            ; Tells 
bdb_sectors_per_fat:       dw 9               ; Each FAT table will take 9 sectors
bdb_sectors_per_track:     dw 18              ; Each track will have 18 sectors (ignore the fact that outer tracks are longer)
bdb_heads:                 dw 2               ; Since we are on the floppy disk we will have 2 heads only
bdb_hidden_sectors:        dd 0                 
bdb_large_sector_count:    dd 0 
 
ebr_drive_number:          db 0x00            ; Hardcoding that we are using a floppy disk
                           db 0               ; Reserved, often used for "current head"
ebr_signature:             db 0x29 
ebr_volume_id:             db 12h,34h,56h,78h 
ebr_volume_label:          db 'SnakeOS    '   ; Must be exactly 11 bytes
ebr_system_id:             db 'FAT12   '      ; Magical value that tells it is FAT12 (must be 8 bytes)

main:
    
    ; Set data segments to the same 64kB chunk & load the root directory
    mov ax, 0                                 
    mov ds, ax                                
    mov es, ax                                
    mov ss, ax                                
    mov sp, 0x7C00                            ; Grow stack below above the code
    call load_root_dir

    ; Find kernel.bin starting cluster
    xor bx,bx                                 ; Clean bx from address where you dumped root directory
    mov si, file_kernel                       ; Move kernel file name into SI
    mov di, buffer                            ; Set DI to address of loaded root directory
    call search_file                          ; SI = file name, DI = start of root dir (buffer), BX = 0 for a loop
    mov [kernel_cluster], ax                  ; Save starting kernel cluster into memory (will be used in stage1)

    ; Find stage1.bin starting cluster
    xor bx, bx                                ; Clean bx for the search_file function
    mov di, buffer                            ; Move starting location of the root directory into di
    mov si, file_stage1                       ; Move stage1 bin file name into si
    call search_file                          ; SI = file name, DI = start of root dir (buffer), BX = 0 for a loop
    mov [stage1_cluster], ax                  ; Save starting kernel cluster into memory (will be used later)

    ; Load FAT12 table into memory
    mov si, msg_moving_fat_to_ram             ; Debugging
    call print                                ; Debugging
    mov bx, buffer                            ; Load it to 0x7E00 since we no longer need a root directory
    mov al, [bdb_reserved_sectors]            ; Starting LBA of a FAT table
    mov ah, [bdb_sectors_per_fat]             ; Sectors to read (TAT table length)
    call disk_read                            ; AH = num of sectors to read; AL - LBA; ES:BX - memo to dump

    ; Load stage1.bin into memory
    mov bx, stage1_load_segment               ; Move segment into bx since can't do it directly into ES
    mov es, bx                                ; Set ES to the segment for stage1
    mov bx, stage1_load_offset                ; Move offset into bx (since BX is used for disk_read dump memory offset)
    mov ax, [stage1_cluster]                  ; Retrieve stage1.bin starting cluster to be used by load_file
    mov si, buffer                            ; Move pointer to FAT12 into SI to be used by load_file
    call load_file                            ; AX = starting cluster; SI = pointer to FAT12; ES:BX = file destination

    ; Load kernel.bin into memory
    mov bx, kernel_load_segment               ; Move segment into bx since can't do it directly into ES
    mov es, bx                                ; Set ES to the segment for stage1
    mov bx, kernel_load_offset                ; Move offset into bx (since BX is used for disk_read dump memory offset)
    mov ax, [kernel_cluster]                  ; Retrieve stage1.bin starting cluster to be used by load_file
    mov si, buffer                            ; Move pointer to FAT12 into SI to be used by load_file
    call load_file                            ; AX = starting cluster; SI = pointer to FAT12; ES:BX = file destination

    ; Jump into stage1.bin
    mov dl, [ebr_drive_number]                ; Save the drive number
    mov ax, stage1_load_segment               ; Move segment into bx since can't do it directly into ds & es
    mov ds, ax                                ; Set ds to the segment with stage1
    mov es, ax                                ; Set es to the segment with stage1
    jmp stage1_load_segment:stage1_load_offset



%include "./src/bootloader/stage0/utils.asm"
%include "./src/bootloader/shared_utils.asm"

read_failure:           db "Read failed", 0x0D, 0x0A, 0x00
disk_read_sucessfully:  db "Read finished", 0x0D, 0x0A, 0x00
file_stage1:            db "STAGE1  BIN"
file_kernel:            db "KERNEL  BIN"
msg_file_not_found:     db "File not found", 0x0D, 0x0A, 0x00
msg_file_found:         db "File found", 0x0D, 0x0A, 0x00
msg_moving_fat_to_ram:  db "Load FAT12", 0x0D, 0x0A, 0x00
stage1_cluster:         dw 0
kernel_cluster:         dw 0

stage1_load_segment     equ 0x8000
stage1_load_offset      equ 0
kernel_load_segment     equ 0x9000
kernel_load_offset      equ 0

TIMES 510-($-$$) DB 0
dw 0xAA55

; 0x7E00 label
buffer: