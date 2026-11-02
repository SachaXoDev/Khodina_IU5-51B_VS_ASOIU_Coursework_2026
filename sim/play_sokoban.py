#!/usr/bin/env python3
"""
===============================================================================
KOCTA-16 Interactive Console Bridge: Sokoban (Task 18)
Coursework VS ASOIU 2026, Variant 16 (Grade 5 Demonstration)
Student: Khodina A. P. (IU5-51B)

Enables real-time gameplay of Sokoban in the macOS Terminal.
Supports:
  - Arrow keys: Left, Right, Up, Down (both CSI and SS3 modes)
  - English WASD: W, A, S, D
  - Russian layout: Ц, Ф, Ы, В (автоматическая поддержка русской раскладки!)
===============================================================================
"""

import os
import sys
import time
import termios
import tty

# ANSI Colors
C_RESET   = "\033[0m"
C_BOLD    = "\033[1m"
C_CYAN    = "\033[36m"
C_GREEN   = "\033[32m"
C_YELLOW  = "\033[33m"
C_RED     = "\033[31m"
C_BLUE    = "\033[34m"
C_MAGENTA = "\033[35m"
C_CLEAR   = "\033[2J\033[H"

class SokobanEmulator:
    """Cycle-accurate KOCTA-16 CPU & MMIO emulator for Sokoban."""
    def __init__(self, hex_path):
        self.rom = [0] * 256
        self.ram = [0] * 256
        self.rf = [0] * 16
        self.pc = 0
        self.halted = False
        self.key_buffer = 0
        self.key_available = False
        self.flag_z = False
        self.flag_n = False
        self.load_rom(hex_path)

    def load_rom(self, path):
        if not os.path.exists(path):
            return
        with open(path, "r") as f:
            addr = 0
            for line in f:
                line = line.strip()
                if not line or line.startswith("//") or line.startswith("#"):
                    continue
                self.rom[addr] = int(line, 16)
                addr += 1

    def push_logic(self, tile_target, tile_beyond):
        """Hardware implementation of PUSH_LOGIC accelerator."""
        T_FLOOR       = 0x20 # ' '
        T_BOX         = 0x24 # '$'
        T_GOAL        = 0x2E # '.'
        T_BOX_ON_GOAL = 0x2A # '*'
        T_PLAYER      = 0x40 # '@'
        T_PLAYER_GOAL = 0x2B # '+'

        c1_is_walkable = (tile_target in [T_FLOOR, T_GOAL])
        c1_is_box      = (tile_target in [T_BOX, T_BOX_ON_GOAL])
        c2_is_free     = (tile_beyond in [T_FLOOR, T_GOAL])

        if c1_is_walkable:
            move_status = 1
            new_c1 = T_PLAYER_GOAL if (tile_target == T_GOAL) else T_PLAYER
            new_c2 = tile_beyond
        elif c1_is_box and c2_is_free:
            move_status = 2
            new_c1 = T_PLAYER_GOAL if (tile_target == T_BOX_ON_GOAL) else T_PLAYER
            new_c2 = T_BOX_ON_GOAL if (tile_beyond == T_GOAL) else T_BOX
        else:
            move_status = 0
            new_c1 = tile_target
            new_c2 = tile_beyond

        return ((new_c2 & 0xFF) << 8) | (move_status & 0x03)

    def step(self):
        if self.halted:
            return False

        instr = self.rom[self.pc]
        op = (instr >> 12) & 0xF
        rd = (instr >> 8) & 0xF
        rs1 = (instr >> 4) & 0xF
        rs2 = instr & 0xF
        imm8 = instr & 0xFF

        next_pc = (self.pc + 1) & 0xFF

        if op == 0x0: # NOP
            pass
        elif op == 0x1: # ADD
            res = (self.rf[rs1] + self.rf[rs2]) & 0xFFFF
            if rd != 0: self.rf[rd] = res
            self.flag_z = (res == 0); self.flag_n = bool(res & 0x8000)
        elif op == 0x2: # SUB
            res = (self.rf[rs1] - self.rf[rs2]) & 0xFFFF
            if rd != 0: self.rf[rd] = res
            self.flag_z = (res == 0); self.flag_n = bool(res & 0x8000)
        elif op == 0x3: # AND
            res = (self.rf[rs1] & self.rf[rs2]) & 0xFFFF
            if rd != 0: self.rf[rd] = res
            self.flag_z = (res == 0); self.flag_n = bool(res & 0x8000)
        elif op == 0x4: # OR
            res = (self.rf[rs1] | self.rf[rs2]) & 0xFFFF
            if rd != 0: self.rf[rd] = res
            self.flag_z = (res == 0); self.flag_n = bool(res & 0x8000)
        elif op == 0x5: # XOR
            res = (self.rf[rs1] ^ self.rf[rs2]) & 0xFFFF
            if rd != 0: self.rf[rd] = res
            self.flag_z = (res == 0); self.flag_n = bool(res & 0x8000)
        elif op == 0x6: # CMP
            v1 = self.rf[rs1]
            v2 = self.rf[rs2]
            self.flag_z = (v1 == v2)
            s1 = v1 if v1 < 0x8000 else v1 - 0x10000
            s2 = v2 if v2 < 0x8000 else v2 - 0x10000
            self.flag_n = (s1 < s2)
        elif op == 0x7: # LDI
            if rd != 0: self.rf[rd] = imm8
        elif op == 0x8: # LDH
            if rd != 0: self.rf[rd] = ((imm8 << 8) | (self.rf[rd] & 0xFF)) & 0xFFFF
        elif op == 0x9: # LOAD
            addr = (self.rf[rs1] + rs2) & 0xFFFF
            val = 0
            if addr >= 0xFF00:
                if addr == 0xFF01:
                    val = self.key_buffer
                    self.key_available = False
                elif addr == 0xFF02:
                    val = 1 if self.key_available else 0
                elif addr == 0xFF16:
                    val = self.ram[1]
                elif addr == 0xFF17:
                    val = self.ram[2]
            elif addr < 256:
                val = self.ram[addr]
            if rd != 0: self.rf[rd] = val
        elif op == 0xA: # STORE
            addr = (self.rf[rs1] + rs2) & 0xFFFF
            val = self.rf[rd]
            if addr >= 0xFF00:
                if addr == 0xFF01:
                    self.key_available = False
                elif addr == 0xFF16:
                    self.ram[1] = val
                elif addr == 0xFF17:
                    self.ram[2] = val
                elif addr == 0xFFFF and (val & 1):
                    self.halted = True
            elif addr < 256:
                self.ram[addr] = val
        elif op == 0xB: # BRANCH
            cond = rd
            target = imm8
            taken = False
            if cond == 0: taken = self.flag_z
            elif cond == 1: taken = not self.flag_z
            elif cond == 2: taken = self.flag_n
            elif cond == 3: taken = not self.flag_n
            elif cond == 4: taken = True
            elif cond == 5: # CALL
                self.rf[14] = next_pc
                taken = True
            elif cond == 6: # RET
                next_pc = self.rf[14]
                taken = False

            if taken:
                next_pc = target
        elif op == 0xC: # SHL
            res = (self.rf[rs1] << (rs2 & 0xF)) & 0xFFFF
            if rd != 0: self.rf[rd] = res
        elif op == 0xD: # SHR
            res = (self.rf[rs1] >> (rs2 & 0xF)) & 0xFFFF
            if rd != 0: self.rf[rd] = res
        elif op == 0xE: # PUSH_LOGIC or HALT
            if rd == 0 and (imm8 == 0 or imm8 == 0xFF):
                self.halted = True
            else:
                target_tile = self.rf[rs1] & 0xFF
                beyond_tile = self.rf[rs2] & 0xFF
                res = self.push_logic(target_tile, beyond_tile)
                if rd != 0: self.rf[rd] = res
                self.flag_z = (res == 0); self.flag_n = bool(res & 0x8000)

        self.pc = next_pc
        return True

    def run_until_input(self):
        steps = 0
        while not self.halted and steps < 20000:
            instr = self.rom[self.pc]
            op = (instr >> 12) & 0xF
            rs1 = (instr >> 4) & 0xF
            rs2 = instr & 0xF
            if op == 0x9:
                addr = (self.rf[rs1] + rs2) & 0xFFFF
                if addr == 0xFF02 and not self.key_available:
                    return
            self.step()
            steps += 1

    def inject_key(self, key_code):
        self.key_buffer = key_code
        self.key_available = True

