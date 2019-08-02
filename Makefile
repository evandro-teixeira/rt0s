.PHONY: all

PFX := @arm-none-eabi
AFLAGS := -mcpu=cortex-m0 -mthumb -ggdb
LDFLAGS :=
CFLAGS := -ggdb -o0 -fno-builtin
BOARD := stm32f0308-disco

all: elf

elf: asm c
	$(PFX)-ld -Tboards/$(BOARD)/linker.ld rt0s.o $(BOARD).o \
		$(LDFLAGS) -o rt0s.elf
	$(PFX)-objcopy -R .data -O ihex rt0s.elf rt0s.hex
	$(PFX)-objdump -marm -D -Mforce-thumb rt0s.elf > rt0s.lst
	$(PFX)-ld -Tboards/$(BOARD)/linker.ld rt0s.o $(LDFLAGS) -o kernel.elf
	$(PFX)-size kernel.elf
	@rm kernel.elf
	@rm *.o

asm: rt0s.s
	$(PFX)-as $(AFLAGS) -Iboards/$(BOARD)/ -o rt0s.o rt0s.s

c: boards/$(BOARD)/main.c
	$(PFX)-gcc -fno-builtin-free -fno-builtin-memset -mcpu=cortex-m0 -mthumb \
		-c $(CFLAGS) -I./ -Wall $^ -o $(BOARD).o

clean:
	rm -rf *.elf *.o *.bin *.hex *.lst *.map

flash:
	@JLinkExe -device STM32F030R8 -if SWD -speed 4000 -autoconnect 1 \
		-CommanderScript script/flash.jlink

debug_server:
	@JLinkGDBServerCL -select USB -device STM32F030R8 -endian little -if JTAG \
		-speed 4000 -noir

debug:
	script/tmux.sh

