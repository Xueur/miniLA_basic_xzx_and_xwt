# 数据冒险测试程序
# 用于观察流水线如何通过前递、Load-Use 停顿、WB->ID 旁路处理数据冒险

.text
MAIN:
    # ===== 第一部分：前递（EX/MEM 前递）=====
    # add.w 的结果被下一条 sub.w 使用，触发 EX/MEM 前递
    addi.w  $t0, $zero, 3     # t0 = 3
    addi.w  $t1, $zero, 5     # t1 = 5
    add.w   $t2, $t0, $t1     # t2 = t0 + t1 = 8
    sub.w   $t3, $t2, $t1     # t3 = t2 - t1 = 3   <-- 前递取 t2
    add.w   $t4, $t3, $t0     # t4 = t3 + t0 = 6   <-- 前递取 t3

    # ===== 第二部分：Load-Use 停顿 =====
    # load 结果被下一条指令使用，触发 Load-Use 停顿
    lu12i.w $t5, 0x1          # t5 = 0x1000（访存地址）
    ld.w    $t6, $t5, 0       # t6 = mem[0x1000]
    add.w   $t7, $t6, $t1     # t7 = t6 + t1       <-- Load-Use 停顿

    # ===== 停机标记 =====
    .word   0x2b0000
