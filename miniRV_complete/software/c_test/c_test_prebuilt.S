    .section .text.start
    .globl _start
_start:
    lui     t0, 0xffff0          # switch
    lui     t1, 0xffff1          # LED
    lui     t2, 0xffff2          # digital display
    lui     t3, 0xffff3          # UART
    lui     t4, 0xffff4          # timer

    li      t5, 'O'
wait_o:
    lw      t6, 8(t3)
    andi    t6, t6, 4
    beqz    t6, wait_o
    sw      t5, 4(t3)

    li      t5, 'K'
wait_k:
    lw      t6, 8(t3)
    andi    t6, t6, 4
    beqz    t6, wait_k
    sw      t5, 4(t3)

    li      t5, '\r'
wait_cr:
    lw      t6, 8(t3)
    andi    t6, t6, 4
    beqz    t6, wait_cr
    sw      t5, 4(t3)

    li      t5, '\n'
wait_lf:
    lw      t6, 8(t3)
    andi    t6, t6, 4
    beqz    t6, wait_lf
    sw      t5, 4(t3)

loop:
    lw      s0, 0(t0)
    sw      s0, 0(t1)
    lw      s1, 0(t4)
    sw      s1, 0(t2)

    lw      s2, 8(t3)
    andi    s3, s2, 1
    beqz    s3, loop_next
    lw      s4, 0(t3)
wait_echo:
    lw      t6, 8(t3)
    andi    t6, t6, 4
    beqz    t6, wait_echo
    sw      s4, 4(t3)
loop_next:
    j       loop
