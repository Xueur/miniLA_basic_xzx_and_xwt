ENTRY(_start)

MEMORY
{
    BRAM (rwx) : ORIGIN = 0x00000000, LENGTH = 128K
}

SECTIONS
{
    . = ORIGIN(BRAM);
    .text : {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
    } > BRAM

    .data : {
        *(.data*)
    } > BRAM

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    } > BRAM

    . = ALIGN(16);
    _end = .;
}