def render_map(emu):
    print(C_CLEAR, end="")
    print(f"{C_BOLD}{C_CYAN}======================================================{C_RESET}")
    print(f"{C_BOLD}{C_YELLOW}  KOCTA-16 SoC: SOKOBAN (СОКОБАН - TASK 18)           {C_RESET}")
    print(f"{C_BOLD}{C_CYAN}  Аппаратный ускоритель: PUSH_LOGIC (1 такт на ход)  {C_RESET}")
    print(f"{C_BOLD}{C_CYAN}======================================================{C_RESET}")
    
    moves = emu.ram[1]
    won = emu.ram[2]
    status_str = f"{C_BOLD}{C_GREEN}ПОБЕДА! ЯЩИК НА ЦЕЛИ!{C_RESET}" if won else f"{C_YELLOW}В игре{C_RESET}"
    print(f"Ходов сделано: {C_BOLD}{moves}{C_RESET} | Статус: {status_str}\n")

    # 10 cols x 10 rows from RAM[16..115]
    for r in range(10):
        row_str = "    "
        for c in range(10):
            tile = chr(emu.ram[16 + r * 10 + c])
            if tile == '#':
                row_str += f"{C_BLUE}{C_BOLD}██{C_RESET}"
            elif tile == '@':
                row_str += f"{C_YELLOW}{C_BOLD}🚹{C_RESET}"
            elif tile == '$':
                row_str += f"{C_RED}{C_BOLD}📦{C_RESET}"
            elif tile == '.':
                row_str += f"{C_GREEN}{C_BOLD}🎯{C_RESET}"
            elif tile == '*':
                row_str += f"{C_GREEN}{C_BOLD}✅{C_RESET}"
            elif tile == '+':
                row_str += f"{C_YELLOW}{C_BOLD}🚹{C_RESET}"
            else:
                row_str += "  "
        print(row_str)

    print(f"\n{C_CYAN}------------------------------------------------------{C_RESET}")
    if won:
        print(f"\n{C_BOLD}{C_GREEN}  ПОЗДРАВЛЯЕМ! ГОЛОВОЛОМКА СОКОБАН РЕШЕНА!{C_RESET}\n")
    print(f"{C_BOLD}Управление:{C_RESET}")
    print("  Стрелки: [<-] Влево   [->] Вправо   [^] Вверх   [v] Вниз")
    print("  Буквы (Eng): [A] Влево   [D] Вправо   [W] Вверх   [S] Вниз")
    print("  Буквы (Рус): [Ф] Влево   [В] Вправо   [Ц] Вверх   [Ы] Вниз")
    print("  [R / К] Сброс игры  [Q / Й] Выход")
    print(f"{C_CYAN}------------------------------------------------------{C_RESET}")

