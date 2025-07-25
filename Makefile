ASM=nasm
CC=gcc
LD=ld
SRC_DIR=src
BUILD_DIR=build

CFLAGS=-ffreestanding -m64 -nostdlib -O2 -Wall
LDFLAGS=-T $(SRC_DIR)/kernel/kernel.ld -nostdlib -z max-page-size=0x1000

# Floppy disk
floppy_image: $(BUILD_DIR)/main.img
$(BUILD_DIR)/main.img: stage0 stage1 kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main.img bs=512 count=2880
	mkfs.fat -F 12 -n "SNAKEOS" $(BUILD_DIR)/main.img
	dd if=$(BUILD_DIR)/stage0.bin of=$(BUILD_DIR)/main.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main.img $(BUILD_DIR)/stage1.bin "::stage1.bin"
	mcopy -i $(BUILD_DIR)/main.img $(BUILD_DIR)/kernel.bin "::kernel.bin"

# Bootloader
stage0: $(BUILD_DIR)/stage0.bin
$(BUILD_DIR)/stage0.bin:
	$(ASM) $(SRC_DIR)/bootloader/stage0/stage0.asm -f bin -o $(BUILD_DIR)/stage0.bin

# Stage 1
stage1: $(BUILD_DIR)/stage1.bin
$(BUILD_DIR)/stage1.bin:
	$(ASM) $(SRC_DIR)/bootloader/stage1/stage1.asm -f bin -o $(BUILD_DIR)/stage1.bin

# Kernel
kernel: $(BUILD_DIR)/kernel.bin
$(BUILD_DIR)/kernel.bin: $(BUILD_DIR)/kernel_entry.o $(BUILD_DIR)/main.o $(SRC_DIR)/kernel/kernel.ld
	$(LD) $(LDFLAGS) -o $(BUILD_DIR)/kernel.bin $(BUILD_DIR)/kernel_entry.o $(BUILD_DIR)/main.o

$(BUILD_DIR)/kernel_entry.o: $(SRC_DIR)/kernel/kernel_entry.asm
	$(ASM) -f elf64 $< -o $@

$(BUILD_DIR)/main.o: $(SRC_DIR)/kernel/main.c
	$(CC) $(CFLAGS) -c $< -o $@

# Run
run:
	qemu-system-x86_64 -fda $(BUILD_DIR)/main.img

# Debug
debug:
	./debug.sh

clean:
	rm -rf $(BUILD_DIR)/*.bin $(BUILD_DIR)/*.img $(BUILD_DIR)/*.o
