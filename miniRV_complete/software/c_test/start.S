    .section .text.start
    .globl _start
_start:
    lui     sp, 0x20
    addi    sp, sp, -16
    call    main
1:
    j       1b

