from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

P = []
L = {}


def emit(op, *args):
    P.append((op, args))


def label(name):
    L[name] = len(P)


emit("addi", 30, 0, 1536)
emit("addi", 1, 0, 7)
emit("addi", 2, 0, -3)
emit("lui", 3, 0x80000)
emit("addi", 4, 0, 4)

emit("sll", 5, 1, 4)
emit("srl", 5, 3, 4)
emit("srli", 5, 3, 4)
emit("sra", 5, 3, 4)
emit("srai", 5, 3, 4)
emit("slli", 5, 1, 3)
emit("add", 5, 1, 2)
emit("sub", 5, 1, 2)
emit("auipc", 5, 0x00001)
emit("xor", 5, 1, 2)
emit("xori", 5, 1, -1)
emit("or", 5, 1, 2)
emit("ori", 5, 1, 0x155)
emit("and", 5, 1, 2)
emit("andi", 5, 2, 0x0F0)

emit("slt", 5, 2, 1)
emit("slti", 5, 2, 0)
emit("sltu", 5, 2, 1)
emit("sltiu", 5, 1, -1)

emit("mul", 5, 1, 2)
emit("lui", 6, 0x80000)
emit("addi", 7, 0, -2)
emit("mulh", 5, 6, 7)
emit("mulhu", 5, 6, 7)
emit("div", 5, 1, 2)
emit("divu", 5, 2, 1)
emit("rem", 5, 1, 2)
emit("remu", 5, 2, 1)

emit("lb", 5, 30, 2)
emit("lbu", 5, 30, 3)
emit("lh", 5, 30, 0)
emit("lhu", 5, 30, 2)
emit("lw", 5, 30, 0)

emit("lui", 6, 0x0000C)
emit("addi", 6, 6, -273)
emit("sw", 6, 30, 4)
emit("addi", 7, 0, 0x0AA)
emit("sb", 7, 30, 9)
emit("sh", 6, 30, 14)
emit("lw", 5, 30, 4)
emit("lw", 5, 30, 8)
emit("lw", 5, 30, 12)

emit("addi", 7, 0, 7)
emit("addi", 5, 0, 1)
emit("beq", 1, 7, "beq_ok")
emit("addi", 5, 0, 0)
label("beq_ok")
emit("addi", 5, 5, 0)

emit("addi", 5, 0, 1)
emit("bne", 1, 2, "bne_ok")
emit("addi", 5, 0, 0)
label("bne_ok")
emit("addi", 5, 5, 0)

emit("addi", 5, 0, 1)
emit("blt", 2, 1, "blt_ok")
emit("addi", 5, 0, 0)
label("blt_ok")
emit("addi", 5, 5, 0)

emit("addi", 5, 0, 1)
emit("bge", 1, 2, "bge_ok")
emit("addi", 5, 0, 0)
label("bge_ok")
emit("addi", 5, 5, 0)

emit("addi", 5, 0, 1)
emit("bltu", 1, 2, "bltu_ok")
emit("addi", 5, 0, 0)
label("bltu_ok")
emit("addi", 5, 5, 0)

emit("addi", 5, 0, 1)
emit("bgeu", 2, 1, "bgeu_ok")
emit("addi", 5, 0, 0)
label("bgeu_ok")
emit("addi", 5, 5, 0)

emit("jal", 5, "jal_ok")
emit("addi", 28, 0, 0)
label("jal_ok")
emit("addi", 28, 0, 1)

label("jalr_base")
emit("auipc", 6, 0)
emit("addi", 6, 6, 17)
emit("jalr", 5, 6, 0)
emit("addi", 28, 0, 0)
label("jalr_ok")
emit("addi", 28, 0, 1)
emit("ecall")


def u32(x):
    return x & 0xFFFFFFFF


def s32(x):
    x &= 0xFFFFFFFF
    return x - 0x100000000 if x & 0x80000000 else x


def enc_r(f7, rs2, rs1, f3, rd, opc=0x33):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc


def enc_i(imm, rs1, f3, rd, opc=0x13):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc


