#!/usr/bin/env python3
"""Generate the dependency-free C_TEST image used by the EGO1 bitstream."""

from pathlib import Path


def i_type(imm, rs1, funct3, rd, opcode=0x13):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | \
           (rd << 7) | opcode


def s_type(imm, rs2, rs1, funct3=2):
    value = imm & 0xFFF
    return ((value >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | ((value & 0x1F) << 7) | 0x23


def b_type(offset, rs2, rs1, funct3=0):
    value = offset & 0x1FFF
    return (((value >> 12) & 1) << 31) | \
           (((value >> 5) & 0x3F) << 25) | \
           (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | \
           (((value >> 1) & 0xF) << 8) | \
           (((value >> 11) & 1) << 7) | 0x63


def u_type(imm20, rd):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37


def j_type(offset, rd=0):
    value = offset & 0x1FFFFF
    return (((value >> 20) & 1) << 31) | \
           (((value >> 1) & 0x3FF) << 21) | \
           (((value >> 11) & 1) << 20) | \
           (((value >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F


class Program:
    def __init__(self):
        self.words = []
        self.labels = {}
        self.fixups = []

    def label(self, name):
        self.labels[name] = len(self.words)

    def emit(self, word):
        self.words.append(word)

    def branch_zero(self, rs1, target):
        self.fixups.append((len(self.words), "b", target, rs1))
        self.words.append(0)

    def jump(self, target):
        self.fixups.append((len(self.words), "j", target, 0))
        self.words.append(0)

    def resolve(self):
        for index, kind, target, register in self.fixups:
            offset = (self.labels[target] - index) * 4
            if kind == "b":
                self.words[index] = b_type(offset, 0, register)
            else:
                self.words[index] = j_type(offset)


def main():
    p = Program()
    t0, t1, t2, t3, t4, t5, t6 = 5, 6, 7, 28, 29, 30, 31
    s0, s1, s2, s3, s4 = 8, 9, 18, 19, 20

    for upper, rd in [
        (0xFFFF0, t0), (0xFFFF1, t1), (0xFFFF2, t2),
        (0xFFFF3, t3), (0xFFFF4, t4),
    ]:
        p.emit(u_type(upper, rd))

    for character, wait_label in [
        (ord("O"), "wait_o"), (ord("K"), "wait_k"),
        (ord("\r"), "wait_cr"), (ord("\n"), "wait_lf"),
    ]:
        p.emit(i_type(character, 0, 0, t5))
        p.label(wait_label)
        p.emit(i_type(8, t3, 2, t6, opcode=0x03))
        p.emit(i_type(4, t6, 7, t6))
        p.branch_zero(t6, wait_label)
        p.emit(s_type(4, t5, t3))

    p.label("loop")
    p.emit(i_type(0, t0, 2, s0, opcode=0x03))
    p.emit(s_type(0, s0, t1))
    p.emit(i_type(0, t4, 2, s1, opcode=0x03))
    p.emit(s_type(0, s1, t2))
    p.emit(i_type(8, t3, 2, s2, opcode=0x03))
    p.emit(i_type(1, s2, 7, s3))
    p.branch_zero(s3, "loop_next")
    p.emit(i_type(0, t3, 2, s4, opcode=0x03))
    p.label("wait_echo")
    p.emit(i_type(8, t3, 2, t6, opcode=0x03))
    p.emit(i_type(4, t6, 7, t6))
    p.branch_zero(t6, "wait_echo")
    p.emit(s_type(4, s4, t3))
    p.label("loop_next")
    p.jump("loop")
    p.resolve()

    output = Path(__file__).resolve().parents[1] / \
        "software" / "c_test" / "c_test.hex"
    output.write_text(
        "".join(f"{word:08x}\n" for word in p.words),
        encoding="ascii",
    )
    print(f"generated {output} ({len(p.words)} words)")


if __name__ == "__main__":
    main()
