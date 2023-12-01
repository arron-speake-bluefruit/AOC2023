.PHONY: all clean

all: one-1.elf one-2.elf

clean:
	rm -f *.elf *.o

%.S.o: %.S
	as -g $^ -o $@

%.elf: %.S.o common.S.o
	ld $^ -o $@
