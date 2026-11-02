#!/usr/bin/env python3
"""
Generates initial RAM image for Binary Search verification.
"""
def create_ram_hex(target=77, output_path="firmware/binary_search_data.hex"):
    array = [10, 20, 35, 42, 55, 68, 77, 89, 99, 120, 150, 200, 310, 450, 500, 999]
    ram = [0] * 256
    ram[0x00] = target
    ram[0x01] = 0x0000
    ram[0x02] = len(array)
    for i, val in enumerate(array):
        ram[0x10 + i] = val

    with open(output_path, "w") as f:
        for val in ram:
            f.write(f"{val:04X}\n")
    print(f"RAM initialized for target={target} -> {output_path}")

if __name__ == "__main__":
    create_ram_hex(77)
