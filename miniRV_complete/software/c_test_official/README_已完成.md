# 老师正式 C_TEST 0～4

- 学号：`2024311373`
- 测试0：5处 TODO 已完成
- 测试1：5处 TODO 已完成
- 测试2：5处 TODO 已完成
- 测试3：老师原文件无 TODO，保持原样
- 测试4：老师原文件无 TODO，`MHZ=50`
- 测试5：不在本交付范围内

同时修复了老师源码中两处未标 TODO 的问题：

1. 测试1和测试2的 `vscanf()` 首次调用不再解引用空指针。
2. 测试2的 `delay_ms()` 使用正确的 `CLKS_PER_SEC`。

在课程虚拟机中执行：

```sh
chmod +x compile_all_0_to_4.sh
./compile_all_0_to_4.sh
```

也可以进入单个目录运行 `./compile.sh`；CoreMark目录使用 `make`。

测试3会访问 `0x20000000` 的外部DDR。只有连接了DDR控制器的SoC工程
才能完成它的下板测试；编译成功不等于DDR下板通过。
