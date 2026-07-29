    addi x30, x0, 1536
    addi x1, x0, 7
    addi x2, x0, -3
    lui x3, 0x80000
    addi x4, x0, 4
    sll x5, x1, x4
    srl x5, x3, x4
    srli x5, x3, 4
    sra x5, x3, x4
    srai x5, x3, 4
    slli x5, x1, 3
    add x5, x1, x2
    sub x5, x1, x2
    auipc x5, 0x1
    xor x5, x1, x2
    xori x5, x1, -1
    or x5, x1, x2
    ori x5, x1, 341
    and x5, x1, x2
    andi x5, x2, 240
    slt x5, x2, x1
    slti x5, x2, 0
    sltu x5, x2, x1
    sltiu x5, x1, -1
    mul x5, x1, x2
    lui x6, 0x80000
    addi x7, x0, -2
    mulh x5, x6, x7
    mulhu x5, x6, x7
    div x5, x1, x2
    divu x5, x2, x1
    rem x5, x1, x2
    remu x5, x2, x1
    lb x5, 2(x30)
    lbu x5, 3(x30)
    lh x5, 0(x30)
    lhu x5, 2(x30)
    lw x5, 0(x30)
    lui x6, 0xc
    addi x6, x6, -273
    sw x6, 4(x30)
    addi x7, x0, 170
    sb x7, 9(x30)
    sh x6, 14(x30)
    lw x5, 4(x30)
    lw x5, 8(x30)
    lw x5, 12(x30)
    addi x7, x0, 7
    addi x5, x0, 1
    beq x1, x7, beq_ok
    addi x5, x0, 0
beq_ok:
    addi x5, x5, 0
    addi x5, x0, 1
    bne x1, x2, bne_ok
    addi x5, x0, 0
bne_ok:
    addi x5, x5, 0
    addi x5, x0, 1
    blt x2, x1, blt_ok
    addi x5, x0, 0
blt_ok:
    addi x5, x5, 0
    addi x5, x0, 1
    bge x1, x2, bge_ok
    addi x5, x0, 0
bge_ok:
    addi x5, x5, 0
    addi x5, x0, 1
    bltu x1, x2, bltu_ok
    addi x5, x0, 0
bltu_ok:
    addi x5, x5, 0
    addi x5, x0, 1
    bgeu x2, x1, bgeu_ok
    addi x5, x0, 0
bgeu_ok:
    addi x5, x5, 0
    jal x5, jal_ok
    addi x28, x0, 0
jal_ok:
    addi x28, x0, 1
jalr_base:
    auipc x6, 0x0
    addi x6, x6, 17
    jalr x5, 0(x6)
    addi x28, x0, 0
jalr_ok:
    addi x28, x0, 1
    ecall
