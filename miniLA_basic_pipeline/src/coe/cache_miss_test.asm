# Cache 缺失测试程序
# 用于观察 DCache 发生缺失 -> 向 AXI 总线发出读请求 -> 总线读主存 -> 返回数据给 Cache 的过程

.text
MAIN:
    # ===== DCache 读缺失 =====
    lu12i.w $t0, 0x1          # t0 = 0x1000（访存地址）
    ld.w    $t1, $t0, 0       # 读 mem[0x1000]  <-- 第一次读，DCache miss
    ld.w    $t2, $t0, 4       # 读 mem[0x1004]  <-- 与上一行同一 Cache 行
    ld.w    $t3, $t0, 8       # 读 mem[0x1008]  <-- 同一 Cache 行

    # ===== 使用读回的数据 + 写内存 =====
    add.w   $t4, $t1, $t2     # t4 = t1 + t2
    st.w    $t4, $t0, 16      # 写 mem[0x1010]  <-- DCache 写

    # ===== 停机标记 =====
    .word   0x2b0000
