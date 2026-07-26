ADD_ASM_MACRO ?= -D__ASSEMBLY__=1

FLAGS = -O2 -funroll-loops -fpeel-loops -fgcse-sm -fgcse-las $(ADD_FLAGS)
FLAGS_STR = "$(FLAGS)"

NEWLIB = /opt/newlib
PICOLIBC = /opt/picolibc

CFLAGS_COMMON = -static -std=gnu99 -fno-common -fno-builtin-printf -DTCM=$(TCM) \
				-fno-builtin -I$(PICOLIBC)/include

CFLAGS := $(FLAGS) $(EXT_CFLAGS) \
$(CFLAGS_COMMON) \
-DFLAGS_STR=\"$(FLAGS_STR)\" \
$(ADD_CFLAGS)

LDFLAGS   ?= -L$(PICOLIBC)/lib -static-libgcc -nostartfiles -nostdlib -lc -lgcc

ifeq (,$(findstring 0,$(TCM)))
ld_script := $(inc_dir)/ram.lds
asm_src   ?= init_asm.S
else
ld_script := $(inc_dir)/ram.lds
asm_src   ?= init_asm.S
endif

VPATH += $(src_dir) $(inc_dir) $(ADD_VPATH)
incs  += -I$(src_dir) -I$(inc_dir) $(ADD_incs)

c_objs   := $(addprefix $(bld_dir)/,$(patsubst %.c, %.o, $(c_src)))
asm_objs := $(addprefix $(bld_dir)/,$(patsubst %.S, %.o, $(asm_src)))

.PHONY: all
all: $(bld_dir)/coremark.dump $(bld_dir)/coremark.hex

$(bld_dir)/%.o: %.S
	$(GCC) $(CFLAGS) $(ADD_ASM_MACRO) -c $(incs) $< -o $@

$(bld_dir)/%.o: %.c
	$(GCC) $(CFLAGS) -c $(incs) $< -o $@

$(bld_dir)/coremark.elf: $(ld_script) $(c_objs) $(asm_objs)
	$(GCC) -o $@ -T $^ $(LDFLAGS)

$(bld_dir)/coremark.bin: $(bld_dir)/coremark.elf
	$(OBJCOPY) -O binary $^ $@

$(bld_dir)/coremark.hex: $(bld_dir)/coremark.bin
	od -t x4 -An -w4 -v $^ > $@
	
$(bld_dir)/coremark.dump: $(bld_dir)/coremark.elf
	$(OBJDUMP) $^ > $@