def enc_s(imm, rs2, rs1, f3):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | 0x23


def enc_b(imm, rs2, rs1, f3):
    imm &= 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63


def enc_u(imm20, rd, opc):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | opc


def enc_j(imm, rd):
    imm &= 0x1FFFFF
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F


R = {
    "add": (0x00, 0), "sub": (0x20, 0), "sll": (0x00, 1),
    "slt": (0x00, 2), "sltu": (0x00, 3), "xor": (0x00, 4),
    "srl": (0x00, 5), "sra": (0x20, 5), "or": (0x00, 6),
    "and": (0x00, 7), "mul": (0x01, 0), "mulh": (0x01, 1),
    "mulhu": (0x01, 3), "div": (0x01, 4), "divu": (0x01, 5),
    "rem": (0x01, 6), "remu": (0x01, 7),
}
I = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
LOAD = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
STORE = {"sb": 0, "sh": 1, "sw": 2}
BRANCH = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}


def encode(index, ins):
    op, a = ins
    pc = index * 4
    if op in R:
        rd, rs1, rs2 = a
        f7, f3 = R[op]
        return enc_r(f7, rs2, rs1, f3, rd)
    if op in I:
        rd, rs1, imm = a
        return enc_i(imm, rs1, I[op], rd)
    if op in ("slli", "srli", "srai"):
        rd, rs1, shamt = a
        f3 = 1 if op == "slli" else 5
        imm = shamt | (0x400 if op == "srai" else 0)
        return enc_i(imm, rs1, f3, rd)
    if op in LOAD:
        rd, rs1, imm = a
        return enc_i(imm, rs1, LOAD[op], rd, 0x03)
    if op in STORE:
        rs2, rs1, imm = a
        return enc_s(imm, rs2, rs1, STORE[op])
    if op in BRANCH:
        rs1, rs2, target = a
        return enc_b(L[target] * 4 - pc, rs2, rs1, BRANCH[op])
    if op == "lui":
        return enc_u(a[1], a[0], 0x37)
    if op == "auipc":
        return enc_u(a[1], a[0], 0x17)
    if op == "jal":
        return enc_j(L[a[1]] * 4 - pc, a[0])
    if op == "jalr":
        rd, rs1, imm = a
        return enc_i(imm, rs1, 0, rd, 0x67)
    if op == "ecall":
        return 0x00000073
    raise ValueError(op)


def load_mem(mem, addr, n, signed=False):
    value = sum(mem.get(addr + i, 0) << (8 * i) for i in range(n))
    if signed and value & (1 << (8 * n - 1)):
        value -= 1 << (8 * n)
    return u32(value)


def store_mem(mem, addr, value, n):
    for i in range(n):
        mem[addr + i] = (value >> (8 * i)) & 0xFF


def div_signed(a, b):
    a, b = s32(a), s32(b)
    if b == 0:
        return 0xFFFFFFFF
    if a == -0x80000000 and b == -1:
        return 0x80000000
    q = abs(a) // abs(b)
    return u32(-q if (a < 0) ^ (b < 0) else q)


def rem_signed(a, b):
    aa, bb = s32(a), s32(b)
    if bb == 0:
        return u32(aa)
    if aa == -0x80000000 and bb == -1:
        return 0
    q = s32(div_signed(aa, bb))
    return u32(aa - q * bb)


