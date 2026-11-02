#!/usr/bin/env python3
"""
KOCTA-16 Two-Pass Assembler
Translates KOCTA-16 assembly (.asm) into machine code (.hex / .bin / .lst)
Coursework: VS ASOIU 2026, Variant 16
"""

import sys
import re
import os

OPCODES = {
    "NOP":       0x0,
    "ADD":       0x1,
    "SUB":       0x2,
    "AND":       0x3,
    "OR":        0x4,
    "XOR":       0x5,
    "CMP":       0x6,
    "LDI":       0x7,
    "LDH":       0x8,
    "LOAD":      0x9,
    "STORE":     0xA,
    "BRANCH":    0xB,
    "SHL":       0xC,
    "SHR":       0xD,
    "SYS":        0xE,
    "PUSH_LOGIC": 0xE,
    "CROSS_XOR":  0xF,
}

BRANCH_CONDS = {
    "JZ":   0x0,
    "BEQ":  0x0,
    "JNZ":  0x1,
    "BNE":  0x1,
    "JLT":  0x2,
    "BLT":  0x2,
    "JGE":  0x3,
    "BGE":  0x3,
    "JMP":  0x4,
    "CALL": 0x5,
    "RET":  0x6,
}

def parse_reg(token):
    token = token.strip().upper()
    if token.startswith("R"):
        try:
            num = int(token[1:])
            if 0 <= num <= 15:
                return num
        except ValueError:
            pass
    elif token == "ZERO":
        return 0
    elif token == "SP":
        return 13
    elif token == "LR":
        return 14
    elif token == "FLAGS":
        return 15
    raise ValueError(f"Invalid register name: '{token}' (expected R0-R15)")

def parse_val(token, symbol_table=None):
    token = token.strip()
    # Check symbol table
    if symbol_table and token in symbol_table:
        return symbol_table[token]
    # Check numeric formats
    if token.startswith("0x") or token.startswith("0X"):
        return int(token, 16)
    elif token.startswith("0b") or token.startswith("0B"):
        return int(token, 2)
    elif token.startswith("'") and token.endswith("'") and len(token) == 3:
        return ord(token[1])
    else:
        return int(token)

def parse_mem_operand(token):
    # Formats: [Rs], [Rs + Offset], [Rs+Offset], [Rs - Offset]
    token = token.strip()
    if not (token.startswith("[") and token.endswith("]")):
        raise ValueError(f"Memory operand must be enclosed in square brackets: '{token}'")
    inner = token[1:-1].strip()
    if "+" in inner:
        parts = inner.split("+")
        rs = parse_reg(parts[0].strip())
        offset = parse_val(parts[1].strip())
    elif "-" in inner:
        parts = inner.split("-")
        rs = parse_reg(parts[0].strip())
        offset = -parse_val(parts[1].strip())
    else:
        rs = parse_reg(inner)
        offset = 0
    if not (0 <= offset <= 15):
        raise ValueError(f"Memory offset must be between 0 and 15, got {offset}")
    return rs, offset