def get_key():
    """
    Reads raw bytes directly from stdin using unbuffered OS syscall.
    Reliably decodes all macOS escape sequences for arrow keys and UTF-8 Russian characters.
    """
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        data = os.read(fd, 32)
        if not data:
            return None

        # Ctrl+C
        if data == b'\x03':
            return 'q'

        try:
            text = data.decode('utf-8', errors='ignore')
        except Exception:
            return None

        if not text:
            return None

        # Handle arrow keys (ANSI escape sequences)
        if text.startswith('\x1b'):
            if len(text) > 1:
                last = text[-1]
                if last == 'A': return 'w'  # Up arrow
                elif last == 'B': return 's'  # Down arrow
                elif last == 'C': return 'd'  # Right arrow
                elif last == 'D': return 'a'  # Left arrow
            return None

        # Handle regular letters (case-insensitive English & Russian)
        ch = text[0].lower()
        mapping = {
            'w': 'w', 'ц': 'w',
            's': 's', 'ы': 's',
            'a': 'a', 'ф': 'a',
            'd': 'd', 'в': 'd',
            'q': 'q', 'й': 'q',
            'r': 'r', 'к': 'r',
        }
        return mapping.get(ch, None)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    hex_path = os.path.join(script_dir, "..", "firmware", "sokoban.hex")
    
    if not os.path.exists(hex_path):
        print(f"Error: {hex_path} not found. Run 'make assemble' first.")
        return

    emu = SokobanEmulator(hex_path)
    emu.run_until_input()

    try:
        while not emu.halted:
            render_map(emu)
            cmd = get_key()
            if cmd is None:
                continue

            if cmd == 'q':
                break
            elif cmd == 'r':
                emu = SokobanEmulator(hex_path)
                emu.run_until_input()
                continue
            elif cmd in ['w', 's', 'a', 'd']:
                emu.inject_key(ord(cmd))
                emu.step()
                emu.run_until_input()

    except KeyboardInterrupt:
        pass
    finally:
        print(f"\n{C_BOLD}Сеанс игры Сокобан завершен.{C_RESET}\n")

if __name__ == "__main__":
    main()