def simulate():
    regs = [0] * 32
    mem = {}
    store_mem(mem, 0x600, 0x80FF7F01, 4)
    store_mem(mem, 0x608, 0x11223344, 4)
    store_mem(mem, 0x60C, 0x11223344, 4)
    pc = 0
    pcs = []
    wbs = []

    def write(rd, value):
        value = u32(value)
        if rd:
            regs[rd] = value
            wbs.append((rd, value))

    for _ in range(1000):
        idx = pc // 4
        op, a = P[idx]
        pcs.append(pc)
        npc = pc + 4

        if op == "ecall":
            return pcs, wbs, mem
        if op in I:
            rd, rs1, imm = a
            if op == "addi": value = regs[rs1] + imm
            elif op == "slti": value = int(s32(regs[rs1]) < imm)
            elif op == "sltiu": value = int(regs[rs1] < u32(imm))
            elif op == "xori": value = regs[rs1] ^ u32(imm)
            elif op == "ori": value = regs[rs1] | u32(imm)
            else: value = regs[rs1] & u32(imm)
            write(rd, value)
        elif op in ("slli", "srli", "srai"):
            rd, rs1, shamt = a
            if op == "slli": value = regs[rs1] << shamt
            elif op == "srli": value = regs[rs1] >> shamt
            else: value = s32(regs[rs1]) >> shamt
            write(rd, value)
        elif op in R:
            rd, rs1, rs2 = a
            x, y = regs[rs1], regs[rs2]
            if op == "add": value = x + y
            elif op == "sub": value = x - y
            elif op == "sll": value = x << (y & 31)
            elif op == "srl": value = x >> (y & 31)
            elif op == "sra": value = s32(x) >> (y & 31)
            elif op == "slt": value = int(s32(x) < s32(y))
            elif op == "sltu": value = int(x < y)
            elif op == "xor": value = x ^ y
            elif op == "or": value = x | y
            elif op == "and": value = x & y
            elif op == "mul": value = s32(x) * s32(y)
            elif op == "mulh": value = (u32(s32(x) * s32(y)) if False else (s32(x) * s32(y)) & 0xFFFFFFFFFFFFFFFF) >> 32
            elif op == "mulhu": value = (x * y) >> 32
            elif op == "div": value = div_signed(x, y)
            elif op == "divu": value = 0xFFFFFFFF if y == 0 else x // y
            elif op == "rem": value = rem_signed(x, y)
            else: value = x if y == 0 else x % y
            write(rd, value)
        elif op in LOAD:
            rd, rs1, imm = a
            addr = u32(regs[rs1] + imm)
            n = 1 if op in ("lb", "lbu") else 2 if op in ("lh", "lhu") else 4
            write(rd, load_mem(mem, addr, n, op in ("lb", "lh")))
        elif op in STORE:
            rs2, rs1, imm = a
            addr = u32(regs[rs1] + imm)
            n = 1 if op == "sb" else 2 if op == "sh" else 4
            store_mem(mem, addr, regs[rs2], n)
        elif op in BRANCH:
            rs1, rs2, target = a
            x, y = regs[rs1], regs[rs2]
            take = {
                "beq": x == y, "bne": x != y,
                "blt": s32(x) < s32(y), "bge": s32(x) >= s32(y),
                "bltu": x < y, "bgeu": x >= y,
            }[op]
            if take:
                npc = L[target] * 4
        elif op == "lui":
            write(a[0], a[1] << 12)
        elif op == "auipc":
            write(a[0], pc + (a[1] << 12))
        elif op == "jal":
            write(a[0], pc + 4)
            npc = L[a[1]] * 4
        elif op == "jalr":
            rd, rs1, imm = a
            target = u32(regs[rs1] + imm) & 0xFFFFFFFE
            write(rd, pc + 4)
            npc = target
        else:
            raise ValueError(op)

        regs[0] = 0
        pc = u32(npc)
    raise RuntimeError("program did not finish")


def asm_line(op, a):
    if op in R:
        return f"{op} x{a[0]}, x{a[1]}, x{a[2]}"
    if op in I or op in ("slli", "srli", "srai"):
        return f"{op} x{a[0]}, x{a[1]}, {a[2]}"
    if op in LOAD:
        return f"{op} x{a[0]}, {a[2]}(x{a[1]})"
    if op in STORE:
        return f"{op} x{a[0]}, {a[2]}(x{a[1]})"
    if op in BRANCH:
        return f"{op} x{a[0]}, x{a[1]}, {a[2]}"
    if op in ("lui", "auipc"):
        return f"{op} x{a[0]}, 0x{a[1]:x}"
    if op == "jal":
        return f"jal x{a[0]}, {a[1]}"
    if op == "jalr":
        return f"jalr x{a[0]}, {a[2]}(x{a[1]})"
    return op