class Assembler:
    def __init__(self):
        self.symbol_table = {}
        self.source_lines = []
        self.expanded_lines = []
        self.machine_code = []

    def clean_line(self, line):
        # Remove comments //, ;, #
        for c in ["//", ";", "#"]:
            line = line.split(c)[0]
        return line.strip()

    def pass1_expand(self, lines):
        """Pass 1: Expand pseudo-instructions and collect label addresses"""
        self.expanded_lines = []
        self.symbol_table = {}
        addr = 0

        for raw_line in lines:
            line = self.clean_line(raw_line)
            if not line:
                continue

            # Check for label at line start (e.g. "LOOP:" or "LOOP: ADD R1, R2, R3")
            while ":" in line:
                label_part, rest = line.split(":", 1)
                label_name = label_part.strip()
                if not re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', label_name):
                    raise ValueError(f"Invalid label name: '{label_name}'")
                self.symbol_table[label_name] = addr
                line = rest.strip()
                if not line:
                    break

            if not line:
                continue

            # Process instruction / pseudo-instruction
            parts = re.split(r'[\s,]+', line)
            mnemonic = parts[0].upper()
            args = parts[1:]

            # Pseudo-instruction expansions
            if mnemonic == "MOV":
                # MOV Rd, Rs -> ADD Rd, Rs, R0
                self.expanded_lines.append((addr, f"ADD {args[0]}, {args[1]}, R0", line))
                addr += 1
            elif mnemonic == "CLR":
                # CLR Rd -> ADD Rd, R0, R0
                self.expanded_lines.append((addr, f"ADD {args[0]}, R0, R0", line))
                addr += 1
            elif mnemonic == "HALT":
                # HALT -> SYS 0
                self.expanded_lines.append((addr, "SYS 0", line))
                addr += 1
            elif mnemonic == "RET":
                # RET -> BRANCH 6, 0
                self.expanded_lines.append((addr, "BRANCH 6, 0", line))
                addr += 1
            elif mnemonic in BRANCH_CONDS:
                # JZ, JNZ, JLT, JGE, JMP, CALL
                cond_code = BRANCH_CONDS[mnemonic]
                target_label = args[0]
                self.expanded_lines.append((addr, f"BRANCH {cond_code}, {target_label}", line))
                addr += 1
            elif mnemonic == "LI":
                # LI Rd, Imm16 -> LDI Rd, low ; LDH Rd, high (if needed)
                rd = args[0]
                val_str = args[1]
                # Can be a number or label
                try:
                    val = parse_val(val_str)
                    if 0 <= val <= 255:
                        self.expanded_lines.append((addr, f"LDI {rd}, {val}", line))
                        addr += 1
                    else:
                        low = val & 0xFF
                        high = (val >> 8) & 0xFF
                        self.expanded_lines.append((addr, f"LDI {rd}, {low}", line))
                        addr += 1
                        self.expanded_lines.append((addr, f"LDH {rd}, {high}", line))
                        addr += 1
                except Exception:
                    # Target might be a label known in pass 2
                    self.expanded_lines.append((addr, f"LI_DEFERRED {rd}, {val_str}", line))
                    addr += 2
            else:
                self.expanded_lines.append((addr, line, line))
                addr += 1

    def pass2_assemble(self):
        """Pass 2: Generate 16-bit binary and hex words"""
        self.machine_code = []

        for addr, line, orig in self.expanded_lines:
            # Handle memory operands with brackets e.g. LOAD R1, [R2 + 4]
            # Replace [ ... ] temporarily to avoid splitting commas inside
            mem_match = re.search(r'\[.*?\]', line)
            mem_part = None
            if mem_match:
                mem_part = mem_match.group(0)
                line_placeholder = line[:mem_match.start()] + "__MEM__" + line[mem_match.end():]
                parts = re.split(r'[\s,]+', line_placeholder.strip())
                parts = [mem_part if p == "__MEM__" else p for p in parts]
            else:
                parts = re.split(r'[\s,]+', line.strip())

            mnemonic = parts[0].upper()
            args = parts[1:]

            code = 0x0000

            if mnemonic == "NOP":
                code = 0x0000

            elif mnemonic in ["ADD", "SUB", "AND", "OR", "XOR", "SLT", "CROSS_XOR", "PUSH_LOGIC"]:
                op = OPCODES[mnemonic]
                rd = parse_reg(args[0])
                rs1 = parse_reg(args[1])
                rs2 = parse_reg(args[2])
                code = (op << 12) | (rd << 8) | (rs1 << 4) | rs2

            elif mnemonic == "CMP":
                op = OPCODES["CMP"]
                rs1 = parse_reg(args[0])
                rs2 = parse_reg(args[1])
                code = (op << 12) | (0 << 8) | (rs1 << 4) | rs2

            elif mnemonic == "LDI":
                op = OPCODES["LDI"]
                rd = parse_reg(args[0])
                imm8 = parse_val(args[1], self.symbol_table) & 0xFF
                code = (op << 12) | (rd << 8) | imm8

            elif mnemonic == "LDH":
                op = OPCODES["LDH"]
                rd = parse_reg(args[0])
                imm8 = parse_val(args[1], self.symbol_table) & 0xFF
                code = (op << 12) | (rd << 8) | imm8

            elif mnemonic == "LOAD":
                op = OPCODES["LOAD"]
                rd = parse_reg(args[0])
                rs1, offset4 = parse_mem_operand(args[1])
                code = (op << 12) | (rd << 8) | (rs1 << 4) | (offset4 & 0xF)

            elif mnemonic == "STORE":
                op = OPCODES["STORE"]
                rs_data = parse_reg(args[0])
                rs_base, offset4 = parse_mem_operand(args[1])
                code = (op << 12) | (rs_data << 8) | (rs_base << 4) | (offset4 & 0xF)

            elif mnemonic == "BRANCH":
                op = OPCODES["BRANCH"]
                cond = int(args[0])
                target = parse_val(args[1], self.symbol_table) & 0xFF
                code = (op << 12) | (cond << 8) | target

            elif mnemonic in ["SHL", "SHR"]:
                op = OPCODES[mnemonic]
                rd = parse_reg(args[0])
                rs1 = parse_reg(args[1])
                shift = parse_val(args[2], self.symbol_table) & 0xF
                code = (op << 12) | (rd << 8) | (rs1 << 4) | shift

            elif mnemonic == "SYS":
                op = OPCODES["SYS"]
                imm8 = parse_val(args[0], self.symbol_table) & 0xFF
                code = (op << 12) | (0 << 8) | imm8

            elif mnemonic == "LI_DEFERRED":
                rd = parse_reg(args[0])
                val = parse_val(args[1], self.symbol_table)
                low = val & 0xFF
                high = (val >> 8) & 0xFF
                code1 = (OPCODES["LDI"] << 12) | (rd << 8) | low
                code2 = (OPCODES["LDH"] << 12) | (rd << 8) | high
                self.machine_code.append((addr, code1, f"LDI {args[0]}, {low}"))
                self.machine_code.append((addr + 1, code2, f"LDH {args[0]}, {high}"))
                continue

            else:
                raise ValueError(f"Unknown mnemonic: '{mnemonic}' on line: '{orig}'")

            self.machine_code.append((addr, code, orig))

    def assemble(self, source_text):
        lines = source_text.splitlines()
        self.pass1_expand(lines)
        self.pass2_assemble()
        return self.machine_code

    def write_hex(self, output_path, pad_to=256):
        with open(output_path, "w") as f:
            for i in range(pad_to):
                if i < len(self.machine_code):
                    addr, code, _ = self.machine_code[i]
                    f.write(f"{code:04X}\n")
                else:
                    f.write("0000\n")

    def write_lst(self, output_path):
        with open(output_path, "w") as f:
            f.write("; ==========================================================\n")
            f.write("; KOCTA-16 Assembly Listing\n")
            f.write("; Symbol Table:\n")
            for sym, saddr in sorted(self.symbol_table.items(), key=lambda x: x[1]):
                f.write(f";   {sym:<16} = 0x{saddr:02X} ({saddr})\n")
            f.write("; ==========================================================\n\n")
            for addr, code, orig in self.machine_code:
                bin_str = f"{code:016b}"
                f.write(f"[{addr:02X}]  {code:04X}  {bin_str[:4]}_{bin_str[4:8]}_{bin_str[8:12]}_{bin_str[12:]}  |  {orig}\n")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 assembler.py <input.asm> [output.hex] [output.lst]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_hex = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(input_file)[0] + ".hex"
    output_lst = sys.argv[3] if len(sys.argv) > 3 else os.path.splitext(input_file)[0] + ".lst"

    with open(input_file, "r") as f:
        src = f.read()

    asm = Assembler()
    asm.assemble(src)
    asm.write_hex(output_hex)
    asm.write_lst(output_lst)
    print(f"Assembly completed: {len(asm.machine_code)} instructions generated.")
    print(f"Hex output: {output_hex}")
    print(f"Listing output: {output_lst}")

if __name__ == "__main__":
    main()
