KERNEL_OBJS = boot.o gdt.o idt.o irq.o
FORTH_OBJS = forth_core.o forth_words.o kernel_words.o kernel_debug.o kernel_video.o kernel_kbd.o \
			 kernel_pit.o kernel_test.o kbd_map.o  kernel.o 
FORTH_INC = forth_core.h forth_words.h kernel_words.h kernel_debug.h  kernel_video.h 
TEST_OBJS = forth_core.o forth_words.o test.o
# Clean files
# Headers to clean
DEL_H_OBJS = forth_core.h forth_words.h kernel.h
# Objects which .h and .s files should be clean
DEL_H_S_OBJS = idt.fth kernel_kbd.fth kernel_debug.fth kernel_test.fth  kernel_video.fth  kernel_words.fth \
			   kernel_pit.fth irq.fth test.fth kernel.fth

LDFLAGS = -Tlink.ld  -melf_i386
ASFLAGS = -g -felf32
asm = nasm
naturaldocs = /usr/bin/naturaldocs

.PHONY: docs
.SUFFIXES: .fth

.fth.s:
	./forth2s.py -i $< -o $@
	./s2h $@

.s.h:
	./s2h $<

.s.o:
	$(asm) $(ASFLAGS) $<

kernel: $(FORTH_INC) $(KERNEL_OBJS) $(FORTH_OBJS)
	ld $(LDFLAGS) -o kernel $(KERNEL_OBJS) $(FORTH_OBJS)

image: kernel
	cp -f floppy.orig.img floppy.img
	sudo losetup /dev/loop0 floppy.img
	sudo mount /dev/loop0 /mnt
	sudo cp kernel /mnt/kernel
	sudo cp forth.f /mnt/forth.f
	-sudo umount /dev/loop0
	-sudo losetup -d /dev/loop0 

test: $(TEST_OBJS)
	ld -melf_i386 -o test $(TEST_OBJS)

run: image
	qemu  -fda floppy.img  


test.o: forth_words.h
forth_words.o: forth_core.h
kernel_words.o: forth_words.h forth_core.h
kernel_debug.o: kernel_words.h forth_words.h forth_core.h
kernel_video.o: kernel_words.h forth_words.h forth_core.h
kernel_kbd.o: kernel_video.h kernel_video.s kernel_words.h forth_words.h forth_core.h
kernel_pit.o: kernel_words.h forth_words.h forth_core.h
kernel_test.o:  kernel_words.h forth_words.h forth_core.h kernel_debug.h

kernel.o: kernel.s 
irq.o: irq.h irq.s
idt.o: idt.h idt.s

# Generating documentation.
# Be sure to add "s" and "fth" to "Extensions:" in "Language: Assembly"
# in /usr/share/perl5/naturaldocs/Config/Languages.txt
docs: 
	$(naturaldocs) -i . -p docs -o HTML docs 

clean:
	-rm -f $(DEL_H_OBJS)
	-rm -f $(DEL_H_S_OBJS:.fth=.h)
	-rm -f $(DEL_H_S_OBJS:.fth=.s)
	-rm -f *.o core kernel test