def write_tb(words, pcs, wbs, mem):
    init = []
    for i, word in enumerate(words):
        init.append(f"        imem[{i}] = 32'h{word:08x};")
    for i, pc in enumerate(pcs):
        init.append(f"        expected_pc[{i}] = 32'h{pc:08x};")
    for i, (rd, value) in enumerate(wbs):
        init.append(f"        expected_wb_rd[{i}] = 5'd{rd}; expected_wb_data[{i}] = 32'h{value:08x};")

    mem4 = load_mem(mem, 0x604, 4)
    mem8 = load_mem(mem, 0x608, 4)
    memc = load_mem(mem, 0x60C, 4)

    tb = f'''`timescale 1ns / 1ps

module cpu_core_all_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;

    wire ifetch_req;
    wire [31:0] ifetch_addr;
    reg ifetch_valid = 1'b0;
    reg [31:0] ifetch_inst = 32'h13;

    wire [3:0] daccess_ren;
    wire [31:0] daccess_addr;
    reg daccess_rvalid = 1'b0;
    reg [31:0] daccess_rdata = 32'h0;
    wire [3:0] daccess_wen;
    wire [31:0] daccess_wdata;
    reg daccess_wresp = 1'b0;

    reg [31:0] imem [0:255];
    reg [31:0] dmem [0:1023];
    reg [31:0] expected_pc [0:{len(pcs)-1}];
    reg [4:0] expected_wb_rd [0:{len(wbs)-1}];
    reg [31:0] expected_wb_data [0:{len(wbs)-1}];

    integer i;
    integer pc_count = 0;
    integer wb_count = 0;

    always #5 clk = ~clk;

    initial begin
        for (i = 0; i < 256; i = i + 1) imem[i] = 32'h00000013;
        for (i = 0; i < 1024; i = i + 1) dmem[i] = 32'h0;
        dmem[384] = 32'h80ff7f01;
        dmem[386] = 32'h11223344;
        dmem[387] = 32'h11223344;
{chr(10).join(init)}
        #37 rst = 1'b0;
    end

    always @(posedge clk) begin
        if (rst) begin
            ifetch_valid <= 1'b0;
            daccess_rvalid <= 1'b0;
            daccess_wresp <= 1'b0;
        end else begin
            ifetch_valid <= ifetch_req;
            if (ifetch_req) ifetch_inst <= imem[ifetch_addr[9:2]];

            daccess_rvalid <= |daccess_ren;
            if (|daccess_ren) daccess_rdata <= dmem[daccess_addr[11:2]];
            daccess_wresp <= |daccess_wen;
            if (daccess_wen[0]) dmem[daccess_addr[11:2]][7:0] <= daccess_wdata[7:0];
            if (daccess_wen[1]) dmem[daccess_addr[11:2]][15:8] <= daccess_wdata[15:8];
            if (daccess_wen[2]) dmem[daccess_addr[11:2]][23:16] <= daccess_wdata[23:16];
            if (daccess_wen[3]) dmem[daccess_addr[11:2]][31:24] <= daccess_wdata[31:24];
        end
    end

    always @(negedge clk) begin
        if (!rst) begin
            if (ifetch_valid) begin
                if (pc_count >= {len(pcs)}) $fatal(1, "PC trace is longer than expected");
                if (DUT.pc !== expected_pc[pc_count])
                    $fatal(1, "PC mismatch at %0d: got %08x expected %08x", pc_count, DUT.pc, expected_pc[pc_count]);
                pc_count = pc_count + 1;
            end

            if (DUT.rf_we1 && DUT.rf_wR != 5'h0) begin
                if (wb_count >= {len(wbs)}) $fatal(1, "WB trace is longer than expected");
                if (DUT.rf_wR !== expected_wb_rd[wb_count] || DUT.rf_wD !== expected_wb_data[wb_count])
                    $fatal(1, "WB mismatch at %0d: got x%0d=%08x expected x%0d=%08x",
                           wb_count, DUT.rf_wR, DUT.rf_wD,
                           expected_wb_rd[wb_count], expected_wb_data[wb_count]);
                wb_count = wb_count + 1;
            end

            if (ifetch_valid && ifetch_inst == 32'h00000073) begin
                if (pc_count != {len(pcs)}) $fatal(1, "PC trace ended early: %0d/{len(pcs)}", pc_count);
                if (wb_count != {len(wbs)}) $fatal(1, "WB trace ended early: %0d/{len(wbs)}", wb_count);
                if (dmem[385] !== 32'h{mem4:08x}) $fatal(1, "SW failed: %08x", dmem[385]);
                if (dmem[386] !== 32'h{mem8:08x}) $fatal(1, "SB failed: %08x", dmem[386]);
                if (dmem[387] !== 32'h{memc:08x}) $fatal(1, "SH failed: %08x", dmem[387]);
                $display("ALL 44 miniRV INSTRUCTIONS PASSED");
                $finish;
            end
        end
    end

    initial begin
        #200000;
        $fatal(1, "timeout");
    end

    cpu_core DUT (
        .cpu_rst(rst), .cpu_clk(clk),
        .ifetch_req(ifetch_req), .ifetch_addr(ifetch_addr),
        .ifetch_valid(ifetch_valid), .ifetch_inst(ifetch_inst),
        .daccess_ren(daccess_ren), .daccess_addr(daccess_addr),
        .daccess_rvalid(daccess_rvalid), .daccess_rdata(daccess_rdata),
        .daccess_wen(daccess_wen), .daccess_wdata(daccess_wdata),
        .daccess_wresp(daccess_wresp)
    );
endmodule
'''
    (ROOT / "src/sim/cpu_core_all_tb.v").write_text(tb, encoding="utf-8")


