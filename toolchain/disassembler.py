#!/usr/bin/env python3
"""
KOCTA-16 Disassembler
Decodes 16-bit hex machine code into assembly mnemonics.
"""

import sys

OPNAMES = {
    0x0: "NOP",
    0x1: "ADD",
    0x2: "SUB",
    0x3: "AND",
    0x4: "OR",
    0x5: "XOR",
    0x6: "CMP",
    0x7: "LDI",
    0x8: "LDH",
    0x9: "LOAD",
    0xA: "STORE",
    0xB: "BRANCH",
    0xC: "SHL",
    0xD: "SHR",
    0xE: "SYS",
    0xF: "CROSS_XOR",
}

BRANCH_NAMES = {
    0x0: "BEQ",
    0x1: "BNE",
    0x2: "BLT",
    0x3: "BGE",
    0x4: "JMP",
    0x5: "CALL",
    0x6: "RET",
}

def disassemble_word(code):
    op = (code >> 12) & 0xF
    rd = (code >> 8) & 0xF
    rs1 = (code >> 4) & 0xF
    rs2 = code & 0xF
    imm8 = code & 0xFF

    if op == 0x0:
        return "NOP"
    elif op in [0x1, 0x2, 0x3, 0x4, 0x5, 0xF]:
        return f"{OPNAMES[op]} R{rd}, R{rs1}, R{rs2}"
    elif op == 0x6:
        return f"CMP R{rs1}, R{rs2}"
    elif op == 0x7:
        return f"LDI R{rd}, 0x{imm8:02X}"
    elif op == 0x8:
        return f"LDH R{rd}, 0x{imm8:02X}"
    elif op == 0x9:
        return f"LOAD R{rd}, [R{rs1} + {rs2}]"
    elif op == 0xA:
        return f"STORE R{rd}, [R{rs1} + {rs2}]"
    elif op == 0xB:
        cond = rd
        bname = BRANCH_NAMES.get(cond, f"BRANCH_{cond}")
        if cond == 0x6:
            return "RET"
        return f"{bname} 0x{imm8:02X}"
    elif op in [0xC, 0xD]:
        return f"{OPNAMES[op]} R{rd}, R{rs1}, {rs2}"
    elif op == 0xE:
        if rd == 0 and (imm8 == 0x00 or imm8 == 0xFF):
            return "HALT"
        return f"PUSH_LOGIC R{rd}, R{rs1}, R{rs2}"
    return f"UNKNOWN 0x{code:04X}"

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 disassembler.py <firmware.hex>")
        sys.exit(1)

    with open(sys.argv[1], "r") as f:
        lines = f.readlines()

    addr = 0
    for line in lines:
        line = line.strip()
        if not line or line.startswith("//") or line.startswith(";"):
            continue
        code = int(line, 16)
        disasm = disassemble_word(code)
        print(f"[{addr:02X}]  0x{code:04X}  :  {disasm}")
        addr += 1

if __name__ == "__main__":
    main()