def main():
    words = [encode(i, ins) for i, ins in enumerate(P)]
    pcs, wbs, mem = simulate()

    required = {
        "slli", "addi", "lui", "ori", "lw", "jal", "beq", "bne",
        "sll", "srl", "srli", "sra", "srai", "add", "sub", "auipc",
        "xor", "xori", "lb", "lbu", "lh", "lhu", "sw", "sb", "sh", "jalr",
        "mul", "mulh", "mulhu", "div", "divu", "rem", "remu", "slt", "slti",
        "sltu", "sltiu", "or", "and", "andi", "blt", "bge", "bltu", "bgeu",
    }
    covered = {op for op, _ in P}
    missing = required - covered
    if missing:
        raise RuntimeError(f"missing instructions: {sorted(missing)}")

    coe = "memory_initialization_radix=16;\nmemory_initialization_vector=\n"
    coe += ",\n".join(f"{w:08x}" for w in words) + ";\n"
    (ROOT / "src/coe/all_instructions_test.coe").write_text(coe, encoding="ascii")
    (ROOT / "src/coe/all_instructions_test.hex").write_text(
        "\n".join(f"{w:08x}" for w in words) + "\n", encoding="ascii"
    )

    reverse_labels = {}
    for name, idx in L.items():
        reverse_labels.setdefault(idx, []).append(name)
    listing = []
    for i, ins in enumerate(P):
        for name in reverse_labels.get(i, []):
            listing.append(f"{name}:")
        listing.append(f"    {asm_line(*ins)}")
    (ROOT / "src/coe/all_instructions_test.asm").write_text(
        "\n".join(listing) + "\n", encoding="utf-8"
    )

    report = [
        "miniRV 44-instruction self-test",
        f"program instructions: {len(P)}",
        f"fetched PC trace entries: {len(pcs)}",
        f"register write trace entries: {len(wbs)}",
        f"covered required mnemonics: {len(required)}/44",
        "covered: " + ", ".join(sorted(required)),
    ]
    (ROOT / "docs/self_test_coverage.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
    write_tb(words, pcs, wbs, mem)


if __name__ == "__main__":
    main()
